//
//  PreviewPanel.swift
//  Motion Hub
//
//  Center panel showing visual preview
//

import SwiftUI
import MetalKit

struct PreviewPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioAnalyzer: AudioAnalyzer

    var body: some View {
        ZStack {
            // Metal view for rendering
            MetalPreviewView(appState: appState, audioAnalyzer: audioAnalyzer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Footer with stats
            VStack {
                Spacer()
                footer
                    .padding()
            }
        }
    }

    private var footer: some View {
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

            // Audio levels
            HStack(spacing: 6) {
                Text("AUDIO")
                    .font(AppFonts.display(size: 10))
                    .foregroundColor(AppColors.textSecondary)

                audioLevelBar(appState.audioLevels.overall)
            }

            Spacer()

            // Performance mode button
            Button(action: {
                appState.isPerformanceMode = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.display")
                    Text("Performance Mode")
                        .font(AppFonts.displayBold(size: 11))
                        .textCase(.uppercase)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.accent.opacity(0.2))
                .foregroundColor(AppColors.accent)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColors.accent, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.bgDark.opacity(0.9))
        .cornerRadius(8)
    }

    private func audioLevelBar(_ level: Float) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(AppColors.bgLight)
                    .frame(height: 4)

                // Level indicator
                Rectangle()
                    .fill(AppColors.accent)
                    .frame(width: geometry.size.width * CGFloat(level), height: 4)
            }
        }
        .frame(width: 60, height: 4)
        .cornerRadius(2)
    }
}

// MARK: - Metal Preview View
struct MetalPreviewView: NSViewRepresentable {
    let appState: AppState
    let audioAnalyzer: AudioAnalyzer

    func makeNSView(context: Context) -> MTKView {
        print("🎨 MetalPreviewView makeNSView starting...")
        let mtkView = MTKView()

        // Safely get Metal device - may be nil on some systems
        if let device = MTLCreateSystemDefaultDevice() {
            print("🎨 Metal device created: \(device.name)")
            mtkView.device = device
            mtkView.colorPixelFormat = .bgra8Unorm
            mtkView.clearColor = MTLClearColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1.0)
            mtkView.delegate = context.coordinator
            mtkView.preferredFramesPerSecond = appState.targetFPS

            // Start paused, unpause after setup
            mtkView.isPaused = true
            mtkView.enableSetNeedsDisplay = false

            // Initialize the visual engine with the device
            print("🎨 Setting up VisualEngine...")
            context.coordinator.setupVisualEngine(device: device, appState: appState)

            // Enable continuous rendering for smooth animations
            if context.coordinator.visualEngine != nil {
                print("🎨 VisualEngine created successfully - enabling continuous rendering")
                mtkView.isPaused = false
                mtkView.enableSetNeedsDisplay = false
                print("🎨 MTKView state - isPaused: \(mtkView.isPaused), delegate: \(mtkView.delegate != nil), device: \(mtkView.device != nil)")
            } else {
                print("🎨 ERROR: VisualEngine creation failed!")
            }
        } else {
            print("🎨 ERROR: Metal is not available on this system")
        }

        print("🎨 MetalPreviewView makeNSView complete")
        print("🎨 MTKView frame: \(mtkView.frame), bounds: \(mtkView.bounds)")
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update target FPS if changed
        nsView.preferredFramesPerSecond = appState.targetFPS

        // Update coordinator's reference to appState and audioAnalyzer
        context.coordinator.appState = appState
        context.coordinator.audioAnalyzer = audioAnalyzer
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState, audioAnalyzer: audioAnalyzer)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var appState: AppState
        var audioAnalyzer: AudioAnalyzer
        var visualEngine: VisualEngine?

        // Frame timing
        private var lastFrameTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        private var frameCount: Int = 0
        private var fpsUpdateTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        private var hasLoggedFirstFrame = false

        init(appState: AppState, audioAnalyzer: AudioAnalyzer) {
            self.appState = appState
            self.audioAnalyzer = audioAnalyzer
            super.init()
        }

        func setupVisualEngine(device: MTLDevice, appState: AppState) {
            self.visualEngine = VisualEngine(device: device)
            self.visualEngine?.appState = appState
            print("🎨 VisualEngine setup complete: \(self.visualEngine != nil ? "success" : "failed")")
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            print("🎨 Drawable size changed: \(size)")
        }

        func draw(in view: MTKView) {
            if !hasLoggedFirstFrame {
                print("🎨 First draw call")
                hasLoggedFirstFrame = true
            }

            // Calculate delta time
            let currentTime = CFAbsoluteTimeGetCurrent()
            let deltaTime = Float(currentTime - lastFrameTime)
            lastFrameTime = currentTime

            // Update FPS counter (only once per second)
            frameCount += 1
            if currentTime - fpsUpdateTime >= 1.0 {
                let fps = frameCount
                frameCount = 0
                fpsUpdateTime = currentTime

                // Update FPS on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.appState.currentFPS = fps
                }
            }

            // Update and render using VisualEngine
            guard let engine = visualEngine else {
                return
            }

            // Read audio levels directly from audioAnalyzer (not appState)
            // to avoid excessive SwiftUI view updates
            engine.update(
                deltaTime: deltaTime,
                audioLevels: audioAnalyzer.levels,
                appState: appState
            )
            engine.render(in: view)
        }
    }
}
