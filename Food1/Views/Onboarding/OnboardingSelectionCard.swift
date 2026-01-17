//
//  OnboardingSelectionCard.swift
//  Food1
//
//  Reusable selection card for onboarding screens.
//
//  PREMIUM EDITORIAL DESIGN (Typography-Only):
//  - NO SF Symbol icons - typography and whitespace carry the design
//  - Like premium apps: Arc, Linear, Notion
//  - Title: Manrope SemiBold 17pt
//  - Description: Manrope Regular 15pt, LEFT-ALIGNED
//  - Selection: 24pt circle indicator on right
//  - Selected: Blue 8% fill + 2pt blue border + scale 1.02
//  - Unselected: System fill color + 1pt subtle border
//  - Corner radius: 16pt
//  - Haptic: Medium impact on selection
//

import SwiftUI
import UIKit

// MARK: - Typography-Only Selection Card

/// Premium typography-only selection card.
/// Icons are intentionally omitted - typography and whitespace define the design.
struct OnboardingSelectionCard<T: Hashable>: View {

    // MARK: - Properties

    let option: T
    let title: String
    let description: String
    let icon: String  // Kept for API compatibility, but IGNORED in new design
    let iconColor: Color  // Kept for API compatibility, but IGNORED
    let isSelected: Bool
    let action: () -> Void

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack(alignment: .top, spacing: 16) {
                // Text content (NO icon - typography only)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(DesignSystem.Typography.semiBold(size: 17))
                        .foregroundStyle(textColor)

                    Text(description)
                        .font(DesignSystem.Typography.regular(size: 15))
                        .foregroundStyle(descriptionColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)  // LEFT-ALIGNED
                }

                Spacer()

                // Selection indicator - 24pt circle
                selectionIndicator
            }
            .padding(20)
            .background(cardBackground)
            .overlay(cardBorder)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Colors (Adaptive)

    private var textColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var descriptionColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.7)
            : Color.primary.opacity(0.6)
    }

    // MARK: - Selection Indicator

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected
                        ? ColorPalette.onboardingCardSelectedBorder
                        : (colorScheme == .dark ? Color.white.opacity(0.3) : Color.primary.opacity(0.2)),
                    lineWidth: 2
                )
                .frame(width: 24, height: 24)

            if isSelected {
                Circle()
                    .fill(ColorPalette.onboardingCardSelectedBorder)
                    .frame(width: 16, height: 16)
            }
        }
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                isSelected
                    ? ColorPalette.onboardingCardSelectedBackground
                    : ColorPalette.onboardingCardSolidBackground
            )
    }

    // MARK: - Card Border

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                isSelected
                    ? ColorPalette.onboardingCardSelectedBorder
                    : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.primary.opacity(0.08)),
                lineWidth: isSelected ? 2 : 1
            )
    }
}

// MARK: - Compact Variant (Sex Selection)

/// Compact card for 2-across layouts (e.g., sex selection).
/// Also typography-only - no icons.
struct OnboardingSelectionCardCompact<T: Hashable>: View {

    let option: T
    let title: String
    let icon: String  // Kept for API compatibility, IGNORED
    let iconColor: Color  // Kept for API compatibility, IGNORED
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 12) {
                // Title only - no icon
                Text(title)
                    .font(DesignSystem.Typography.semiBold(size: 17))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected
                                ? ColorPalette.onboardingCardSelectedBorder
                                : (colorScheme == .dark ? Color.white.opacity(0.3) : Color.primary.opacity(0.2)),
                            lineWidth: 2
                        )
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(ColorPalette.onboardingCardSelectedBorder)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? ColorPalette.onboardingCardSelectedBackground
                            : ColorPalette.onboardingCardSolidBackground
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? ColorPalette.onboardingCardSelectedBorder
                            : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.primary.opacity(0.08)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple Text Card

/// Text-only selection card for lists without icons.
struct OnboardingTextCard<T: Hashable>: View {

    let option: T
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(
        option: T,
        title: String,
        subtitle: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.option = option
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignSystem.Typography.semiBold(size: 17))
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.regular(size: 14))
                            .foregroundStyle(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.6)
                                    : Color.primary.opacity(0.5)
                            )
                    }
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected
                                ? ColorPalette.onboardingCardSelectedBorder
                                : (colorScheme == .dark ? Color.white.opacity(0.3) : Color.primary.opacity(0.2)),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(ColorPalette.onboardingCardSelectedBorder)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? ColorPalette.onboardingCardSelectedBackground
                            : ColorPalette.onboardingCardSolidBackground
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? ColorPalette.onboardingCardSelectedBorder
                            : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.primary.opacity(0.08)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Typography-Only Cards") {
    VStack(spacing: 16) {
        OnboardingSelectionCard(
            option: "weightLoss",
            title: "Lose Weight",
            description: "Sustainable fat loss while maintaining energy and muscle mass",
            icon: "ignored",
            iconColor: .orange,
            isSelected: true,
            action: {}
        )

        OnboardingSelectionCard(
            option: "health",
            title: "Optimize Health",
            description: "Focus on overall wellness and balanced nutrition",
            icon: "ignored",
            iconColor: .pink,
            isSelected: false,
            action: {}
        )

        OnboardingSelectionCard(
            option: "muscle",
            title: "Build Muscle",
            description: "Gain lean mass with optimal protein intake",
            icon: "ignored",
            iconColor: .blue,
            isSelected: false,
            action: {}
        )
    }
    .padding()
    .background(ColorPalette.onboardingSolidDark)
}

#Preview("Compact Cards") {
    HStack(spacing: 12) {
        OnboardingSelectionCardCompact(
            option: "male",
            title: "Male",
            icon: "figure.stand",
            iconColor: .blue,
            isSelected: true,
            action: {}
        )

        OnboardingSelectionCardCompact(
            option: "female",
            title: "Female",
            icon: "figure.stand.dress",
            iconColor: .pink,
            isSelected: false,
            action: {}
        )
    }
    .padding()
    .background(ColorPalette.onboardingSolidDark)
}

#Preview("Text Cards") {
    VStack(spacing: 12) {
        OnboardingTextCard(
            option: "low",
            title: "Sedentary",
            subtitle: "Little or no exercise",
            isSelected: false,
            action: {}
        )

        OnboardingTextCard(
            option: "moderate",
            title: "Moderately Active",
            subtitle: "Exercise 3-5 days/week",
            isSelected: true,
            action: {}
        )

        OnboardingTextCard(
            option: "high",
            title: "Very Active",
            subtitle: "Hard exercise 6-7 days/week",
            isSelected: false,
            action: {}
        )
    }
    .padding()
    .background(ColorPalette.onboardingSolidDark)
}

#Preview("Light Mode") {
    VStack(spacing: 16) {
        OnboardingSelectionCard(
            option: "test",
            title: "Lose Weight",
            description: "Sustainable fat loss while maintaining energy",
            icon: "ignored",
            iconColor: .blue,
            isSelected: true,
            action: {}
        )

        OnboardingSelectionCard(
            option: "test2",
            title: "Build Muscle",
            description: "Gain lean mass with optimal protein intake",
            icon: "ignored",
            iconColor: .blue,
            isSelected: false,
            action: {}
        )
    }
    .padding()
    .background(ColorPalette.onboardingSolidLight)
    .preferredColorScheme(.light)
}
