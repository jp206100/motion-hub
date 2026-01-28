//
//  AppFonts.swift
//  Motion Hub
//
//  Typography system - using system fonts for reliability
//

import SwiftUI

enum AppFonts {
    // Display font: System default (clean, modern look)
    static func display(size: CGFloat = 14) -> Font {
        Font.system(size: size, weight: .regular, design: .default)
    }

    static func displayBold(size: CGFloat = 14) -> Font {
        Font.system(size: size, weight: .bold, design: .default)
    }

    // Mono font: System monospaced (values, metadata, code)
    static func mono(size: CGFloat = 12) -> Font {
        Font.system(size: size, weight: .regular, design: .monospaced)
    }

    static func monoRegular(size: CGFloat = 12) -> Font {
        Font.system(size: size, weight: .regular, design: .monospaced)
    }

    // System fallbacks (same as above now)
    static let displayFallback = Font.system(.body, design: .default)
    static let monoFallback = Font.system(.body, design: .monospaced)
}
