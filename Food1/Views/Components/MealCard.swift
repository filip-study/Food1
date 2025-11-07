//
//  MealCard.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct MealCard: View {
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric

    let meal: Meal

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: meal.timestamp)
    }

    private var macroString: String {
        let protein = NutritionFormatter.formatValue(meal.protein, unit: nutritionUnit, decimals: 0)
        let carbs = NutritionFormatter.formatValue(meal.carbs, unit: nutritionUnit, decimals: 0)
        let fat = NutritionFormatter.formatValue(meal.fat, unit: nutritionUnit, decimals: 0)

        return "\(Int(meal.calories))cal  •  \(protein)P  •  \(carbs)C  •  \(fat)F"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Emoji
            Text(meal.emoji)
                .font(.system(size: 40))
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )

            // Meal info
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text(timeString)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text(macroString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            Spacer()

            // Subtle arrow indicator
            Image(systemName: "arrow.forward.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue.opacity(0.3))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
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
