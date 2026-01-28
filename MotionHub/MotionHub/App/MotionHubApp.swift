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
    @StateObject private var audioAnalyzer = AudioAnalyzer()
    @StateObject private var midiHandler = MIDIHandler()
    @StateObject private var packManager = PackManager()
    @StateObject private var preprocessingManager = PreprocessingManager()

    init() {
        // Set up app directories
        PackManager.setupApplicationDirectories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(audioAnalyzer)
                .environmentObject(midiHandler)
                .environmentObject(packManager)
                .environmentObject(preprocessingManager)
                .preferredColorScheme(.dark)
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
