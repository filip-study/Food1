//
//  DietTypeSelectionView.swift
//  Food1
//
//  Onboarding step 2: Select dietary preference.
//
//  ACT II - DISCOVERY DESIGN:
//  - Solid color background for high visibility
//  - Primary/secondary text colors (adapts to light/dark mode)
//  - Typography-only selection cards (no icons)
//

import SwiftUI

struct DietTypeSelectionView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    var onBack: () -> Void
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

                    // Diet options - typography-only cards
                    VStack(spacing: 16) {
                        ForEach(DietType.allCases) { diet in
                            OnboardingSelectionCard(
                                option: diet,
                                title: diet.title,
                                description: diet.description,
                                icon: diet.icon,  // Ignored
                                iconColor: .white,  // Ignored
                                isSelected: data.dietType == diet,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        data.dietType = diet
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
        }
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Do you follow a specific diet?")
                .font(DesignSystem.Typography.bold(size: 28))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text("Don't worry if yours isn't listed — just choose Balanced")
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Footer Note

    private var footerNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)

            Text("This affects your recommended macro balance")
                .font(DesignSystem.Typography.regular(size: 14))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            OnboardingBackButton(action: onBack)

            // Continue button
            VStack(spacing: 8) {
                OnboardingNextButton(
                    text: data.dietType != nil ? "Continue" : "Select a diet",
                    isEnabled: data.dietType != nil,
                    action: onNext
                )

                Button("Skip for now", action: onSkip)
                    .font(DesignSystem.Typography.regular(size: 14))
                    .foregroundStyle(.tertiary)
            }
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
    DietTypeSelectionView(
        data: OnboardingData(),
        onBack: { print("Back") },
        onNext: { print("Next") },
        onSkip: { print("Skip") }
    )
}
