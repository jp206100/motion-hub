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
    @Published var isAudioAvailable: Bool = false
    @Published var permissionStatus: PermissionStatus = .unknown

    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
    }

    // MARK: - Configuration
    private var sampleRate: Double = 44100
    private let bufferSize: Int = 2048
    private let fftSize: Int = 2048

    // MARK: - Audio Engine (optional - may not be available)
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    // MARK: - FFT Setup
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    private var magnitudes: [Float]

    // MARK: - Smoothing
    private var smoothedLevels: AudioLevels = .zero
    private let smoothingFactor: Float = 0.7

    // MARK: - State
    private var isRunning = false
    private var isSetupComplete = false
    private var isEnablingAudio = false  // Guard against race condition

    init() {
        print("🎤 AudioAnalyzer init() starting...")

        window = [Float](repeating: 0, count: fftSize)
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )

        print("🎤 AudioAnalyzer init() - requesting permission...")

        // Request permission before loading devices
        requestMicrophonePermission()

        print("🎤 AudioAnalyzer init() complete")
    }

    // MARK: - Permission Handling

    func requestMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 requestMicrophonePermission() - status: \(status.rawValue)")

        switch status {
        case .authorized:
            print("🎤 Permission AUTHORIZED - enabling audio...")
            DebugLogger.shared.info("Microphone permission already granted", context: "Audio")
            DispatchQueue.main.async {
                self.permissionStatus = .granted
            }
            enableAudio()

        case .notDetermined:
            print("🎤 Permission NOT DETERMINED - requesting...")
            DebugLogger.shared.info("Requesting microphone permission...", context: "Audio")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                print("🎤 Permission request result: \(granted)")
                DispatchQueue.main.async {
                    if granted {
                        DebugLogger.shared.info("Microphone permission granted", context: "Audio")
                        self?.permissionStatus = .granted
                        self?.enableAudio()
                    } else {
                        DebugLogger.shared.warning("Microphone permission denied", context: "Audio")
                        self?.permissionStatus = .denied
                    }
                }
            }

        case .denied:
            print("🎤 Permission DENIED")
            DebugLogger.shared.warning("Microphone permission denied - user must enable in System Settings", context: "Audio")
            DispatchQueue.main.async {
                self.permissionStatus = .denied
            }

        case .restricted:
            print("🎤 Permission RESTRICTED")
            DebugLogger.shared.warning("Microphone permission restricted", context: "Audio")
            DispatchQueue.main.async {
                self.permissionStatus = .restricted
            }

        @unknown default:
            print("🎤 Permission UNKNOWN")
            DebugLogger.shared.warning("Unknown microphone permission status", context: "Audio")
        }
    }

    func refreshDevices() {
        print("🎤 refreshDevices() called")
        DebugLogger.shared.info("Refreshing audio devices...", context: "Audio")
        // Re-check permission status first
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 Current permission status: \(status.rawValue) (0=notDetermined, 1=restricted, 2=denied, 3=authorized)")
        DebugLogger.shared.info("Current permission status: \(status.rawValue)", context: "Audio")

        if status == .authorized {
            print("🎤 Permission AUTHORIZED - loading devices...")
            DispatchQueue.main.async {
                self.permissionStatus = .granted
            }
            loadAvailableDevices()
        } else if status == .notDetermined {
            print("🎤 Permission NOT DETERMINED - requesting...")
            requestMicrophonePermission()
        } else {
            print("🎤 Permission DENIED or RESTRICTED - still trying to load devices...")
            DispatchQueue.main.async {
                self.permissionStatus = .denied
            }
            // Still try to load devices - Core Audio enumeration might work without permission
            loadAvailableDevices()
        }
    }

    func enableAudio() {
        // Synchronous guards to prevent race condition
        // Both isEnablingAudio and isAudioAvailable must be checked
        guard !isAudioAvailable, !isEnablingAudio else {
            print("🎤 enableAudio() skipped - already enabling or available")
            return
        }

        // Set flag synchronously BEFORE async dispatch to prevent race
        isEnablingAudio = true
        print("🎤 enableAudio() starting initialization...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.initializeAudioEngine()
        }
    }

    private func initializeAudioEngine() {
        print("🎤 initializeAudioEngine() starting on background thread...")
        let hasDevices = safeCheckForInputDevices()

        guard hasDevices else {
            print("🎤 No audio input devices available or CoreAudio unavailable")
            DispatchQueue.main.async {
                self.isEnablingAudio = false  // Reset flag so it can be retried
                self.safeLoadAvailableDevices()
            }
            return
        }

        print("🎤 Creating AVAudioEngine...")
        let engine = AVAudioEngine()
        let input = engine.inputNode

        let hardwareFormat = input.outputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 else {
            print("🎤 Audio input not available - no valid hardware format")
            DispatchQueue.main.async {
                self.isEnablingAudio = false  // Reset flag so it can be retried
                self.safeLoadAvailableDevices()
            }
            return
        }

        print("🎤 Hardware format: \(hardwareFormat.sampleRate) Hz, \(hardwareFormat.channelCount) channels")

        // Create audio format for tap - do this on background thread
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("🎤 Failed to create audio format")
            DispatchQueue.main.async {
                self.isEnablingAudio = false
                self.safeLoadAvailableDevices()
            }
            return
        }

        // Install tap on background thread - this can block!
        print("🎤 Installing audio tap on background thread...")
        input.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(self.bufferSize),
            format: format
        ) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        print("🎤 Audio tap installed")

        // DON'T start the engine automatically - let user select device first
        // Just update state to indicate audio is available
        print("🎤 Audio engine ready, updating state on main thread...")
        DispatchQueue.main.async {
            self.audioEngine = engine
            self.inputNode = input
            self.sampleRate = hardwareFormat.sampleRate
            self.isAudioAvailable = true
            self.isSetupComplete = true
            self.isEnablingAudio = false  // Reset flag - initialization complete
            self.safeLoadAvailableDevices()
            print("🎤 Audio engine initialization complete!")
        }
    }

    private func safeCheckForInputDevices() -> Bool {
        #if os(macOS)
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

        guard status == noErr, dataSize > 0 else { return false }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard deviceCount > 0 else { return false }

        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else { return false }

        for deviceID in deviceIDs {
            if hasInputChannels(deviceID: deviceID) {
                return true
            }
        }

        return false
        #else
        return true
        #endif
    }

    private func safeLoadAvailableDevices() {
        #if os(macOS)
        guard isAudioAvailable || availableDevices.isEmpty else { return }
        #endif
        loadAvailableDevices()
    }

    deinit {
        stop()
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        guard let inputNode = inputNode else {
            print("Cannot setup audio engine - input node not available")
            return
        }

        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        guard hardwareFormat.sampleRate > 0 else {
            print("Audio input not available - no valid hardware format")
            return
        }

        sampleRate = hardwareFormat.sampleRate

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("Failed to create audio format for sample rate: \(hardwareFormat.sampleRate)")
            return
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(bufferSize),
            format: format
        ) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        isSetupComplete = true
    }

    private func loadAvailableDevices() {
        #if os(macOS)
        print("🎤 loadAvailableDevices() starting...")
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
            print("🎤 ERROR: Failed to get device list size: OSStatus \(status)")
            DebugLogger.shared.error("Failed to get device list size: OSStatus \(status)", context: "Audio")
            return
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        print("🎤 Found \(deviceCount) total audio devices")
        DebugLogger.shared.debug("Found \(deviceCount) total audio devices", context: "Audio")

        if deviceCount == 0 {
            print("🎤 ERROR: No audio devices found at all!")
            return
        }

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
            print("🎤 ERROR: Failed to get device list: OSStatus \(status)")
            DebugLogger.shared.error("Failed to get device list: OSStatus \(status)", context: "Audio")
            return
        }

        var devices: [AudioDevice] = []
        var allDeviceNames: [String] = []

        for deviceID in deviceIDs {
            if let device = getDeviceInfo(deviceID: deviceID) {
                allDeviceNames.append(device.name)
                let hasInput = hasInputChannels(deviceID: deviceID)
                print("🎤 Device: '\(device.name)' (ID: \(device.id)) - hasInput: \(hasInput)")
                DebugLogger.shared.debug("Device: \(device.name) (ID: \(device.id)) - hasInput: \(hasInput)", context: "Audio")
                // Only include input devices
                if hasInput {
                    devices.append(device)
                }
            } else {
                print("🎤 Could not get info for device ID: \(deviceID)")
                DebugLogger.shared.debug("Could not get info for device ID: \(deviceID)", context: "Audio")
            }
        }

        print("🎤 All devices found: \(allDeviceNames.joined(separator: ", "))")
        print("🎤 Total INPUT devices found: \(devices.count)")
        DebugLogger.shared.info("Total input devices found: \(devices.count)", context: "Audio")

        if devices.isEmpty {
            print("🎤 WARNING: No input devices found!")
            print("🎤 This could mean:")
            print("🎤   1. No microphone or audio input devices connected")
            print("🎤   2. BlackHole or other virtual audio devices not installed")
            print("🎤   3. Devices don't report input channels correctly")
            DebugLogger.shared.warning("No input devices found! Check microphone permissions.", context: "Audio")
        }

        DispatchQueue.main.async {
            print("🎤 Setting availableDevices to \(devices.count) devices on main thread")
            self.availableDevices = devices
            // Note: Don't auto-select device here - user should manually select
            // Auto-selection was causing the app to freeze by triggering
            // selectInputDevice which blocks the main thread
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

        while samples.count < fftSize {
            samples.append(0)
        }

        var windowedSamples = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

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

        var tempMagnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<(fftSize / 2) {
            let real = realPart[i]
            let imag = imagPart[i]
            tempMagnitudes[i] = sqrt(real * real + imag * imag)
        }

        magnitudes = tempMagnitudes

        let overall = calculateOverallLevel()
        let bass = analyzeBand(minFreq: 20, maxFreq: 250)
        let mid = analyzeBand(minFreq: 250, maxFreq: 2000)
        let high = analyzeBand(minFreq: 2000, maxFreq: 20000)
        let frequencyBand = analyzeBand(minFreq: 80, maxFreq: 4200)

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

        DispatchQueue.main.async {
            self.levels = self.smoothedLevels
        }
    }

    private func calculateOverallLevel() -> Float {
        let sum = magnitudes.reduce(0, +)
        let avg = sum / Float(magnitudes.count)
        return min(1.0, avg * 10)
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

        return min(1.0, avg * 10)
    }

    private func smooth(_ current: Float, target: Float) -> Float {
        return current * smoothingFactor + target * (1.0 - smoothingFactor)
    }

    // MARK: - Public Methods

    func start() {
        guard !isRunning, let audioEngine = audioEngine, isSetupComplete else { return }

        do {
            try audioEngine.start()
            isRunning = true
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }

    func stop() {
        guard isRunning, let audioEngine = audioEngine else { return }

        audioEngine.stop()
        isRunning = false
    }

    func selectInputDevice(_ device: AudioDevice) {
        guard selectedDevice?.id != device.id else { return }

        print("🎤 selectInputDevice: \(device.name)")
        selectedDevice = device

        #if os(macOS)
        stop()
        inputNode?.removeTap(onBus: 0)

        // Do all audio engine setup on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            print("🎤 Creating new audio engine on background thread...")
            let engine = AVAudioEngine()
            let input = engine.inputNode

            // Configure device on background thread
            if let audioUnit = input.audioUnit {
                var deviceID = device.id
                let status = AudioUnitSetProperty(
                    audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &deviceID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                if status != noErr {
                    print("🎤 Failed to set audio input device: \(status)")
                } else {
                    print("🎤 Audio device configured successfully")
                }
            }

            // Get hardware format
            let hardwareFormat = input.outputFormat(forBus: 0)
            guard hardwareFormat.sampleRate > 0 else {
                print("🎤 Audio input not available - no valid hardware format")
                return
            }

            print("🎤 Hardware format: \(hardwareFormat.sampleRate) Hz")

            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: hardwareFormat.sampleRate,
                channels: 1,
                interleaved: false
            ) else {
                print("🎤 Failed to create audio format")
                return
            }

            // Install tap on background thread
            input.installTap(
                onBus: 0,
                bufferSize: AVAudioFrameCount(self.bufferSize),
                format: format
            ) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }

            print("🎤 Audio tap installed, starting engine...")

            // Start engine on background thread
            do {
                try engine.start()
                print("🎤 Audio engine started successfully")

                // Update state on main thread
                DispatchQueue.main.async {
                    self.audioEngine = engine
                    self.inputNode = input
                    self.sampleRate = hardwareFormat.sampleRate
                    self.isSetupComplete = true
                    self.isRunning = true
                }
            } catch {
                print("🎤 Failed to start audio engine: \(error)")
            }
        }
        #endif
    }

    #if os(macOS)
    private func configureInputDevice(deviceID: AudioDeviceID) {
        guard let inputNode = inputNode,
              let audioUnit = inputNode.audioUnit else {
            print("Failed to get audio unit from input node")
            return
        }

        var deviceID = deviceID

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
    let id: UInt32
    let name: String
    let uid: String
}
