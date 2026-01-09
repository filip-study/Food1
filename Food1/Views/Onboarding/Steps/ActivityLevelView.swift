//
//  ActivityLevelView.swift
//  Food1
//
//  Onboarding step 5: Select activity level.
//  Three simple options with optional HealthKit-based estimation.
//  NOT skippable - required for calorie calculation.
//

import SwiftUI

struct ActivityLevelView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    @ObservedObject var healthKit: HealthKitService
    var onBack: () -> Void
    var onNext: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                    .padding(.top, 24)

                // HealthKit suggestion (if available)
                if let suggestedLevel = healthKit.estimatedActivityLevel {
                    healthKitSuggestion(suggestedLevel)
                }

                // Activity options
                VStack(spacing: 16) {
                    ForEach(SimpleActivityLevel.allCases) { level in
                        OnboardingSelectionCard(
                            option: level,
                            title: level.title,
                            description: level.description,
                            icon: level.icon,
                            iconColor: level.iconColor,
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
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("How active are you?")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("We'll use this to fine-tune your daily calorie goal")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
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
                // Apple Health icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Based on Apple Health")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    if let steps = healthKit.averageSteps {
                        Text("~\(steps.formatted()) daily steps → \(level.title)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Selection indicator
                if data.useHealthKitActivity && data.activityLevel == level {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.pink.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                data.useHealthKitActivity ? Color.pink : Color.clear,
                                lineWidth: 2
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
                text: data.activityLevel != nil ? "Continue" : "Select activity level",
                isEnabled: data.activityLevel != nil,
                action: onNext
            )
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

        ActivityLevelView(
            data: OnboardingData(),
            healthKit: HealthKitService.shared,
            onBack: { print("Back") },
            onNext: { print("Next") }
        )
    }
}
