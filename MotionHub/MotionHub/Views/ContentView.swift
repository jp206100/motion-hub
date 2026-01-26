//
//  ContentView.swift
//  Motion Hub
//
//  Main three-panel layout: Inspiration | Preview | Controls
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioAnalyzer: AudioAnalyzer
    @EnvironmentObject var midiHandler: MIDIHandler
    @EnvironmentObject var packManager: PackManager

    var body: some View {
        ZStack {
            // Main three-panel layout
            HStack(spacing: 0) {
                // Left: Inspiration Panel (280px)
                InspirationPanel()
                    .frame(width: 280)
                    .background(AppColors.bgDark)

                Divider()
                    .background(AppColors.border)

                // Center: Preview Panel (flexible)
                PreviewPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.bgDarkest)

                Divider()
                    .background(AppColors.border)

                // Right: Controls Panel (360px)
                ControlsPanel()
                    .frame(width: 360)
                    .background(AppColors.bgDark)
            }

            // Modals
            if appState.showSavePackModal {
                SavePackModal()
            }

            if appState.showLoadPackModal {
                LoadPackModal()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bgDarkest)
        .onReceive(audioAnalyzer.$levels) { levels in
            // Sync audio levels to appState for visual engine
            appState.audioLevels = levels
        }
        .onAppear {
            // Start audio analysis when view appears
            audioAnalyzer.start()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(AudioAnalyzer())
            .environmentObject(MIDIHandler())
            .environmentObject(PackManager())
            .environmentObject(PreprocessingManager())
            .preferredColorScheme(.dark)
            .frame(width: 1400, height: 900)
    }
}
