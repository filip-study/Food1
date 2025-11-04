//
//  MealCard.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct MealCard: View {
    let meal: Meal

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: meal.timestamp)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Emoji
            Text(meal.emoji)
                .font(.system(size: 44))
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )

            // Meal info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(meal.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Text(timeString)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // Macros
                HStack(spacing: 16) {
                    MacroTag(
                        value: Int(meal.calories),
                        unit: "cal",
                        color: .purple
                    )

                    MacroTag(
                        value: Int(meal.protein),
                        unit: "P",
                        color: .blue
                    )

                    MacroTag(
                        value: Int(meal.carbs),
                        unit: "C",
                        color: .green
                    )

                    MacroTag(
                        value: Int(meal.fat),
                        unit: "F",
                        color: .orange
                    )

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct MacroTag: View {
    let value: Int
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text(unit)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        MealCard(
            meal: Meal(
                name: "Grilled Chicken Salad",
                emoji: "🥗",
                timestamp: Date(),
                calories: 420,
                protein: 38,
                carbs: 28,
                fat: 18
            )
        )

        MealCard(
            meal: Meal(
                name: "Oatmeal with Berries",
                emoji: "🥣",
                timestamp: Date().addingTimeInterval(-3600),
                calories: 320,
                protein: 12,
                carbs: 54,
                fat: 8
            )
        )

        MealCard(
            meal: Meal(
                name: "Salmon with Quinoa",
                emoji: "🐟",
                timestamp: Date().addingTimeInterval(-7200),
                calories: 520,
                protein: 42,
                carbs: 48,
                fat: 18
            )
        )
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
