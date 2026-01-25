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

    var body: some View {
        ZStack {
            // Metal view for rendering
            MetalPreviewView()
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
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()

        // Safely get Metal device - may be nil on some systems
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
            mtkView.colorPixelFormat = .bgra8Unorm
            mtkView.clearColor = MTLClearColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1.0)
            mtkView.delegate = context.coordinator
        } else {
            print("Metal is not available on this system")
        }

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Updates handled by delegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MTKViewDelegate {
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize
        }

        func draw(in view: MTKView) {
            // Rendering will be implemented by VisualEngine
            // For now, just clear the view
            guard let commandBuffer = view.device?.makeCommandQueue()?.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
                  let drawable = view.currentDrawable else {
                return
            }

            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
