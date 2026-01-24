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

class AudioAnalyzer: ObservableObject {
    // MARK: - Published Properties
    @Published var levels: AudioLevels = .zero
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDevice: AudioDevice?

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

        setupAudioEngine()
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

        guard status == noErr else { return }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else { return }

        var devices: [AudioDevice] = []

        for deviceID in deviceIDs {
            if let device = getDeviceInfo(deviceID: deviceID) {
                // Only include input devices
                if hasInputChannels(deviceID: deviceID) {
                    devices.append(device)
                }
            }
        }

        DispatchQueue.main.async {
            self.availableDevices = devices
            // Auto-select BlackHole if available
            if let blackHole = devices.first(where: { $0.name.lowercased().contains("blackhole") }) {
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

        var dataSize: UInt32 = 0
        var deviceName: CFString?

        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return nil }

        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )

        guard status == noErr, let name = deviceName else { return nil }

        return AudioDevice(
            id: deviceID,
            name: name as String,
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
        selectedDevice = device

        // Note: Changing the input device requires recreating the audio engine
        // This is a simplified version - full implementation would handle device switching
        stop()
        // TODO: Implement device switching
        start()
    }
}

// MARK: - Audio Device
struct AudioDevice: Identifiable, Hashable {
    let id: UInt32  // AudioDeviceID on macOS
    let name: String
    let uid: String
}
