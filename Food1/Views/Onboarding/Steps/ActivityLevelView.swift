//
//  ActivityLevelView.swift
//  Food1
//
//  Onboarding step 5: Select activity level.
//
//  ACT II - DISCOVERY DESIGN:
//  - Solid color background for high visibility
//  - Primary/secondary text colors (adapts to light/dark mode)
//  - Typography-only selection cards
//  - HealthKit suggestion styled with solid card
//

import SwiftUI

struct ActivityLevelView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    @ObservedObject var healthKit: HealthKitService
    var onBack: () -> Void
    var onNext: () -> Void

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

                    // HealthKit suggestion (if available)
                    if let suggestedLevel = healthKit.estimatedActivityLevel {
                        healthKitSuggestion(suggestedLevel)
                    }

                    // Activity options - typography-only cards
                    VStack(spacing: 16) {
                        ForEach(SimpleActivityLevel.allCases) { level in
                            OnboardingSelectionCard(
                                option: level,
                                title: level.title,
                                description: level.description,
                                icon: level.icon,  // Ignored
                                iconColor: .white,  // Ignored
                                isSelected: data.activityLevel == level,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        data.activityLevel = level
                                        data.useHealthKitActivity = false
                                    }
                                }
                            )
                        }
                    }
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
            Text("How active are you?")
                .font(DesignSystem.Typography.bold(size: 28))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text("We'll use this to fine-tune your daily calorie goal")
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - HealthKit Suggestion

    private func healthKitSuggestion(_ level: SimpleActivityLevel) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                data.activityLevel = level
                data.useHealthKitActivity = true
            }
        } label: {
            HStack(spacing: 16) {
                // Health icon in solid circle
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 44, height: 44)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.pink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Based on Apple Health")
                        .font(DesignSystem.Typography.semiBold(size: 15))
                        .foregroundStyle(.primary)

                    if let steps = healthKit.averageSteps {
                        Text("~\(steps.formatted()) daily steps → \(level.title)")
                            .font(DesignSystem.Typography.regular(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if data.useHealthKitActivity && data.activityLevel == level {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(ColorPalette.onboardingCardSelectedBorder)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                data.useHealthKitActivity
                                    ? ColorPalette.onboardingCardSelectedBorder
                                    : Color(.separator),
                                lineWidth: data.useHealthKitActivity ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            OnboardingBackButton(action: onBack)

            OnboardingNextButton(
                text: data.activityLevel != nil ? "Continue" : "Select activity level",
                isEnabled: data.activityLevel != nil,
                action: onNext
            )
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
    ActivityLevelView(
        data: OnboardingData(),
        healthKit: HealthKitService.shared,
        onBack: { print("Back") },
        onNext: { print("Next") }
    )
}
