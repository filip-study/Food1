//
//  GoalSelectionView.swift
//  Food1
//
//  Onboarding step 1: Select primary nutrition goal.
//
//  ACT II - DISCOVERY DESIGN:
//  - Solid color background for high visibility
//  - Primary/secondary text colors (adapts to light/dark mode)
//  - Typography-only selection cards (no icons)
//  - Left-aligned footer note
//

import SwiftUI

struct GoalSelectionView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    var onNext: () -> Void
    var onSkip: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        ZStack {
            // Solid color background (Act II)
            OnboardingBackground(theme: .solid)

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                        .padding(.top, 24)

                    // Goal options - typography-only cards
                    VStack(spacing: 16) {
                        ForEach(NutritionGoal.allCases) { goal in
                            OnboardingSelectionCard(
                                option: goal,
                                title: goal.title,
                                description: goal.description,
                                icon: goal.icon,  // Ignored in typography-only design
                                iconColor: .white,  // Ignored
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

                    // Footer note - LEFT aligned
                    footerNote
                        .padding(.horizontal, 24)

                    Spacer(minLength: 120)
                }
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("What's your main goal?")
                .font(DesignSystem.Typography.bold(size: 28))
                .foregroundStyle(.primary)  // Adapts to light/dark mode
                .multilineTextAlignment(.center)

            Text("This helps us personalize your experience")
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Footer Note

    private var footerNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)

            Text("You can change this anytime in Settings")
                .font(DesignSystem.Typography.regular(size: 14))
                .foregroundStyle(.tertiary)
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
                .font(DesignSystem.Typography.regular(size: 14))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.3)
                : Color.white.opacity(0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    GoalSelectionView(
        data: OnboardingData(),
        onNext: { print("Next") },
        onSkip: { print("Skip") }
    )
}
