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
    @StateObject private var appState = AppState()
    @StateObject private var packManager = PackManager()

    // Lazy initialization for potentially problematic services
    @StateObject private var audioAnalyzer = AudioAnalyzer()
    @StateObject private var midiHandler = MIDIHandler()

    init() {
        // Print to confirm init is running
        print("MotionHubApp init starting...")

        // Set up app directories
        PackManager.setupApplicationDirectories()

        print("MotionHubApp init complete")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(audioAnalyzer)
                .environmentObject(midiHandler)
                .environmentObject(packManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    print("ContentView appeared!")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1400, height: 900)
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
