//
//  ControlsPanel.swift
//  Motion Hub
//
//  Right panel with controls and settings
//

import SwiftUI

struct ControlsPanel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                header

                Divider()
                    .background(AppColors.border)

                // Controls section
                controlsSection

                Divider()
                    .background(AppColors.border)

                // Frequency range section
                frequencySection

                Divider()
                    .background(AppColors.border)

                // Actions section
                actionsSection

                Divider()
                    .background(AppColors.border)

                // Settings section
                settingsSection

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Controls")
                .font(AppFonts.displayBold(size: 16))
                .foregroundColor(AppColors.textPrimary)
                .textCase(.uppercase)
                .tracking(1)

            Text("Adjust visual parameters")
                .font(AppFonts.mono(size: 10))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlsSection: some View {
        VStack(spacing: 20) {
            // Row 1: Intensity, Glitch Amount
            HStack(spacing: 20) {
                KnobView(
                    value: $appState.intensity,
                    label: "Intensity",
                    displayValue: "\(Int(appState.intensity * 100))%"
                )

                KnobView(
                    value: $appState.glitchAmount,
                    label: "Glitch",
                    displayValue: "\(Int(appState.glitchAmount * 100))%"
                )
            }

            // Row 2: Speed, Color Shift
            HStack(spacing: 20) {
                KnobView(
                    value: Binding(
                        get: { Double(appState.speed - 1) / 3.0 },
                        set: { appState.speed = Int($0 * 3) + 1 }
                    ),
                    label: "Speed",
                    displayValue: "\(appState.speed)X",
                    stepped: true,
                    steps: ["1X", "2X", "3X", "4X"]
                )

                KnobView(
                    value: $appState.colorShift,
                    label: "Color Shift",
                    displayValue: "\(Int(appState.colorShift * 100))%"
                )
            }
        }
    }

    private var frequencySection: some View {
        VStack(spacing: 16) {
            Text("Frequency Range")
                .font(AppFonts.displayBold(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                KnobView(
                    value: Binding(
                        get: { logarithmicToLinear(appState.freqMin) },
                        set: { appState.freqMin = linearToLogarithmic($0) }
                    ),
                    label: "Freq Min",
                    displayValue: formatFrequency(appState.freqMin)
                )

                KnobView(
                    value: Binding(
                        get: { logarithmicToLinear(appState.freqMax) },
                        set: { appState.freqMax = linearToLogarithmic($0) }
                    ),
                    label: "Freq Max",
                    displayValue: formatFrequency(appState.freqMax)
                )
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(AppFonts.displayBold(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            ControlButton(
                label: "Monochrome",
                icon: "circle.lefthalf.filled",
                isToggle: true,
                isActive: $appState.isMonochrome,
                action: {}
            )

            ControlButton(
                label: "Reset",
                icon: "arrow.counterclockwise",
                action: {
                    appState.reset()
                }
            )
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 12) {
            Text("Settings")
                .font(AppFonts.displayBold(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Target FPS
            VStack(alignment: .leading, spacing: 8) {
                Text("Target FPS: \(appState.targetFPS)")
                    .font(AppFonts.mono(size: 11))
                    .foregroundColor(AppColors.textPrimary)

                Slider(
                    value: Binding(
                        get: { Double(appState.targetFPS) },
                        set: { appState.targetFPS = Int($0) }
                    ),
                    in: 15...60,
                    step: 15
                )
                .accentColor(AppColors.accent)
            }
        }
    }

    // MARK: - Helper Functions

    private func formatFrequency(_ freq: Double) -> String {
        if freq >= 1000 {
            return String(format: "%.1f kHz", freq / 1000)
        } else {
            return "\(Int(freq)) Hz"
        }
    }

    private func logarithmicToLinear(_ value: Double) -> Double {
        let minLog = log10(20.0)
        let maxLog = log10(20000.0)
        let valueLog = log10(max(20, value))
        return (valueLog - minLog) / (maxLog - minLog)
    }

    private func linearToLogarithmic(_ value: Double) -> Double {
        let minLog = log10(20.0)
        let maxLog = log10(20000.0)
        return pow(10, minLog + value * (maxLog - minLog))
    }
}
