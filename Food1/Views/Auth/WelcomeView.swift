//
//  WelcomeView.swift
//  Food1
//
//  Welcome screen shown to new/logged-out users before authentication.
//
//  CLEAN DESIGN:
//  - White Prismae logo on black background - elegant and minimal
//  - Two clear call-to-action buttons:
//    - "Get Started" for new users → personalization onboarding → register at end
//    - "I already have an account" for returning users → login sheet → skip onboarding
//  - No animations, no distractions - just brand clarity
//
//  DEBUG ONLY:
//  - Triple-tap on logo activates Demo Mode (for screenshots/testing)
//

import SwiftUI

struct WelcomeView: View {
    /// Triggers personalization onboarding for new users
    @Binding var showOnboarding: Bool
    /// Shows login sheet for returning users
    @Binding var showLoginSheet: Bool

    #if DEBUG
    /// Callback to activate demo mode (injected from parent)
    var onDemoModeActivated: (() -> Void)?

    /// Track tap count for demo mode activation
    @State private var logoTapCount = 0
    @State private var lastTapTime = Date.distantPast
    #endif

    var body: some View {
        ZStack {
            // Solid black background - clean and elegant
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Hero section - logo and brand
                VStack(spacing: 32) {
                    // White logo - simple and bold
                    PrismaeLogoShape()
                        .fill(Color.white)
                        .frame(width: 140, height: 140)
                        #if DEBUG
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleLogoTap()
                        }
                        .accessibilityIdentifier("demoModeLogo")
                        #endif

                    // App name and tagline
                    VStack(spacing: 12) {
                        Text("Prismae")
                            .font(DesignSystem.Typography.bold(size: 42))
                            .tracking(-0.5)
                            .foregroundColor(.white)

                        Text("Every meal is data.\nEvery day is progress.")
                            .font(DesignSystem.Typography.editorialItalic(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                Spacer()
                Spacer()

                // Buttons section
                VStack(spacing: 16) {
                    // Primary: Get Started (new users → onboarding first)
                    Button {
                        HapticManager.medium()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showOnboarding = true
                        }
                    } label: {
                        Text("Get Started")
                            .font(DesignSystem.Typography.semiBold(size: 18))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                    .accessibilityIdentifier("getStartedButton")

                    // Secondary: Already have account (returning users → login sheet)
                    Button {
                        HapticManager.light()
                        showLoginSheet = true
                    } label: {
                        Text("I already have an account")
                            .font(DesignSystem.Typography.medium(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .accessibilityIdentifier("signInButton")
                }
                .padding(.horizontal, 24)

                // Privacy note
                Text("Your data stays private and secure")
                    .font(DesignSystem.Typography.regular(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 24)

                Spacer()
                    .frame(height: 48)
            }
        }
    }

    // MARK: - Demo Mode (DEBUG Only)

    #if DEBUG
    /// Handle logo tap for demo mode activation (triple-tap within 5 seconds)
    private func handleLogoTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)

        if timeSinceLastTap > 5.0 {
            logoTapCount = 1
        } else {
            logoTapCount += 1
        }

        lastTapTime = now

        if logoTapCount >= 3 {
            logoTapCount = 0
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()

            print("[DemoMode] Triple-tap detected - activating demo mode")
            onDemoModeActivated?()
        } else {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    #endif
}

// MARK: - Preview

#Preview("Welcome") {
    WelcomeView(
        showOnboarding: .constant(false),
        showLoginSheet: .constant(false)
    )
}
