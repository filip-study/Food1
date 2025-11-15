//
//  GradientProgressRing.swift
//  Food1
//
//  Created by Claude on 2025-11-14.
//  Premium UI Redesign - Gradient progress ring with glow effect
//

import SwiftUI

struct GradientProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let showGlow: Bool

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) var colorScheme

    init(
        progress: Double,
        size: CGFloat = 200,
        lineWidth: CGFloat = 12,
        showGlow: Bool = true
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.showGlow = showGlow
    }

    // Progress band colors using ColorPalette
    private var strokeColors: [Color] {
        ColorPalette.gradientForProgress(progress)
    }

    // Glow color (first color of gradient)
    private var glowColor: Color {
        strokeColors.first ?? .blue
    }

    // Adaptive shadow opacity for light/dark mode
    private var shadowOpacity: Double {
        colorScheme == .light ? 0.6 : 0.8
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Progress ring with gradient and glow
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        colors: strokeColors,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: showGlow ? glowColor.opacity(shadowOpacity) : .clear,
                    radius: 4
                )
                .shadow(
                    color: showGlow ? glowColor.opacity(shadowOpacity * 0.5) : .clear,
                    radius: 12
                )
                .animation(
                    reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.4, dampingFraction: 0.75),
                    value: progress
                )
        }
    }
}

// MARK: - Compact variant for toolbar button
struct GradientProgressRingButton: View {
    let progress: Double
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.medium()
            action()
        }) {
            ZStack {
                GradientProgressRing(
                    progress: progress,
                    size: 64,
                    lineWidth: 6,
                    showGlow: false  // Too small for glow effect
                )

                // Plus icon in center
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityHint("Double tap to add meal")
    }
}

#Preview("Progress Bands") {
    VStack(spacing: 40) {
        VStack {
            Text("0-30%: Muted Blue")
                .font(.caption)
            GradientProgressRing(progress: 0.15, size: 150, lineWidth: 10)
        }

        VStack {
            Text("30-70%: Teal → Blue")
                .font(.caption)
            GradientProgressRing(progress: 0.50, size: 150, lineWidth: 10)
        }

        VStack {
            Text("70-100%: Green → Mint")
                .font(.caption)
            GradientProgressRing(progress: 0.85, size: 150, lineWidth: 10)
        }

        VStack {
            Text(">100%: Orange → Coral")
                .font(.caption)
            GradientProgressRing(progress: 1.20, size: 150, lineWidth: 10)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Button Variant") {
    GradientProgressRingButton(progress: 0.65, action: {})
        .padding()
}
