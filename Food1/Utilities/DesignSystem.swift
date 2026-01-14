//
//  DesignSystem.swift
//  Food1
//
//  Centralized design constants for consistent spacing, sizing, and typography
//

import SwiftUI

/// Design system constants for consistent UI across the app
enum DesignSystem {

    // MARK: - Spacing

    enum Spacing {
        /// 4pt - Minimal spacing between closely related elements
        static let xxSmall: CGFloat = 4

        /// 8pt - Small spacing for tight layouts
        static let xSmall: CGFloat = 8

        /// 12pt - Compact spacing
        static let small: CGFloat = 12

        /// 16pt - Standard spacing for most use cases
        static let medium: CGFloat = 16

        /// 20pt - Comfortable spacing between sections
        static let large: CGFloat = 20

        /// 24pt - Generous spacing for visual separation
        static let xLarge: CGFloat = 24

        /// 32pt - Extra large spacing for major sections
        static let xxLarge: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        /// 8pt - Small elements like buttons, badges
        static let small: CGFloat = 8

        /// 12pt - Medium elements like text fields, smaller cards
        static let medium: CGFloat = 12

        /// 16pt - Standard cards and containers
        static let large: CGFloat = 16

        /// 20pt - Meal cards, insight cards
        static let card: CGFloat = 20

        /// 24pt - Hero sections, dashboard cards
        static let hero: CGFloat = 24
    }

    // MARK: - Icon Size

    enum IconSize {
        /// 16pt - Inline icons, badges
        static let small: CGFloat = 16

        /// 24pt - Standard toolbar/button icons
        static let medium: CGFloat = 24

        /// 32pt - Feature icons
        static let large: CGFloat = 32

        /// 64pt - Hero/empty state icons
        static let hero: CGFloat = 64
    }

    // MARK: - Typography

    /// Manrope - Primary brand font for headings, buttons, and UI elements
    /// Variable font supports weights 200-800
    enum Typography {
        /// Font name for the Manrope variable font
        private static let manropeName = "Manrope"

        /// Extra Light (200) - Decorative, large display text
        static func extraLight(size: CGFloat) -> Font {
            .custom(manropeName, size: size).weight(.ultraLight)
        }

        /// Light (300) - Subtle, secondary text
        static func light(size: CGFloat) -> Font {
            .custom(manropeName, size: size).weight(.light)
        }

        /// Regular (400) - Body text, descriptions
        static func regular(size: CGFloat) -> Font {
            .custom(manropeName, size: size).weight(.regular)
        }

        /// Medium (500) - Emphasized body, labels
        static func medium(size: CGFloat) -> Font {
            .custom(manropeName, size: size).weight(.medium)
        }

        /// SemiBold (600) - Subheadings, buttons
        static func semiBold(size: CGFloat) -> Font {
            .custom(manropeName, size: size).weight(.semibold)
        }

        /// Bold (700) - Headings, important UI
        static func bold(size: CGFloat) -> Font {
            .custom(manropeName, size: size).weight(.bold)
        }

        /// ExtraBold (800) - Display, hero text
        static func extraBold(size: CGFloat) -> Font {
            .custom(manropeName, size: size).weight(.heavy)
        }
    }

    // MARK: - Shadow

    enum Shadow {
        /// Standard card shadow
        static func card(colorScheme: ColorScheme) -> some View {
            EmptyView()
                .shadow(
                    color: Color.black.opacity(colorScheme == .light ? 0.06 : 0.12),
                    radius: 12,
                    x: 0,
                    y: 4
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .light ? 0.02 : 0.04),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        }
    }
}
