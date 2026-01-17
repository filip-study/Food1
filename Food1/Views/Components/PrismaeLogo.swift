//
//  PrismaeLogo.swift
//  Food1
//
//  Prismae logo shape - golden double-chevron design.
//  Converted from SVG: food1.icon/Assets/Asset 7 2.svg
//  viewBox: 0 0 532.26 558.3
//
//  Used in: LaunchScreenView, AnimatedLogoView (onboarding/welcome)
//

import SwiftUI

/// The Prismae logo as a SwiftUI Shape
/// Golden double-chevron design with curved connecting arcs
struct PrismaeLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Original viewBox dimensions from SVG
        let originalWidth: CGFloat = 532.26
        let originalHeight: CGFloat = 558.3

        // Scale factor to fit the rect while maintaining aspect ratio
        let scale = min(rect.width / originalWidth, rect.height / originalHeight)

        // Center the logo in the rect, accounting for rect's origin position
        // This is crucial when the rect doesn't start at (0,0), e.g., in Canvas drawing
        let xOffset = rect.minX + (rect.width - originalWidth * scale) / 2
        let yOffset = rect.minY + (rect.height - originalHeight * scale) / 2

        // Helper to transform points
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scale + xOffset, y: y * scale + yOffset)
        }

        // Path 1: Right chevron with curved arc
        // M486.45,238.75 l-319.55,319.55 h130.59 l174.86-174.86 c79.88-79.88,79.88-209.39,0-289.26 L378.17,0 h-130.57 l238.85,238.74 Z
        path.move(to: point(486.45, 238.75))
        path.addLine(to: point(486.45 - 319.55, 238.75 + 319.55)) // l-319.55,319.55 → (166.9, 558.3)
        path.addLine(to: point(166.9 + 130.59, 558.3))             // h130.59 → (297.49, 558.3)
        path.addLine(to: point(297.49 + 174.86, 558.3 - 174.86))   // l174.86,-174.86 → (472.35, 383.44)

        // Bezier curve: c79.88-79.88,79.88-209.39,0-289.26
        // Current point: (472.35, 383.44)
        // Control point 1: (472.35 + 79.88, 383.44 - 79.88) = (552.23, 303.56)
        // Control point 2: (472.35 + 79.88, 383.44 - 209.39) = (552.23, 174.05)
        // End point: (472.35 + 0, 383.44 - 289.26) = (472.35, 94.18)
        path.addCurve(
            to: point(472.35, 94.18),
            control1: point(552.23, 303.56),
            control2: point(552.23, 174.05)
        )

        path.addLine(to: point(378.17, 0))                          // L378.17,0
        path.addLine(to: point(378.17 - 130.57, 0))                 // h-130.57 → (247.6, 0)
        path.addLine(to: point(247.6 + 238.85, 0 + 238.74))         // l238.85,238.74 → (486.45, 238.74)
        path.closeSubpath()

        // Path 2: Left chevron with curved arc
        // M224.75,94.17 L130.57,0 H0 l238.85,238.75 L59.11,418.49 h130.59 l35.05-35.05 c79.88-79.87,79.88-209.38,0-289.26
        path.move(to: point(224.75, 94.17))
        path.addLine(to: point(130.57, 0))                          // L130.57,0
        path.addLine(to: point(0, 0))                               // H0
        path.addLine(to: point(238.85, 238.75))                     // l238.85,238.75 (absolute: 238.85, 238.75)
        path.addLine(to: point(59.11, 418.49))                      // L59.11,418.49
        path.addLine(to: point(59.11 + 130.59, 418.49))             // h130.59 → (189.7, 418.49)
        path.addLine(to: point(189.7 + 35.05, 418.49 - 35.05))      // l35.05,-35.05 → (224.75, 383.44)

        // Bezier curve: c79.88-79.87,79.88-209.38,0-289.26
        // Current point: (224.75, 383.44)
        // Control point 1: (224.75 + 79.88, 383.44 - 79.87) = (304.63, 303.57)
        // Control point 2: (224.75 + 79.88, 383.44 - 209.38) = (304.63, 174.06)
        // End point: (224.75 + 0, 383.44 - 289.26) = (224.75, 94.18)
        path.addCurve(
            to: point(224.75, 94.18),
            control1: point(304.63, 303.57),
            control2: point(304.63, 174.06)
        )
        path.closeSubpath()

        return path
    }
}

/// Prismae logo view with Liquid Glass styling
struct PrismaeLogo: View {
    var size: CGFloat = 120
    var animated: Bool = true

    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var glowIntensity: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Prismae golden brand color from SVG (#d6ac25)
    private let goldColor = Color(hex: "D6AC25")
    private let goldDark = Color(hex: "B8941F")

    var body: some View {
        ZStack {
            // Glow effect behind logo
            PrismaeLogoShape()
                .fill(goldColor.opacity(glowIntensity * 0.3))
                .blur(radius: 20)

            // Main logo with gradient fill
            PrismaeLogoShape()
                .fill(
                    LinearGradient(
                        colors: [goldColor, goldDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            // Specular highlight overlay
            PrismaeLogoShape()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .blur(radius: 2)
        }
        .frame(width: size, height: size)
        .scaleEffect(logoScale)
        .opacity(logoOpacity)
        .onAppear {
            if animated {
                animateLogo()
            } else {
                logoScale = 1.0
                logoOpacity = 1.0
                glowIntensity = 0.5
            }
        }
    }

    private func animateLogo() {
        if reduceMotion {
            logoScale = 1.0
            logoOpacity = 1.0
            glowIntensity = 0.5
        } else {
            // Scale and fade in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            // Glow builds up
            withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
                glowIntensity = 0.7
            }

            // Glow settles
            withAnimation(.easeOut(duration: 0.3).delay(0.7)) {
                glowIntensity = 0.5
            }
        }
    }
}

// MARK: - Preview

#Preview("Logo - Light") {
    ZStack {
        Color(UIColor.systemBackground)
        PrismaeLogo(size: 200)
    }
}

#Preview("Logo - Dark") {
    ZStack {
        Color.black
        PrismaeLogo(size: 200)
    }
}

#Preview("Logo Shape Only") {
    PrismaeLogoShape()
        .fill(Color(hex: "D6AC25"))
        .frame(width: 200, height: 200)
        .padding()
}
