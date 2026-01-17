//
//  OnboardingNavigationButtons.swift
//  Food1
//
//  Navigation controls for onboarding flow.
//
//  PHOTO-FIRST NEUTRAL DESIGN:
//  - Primary buttons: Solid white background, black text
//  - Back button: 52pt circle with glass effect
//  - Skip: White text button at 65% opacity
//  - 56pt minimum height for touch targets
//  - Soft shadows for depth on photo backgrounds
//

import SwiftUI

// MARK: - Full Navigation Bar

/// Complete navigation bar with back, next, and optional skip buttons.
struct OnboardingNavigationButtons: View {

    // MARK: - Properties

    let showBack: Bool
    let canProceed: Bool
    let showSkip: Bool
    let isLoading: Bool
    let nextButtonText: String

    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: (() -> Void)?

    // MARK: - Initialization

    init(
        showBack: Bool = true,
        canProceed: Bool = true,
        showSkip: Bool = false,
        isLoading: Bool = false,
        nextButtonText: String = "Continue",
        onBack: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onSkip: (() -> Void)? = nil
    ) {
        self.showBack = showBack
        self.canProceed = canProceed
        self.showSkip = showSkip
        self.isLoading = isLoading
        self.nextButtonText = nextButtonText
        self.onBack = onBack
        self.onNext = onNext
        self.onSkip = onSkip
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Main action buttons
            HStack(spacing: 16) {
                // Back button
                if showBack {
                    OnboardingBackButton(action: onBack)
                }

                // Primary action button
                OnboardingPrimaryButton(
                    text: nextButtonText,
                    isEnabled: canProceed,
                    isLoading: isLoading,
                    action: onNext
                )
            }

            // Skip button
            if showSkip, let onSkip = onSkip {
                Button("Skip for now", action: onSkip)
                    .font(DesignSystem.Typography.regular(size: 14))
                    .foregroundStyle(ColorPalette.onboardingTextTertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.5))
    }
}

// MARK: - Back Button Component

/// Circular back button with glass effect.
/// 52pt diameter with chevron icon.
struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(ColorPalette.onboardingBackButtonBackground)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ColorPalette.onboardingText)
                )
        }
        .buttonStyle(OnboardingScaleButtonStyle())
    }
}

// MARK: - Primary Button Component

/// Main action button with solid white background.
/// 56pt height, 16pt corner radius, black text.
struct OnboardingPrimaryButton: View {
    let text: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(ColorPalette.onboardingButtonText)
                } else {
                    Text(text)
                        .font(DesignSystem.Typography.semiBold(size: 18))
                }
            }
            .foregroundColor(ColorPalette.onboardingButtonText)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorPalette.onboardingButtonBackground)
            )
            .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        }
        .buttonStyle(OnboardingScaleButtonStyle())
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Simple Next Button (Legacy Support)

/// Standalone next button for screens that don't need full navigation bar.
/// Now uses neutral white styling instead of gradients.
struct OnboardingNextButton: View {

    let text: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    init(
        text: String = "Continue",
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        OnboardingPrimaryButton(
            text: text,
            isEnabled: isEnabled,
            isLoading: isLoading,
            action: action
        )
    }
}

// MARK: - Button Style

/// Scale-down animation on press for tactile feedback.
private struct OnboardingScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Full Navigation Bar") {
    ZStack {
        OnboardingBackground(theme: .forestFloor)

        VStack {
            Spacer()

            OnboardingNavigationButtons(
                showBack: true,
                canProceed: true,
                showSkip: true,
                onBack: { print("Back") },
                onNext: { print("Next") },
                onSkip: { print("Skip") }
            )
        }
    }
}

#Preview("Primary Button States") {
    ZStack {
        OnboardingBackground(theme: .sunlight)

        VStack(spacing: 24) {
            OnboardingPrimaryButton(
                text: "Continue",
                isEnabled: true,
                action: {}
            )

            OnboardingPrimaryButton(
                text: "Disabled",
                isEnabled: false,
                action: {}
            )

            OnboardingPrimaryButton(
                text: "Loading...",
                isEnabled: true,
                isLoading: true,
                action: {}
            )
        }
        .padding(.horizontal, 24)
    }
}

#Preview("Back Button") {
    ZStack {
        OnboardingBackground(theme: .droplet)

        VStack {
            HStack {
                OnboardingBackButton(action: { print("Back") })
                Spacer()
            }
            .padding()
            Spacer()
        }
    }
}
