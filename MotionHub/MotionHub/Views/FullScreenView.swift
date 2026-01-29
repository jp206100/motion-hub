//
//  FullScreenView.swift
//  Motion Hub
//
//  Fullscreen view showing only the Metal visual preview
//

import SwiftUI
import MetalKit

// MARK: - Fullscreen Window Controller
class FullScreenWindowController {
    static let shared = FullScreenWindowController()
    private var fullscreenWindow: NSWindow?
    private var eventMonitor: Any?

    func openFullScreen(appState: AppState, audioAnalyzer: AudioAnalyzer) {
        // Close existing fullscreen window if any
        closeFullScreen()

        // Get the main screen or use the first available screen
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        // Create fullscreen window
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .statusBar
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.fullScreenPrimary, .managed]

        // Create the Metal view content
        let contentView = FullScreenContentView(appState: appState, audioAnalyzer: audioAnalyzer)

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.setFrame(screen.frame, display: true)

        // Toggle to native fullscreen
        window.toggleFullScreen(nil)

        self.fullscreenWindow = window
        appState.isFullScreen = true

        // Add ESC key monitor
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak appState] event in
            if event.keyCode == 53 { // ESC key
                self?.closeFullScreen()
                appState?.isFullScreen = false
                return nil
            }
            return event
        }
    }

    func closeFullScreen() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        if let window = fullscreenWindow {
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
            window.close()
            fullscreenWindow = nil
        }
    }
}

// MARK: - Fullscreen Content View
struct FullScreenContentView: View {
    let appState: AppState
    let audioAnalyzer: AudioAnalyzer

    var body: some View {
        ZStack {
            MetalPreviewView(appState: appState, audioAnalyzer: audioAnalyzer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}
