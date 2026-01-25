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

    // TEMPORARILY DISABLED - Testing if these cause the hang
    // @StateObject private var audioAnalyzer = AudioAnalyzer()
    // @StateObject private var midiHandler = MIDIHandler()

    init() {
        print("MotionHubApp init starting...")
        PackManager.setupApplicationDirectories()
        print("MotionHubApp init complete")
    }

    var body: some Scene {
        WindowGroup {
            // Simplified view for testing
            VStack {
                Text("Motion Hub")
                    .font(.largeTitle)
                Text("App started successfully!")
                    .foregroundColor(.green)
            }
            .frame(width: 400, height: 300)
            .environmentObject(appState)
            .environmentObject(packManager)
            .preferredColorScheme(.dark)
            .onAppear {
                print("ContentView appeared!")
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 300)
    }
}
