//
//  OnboardingSelectionCard.swift
//  Food1
//
//  Reusable selection card for onboarding screens.
//  Bold, vibrant design distinct from in-app glassmorphic style.
//

import SwiftUI
import UIKit

struct OnboardingSelectionCard<T: Hashable>: View {

    // MARK: - Properties

    let option: T
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
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
            HStack(spacing: 16) {
                // Icon with colorful background
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? iconColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(iconColor)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding(20)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? iconColor : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: isSelected ? iconColor.opacity(0.2) : .black.opacity(0.05),
                radius: isSelected ? 12 : 8,
                y: isSelected ? 4 : 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background

    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(UIColor.systemGray6)
            } else {
                Color.white
            }
        }
    }
}

// MARK: - Compact Variant (for smaller screens or more options)

struct OnboardingSelectionCardCompact<T: Hashable>: View {

    let option: T
    let title: String
    let icon: String
    let iconColor: Color
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
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                // Title
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? iconColor : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: isSelected ? iconColor.opacity(0.2) : .black.opacity(0.05),
                radius: isSelected ? 8 : 4,
                y: 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(UIColor.systemGray6)
            } else {
                Color.white
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            OnboardingSelectionCard(
                option: "weightLoss",
                title: "Weight Loss",
                description: "Lose weight while maintaining energy",
                icon: "arrow.down.circle.fill",
                iconColor: .orange,
                isSelected: true,
                action: {}
            )

            OnboardingSelectionCard(
                option: "health",
                title: "Health Optimization",
                description: "Optimize nutrition for overall wellness",
                icon: "heart.circle.fill",
                iconColor: .pink,
                isSelected: false,
                action: {}
            )

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
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}
