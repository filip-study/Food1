//
//  OnboardingProgressBar.swift
//  Food1
//
//  Progress indicator for onboarding flow - Stepped Dots Design.
//
//  PREMIUM EDITORIAL DESIGN:
//  - 10 discrete dots showing clear step awareness
//  - Current dot: Filled white with subtle glow/pulse animation
//  - Completed dots: Filled white
//  - Upcoming dots: Hollow circle (white stroke, transparent fill)
//  - Safe area aware positioning (below notch/Dynamic Island)
//  - Smooth spring animations between steps
//

import SwiftUI

// MARK: - Stepped Dots Progress Indicator

/// Redesigned progress indicator using stepped dots.
/// Each dot represents one step - clearer progress awareness than a continuous bar.
struct OnboardingProgressBar: View {

    // MARK: - Properties

    let current: Int
    let total: Int

    // MARK: - Animation State

    @State private var glowOpacity: Double = 0.8

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<total, id: \.self) { index in
                progressDot(for: index)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
        .onAppear {
            startGlowAnimation()
        }
    }

    // MARK: - Progress Dot

    @ViewBuilder
    private func progressDot(for index: Int) -> some View {
        let isCompleted = index < current
        let isCurrent = index == current
        let isUpcoming = index > current

        ZStack {
            // Glow effect for current dot
            if isCurrent && !reduceMotion {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .blur(radius: 4)
                    .opacity(glowOpacity)
            }

            // Main dot
            Circle()
                .fill(isCurrent || isCompleted ? Color.white : Color.clear)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isUpcoming ? 1.5 : 0)
                )
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: current)
    }

    // MARK: - Glow Animation

    private func startGlowAnimation() {
        guard !reduceMotion else { return }

        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 1.0
        }
    }
}

// MARK: - Solid Background Variant

/// Progress indicator optimized for solid color backgrounds (Act II screens).
/// Uses primary color adaptation for better visibility on light backgrounds.
struct OnboardingProgressBarSolid: View {

    let current: Int
    let total: Int

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var glowOpacity: Double = 0.8

    private var dotColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<total, id: \.self) { index in
                progressDot(for: index)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
        .onAppear {
            startGlowAnimation()
        }
    }

    @ViewBuilder
    private func progressDot(for index: Int) -> some View {
        let isCompleted = index < current
        let isCurrent = index == current
        let isUpcoming = index > current

        ZStack {
            // Glow effect for current dot
            if isCurrent && !reduceMotion {
                Circle()
                    .fill(ColorPalette.accentPrimary.opacity(0.4))
                    .frame(width: 16, height: 16)
                    .blur(radius: 4)
                    .opacity(glowOpacity)
            }

            // Main dot
            Circle()
                .fill(
                    isCurrent ? ColorPalette.accentPrimary :
                    isCompleted ? dotColor :
                    Color.clear
                )
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(
                            isUpcoming ? dotColor.opacity(0.3) : Color.clear,
                            lineWidth: 1.5
                        )
                )
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: current)
    }

    private func startGlowAnimation() {
        guard !reduceMotion else { return }

        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 1.0
        }
    }
}

// MARK: - Step Counter (Text Variant)

/// Text-based step counter as alternative to visual progress dots.
struct OnboardingStepCounter: View {

    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("Step \(current + 1)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorPalette.onboardingText)

            Text("of \(total)")
                .font(.subheadline)
                .foregroundStyle(ColorPalette.onboardingTextSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

// MARK: - Legacy Support

/// Gradient variant kept for backward compatibility.
/// New screens should use the standard OnboardingProgressBar.
struct OnboardingProgressBarGradient: View {

    let current: Int
    let total: Int
    let gradient: LinearGradient

    init(
        current: Int,
        total: Int,
        gradient: LinearGradient = LinearGradient(
            colors: [.white, .white],
            startPoint: .leading,
            endPoint: .trailing
        )
    ) {
        self.current = current
        self.total = total
        self.gradient = gradient
    }

    var body: some View {
        // Redirect to new stepped dots design
        OnboardingProgressBar(current: current, total: total)
    }
}

// MARK: - Previews

#Preview("Stepped Dots - Various States") {
    ZStack {
        OnboardingBackground(theme: .sunlight)

        VStack(spacing: 40) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step 1 of 10")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                OnboardingProgressBar(current: 0, total: 10)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Step 5 of 10")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                OnboardingProgressBar(current: 4, total: 10)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Step 10 of 10")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                OnboardingProgressBar(current: 9, total: 10)
            }
        }
    }
}

#Preview("Stepped Dots - Animated") {
    struct AnimatedPreview: View {
        @State private var step = 0

        var body: some View {
            ZStack {
                OnboardingBackground(theme: .forestFloor)

                VStack(spacing: 40) {
                    OnboardingProgressBar(current: step, total: 10)

                    Text("Step \(step + 1) of 10")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Button("Next Step") {
                        step = (step + 1) % 10
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    return AnimatedPreview()
}

#Preview("Solid Background Variant") {
    VStack(spacing: 40) {
        OnboardingProgressBarSolid(current: 2, total: 10)
        OnboardingProgressBarSolid(current: 5, total: 10)
        OnboardingProgressBarSolid(current: 8, total: 10)
    }
    .padding()
    .background(ColorPalette.onboardingSolidDark)
}

#Preview("Step Counter") {
    ZStack {
        OnboardingBackground(theme: .droplet)

        VStack(spacing: 32) {
            OnboardingStepCounter(current: 2, total: 7)
            OnboardingStepCounter(current: 5, total: 7)
        }
    }
}
