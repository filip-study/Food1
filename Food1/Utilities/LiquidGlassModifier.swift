//
//  LiquidGlassModifier.swift
//  Food1
//
//  Reusable liquid glass (glassmorphic) background styling.
//  Provides multi-layer depth with backdrop blur, gradient borders, shadows, and inner highlights.
//
//  WHY THIS ARCHITECTURE:
//  - Centralized liquid glass styling ensures consistency across navigation components
//  - Matches iOS 26 Liquid Glass app icon aesthetic
//  - Adaptive to color scheme (light/dark) and accessibility settings
//  - Multi-layer shadows and highlights create premium depth effect
//

import SwiftUI

// MARK: - Liquid Glass Background View

struct LiquidGlassBackground<S: Shape>: View {
    let shape: S
    let glowColor: Color?

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    init(shape: S, glowColor: Color? = nil) {
        self.shape = shape
        self.glowColor = glowColor
    }

    var body: some View {
        ZStack {
            // Base glassmorphic material
            if reduceTransparency {
                shape
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            } else {
                shape
                    .fill(.ultraThinMaterial)
            }

            // Gradient border
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.2 : 0.3),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )

            // Inner highlight
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.03 : 0.08),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blur(radius: 6)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15),
            radius: 20,
            x: 0,
            y: 8
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08),
            radius: 8,
            x: 0,
            y: 3
        )
    }
}
