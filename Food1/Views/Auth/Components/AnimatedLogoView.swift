//
//  AnimatedLogoView.swift
//  Food1
//
//  Animated MacroRings logo for authentication screens.
//  Reuses the Liquid Glass design from launch screen at smaller scale.
//

import SwiftUI

struct AnimatedLogoView: View {
    @State private var proteinScale: CGFloat = 0.3
    @State private var proteinOpacity: Double = 0
    @State private var carbsScale: CGFloat = 0.3
    @State private var carbsOpacity: Double = 0
    @State private var fatScale: CGFloat = 0.3
    @State private var fatOpacity: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // MacroRings logo - scaled down for auth screen
            let size: CGFloat = 140  // Smaller than launch screen (280)
            let scale = size / 1024
            let strokeWidth: CGFloat = 50 * scale
            let radius: CGFloat = 140 * scale

            // Layer 1: Protein ring (top center) - Blue
            AuthLiquidGlassRing(
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
            .opacity(proteinOpacity * 0.9)

            // Layer 2: Carbs ring (bottom left) - Teal
            AuthLiquidGlassRing(
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
            .opacity(carbsOpacity * 0.9)

            // Layer 3: Fat ring (bottom right) - Coral
            AuthLiquidGlassRing(
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
            .opacity(fatOpacity * 0.9)
        }
        .frame(width: 140, height: 140)
        .onAppear {
            animateLogo()
        }
    }

    private func animateLogo() {
        if reduceMotion {
            // Instant appearance for accessibility
            proteinScale = 1.0
            proteinOpacity = 1.0
            carbsScale = 1.0
            carbsOpacity = 1.0
            fatScale = 1.0
            fatOpacity = 1.0
        } else {
            // Sequential spring animation
            // Ring 1: Protein (blue) - 0→0.4s
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0).delay(0)) {
                proteinScale = 1.0
                proteinOpacity = 1.0
            }

            // Ring 2: Carbs (teal) - 0.15→0.55s
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0).delay(0.15)) {
                carbsScale = 1.0
                carbsOpacity = 1.0
            }

            // Ring 3: Fat (coral) - 0.3→0.7s
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0).delay(0.3)) {
                fatScale = 1.0
                fatOpacity = 1.0
            }
        }
    }
}

/// Liquid Glass ring component - reused from LaunchScreenView
private struct AuthLiquidGlassRing: View {
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
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)

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

#Preview {
    ZStack {
        Color.black
        AnimatedLogoView()
    }
}
