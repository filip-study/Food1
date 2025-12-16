//
//  ColorPalette.swift
//  Food1
//
//  Created by Claude on 2025-11-14.
//  Premium UI Redesign - Centralized color definitions
//

import SwiftUI

struct ColorPalette {
    // MARK: - Accent Colors

    /// Primary accent color (existing blue)
    static let accentPrimary = Color(hex: "#007AFF")

    /// Secondary accent color (teal) - complements blue
    static let accentSecondary = Color(hex: "#00D4AA")

    /// Tertiary accent color (cyan) - lighter variant for highlights
    static let accentTertiary = Color(hex: "#00E5FF")

    // MARK: - Progress Ring Gradients

    /// Progress 0-30%: Muted blue gradient
    static let progressLowGradient = [
        Color.blue.opacity(0.6),
        Color.blue.opacity(0.8)
    ]

    /// Progress 30-70%: Teal → Blue gradient
    static let progressMediumGradient = [
        Color(hex: "#00D4AA"),  // Teal
        Color(hex: "#007AFF")   // Blue
    ]

    /// Progress 70-100%: Green → Mint gradient
    static let progressHighGradient = [
        Color.green,
        Color.mint
    ]

    /// Progress >100%: Orange → Coral gradient
    static let progressOverGradient = [
        Color.orange,
        Color(hex: "#FF6B6B")  // Coral
    ]

    // MARK: - Macro Colors (Ocean Depth Palette)

    /// Protein macro color - Deep Ocean Blue
    static let macroProtein = Color(hex: "#2563EB")

    /// Carbs macro color - Teal
    static let macroCarbs = Color(hex: "#14B8A6")

    /// Fat macro color - Warm Coral
    static let macroFat = Color(hex: "#FB7185")

    /// Calories color - Warm Amber (for area fills/totals)
    static let calories = Color(hex: "#F59E0B")

    // MARK: - Helper Method for Progress Band Selection

    /// Returns appropriate gradient for given progress percentage
    /// - Parameter progress: Progress value (0.0 to 1.0+)
    /// - Returns: Array of colors for gradient
    static func gradientForProgress(_ progress: Double) -> [Color] {
        switch progress {
        case 0..<0.3:
            return progressLowGradient
        case 0.3..<0.7:
            return progressMediumGradient
        case 0.7...1.0:
            return progressHighGradient
        default: // > 1.0
            return progressOverGradient
        }
    }
}

// MARK: - Color Extension for Hex Initialization

extension Color {
    /// Initialize Color from hex string
    /// - Parameter hex: Hex string (e.g., "#007AFF" or "007AFF")
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
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
