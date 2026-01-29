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
        // Simplified layout - just PreviewPanel to test
        PreviewPanel()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.bgDarkest)
            .onAppear {
                audioAnalyzer.refreshDevices()
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
