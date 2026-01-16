//
//  AnimatedMeshBackground.swift
//  Food1
//
//  Premium neutral background with subtle animated depth.
//  Uses iOS 18+ MeshGradient with very slow, organic movement.
//
//  DESIGN PHILOSOPHY:
//  - Pure neutrals: no color tint, lets content (food photos, macro colors) shine
//  - "Invisible" aesthetic: provides depth without competing for attention
//  - Subtle luminosity shifts create premium feel without visible animation
//  - Respects reduceMotion accessibility setting
//
//  WHY NEUTRAL:
//  - Food photos are colorful - background should not add color competition
//  - App UI uses blue/teal/coral for macros - neutral background lets these pop
//  - Matches premium health apps (Oura, Function Health, Apple Health)
//  - Works with any food imagery without color clashing
//

import SwiftUI

/// Animated mesh gradient background with subtle, peaceful motion
/// Uses pure neutrals for a clean, premium aesthetic
@available(iOS 18.0, *)
struct AnimatedMeshBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Animation duration in seconds (longer = more subtle)
    var cycleDuration: Double = 30

    /// Overall opacity multiplier for the gradient
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30, paused: reduceMotion)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let normalizedPhase = (elapsed / cycleDuration).truncatingRemainder(dividingBy: 1.0)

            meshGradient(phase: normalizedPhase)
        }
        .ignoresSafeArea()
    }

    /// Creates the mesh gradient with animated control points
    private func meshGradient(phase: Double) -> some View {
        // Very subtle movement - creates gentle "breathing" effect
        let drift1 = sin(phase * .pi * 2) * 0.03
        let drift2 = cos(phase * .pi * 2) * 0.025
        let drift3 = sin(phase * .pi * 2 + 0.8) * 0.028

        return MeshGradient(
            width: 3,
            height: 4,
            points: [
                // Row 0 (top edge) - FIXED
                .init(0, 0),
                .init(0.5, 0),
                .init(1, 0),

                // Row 1 (interior) - edges fixed, center breathes
                .init(0, 0.33),
                .init(Float(0.5 + drift1), Float(0.33 + drift2)),
                .init(1, 0.33),

                // Row 2 (interior) - edges fixed, center breathes
                .init(0, 0.66),
                .init(Float(0.5 + drift3), Float(0.66 + drift1)),
                .init(1, 0.66),

                // Row 3 (bottom edge) - FIXED
                .init(0, 1),
                .init(0.5, 1),
                .init(1, 1)
            ],
            colors: meshColors
        )
        .opacity(intensity)
    }

    /// Color grid for the mesh (3x4 = 12 colors)
    /// Pure neutrals with subtle luminosity variation for depth
    private var meshColors: [Color] {
        if colorScheme == .dark {
            // Dark mode: Elevated charcoal with visible luminosity zones
            // Softer than pure black, easier on eyes, better depth perception
            return [
                // Row 0 - Top edge (dark charcoal base)
                Color(white: 0.08),
                Color(white: 0.10),
                Color(white: 0.08),

                // Row 1 - Upper area (gentle lift)
                Color(white: 0.10),
                Color(white: 0.13),
                Color(white: 0.10),

                // Row 2 - Middle (luminosity highlight)
                Color(white: 0.11),
                Color(white: 0.14),
                Color(white: 0.11),

                // Row 3 - Bottom (grounding)
                Color(white: 0.09),
                Color(white: 0.11),
                Color(white: 0.09)
            ]
        } else {
            // Light mode: Pure whites with subtle gray shading
            // Creates soft depth without any color tint
            return [
                // Row 0 - Top edge (pure white)
                Color(white: 1.0),
                Color(white: 0.99),
                Color(white: 1.0),

                // Row 1 - Upper area (whisper of gray)
                Color(white: 0.98),
                Color(white: 0.96),
                Color(white: 0.98),

                // Row 2 - Middle (subtle shading)
                Color(white: 0.97),
                Color(white: 0.95),
                Color(white: 0.97),

                // Row 3 - Bottom (slightly warmer white)
                Color(white: 0.99),
                Color(white: 0.97),
                Color(white: 0.99)
            ]
        }
    }
}

/// Fallback for iOS 17 and earlier - static gradient matching the mesh aesthetic
struct StaticGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .light
                ? [Color(white: 1.0), Color(white: 0.96), Color(white: 0.98)]
                : [Color(white: 0.08), Color(white: 0.12), Color(white: 0.09)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Unified background that uses MeshGradient on iOS 18+ or falls back gracefully
struct AdaptiveAnimatedBackground: View {
    var intensity: Double = 1.0
    var cycleDuration: Double = 30

    var body: some View {
        if #available(iOS 18.0, *) {
            AnimatedMeshBackground(cycleDuration: cycleDuration, intensity: intensity)
        } else {
            StaticGradientBackground()
        }
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    ZStack {
        AdaptiveAnimatedBackground()
        VStack {
            Text("Good morning")
                .font(.largeTitle)
            Text("Clean neutral background")
                .foregroundStyle(.secondary)
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ZStack {
        AdaptiveAnimatedBackground()
        VStack {
            Text("Good evening")
                .font(.largeTitle)
            Text("Clean neutral background")
                .foregroundStyle(.secondary)
        }
    }
    .preferredColorScheme(.dark)
}
