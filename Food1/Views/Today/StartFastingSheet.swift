//
//  StartFastingSheet.swift
//  Food1
//
//  Compact sheet for choosing when to start a fast.
//
//  WHY THIS ARCHITECTURE:
//  - Appears after tapping "Fasting" in FAB menu
//  - Two options: "Now" (current time) or "From Last Meal" (retroactive)
//  - Shows time since last meal for context
//  - Compact height (~180pt) - quick decision, not overwhelming
//  - Amber color scheme consistent with fasting UI
//  - Skip sheet entirely if no last meal (just start now)
//

import SwiftUI

struct StartFastingSheet: View {
    let lastMealDate: Date?
    let onStartNow: () -> Void
    let onStartFromLastMeal: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Time since last meal formatted
    private var timeSinceLastMeal: String? {
        guard let lastMeal = lastMealDate else { return nil }
        let seconds = Int(Date().timeIntervalSince(lastMeal))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h ago"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m ago"
        } else {
            return "\(minutes)m ago"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // Header
            Text("Start Fasting")
                .font(DesignSystem.Typography.semiBold(size: 17))
                .padding(.bottom, 16)

            // Options list
            VStack(spacing: 0) {
                // Start Now option
                Button {
                    HapticManager.medium()
                    dismiss()
                    onStartNow()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorPalette.calories)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start now")
                                .font(DesignSystem.Typography.medium(size: 16))
                                .foregroundStyle(.primary)

                            Text("Begin from current time")
                                .font(DesignSystem.Typography.regular(size: 12))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Text(Date(), style: .time)
                            .font(DesignSystem.Typography.regular(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                // From Last Meal option (only if last meal exists)
                if let lastMeal = lastMealDate {
                    Divider()
                        .padding(.leading, 56)

                    Button {
                        HapticManager.medium()
                        dismiss()
                        onStartFromLastMeal(lastMeal)
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorPalette.calories)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("From last meal")
                                    .font(DesignSystem.Typography.medium(size: 16))
                                    .foregroundStyle(.primary)

                                if let timeSince = timeSinceLastMeal {
                                    Text(timeSince)
                                        .font(DesignSystem.Typography.regular(size: 12))
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            Text(lastMeal, style: .time)
                                .font(DesignSystem.Typography.regular(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.height(lastMealDate != nil ? 240 : 160)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }
}

// MARK: - Preview

#Preview("With Last Meal") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            StartFastingSheet(
                lastMealDate: Date().addingTimeInterval(-3.5 * 3600),
                onStartNow: { print("Start now") },
                onStartFromLastMeal: { date in print("Start from \(date)") }
            )
        }
}

#Preview("No Last Meal") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            StartFastingSheet(
                lastMealDate: nil,
                onStartNow: { print("Start now") },
                onStartFromLastMeal: { _ in }
            )
        }
}

#Preview("Long Time Ago") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            StartFastingSheet(
                lastMealDate: Date().addingTimeInterval(-26 * 3600),
                onStartNow: { print("Start now") },
                onStartFromLastMeal: { date in print("Start from \(date)") }
            )
        }
}

#Preview("Dark Mode") {
    Color.clear
        .preferredColorScheme(.dark)
        .sheet(isPresented: .constant(true)) {
            StartFastingSheet(
                lastMealDate: Date().addingTimeInterval(-5 * 3600),
                onStartNow: { print("Start now") },
                onStartFromLastMeal: { date in print("Start from \(date)") }
            )
        }
}
