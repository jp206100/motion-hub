//
//  FullscreenView.swift
//  Motion Hub
//
//  Fullscreen view for performance mode - shows only visuals without controls
//

import SwiftUI
import MetalKit

struct FullscreenView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioAnalyzer: AudioAnalyzer

    @State private var showControls: Bool = false
    @State private var hideControlsTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Full screen Metal view
            MetalPreviewView(appState: appState, audioAnalyzer: audioAnalyzer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // Exit controls overlay
            if showControls {
                exitOverlay
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea()
        .onTapGesture {
            showControlsTemporarily()
        }
        .onHover { hovering in
            if hovering {
                showControlsTemporarily()
            }
        }
        .onExitCommand {
            exitFullscreen()
        }
        .focusable()
    }

    private var exitOverlay: some View {
        VStack {
            HStack {
                Spacer()

                Button(action: {
                    exitFullscreen()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Exit Fullscreen")
                            .font(AppFonts.displayBold(size: 12))
                        Text("(ESC)")
                            .font(AppFonts.mono(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.bgDark.opacity(0.9))
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(20)
            }

            Spacer()

            // Minimal stats footer
            HStack(spacing: 20) {
                // FPS
                HStack(spacing: 6) {
                    Text("FPS")
                        .font(AppFonts.display(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(appState.currentFPS)")
                        .font(AppFonts.mono(size: 12))
                        .foregroundColor(AppColors.textPrimary)
                }

                Divider()
                    .frame(height: 12)
                    .background(AppColors.border)

                // Audio indicator
                HStack(spacing: 6) {
                    Text("AUDIO")
                        .font(AppFonts.display(size: 10))
                        .foregroundColor(audioAnalyzer.selectedDevice != nil && appState.audioLevels.overall > 0.01 ? AppColors.accent : AppColors.textSecondary)

                    audioLevelBar(appState.audioLevels.overall)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColors.bgDark.opacity(0.7))
            .cornerRadius(8)
            .padding(.bottom, 20)
        }
    }

    private func audioLevelBar(_ level: Float) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppColors.bgLight)
                    .frame(height: 4)

                Rectangle()
                    .fill(AppColors.accent)
                    .frame(width: geometry.size.width * CGFloat(level), height: 4)
            }
        }
        .frame(width: 60, height: 4)
        .cornerRadius(2)
    }

    private func showControlsTemporarily() {
        // Cancel any existing hide task
        hideControlsTask?.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            showControls = true
        }

        // Auto-hide after 3 seconds
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls = false
                    }
                }
            }
        }
    }

    private func exitFullscreen() {
        hideControlsTask?.cancel()
        appState.isPerformanceMode = false
    }
}
