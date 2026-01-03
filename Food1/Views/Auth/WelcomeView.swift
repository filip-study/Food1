//
//  WelcomeView.swift
//  Food1
//
//  Welcome screen shown to new/logged-out users before authentication.
//  Features a visually engaging introduction to Prismae's intelligent
//  nutrition tracking capabilities with a prominent "Get Started" CTA.
//
//  WHY THIS DESIGN:
//  - First impression matters: Premium visual experience builds trust
//  - Single CTA reduces decision fatigue (Hick's law)
//  - Feature highlights prime users for the value proposition
//  - Animated elements create sense of quality and polish
//
//  DEBUG ONLY:
//  - Triple-tap on logo activates Demo Mode (for screenshots/testing)
//  - Completely stripped from release builds via #if DEBUG
//

import SwiftUI

struct WelcomeView: View {
    @Binding var showOnboarding: Bool
    @State private var animateContent = false
    @State private var animateButton = false
    @Environment(\.colorScheme) var colorScheme

    #if DEBUG
    /// Callback to activate demo mode (injected from parent)
    var onDemoModeActivated: (() -> Void)?

    /// Track tap count for demo mode activation
    @State private var logoTapCount = 0
    @State private var lastTapTime = Date.distantPast
    #endif

    var body: some View {
        ZStack {
            // Background
            BrandGradientBackground()

            VStack(spacing: 0) {
                Spacer()

                // Hero section
                VStack(spacing: 32) {
                    // Animated logo
                    AnimatedLogoView()
                        .scaleEffect(1.3)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        #if DEBUG
                        .frame(width: 200, height: 200)  // Explicit frame for tap target
                        .contentShape(Rectangle())  // Make entire frame tappable
                        .onTapGesture {
                            handleLogoTap()
                        }
                        .accessibilityIdentifier("demoModeLogo")
                        #endif

                    // App name and tagline
                    VStack(spacing: 12) {
                        Text("Prismae")
                            .font(.system(size: 42, weight: .bold))
                            .tracking(-0.5)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: colorScheme == .dark
                                        ? [.white, .white.opacity(0.85)]
                                        : [.black, .black.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Intelligent Nutrition")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 15)
                }
                .padding(.bottom, 48)

                Spacer()

                // Feature highlights
                VStack(spacing: 20) {
                    FeatureRow(
                        icon: "camera.fill",
                        iconColor: Color(hex: "2563EB"),
                        title: "Snap & Track",
                        description: "AI recognizes your meals instantly"
                    )
                    .opacity(animateContent ? 1 : 0)
                    .offset(x: animateContent ? 0 : -20)

                    FeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: Color(hex: "14B8A6"),
                        title: "Smart Insights",
                        description: "Personalized nutrition guidance"
                    )
                    .opacity(animateContent ? 1 : 0)
                    .offset(x: animateContent ? 0 : -20)

                    FeatureRow(
                        icon: "heart.fill",
                        iconColor: Color(hex: "FB7185"),
                        title: "Health Goals",
                        description: "Track micros, macros, and trends"
                    )
                    .opacity(animateContent ? 1 : 0)
                    .offset(x: animateContent ? 0 : -20)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

                Spacer()

                // Get Started button
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()

                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showOnboarding = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: "2563EB").opacity(0.4), radius: 12, y: 6)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(animateButton ? 1 : 0)
                .offset(y: animateButton ? 0 : 20)
                .accessibilityIdentifier("getStartedButton")

                // Subtle privacy note
                Text("Your data stays private and secure")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                    .opacity(animateButton ? 1 : 0)

                Spacer()
                    .frame(height: 32)
            }
        }
        .onAppear {
            // Staggered animations for polish
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateContent = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                animateButton = true
            }
        }
    }

    // MARK: - Demo Mode (DEBUG Only)

    #if DEBUG
    /// Handle logo tap for demo mode activation (triple-tap within 1 second)
    private func handleLogoTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)

        // Reset count if more than 5 seconds since last tap
        // (longer timeout to allow for automation testing latency)
        if timeSinceLastTap > 5.0 {
            logoTapCount = 1
        } else {
            logoTapCount += 1
        }

        lastTapTime = now

        // Activate demo mode on third tap
        if logoTapCount >= 3 {
            logoTapCount = 0
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()

            print("[DemoMode] Triple-tap detected - activating demo mode")
            onDemoModeActivated?()
        } else {
            // Light feedback on each tap
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    #endif
}

// MARK: - Feature Row Component

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview("Welcome - Light") {
    WelcomeView(showOnboarding: .constant(false))
        .preferredColorScheme(.light)
}

#Preview("Welcome - Dark") {
    WelcomeView(showOnboarding: .constant(false))
        .preferredColorScheme(.dark)
}
