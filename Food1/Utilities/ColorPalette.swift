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

    /// Protein macro color - Teal
    static let macroProtein = Color(hex: "#14B8A6")

    /// Fat macro color - Deep Ocean Blue
    static let macroFat = Color(hex: "#2563EB")

    /// Carbs macro color - Warm Coral/Pink
    static let macroCarbs = Color(hex: "#FB7185")

    /// Calories color - Warm Amber (for area fills/totals)
    static let calories = Color(hex: "#F59E0B")

    // MARK: - Semantic Colors

    /// Success state - Emerald green
    static let success = Color(hex: "#10B981")

    /// Warning state - Amber
    static let warning = Color(hex: "#F59E0B")

    /// Error state - Red
    static let error = Color(hex: "#EF4444")

    /// Disabled state - Gray with reduced opacity
    static let disabled = Color.gray.opacity(0.4)

    // MARK: - Onboarding Colors (Premium Editorial Design)

    /// Primary text on onboarding screens - adapts to background type
    static let onboardingText = Color.white

    /// Secondary text - 80% opacity white
    static let onboardingTextSecondary = Color.white.opacity(0.8)

    /// Tertiary text - 65% opacity white (minimum readable)
    static let onboardingTextTertiary = Color.white.opacity(0.65)

    /// Progress bar track - subtle white
    static let onboardingProgressTrack = Color.white.opacity(0.2)

    /// Progress bar fill - solid white
    static let onboardingProgressFill = Color.white

    /// Button background - solid white for primary buttons
    static let onboardingButtonBackground = Color.white

    /// Button text - black on white buttons
    static let onboardingButtonText = Color.black

    /// Card background - uses .ultraThinMaterial in views
    /// Card border (unselected) - subtle white
    static let onboardingCardBorder = Color.white.opacity(0.1)

    /// Card border (selected) - solid white
    static let onboardingCardBorderSelected = Color.white

    /// Input field background - visible white tint
    static let onboardingInputBackground = Color.white.opacity(0.15)

    /// Input field border - subtle definition
    static let onboardingInputBorder = Color.white.opacity(0.2)

    /// Back button background - glass effect
    static let onboardingBackButtonBackground = Color.white.opacity(0.15)

    // MARK: - Solid Background Colors (Act II: Discovery)

    /// Solid dark background for discovery screens (dark mode)
    static let onboardingSolidDark = Color(hex: "#1A1A1A")

    /// Solid light background for discovery screens (light mode)
    static let onboardingSolidLight = Color(hex: "#FAFAF9")

    /// Input field background on solid backgrounds (dark mode)
    static let onboardingInputSolidDark = Color(uiColor: .systemGray5)

    /// Input field background on solid backgrounds (light mode)
    static let onboardingInputSolidLight = Color(uiColor: .systemGray6)

    /// Input field border on solid backgrounds
    static let onboardingInputSolidBorder = Color.primary.opacity(0.1)

    /// Input focus border - brand blue
    static let onboardingInputFocusBorder = Color(hex: "#007AFF")

    // MARK: - Selection Card Colors (Typography-Only Design)

    /// Card background (unselected) on solid backgrounds
    static let onboardingCardSolidBackground = Color(uiColor: .systemGray6)

    /// Card background (selected) - brand blue at 8% opacity
    static let onboardingCardSelectedBackground = Color(hex: "#007AFF").opacity(0.08)

    /// Card border (selected) - brand blue
    static let onboardingCardSelectedBorder = Color(hex: "#007AFF")

    // MARK: - Celebration Colors (Act III)
    // Premium gradient: Deep indigo → Rich violet → Warm rose
    // Avoids generic Apple blue/teal for a more sophisticated feel

    /// Celebration gradient start - deep indigo (premium, luxurious)
    static let celebrationStart = Color(hex: "#312E81")

    /// Celebration gradient middle - rich violet
    static let celebrationMiddle = Color(hex: "#5B21B6")

    /// Celebration gradient end - warm rose/magenta for celebratory warmth
    static let celebrationEnd = Color(hex: "#DB2777")

    /// Gold particle color for celebrations
    static let celebrationGold = Color(hex: "#F59E0B")

    // MARK: - Legacy Onboarding Gradients (kept for compatibility)

    /// Cosmic night gradient for onboarding dark screens
    static let cosmicNight = LinearGradient(
        colors: [
            Color(hex: "#0F0A1F"),
            Color(hex: "#1A1033")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Morning dew gradient for light/celebratory screens
    static let morningDew = LinearGradient(
        colors: [
            Color(hex: "#FEF3C7"),
            Color(hex: "#FDE68A")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Wellness gradient for health-related screens
    static let wellnessGradient = LinearGradient(
        colors: [
            Color(hex: "#0D9488"),
            Color(hex: "#14B8A6")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
