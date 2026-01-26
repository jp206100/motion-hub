//
//  AudioAnalyzer.swift
//  Motion Hub
//
//  Real-time audio analysis using AVFoundation and Accelerate framework for FFT
//

import Foundation
import AVFoundation
import Accelerate
import Combine
import AudioToolbox

class AudioAnalyzer: ObservableObject {
    // MARK: - Published Properties
    @Published var levels: AudioLevels = .zero
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDevice: AudioDevice?
    @Published var permissionStatus: PermissionStatus = .unknown

    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
    }

    // MARK: - Configuration
    private var sampleRate: Double = 44100     // Will be updated to match hardware
    private let bufferSize: Int = 2048          // ~46ms latency at 44.1kHz
    private let fftSize: Int = 2048

    // MARK: - Audio Engine
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode

    // MARK: - FFT Setup
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    private var magnitudes: [Float]

    // MARK: - Smoothing
    private var smoothedLevels: AudioLevels = .zero
    private let smoothingFactor: Float = 0.7

    // MARK: - State
    private var isRunning = false

    init() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode

        // Create Hanning window
        window = [Float](repeating: 0, count: fftSize)
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Create FFT setup
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )

        // Request permission before loading devices
        requestMicrophonePermission()
    }

    // MARK: - Permission Handling

    func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            DebugLogger.shared.info("Microphone permission already granted", context: "Audio")
            DispatchQueue.main.async {
                self.permissionStatus = .granted
            }
            setupAudioEngine()
            loadAvailableDevices()

        case .notDetermined:
            DebugLogger.shared.info("Requesting microphone permission...", context: "Audio")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        DebugLogger.shared.info("Microphone permission granted", context: "Audio")
                        self?.permissionStatus = .granted
                        self?.setupAudioEngine()
                        self?.loadAvailableDevices()
                    } else {
                        DebugLogger.shared.warning("Microphone permission denied", context: "Audio")
                        self?.permissionStatus = .denied
                    }
                }
            }

        case .denied:
            DebugLogger.shared.warning("Microphone permission denied - user must enable in System Settings", context: "Audio")
            DispatchQueue.main.async {
                self.permissionStatus = .denied
            }

        case .restricted:
            DebugLogger.shared.warning("Microphone permission restricted", context: "Audio")
            DispatchQueue.main.async {
                self.permissionStatus = .restricted
            }

        @unknown default:
            DebugLogger.shared.warning("Unknown microphone permission status", context: "Audio")
        }
    }

    func refreshDevices() {
        DebugLogger.shared.info("Refreshing audio devices...", context: "Audio")
        // Re-check permission status first
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DebugLogger.shared.info("Current permission status: \(status.rawValue)", context: "Audio")

        if status == .authorized {
            DispatchQueue.main.async {
                self.permissionStatus = .granted
            }
            loadAvailableDevices()
        } else if status == .notDetermined {
            requestMicrophonePermission()
        } else {
            DispatchQueue.main.async {
                self.permissionStatus = .denied
            }
            // Still try to load devices - Core Audio enumeration might work without permission
            loadAvailableDevices()
        }
    }

    deinit {
        stop()
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        // Use the input node's output format to match hardware sample rate
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        // Update our sample rate to match the hardware
        sampleRate = hardwareFormat.sampleRate

        // Create a compatible mono format with the hardware's sample rate
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: false
        )!

        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(bufferSize),
            format: format
        ) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }

    private func loadAvailableDevices() {
        #if os(macOS)
        DebugLogger.shared.info("Loading available audio devices...", context: "Audio")

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            DebugLogger.shared.error("Failed to get device list size: OSStatus \(status)", context: "Audio")
            return
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        DebugLogger.shared.debug("Found \(deviceCount) total audio devices", context: "Audio")

        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else {
            DebugLogger.shared.error("Failed to get device list: OSStatus \(status)", context: "Audio")
            return
        }

        var devices: [AudioDevice] = []

        for deviceID in deviceIDs {
            if let device = getDeviceInfo(deviceID: deviceID) {
                let hasInput = hasInputChannels(deviceID: deviceID)
                DebugLogger.shared.debug("Device: \(device.name) (ID: \(device.id)) - hasInput: \(hasInput)", context: "Audio")
                // Only include input devices
                if hasInput {
                    devices.append(device)
                }
            } else {
                DebugLogger.shared.debug("Could not get info for device ID: \(deviceID)", context: "Audio")
            }
        }

        DebugLogger.shared.info("Total input devices found: \(devices.count)", context: "Audio")
        if devices.isEmpty {
            DebugLogger.shared.warning("No input devices found! Check microphone permissions.", context: "Audio")
        }

        DispatchQueue.main.async {
            self.availableDevices = devices
            // Auto-select BlackHole if available
            if let blackHole = devices.first(where: { $0.name.lowercased().contains("blackhole") }) {
                DebugLogger.shared.info("Auto-selecting BlackHole: \(blackHole.name)", context: "Audio")
                self.selectedDevice = blackHole
            }
        }
        #endif
    }

    #if os(macOS)
    private func getDeviceInfo(deviceID: AudioDeviceID) -> AudioDevice? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &name
        )

        guard status == noErr, let deviceName = name?.takeRetainedValue() as String? else {
            return nil
        }

        return AudioDevice(
            id: deviceID,
            name: deviceName,
            uid: "\(deviceID)"
        )
    }

    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return false }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferListPointer
        )

        guard status == noErr else { return false }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        var channelCount = 0

        for buffer in bufferList {
            channelCount += Int(buffer.mNumberChannels)
        }

        return channelCount > 0
    }
    #endif

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0],
              let setup = fftSetup else { return }

        let frameCount = Int(buffer.frameLength)
        var samples = Array(UnsafeBufferPointer(start: channelData, count: min(frameCount, fftSize)))

        // Pad if needed
        while samples.count < fftSize {
            samples.append(0)
        }

        // Apply window
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // Perform FFT
        var realPart = [Float](repeating: 0, count: fftSize)
        var imagPart = [Float](repeating: 0, count: fftSize)
        let zeroImagInput = [Float](repeating: 0, count: fftSize)

        windowedSamples.withUnsafeBufferPointer { samplesPtr in
            zeroImagInput.withUnsafeBufferPointer { zeroImagPtr in
                realPart.withUnsafeMutableBufferPointer { realPtr in
                    imagPart.withUnsafeMutableBufferPointer { imagPtr in
                        vDSP_DFT_Execute(setup, samplesPtr.baseAddress!, zeroImagPtr.baseAddress!, realPtr.baseAddress!, imagPtr.baseAddress!)
                    }
                }
            }
        }

        // Calculate magnitudes
        var tempMagnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<(fftSize / 2) {
            let real = realPart[i]
            let imag = imagPart[i]
            tempMagnitudes[i] = sqrt(real * real + imag * imag)
        }

        magnitudes = tempMagnitudes

        // Analyze frequency bands
        let overall = calculateOverallLevel()
        let bass = analyzeBand(minFreq: 20, maxFreq: 250)
        let mid = analyzeBand(minFreq: 250, maxFreq: 2000)
        let high = analyzeBand(minFreq: 2000, maxFreq: 20000)

        // This will be updated with user-selected range
        let frequencyBand = analyzeBand(minFreq: 80, maxFreq: 4200)

        // Smooth the levels
        let newLevels = AudioLevels(
            overall: overall,
            bass: bass,
            mid: mid,
            high: high,
            frequencyBand: frequencyBand
        )

        smoothedLevels = AudioLevels(
            overall: smooth(smoothedLevels.overall, target: newLevels.overall),
            bass: smooth(smoothedLevels.bass, target: newLevels.bass),
            mid: smooth(smoothedLevels.mid, target: newLevels.mid),
            high: smooth(smoothedLevels.high, target: newLevels.high),
            frequencyBand: smooth(smoothedLevels.frequencyBand, target: newLevels.frequencyBand)
        )

        // Update published property on main thread
        DispatchQueue.main.async {
            self.levels = self.smoothedLevels
        }
    }

    private func calculateOverallLevel() -> Float {
        let sum = magnitudes.reduce(0, +)
        let avg = sum / Float(magnitudes.count)
        return min(1.0, avg * 10) // Scale and clamp
    }

    func analyzeFrequencyBand(minFreq: Double, maxFreq: Double) -> Float {
        return analyzeBand(minFreq: minFreq, maxFreq: maxFreq)
    }

    private func analyzeBand(minFreq: Double, maxFreq: Double) -> Float {
        let minBin = Int(minFreq * Double(fftSize) / sampleRate)
        let maxBin = Int(maxFreq * Double(fftSize) / sampleRate)

        let clampedMinBin = max(0, min(minBin, magnitudes.count - 1))
        let clampedMaxBin = max(clampedMinBin, min(maxBin, magnitudes.count - 1))

        if clampedMinBin >= clampedMaxBin {
            return 0
        }

        let bandMagnitudes = Array(magnitudes[clampedMinBin...clampedMaxBin])
        let sum = bandMagnitudes.reduce(0, +)
        let avg = sum / Float(bandMagnitudes.count)

        return min(1.0, avg * 10) // Scale and clamp
    }

    private func smooth(_ current: Float, target: Float) -> Float {
        return current * smoothingFactor + target * (1.0 - smoothingFactor)
    }

    // MARK: - Public Methods

    func start() {
        guard !isRunning else { return }

        do {
            try audioEngine.start()
            isRunning = true
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }

        audioEngine.stop()
        isRunning = false
    }

    func selectInputDevice(_ device: AudioDevice) {
        guard selectedDevice?.id != device.id else { return }

        selectedDevice = device

        #if os(macOS)
        // Stop current audio processing
        stop()

        // Remove existing tap
        inputNode.removeTap(onBus: 0)

        // Recreate audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode

        // Configure the input node to use the selected device
        configureInputDevice(deviceID: device.id)

        // Reinstall the tap with the new input node
        setupAudioEngine()

        // Restart audio processing
        start()
        #endif
    }

    #if os(macOS)
    private func configureInputDevice(deviceID: AudioDeviceID) {
        // Get the underlying audio unit from the input node
        let audioUnit = inputNode.audioUnit!

        var deviceID = deviceID

        // Set the device for the audio unit's input
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            print("Failed to set audio input device: \(status)")
        }
    }
    #endif
}

// MARK: - Audio Device
struct AudioDevice: Identifiable, Hashable {
    let id: UInt32  // AudioDeviceID on macOS
    let name: String
    let uid: String
}
