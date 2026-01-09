//
//  GoalSelectionView.swift
//  Food1
//
//  Onboarding step 1: Select primary nutrition goal.
//  Weight Loss, Health Optimization, or Muscle Building.
//

import SwiftUI

struct GoalSelectionView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    var onNext: () -> Void
    var onSkip: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                    .padding(.top, 24)

                // Goal options
                VStack(spacing: 16) {
                    ForEach(NutritionGoal.allCases) { goal in
                        OnboardingSelectionCard(
                            option: goal,
                            title: goal.title,
                            description: goal.description,
                            icon: goal.icon,
                            iconColor: goal.iconColor,
                            isSelected: data.goal == goal,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    data.goal = goal
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)

                // Footer note
                footerNote
                    .padding(.horizontal, 24)

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("What's your main goal?")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("This helps us personalize your experience")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Footer Note

    private var footerNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.teal)

            Text("You can change this anytime in Settings")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            OnboardingNextButton(
                text: data.goal != nil ? "Continue" : "Select a goal",
                isEnabled: data.goal != nil,
                action: onNext
            )

            Button("Skip for now", action: onSkip)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.5))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        GoalSelectionView(
            data: OnboardingData(),
            onNext: { print("Next") },
            onSkip: { print("Skip") }
        )
    }
}
