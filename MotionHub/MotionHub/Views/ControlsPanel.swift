//
//  ControlsPanel.swift
//  Motion Hub
//
//  Right panel with controls and settings
//

import SwiftUI

struct ControlsPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioAnalyzer: AudioAnalyzer
    @EnvironmentObject var oscHandler: OSCHandler

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

                Divider()
                    .background(AppColors.border)

                // External Control section (OSC)
                externalControlSection

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

            // Row 3: Pulse Strength (dedicated beat response control)
            HStack(spacing: 20) {
                KnobView(
                    value: $appState.pulseStrength,
                    label: "Pulse",
                    displayValue: "\(Int(appState.pulseStrength * 100))%"
                )

                // Empty space to maintain symmetry, or could add another control later
                Spacer()
                    .frame(width: 80)
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

            // Audio Input Device
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Audio Input")
                        .font(AppFonts.mono(size: 11))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    // Debug info
                    Text("(\(audioAnalyzer.availableDevices.count) devices)")
                        .font(AppFonts.mono(size: 9))
                        .foregroundColor(AppColors.textDim)
                    Button(action: {
                        print("🎤 User clicked refresh button")
                        audioAnalyzer.refreshDevices()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                            Text("Refresh")
                                .font(AppFonts.mono(size: 9))
                        }
                        .foregroundColor(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh audio devices")
                }

                // Permission status message
                if audioAnalyzer.permissionStatus == .denied {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("Microphone access required")
                            .font(AppFonts.mono(size: 10))
                            .foregroundColor(.orange)
                    }
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(AppFonts.mono(size: 10))
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.accent)
                }

                Menu {
                    ForEach(audioAnalyzer.availableDevices) { device in
                        Button(action: {
                            audioAnalyzer.selectInputDevice(device)
                        }) {
                            HStack {
                                Text(device.name)
                                if audioAnalyzer.selectedDevice?.id == device.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    if audioAnalyzer.availableDevices.isEmpty {
                        if audioAnalyzer.permissionStatus == .denied {
                            Text("Grant microphone permission to see devices")
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Text("No audio input devices found")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Divider()

                    Button(action: {
                        audioAnalyzer.refreshDevices()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Devices")
                        }
                    }
                } label: {
                    HStack {
                        Text(audioAnalyzer.selectedDevice?.name ?? "Select Audio Input")
                            .font(AppFonts.mono(size: 11))
                            .foregroundColor(audioAnalyzer.selectedDevice != nil ? AppColors.textPrimary : AppColors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppColors.bgLight)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
            }

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

    private var externalControlSection: some View {
        VStack(spacing: 12) {
            Text("External Control")
                .font(AppFonts.displayBold(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            // OSC Server
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("OSC Server")
                        .font(AppFonts.mono(size: 11))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(oscHandler.isConnected ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(oscHandler.isConnected ? "Active" : "Inactive")
                            .font(AppFonts.mono(size: 9))
                            .foregroundColor(AppColors.textDim)
                    }
                }

                // Enable/Disable toggle
                Toggle(isOn: $oscHandler.isEnabled) {
                    Text("Enable OSC")
                        .font(AppFonts.mono(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                // Port configuration
                HStack {
                    Text("Port:")
                        .font(AppFonts.mono(size: 10))
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Port", value: $oscHandler.port, format: .number)
                        .font(AppFonts.mono(size: 11))
                        .textFieldStyle(.plain)
                        .frame(width: 60)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.bgLight)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.border, lineWidth: 1)
                        )

                    Spacer()

                    // Message counter
                    if oscHandler.messageCount > 0 {
                        Text("\(oscHandler.messageCount) msgs")
                            .font(AppFonts.mono(size: 9))
                            .foregroundColor(AppColors.textDim)
                    }
                }

                // Help text
                Text("Use Max for Live to send OSC from Ableton")
                    .font(AppFonts.mono(size: 9))
                    .foregroundColor(AppColors.textDim)
                    .padding(.top, 2)
            }
            .padding(12)
            .background(AppColors.bgLight.opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            )
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
