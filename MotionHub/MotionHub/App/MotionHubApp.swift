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
    // Testing StateObjects one by one
    @StateObject private var appState = AppState()
    @StateObject private var audioAnalyzer = AudioAnalyzer()  // TEST 1
    // @StateObject private var midiHandler = MIDIHandler()
    // @StateObject private var packManager = PackManager()
    // @StateObject private var preprocessingManager = PreprocessingManager()

    init() {
        print("🚀 MotionHubApp init starting...")
        // Set up app directories
        PackManager.setupApplicationDirectories()
        print("🚀 MotionHubApp init complete")
    }

    var body: some Scene {
        WindowGroup {
            // TEMP: Minimal test view
            Text("Window Test - AudioAnalyzer enabled")
                .font(.largeTitle)
                .frame(width: 800, height: 600)
                .background(Color.black)
                .foregroundColor(.white)
                .onAppear {
                    print("🚀 Test view appeared!")
                }
        }
        .defaultSize(width: 800, height: 600)
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
