//
//  DietTypeSelectionView.swift
//  Food1
//
//  Onboarding step 2: Select dietary preference.
//  Balanced, Low-Carb, or Vegan/Vegetarian.
//

import SwiftUI

struct DietTypeSelectionView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    var onBack: () -> Void
    var onNext: () -> Void
    var onSkip: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                    .padding(.top, 24)

                // Diet options
                VStack(spacing: 16) {
                    ForEach(DietType.allCases) { diet in
                        OnboardingSelectionCard(
                            option: diet,
                            title: diet.title,
                            description: diet.description,
                            icon: diet.icon,
                            iconColor: diet.iconColor,
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
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Do you follow a specific diet?")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Don't worry if yours isn't listed — just choose Balanced")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Footer Note

    private var footerNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.cyan)

            Text("This affects your recommended macro balance")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Continue button
            VStack(spacing: 8) {
                OnboardingNextButton(
                    text: data.dietType != nil ? "Continue" : "Select a diet",
                    isEnabled: data.dietType != nil,
                    action: onNext
                )

                Button("Skip for now", action: onSkip)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
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

        DietTypeSelectionView(
            data: OnboardingData(),
            onBack: { print("Back") },
            onNext: { print("Next") },
            onSkip: { print("Skip") }
        )
    }
}
