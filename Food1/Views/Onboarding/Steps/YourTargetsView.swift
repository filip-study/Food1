//
//  YourTargetsView.swift
//  Food1
//
//  Onboarding step 6: Display calculated nutrition targets.
//  Shows daily calories and macro breakdown based on user's profile.
//  This is a summary screen - no input required.
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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Header
                headerSection
                    .padding(.top, 24)

                // Calorie display
                calorieSection

                // Macro breakdown
                macroSection

                // Science note
                scienceNote

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
        .onAppear {
            // Animate the reveal
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateCalories = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                animateMacros = true
            }

            // Count up animation for calories
            animateCalorieCount()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Checkmark icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
            }
            .scaleEffect(animateCalories ? 1 : 0.5)
            .opacity(animateCalories ? 1 : 0)

            Text("Your personalized targets")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .opacity(animateCalories ? 1 : 0)

            Text("Calculated using science-backed formulas")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .opacity(animateCalories ? 1 : 0)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Calorie Display

    private var calorieSection: some View {
        VStack(spacing: 8) {
            Text("\(displayedCalories)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .contentTransition(.numericText())

            Text("calories per day")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
        }
        .opacity(animateCalories ? 1 : 0)
        .offset(y: animateCalories ? 0 : 20)
    }

    // MARK: - Macro Section

    private var macroSection: some View {
        VStack(spacing: 20) {
            Text("Daily Macros")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 16) {
                macroCard(
                    label: "Protein",
                    value: data.calculatedProtein ?? 0,
                    unit: "g",
                    color: .blue
                )

                macroCard(
                    label: "Carbs",
                    value: data.calculatedCarbs ?? 0,
                    unit: "g",
                    color: .orange
                )

                macroCard(
                    label: "Fat",
                    value: data.calculatedFat ?? 0,
                    unit: "g",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 24)
        .opacity(animateMacros ? 1 : 0)
        .offset(y: animateMacros ? 0 : 20)
    }

    private func macroCard(label: String, value: Int, unit: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.title.bold())
                .foregroundStyle(color)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Science Note

    private var scienceNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title3)
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text("Mifflin-St Jeor Equation")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Text("The gold standard for estimating daily energy needs")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cyan.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
        .opacity(animateMacros ? 1 : 0)
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                OnboardingNextButton(
                    text: "Looks good!",
                    isEnabled: true,
                    action: onNext
                )
            }

            Text("You can adjust these anytime in Settings")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.5))
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
    ZStack {
        Color.black.ignoresSafeArea()

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
}
