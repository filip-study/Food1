//
//  AnimatedMeshBackground.swift
//  Food1
//
//  Subtle animated mesh gradient background for premium visual depth.
//  Uses iOS 18+ MeshGradient with very slow, organic movement.
//
//  DESIGN PHILOSOPHY:
//  - "Lowkey" aesthetic: barely perceptible motion, never distracting
//  - Colors derived from app palette but heavily muted (0.1-0.3 opacity)
//  - 20-30 second animation cycles feel natural, not mechanical
//  - Respects reduceMotion accessibility setting
//

import SwiftUI

/// Animated mesh gradient background with subtle, peaceful motion
@available(iOS 18.0, *)
struct AnimatedMeshBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Animation phase (0 to 1, loops continuously)
    @State private var phase: CGFloat = 0

    /// Animation duration in seconds (longer = more subtle)
    var cycleDuration: Double = 25

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
        // Subtle movement offsets - ONLY for interior points (not edges!)
        let drift1 = sin(phase * .pi * 2) * 0.04
        let drift2 = cos(phase * .pi * 2) * 0.03
        let drift3 = sin(phase * .pi * 2 + 1) * 0.035

        return MeshGradient(
            width: 3,
            height: 4,
            points: [
                // Row 0 (top edge) - FIXED, no movement
                .init(0, 0),
                .init(0.5, 0),
                .init(1, 0),

                // Row 1 (interior) - edges fixed, center moves
                .init(0, 0.33),
                .init(Float(0.5 + drift1), Float(0.33 + drift2)),
                .init(1, 0.33),

                // Row 2 (interior) - edges fixed, center moves
                .init(0, 0.66),
                .init(Float(0.5 + drift3), Float(0.66 + drift1)),
                .init(1, 0.66),

                // Row 3 (bottom edge) - FIXED, no movement
                .init(0, 1),
                .init(0.5, 1),
                .init(1, 1)
            ],
            colors: meshColors
        )
        .opacity(intensity)
    }

    /// Color grid for the mesh (3x4 = 12 colors)
    private var meshColors: [Color] {
        if colorScheme == .dark {
            return [
                // Row 0 - Top edge (near black with hint of blue)
                Color.black,
                Color(hex: "#0A1628").opacity(0.95),
                Color.black,

                // Row 1 - Upper area (subtle blue tint)
                Color(hex: "#0D1F3C").opacity(0.9),
                ColorPalette.accentPrimary.opacity(0.15),
                Color(hex: "#0D1F3C").opacity(0.9),

                // Row 2 - Middle (teal accent, very subtle)
                Color(hex: "#071F1F").opacity(0.85),
                ColorPalette.accentSecondary.opacity(0.12),
                Color(hex: "#071F1F").opacity(0.85),

                // Row 3 - Bottom (deeper, grounding)
                Color(hex: "#050A12"),
                Color(hex: "#0A1525").opacity(0.95),
                Color(hex: "#050A12")
            ]
        } else {
            return [
                // Row 0 - Top edge (pure white)
                Color.white,
                Color.white.opacity(0.98),
                Color.white,

                // Row 1 - Upper area (whisper of blue)
                Color.white.opacity(0.97),
                ColorPalette.accentPrimary.opacity(0.08),
                Color.white.opacity(0.97),

                // Row 2 - Middle (hint of teal)
                Color(hex: "#F0FAFA").opacity(0.95),
                ColorPalette.accentSecondary.opacity(0.06),
                Color(hex: "#F0FAFA").opacity(0.95),

                // Row 3 - Bottom (subtle blue wash)
                Color(hex: "#F5F9FF"),
                ColorPalette.accentPrimary.opacity(0.1),
                Color(hex: "#F5F9FF")
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
                ? [Color.white, Color.blue.opacity(0.08), ColorPalette.accentSecondary.opacity(0.05)]
                : [Color.black, Color.blue.opacity(0.15), ColorPalette.accentSecondary.opacity(0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Unified background that uses MeshGradient on iOS 18+ or falls back gracefully
struct AdaptiveAnimatedBackground: View {
    var intensity: Double = 1.0
    var cycleDuration: Double = 25

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
            Text("Lowkey animated background")
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
            Text("Lowkey animated background")
                .foregroundStyle(.secondary)
        }
    }
    .preferredColorScheme(.dark)
}
