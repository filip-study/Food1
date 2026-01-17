//
//  CalculatingView.swift
//  Food1
//
//  Anticipation-building screen shown before revealing nutrition targets.
//
//  REDESIGN:
//  - Forest floor Midjourney image background
//  - Simple pulsing circle indicator (no old MacroRings logo)
//  - 4-second duration for meaningful computation feel
//  - Subtle pulse haptic every second
//  - Success haptic at end
//

import SwiftUI

struct CalculatingView: View {

    // MARK: - Properties

    var onComplete: () -> Void

    // MARK: - State

    @State private var currentPhase = 0
    @State private var showContent = false
    @State private var pulseScale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Calculation phases
    private let phases = [
        "Analyzing your goals...",
        "Calculating daily needs...",
        "Optimizing macros...",
        "Personalizing your plan..."
    ]

    // Total duration before auto-advancing
    private let totalDuration: Double = 4.0

    // MARK: - Body

    var body: some View {
        ZStack {
            // Midjourney forest floor image background
            OnboardingBackground(theme: .forestFloor)

            VStack(spacing: 40) {
                Spacer()

                // Simple pulsing indicator (NOT the old MacroRings logo)
                loadingIndicator
                    .frame(width: 120, height: 120)

                // Phase text
                VStack(spacing: 12) {
                    Text("Building your plan")
                        .font(DesignSystem.Typography.bold(size: 28))
                        .foregroundStyle(.white)
                        .opacity(showContent ? 1 : 0)

                    Text(phases[currentPhase])
                        .font(DesignSystem.Typography.medium(size: 17))
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.opacity)
                        .id(currentPhase)
                        .opacity(showContent ? 1 : 0)
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Loading Indicator (Simple, No Old Logo)

    private var loadingIndicator: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(pulseScale)

            // Simple pulsing ring
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                .frame(width: 60, height: 60)
                .scaleEffect(pulseScale)

            // Center dot
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 12, height: 12)
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        // Show content
        withAnimation(.easeOut(duration: 0.5)) {
            showContent = true
        }

        // Pulsing animation (if not reduce motion)
        if !reduceMotion {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.15
            }
        }

        // Cycle through phases
        let phaseInterval = totalDuration / Double(phases.count)
        for (index, _) in phases.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + phaseInterval * Double(index)) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPhase = index
                }
            }
        }

        // Subtle pulse haptic every second
        if !reduceMotion {
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred(intensity: 0.4)
                }
            }
        }

        // Auto-advance after total duration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            HapticManager.success()
            onComplete()
        }
    }
}

// MARK: - Preview

#Preview {
    CalculatingView {
        print("Calculation complete!")
    }
}

#Preview("Dark") {
    CalculatingView {
        print("Complete")
    }
    .preferredColorScheme(.dark)
}
