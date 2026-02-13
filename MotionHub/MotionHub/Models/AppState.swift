//
//  AppState.swift
//  Motion Hub
//
//  Central state container using Combine for reactive updates
//

import Foundation
import Combine
import AppKit

class AppState: ObservableObject {
    // MARK: - Controls
    @Published var glitchAmount: Double = 0.35    // 0.0 - 1.0
    @Published var speed: Int = 2                 // 1, 2, 3, 4 (multiplier)
    @Published var colorShift: Double = 0.72      // 0.0 - 1.0 (drives both intensity and hue shift)
    @Published var pulseStrength: Double = 0.6    // 0.0 - 1.0 (how strongly visuals react to beats)
    @Published var freqMin: Double = 80           // Hz (20 - 20000)
    @Published var freqMax: Double = 4200         // Hz (20 - 20000)
    @Published var isMonochrome: Bool = false

    // MARK: - Settings
    @Published var audioInputDevice: AudioDevice?
    @Published var midiInputDevice: MIDIDeviceInfo?
    @Published var outputDisplay: NSScreen?
    @Published var targetFPS: Int = 30            // 15 - 60

    // MARK: - Current Pack
    @Published var currentPack: InspirationPack?
    @Published var extractedArtifacts: ExtractedArtifacts?

    // MARK: - Runtime
    @Published var currentFPS: Int = 0
    @Published var cpuUsage: Double = 0
    @Published var gpuUsage: Double = 0
    @Published var isPerformanceMode: Bool = false

    // MARK: - Audio Analysis
    @Published var audioLevels: AudioLevels = .zero

    // MARK: - UI State
    @Published var showSavePackModal: Bool = false
    @Published var showLoadPackModal: Bool = false
    @Published var isProcessingMedia: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var processingMessage: String = ""

    // MARK: - Methods
    func reset() {
        // Trigger visual reset (handled by VisualEngine)
        NotificationCenter.default.post(name: .resetVisuals, object: nil)
    }

    func loadPackSettings(_ settings: PackSettings) {
        // Use the intensity value from old packs as colorShift (combined control)
        colorShift = settings.intensity
        glitchAmount = settings.glitchAmount
        speed = settings.speed
        pulseStrength = settings.pulseStrength
        freqMin = settings.freqMin
        freqMax = settings.freqMax
        isMonochrome = settings.isMonochrome
        targetFPS = settings.targetFPS
    }

    func getCurrentSettings() -> PackSettings {
        PackSettings(
            intensity: colorShift,
            glitchAmount: glitchAmount,
            speed: speed,
            colorShift: colorShift,
            pulseStrength: pulseStrength,
            freqMin: freqMin,
            freqMax: freqMax,
            isMonochrome: isMonochrome,
            targetFPS: targetFPS
        )
    }
}

// MARK: - Audio Levels
struct AudioLevels: Equatable {
    let overall: Float        // 0.0 - 1.0
    let bass: Float           // Low frequencies
    let mid: Float            // Mid frequencies
    let high: Float           // High frequencies
    let frequencyBand: Float  // Level in user-selected freq range

    static let zero = AudioLevels(
        overall: 0,
        bass: 0,
        mid: 0,
        high: 0,
        frequencyBand: 0
    )
}

// MARK: - Notifications
extension Notification.Name {
    static let resetVisuals = Notification.Name("resetVisuals")
}
