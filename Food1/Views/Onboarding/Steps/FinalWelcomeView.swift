//
//  FinalWelcomeView.swift
//  Food1
//
//  Final pump-up screen shown after name entry, before completing onboarding.
//
//  PURPOSE:
//  - Creates a strong emotional ending to onboarding
//  - Builds excitement before launching into the app
//  - Follows peak-end rule: users remember the peak and end of experiences
//
//  DESIGN:
//  - Celebration gradient background
//  - Personalized "You're all set, [Name]!" message
//  - Motivational subtitle
//  - "Let's Go" call-to-action button
//  - Success haptics on appear
//

import SwiftUI

struct FinalWelcomeView: View {

    // MARK: - Properties

    let userName: String
    var onComplete: () -> Void

    // MARK: - State

    @State private var showContent = false
    @State private var showButton = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        ZStack {
            // Celebration background
            OnboardingBackground(theme: .droplet)

            VStack(spacing: 0) {
                Spacer()

                // Main content
                VStack(spacing: 20) {
                    // Checkmark icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.5)

                    // Personalized headline
                    Text("You're all set, \(displayName)!")
                        .font(DesignSystem.Typography.bold(size: 32))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Motivational subtitle
                    Text("Your personalized nutrition journey starts now")
                        .font(DesignSystem.Typography.regular(size: 17))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 15)
                }
                .padding(.horizontal, 32)

                Spacer()

                // "Let's Go" button
                completeButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .onAppear {
            animateEntrance()
        }
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button {
            HapticManager.success()
            onComplete()
        } label: {
            HStack(spacing: 8) {
                Text("Let's Go")
                    .font(DesignSystem.Typography.semiBold(size: 18))

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(ColorPalette.onboardingButtonText)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorPalette.onboardingButtonBackground)
            )
            .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        }
        .buttonStyle(FinalWelcomeButtonStyle())
        .opacity(showButton ? 1 : 0)
        .offset(y: showButton ? 0 : 20)
    }

    // MARK: - Computed

    private var displayName: String {
        let firstName = userName.components(separatedBy: " ").first ?? userName
        return firstName.isEmpty ? "Friend" : firstName
    }

    // MARK: - Animation

    private func animateEntrance() {
        // Success haptic
        if !reduceMotion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                HapticManager.success()
            }
        }

        // Animate content
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            showContent = true
        }

        // Animate button
        withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
            showButton = true
        }
    }
}

// MARK: - Button Style

private struct FinalWelcomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Final Welcome") {
    FinalWelcomeView(userName: "John") {
        print("Complete")
    }
}

#Preview("Final Welcome - Empty Name") {
    FinalWelcomeView(userName: "") {
        print("Complete")
    }
}
