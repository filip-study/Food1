//
//  WelcomeUserView.swift
//  Food1
//
//  Personalized welcome screen shown after authentication.
//
//  ACT III - CELEBRATION DESIGN:
//  - Midjourney sunlight photo background
//  - Typography-driven design (no particles or icons)
//  - "Hello," in serif, name in ExtraBold with shimmer
//  - 3-beat haptic pattern (light, medium, light)
//  - "Begin" button
//

import SwiftUI

struct WelcomeUserView: View {

    // MARK: - Properties

    let userName: String
    var onContinue: () -> Void

    // MARK: - State

    @State private var showGreeting = false
    @State private var showName = false
    @State private var showSubtitle = false
    @State private var showButton = false
    @State private var shimmerPhase: CGFloat = -1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            // Brand gradient background (celebration moment)
            celebrationBackground

            VStack(spacing: 0) {
                Spacer()

                // Greeting section with shimmer name
                greetingSection

                Spacer()

                // "Begin" button - SOLID WHITE
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            animateEntrance()
        }
    }

    // MARK: - Celebration Background (Midjourney Sunlight Image)

    private var celebrationBackground: some View {
        OnboardingBackground(theme: .sunlight)
    }

    // MARK: - Greeting Section (Typography-Driven)

    private var greetingSection: some View {
        VStack(spacing: 12) {
            // "Hello," - Serif, elegant (NOT "Welcome back" - this is onboarding for NEW users)
            Text("Hello,")
                .font(.custom("Georgia", size: 26))
                .italic()
                .foregroundStyle(.white.opacity(0.8))
                .opacity(showGreeting ? 1 : 0)
                .offset(y: showGreeting ? 0 : 20)

            // Name - ExtraBold 42pt with shimmer overlay
            ZStack {
                Text(displayName)
                    .font(DesignSystem.Typography.extraBold(size: 42))
                    .foregroundStyle(.white)

                // Shimmer overlay (only when animating)
                if !reduceMotion {
                    nameShimmerOverlay
                }
            }
            .opacity(showName ? 1 : 0)
            .offset(y: showName ? 0 : 20)

            // Subtitle
            Text("Let's build your personalized\nnutrition plan")
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(showSubtitle ? 1 : 0)
                .offset(y: showSubtitle ? 0 : 15)
                .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Name Shimmer Overlay

    private var nameShimmerOverlay: some View {
        Text(displayName)
            .font(DesignSystem.Typography.extraBold(size: 42))
            .foregroundStyle(.clear)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.4), location: 0.4),
                            .init(color: .white.opacity(0.6), location: 0.5),
                            .init(color: .white.opacity(0.4), location: 0.6),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .blur(radius: 4)
                    .offset(x: shimmerPhase * (geometry.size.width * 1.5))
                }
            )
            .mask(
                Text(displayName)
                    .font(DesignSystem.Typography.extraBold(size: 42))
            )
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            HapticManager.medium()
            onContinue()
        } label: {
            Text("Begin")
                .font(DesignSystem.Typography.semiBold(size: 18))
                .foregroundColor(ColorPalette.onboardingButtonText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorPalette.onboardingButtonBackground)
                )
                .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        }
        .buttonStyle(WelcomeScaleButtonStyle())
        .opacity(showButton ? 1 : 0)
        .offset(y: showButton ? 0 : 20)
    }

    // MARK: - Computed Properties

    private var displayName: String {
        // Extract first name if full name provided
        let firstName = userName.components(separatedBy: " ").first ?? userName
        // Don't use lazy "there" fallback - this screen requires a name from NameEntryView
        return firstName.isEmpty ? "Friend" : firstName
    }

    /// Whether we have a real name (affects greeting structure)
    private var hasRealName: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Animation

    private func animateEntrance() {
        let baseDelay: Double = reduceMotion ? 0 : 0.2

        // 3-beat haptic pattern (light, medium, light)
        if !reduceMotion {
            trigger3BeatHaptics(delay: baseDelay + 0.3)
        }

        // Staggered text animations
        withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.3)) {
            showGreeting = true
        }

        withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.5)) {
            showName = true
        }

        withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.7)) {
            showSubtitle = true
        }

        withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 1.0)) {
            showButton = true
        }

        // Start shimmer after 3.2s delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 4.2)) {
                    shimmerPhase = 1.0
                }
            }
        }
    }

    // MARK: - Haptics

    private func trigger3BeatHaptics(delay: Double) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            generator.impactOccurred(intensity: 0.6)  // Light
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.15) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()  // Medium
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) {
            generator.impactOccurred(intensity: 0.6)  // Light
        }
    }
}

// MARK: - Welcome Button Style

private struct WelcomeScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("With Name") {
    WelcomeUserView(userName: "John Smith") {
        print("Continue tapped")
    }
}

#Preview("First Name Only") {
    WelcomeUserView(userName: "Sarah") {
        print("Continue tapped")
    }
}

#Preview("Empty Name") {
    WelcomeUserView(userName: "") {
        print("Continue tapped")
    }
}
