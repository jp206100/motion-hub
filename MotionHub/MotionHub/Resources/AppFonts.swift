//
//  AppFonts.swift
//  Motion Hub
//
//  Typography system
//

import SwiftUI

enum AppFonts {
    // Display font: Rajdhani (headers, labels, buttons)
    // Fallback: SF Pro Display
    static func display(size: CGFloat = 14) -> Font {
        Font.custom("Rajdhani", size: size)
            .weight(.regular)
    }

    static func displayBold(size: CGFloat = 14) -> Font {
        Font.custom("Rajdhani-Bold", size: size)
            .weight(.bold)
    }

    // Mono font: IBM Plex Mono (values, metadata, code)
    // Fallback: SF Mono
    static func mono(size: CGFloat = 12) -> Font {
        Font.custom("IBMPlexMono", size: size)
            .monospaced()
    }

    static func monoRegular(size: CGFloat = 12) -> Font {
        Font.custom("IBMPlexMono-Regular", size: size)
            .monospaced()
    }

    // System fallbacks when custom fonts aren't available
    static let displayFallback = Font.system(.body, design: .default)
    static let monoFallback = Font.system(.body, design: .monospaced)
}
