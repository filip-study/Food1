//
//  YourTargetsView.swift
//  Food1
//
//  Onboarding step 7: Display calculated nutrition targets.
//
//  ACT III - CELEBRATION DESIGN:
//  - Celebration gradient background (blue → teal → purple)
//  - Hero calorie number (72pt ExtraBold WHITE)
//  - Particle burst on reveal
//  - Macro cards with solid colored backgrounds + borders
//  - 3-phase success haptics
//  - Premium, rewarding, memorable
//

import SwiftUI

struct YourTargetsView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    var onBack: () -> Void
    var onNext: () -> Void

    // MARK: - Animation State

    @State private var animateCalories = false
    @State private var animateMacros = false
    @State private var displayedCalories: Int = 0
    @State private var showParticles = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Celebration gradient background (Act III)
            celebrationBackground

            // Main content
            ScrollView {
                VStack(spacing: 40) {
                    // Top spacing to clear progress bar + Dynamic Island
                    // Progress bar is ~44pt + needs 20pt for Dynamic Island clearance
                    Spacer(minLength: 72)

                    // Header (simplified, no icon)
                    headerSection

                    // Hero calorie display
                    calorieSection

                    // Macro breakdown with solid cards
                    macroSection

                    Spacer(minLength: 120)
                }
            }
            .scrollIndicators(.hidden)

            // Celebration particles overlay
            CelebrationParticles(
                style: .burst,
                trigger: $showParticles,
                duration: 3.0,
                particleCount: 50
            )
            .allowsHitTesting(false)
        }
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
        .onAppear {
            // Staggered reveal animations
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateCalories = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                animateMacros = true
            }

            // Count up animation for calories
            animateCalorieCount()

            // Trigger celebration effects after calorie count completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showParticles = true
                triggerSuccessHaptics()
            }
        }
    }

    // MARK: - Celebration Background (Midjourney Droplet Image)

    private var celebrationBackground: some View {
        OnboardingBackground(theme: .droplet)
    }

    // MARK: - Header (Typography-Driven, No Icon)

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Your personalized targets")
                .font(DesignSystem.Typography.bold(size: 28))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .opacity(animateCalories ? 1 : 0)

            Text("Built just for you")
                .font(.custom("Georgia", size: 17))  // Serif for elegance
                .italic()
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .opacity(animateCalories ? 1 : 0)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Calorie Display (Hero Moment)

    private var calorieSection: some View {
        VStack(spacing: 8) {
            // Hero calorie number - 72pt ExtraBold WHITE
            Text("\(displayedCalories)")
                .font(DesignSystem.Typography.extraBold(size: 72))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            // Elegant serif subtitle
            Text("calories per day")
                .font(.custom("Georgia", size: 18))  // Serif for elegance
                .italic()
                .foregroundStyle(.white.opacity(0.85))
        }
        .opacity(animateCalories ? 1 : 0)
        .offset(y: animateCalories ? 0 : 20)
    }

    // MARK: - Macro Section (Solid Cards with Colored Borders)

    private var macroSection: some View {
        VStack(spacing: 16) {
            Text("Daily Macros")
                .font(DesignSystem.Typography.medium(size: 15))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 12) {
                // Protein - Teal
                macroCard(
                    label: "Protein",
                    value: data.calculatedProtein ?? 0,
                    color: ColorPalette.macroProtein
                )

                // Carbs - Coral/Pink
                macroCard(
                    label: "Carbs",
                    value: data.calculatedCarbs ?? 0,
                    color: ColorPalette.macroCarbs
                )

                // Fat - Blue
                macroCard(
                    label: "Fat",
                    value: data.calculatedFat ?? 0,
                    color: ColorPalette.macroFat
                )
            }
        }
        .padding(.horizontal, 24)
        .opacity(animateMacros ? 1 : 0)
        .offset(y: animateMacros ? 0 : 20)
    }

    /// Macro card with dark base + colored tint for visibility over any background
    private func macroCard(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            // Value in macro color, 28pt bold
            Text("\(value)g")
                .font(DesignSystem.Typography.bold(size: 28))
                .foregroundStyle(color)

            // Label in white, 14pt
            Text(label)
                .font(DesignSystem.Typography.medium(size: 14))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.25))  // Dark base for contrast
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.20))  // Increased from 0.15
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.7), lineWidth: 1.5)  // Stronger border
        )
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                OnboardingBackButton(action: onBack)

                // "Perfect!" button - celebration moment
                OnboardingNextButton(
                    text: "Perfect!",
                    isEnabled: true,
                    action: onNext
                )
            }

            Text("You can adjust these anytime in Settings")
                .font(DesignSystem.Typography.regular(size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 44)  // Generous bottom padding for home indicator clearance
        // SOLID background - no transparency issues over gradient
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Haptics

    /// Trigger 3-phase success haptic pattern
    private func triggerSuccessHaptics() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Animation

    private func animateCalorieCount() {
        let targetCalories = data.calculatedCalories ?? 2000
        let duration: Double = 1.0
        let steps = 30
        let increment = Double(targetCalories) / Double(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (duration / Double(steps)) * Double(i)) {
                withAnimation {
                    displayedCalories = min(Int(increment * Double(i)), targetCalories)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    YourTargetsView(
        data: {
            let d = OnboardingData()
            d.biologicalSex = .male
            d.age = 30
            d.weightKg = 75
            d.heightCm = 178
            d.activityLevel = .moderatelyActive
            d.goal = .healthOptimization
            d.dietType = .balanced
            return d
        }(),
        onBack: { print("Back") },
        onNext: { print("Next") }
    )
}
