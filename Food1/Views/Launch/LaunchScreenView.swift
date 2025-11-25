//
// LaunchScreenView.swift
// Food1
//
// Animated splash screen with gradient background and food1.icon Liquid Glass logo.
// Uses the actual SVG layer positions from food1.icon/Assets/*.svg
//
// Design: Blue → Teal gradient with 3-circle MacroRings logo (triangular arrangement)
// Animation: Professional scale + glow + sequential ring draw
// Duration: ~1.2s + 0.4s fade out
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var proteinScale: CGFloat = 0.3
    @State private var proteinOpacity: Double = 0
    @State private var carbsScale: CGFloat = 0.3
    @State private var carbsOpacity: Double = 0
    @State private var fatScale: CGFloat = 0.3
    @State private var fatOpacity: Double = 0
    @State private var glowIntensity: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Adaptive gradient background
            LinearGradient(
                gradient: Gradient(colors: colorScheme == .dark ?
                    [Color(hex: "1a1a1a"), Color.black] :
                    [Color(hex: "f5f5f7"), Color(hex: "e5e5ea")]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // food1.icon Liquid Glass MacroRings logo
            // Exact SVG layer positions scaled from 1024x1024 viewBox
            GeometryReader { geometry in
                let size: CGFloat = 280
                let scale = size / 1024
                let strokeWidth: CGFloat = 50 * scale
                let radius: CGFloat = 140 * scale

                ZStack {
                    // Layer 1: Protein ring (top center) - Blue - BOTTOM
                    LiquidGlassRing(
                        gradient: LinearGradient(
                            colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        position: CGPoint(x: 512 * scale, y: 380 * scale),
                        radius: radius,
                        strokeWidth: strokeWidth
                    )
                    .scaleEffect(proteinScale)
                    .opacity(proteinOpacity * 0.9) // 90% opacity

                    // Layer 2: Carbs ring (bottom left) - Teal - MIDDLE
                    LiquidGlassRing(
                        gradient: LinearGradient(
                            colors: [Color(hex: "14B8A6"), Color(hex: "0D9488")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        position: CGPoint(x: 400 * scale, y: 600 * scale),
                        radius: radius,
                        strokeWidth: strokeWidth
                    )
                    .scaleEffect(carbsScale)
                    .opacity(carbsOpacity * 0.9) // 90% opacity

                    // Layer 3: Fat ring (bottom right) - Coral - TOP
                    LiquidGlassRing(
                        gradient: LinearGradient(
                            colors: [Color(hex: "FB7185"), Color(hex: "F43F5E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        position: CGPoint(x: 624 * scale, y: 600 * scale),
                        radius: radius,
                        strokeWidth: strokeWidth
                    )
                    .scaleEffect(fatScale)
                    .opacity(fatOpacity * 0.9) // 90% opacity
                }
                .frame(width: size, height: size)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .shadow(color: colorScheme == .dark ? .white.opacity(glowIntensity * 0.15) : .black.opacity(glowIntensity * 0.08), radius: 30)
                .shadow(color: Color(hex: "2563EB").opacity(glowIntensity * 0.2), radius: 50)
            }
        }
        .onAppear {
            if reduceMotion {
                proteinScale = 1.0
                proteinOpacity = 1.0
                carbsScale = 1.0
                carbsOpacity = 1.0
                fatScale = 1.0
                fatOpacity = 1.0
                glowIntensity = 0.4
            } else {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        // Ring 1: Protein appears first (0-500ms)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.0)) {
            proteinScale = 1.0
            proteinOpacity = 1.0
        }

        // Ring 2: Carbs appears (200-700ms)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.2)) {
            carbsScale = 1.0
            carbsOpacity = 1.0
        }

        // Ring 3: Fat appears (400-900ms)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.4)) {
            fatScale = 1.0
            fatOpacity = 1.0
        }

        // Glow builds up as rings appear (200-900ms)
        withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
            glowIntensity = 0.6
        }

        // Glow settles (900-1100ms)
        withAnimation(.easeOut(duration: 0.2).delay(0.9)) {
            glowIntensity = 0.4
        }
    }
}

/// Single Liquid Glass ring from food1.icon SVG layers
struct LiquidGlassRing: View {
    let gradient: LinearGradient
    let position: CGPoint
    let radius: CGFloat
    let strokeWidth: CGFloat

    var body: some View {
        ZStack {
            // Base ring with gradient
            Circle()
                .stroke(gradient, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4) // Neutral shadow 50%

            // Specular highlight (top-left bright spot)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth * 0.6, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .blur(radius: 4)

            // Translucency effect (subtle blur overlay for glass look)
            Circle()
                .stroke(gradient.opacity(0.3), style: StrokeStyle(lineWidth: strokeWidth * 0.5, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .blur(radius: 6)
        }
        .position(position)
    }
}

// MARK: - Preview

#Preview {
    LaunchScreenView()
}
