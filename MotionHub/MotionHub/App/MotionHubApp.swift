//
//  MotionHubApp.swift
//  Motion Hub
//
//  Created by Claude
//  Copyright © 2026 Motion Hub. All rights reserved.
//

import SwiftUI

@main
struct MotionHubApp: App {
    // All StateObjects enabled - testing with simple view (no Metal)
    @StateObject private var appState = AppState()
    @StateObject private var audioAnalyzer = AudioAnalyzer()
    @StateObject private var midiHandler = MIDIHandler()
    @StateObject private var packManager = PackManager()
    @StateObject private var preprocessingManager = PreprocessingManager()

    init() {
        print("🚀 MotionHubApp init starting...")
        // Set up app directories
        PackManager.setupApplicationDirectories()
        print("🚀 MotionHubApp init complete")
    }

    var body: some Scene {
        WindowGroup {
            // Simple test view - no Metal rendering
            VStack(spacing: 20) {
                Text("Motion Hub - All StateObjects Enabled")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                Text("No Metal rendering in this test")
                    .foregroundColor(.gray)
                Text("If this works without hanging, the issue is with Metal/PreviewPanel")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .environmentObject(appState)
            .environmentObject(audioAnalyzer)
            .environmentObject(midiHandler)
            .environmentObject(packManager)
            .environmentObject(preprocessingManager)
            .onAppear {
                print("🚀 Test view appeared!")
            }
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Pack") {
                Button("Save Pack...") {
                    appState.showSavePackModal = true
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Load Pack...") {
                    appState.showLoadPackModal = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("View") {
                Button("Performance Mode") {
                    appState.isPerformanceMode.toggle()
                }
                .keyboardShortcut(.space, modifiers: .command)
            }
        }
    }
}
