//
//  OnboardingNavigationButtons.swift
//  Food1
//
//  Navigation controls for onboarding flow.
//  Includes back, next/continue, and skip buttons with consistent styling.
//

import SwiftUI

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
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 56, height: 56)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Primary action button
                Button(action: onNext) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(nextButtonText)
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(primaryButtonGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(!canProceed || isLoading)
                .opacity(canProceed ? 1.0 : 0.5)
            }

            // Skip button
            if showSkip, let onSkip = onSkip {
                Button("Skip for now", action: onSkip)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }

    // MARK: - Gradient

    private var primaryButtonGradient: LinearGradient {
        LinearGradient(
            colors: [Color.teal, Color.cyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Simple Variant (Just Next Button)

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
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(text)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color.teal, Color.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Preview

#Preview {
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
    .background(Color.gray.opacity(0.1))
}
