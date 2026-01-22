//
//  AppColors.swift
//  Motion Hub
//
//  Color system based on design spec
//

import SwiftUI

enum AppColors {
    // Backgrounds
    static let bgDarkest = Color(hex: "0a0a0b")
    static let bgDark = Color(hex: "121214")
    static let bgMid = Color(hex: "1a1a1d")
    static let bgLight = Color(hex: "242428")
    static let bgLighter = Color(hex: "2e2e33")

    // Text
    static let textPrimary = Color(hex: "e8e8ea")
    static let textSecondary = Color(hex: "8a8a90")
    static let textDim = Color(hex: "5a5a60")

    // Accent
    static let accent = Color(hex: "3dd9d9")
    static let accentDim = Color(hex: "2ba8a8")

    // Borders
    static let border = Color(hex: "2a2a2e")
    static let borderLight = Color(hex: "3a3a40")

    // States
    static let danger = Color(hex: "d93d3d")
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
