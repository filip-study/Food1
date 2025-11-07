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
            // Photo or Emoji
            Group {
                if let imageData = meal.photoData,
                   let uiImage = UIImage(data: imageData) {
                    // Show captured food photo
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
                        )
                } else {
                    // Fallback to emoji
                    Text(meal.emoji)
                        .font(.system(size: 36))
                        .frame(width: 60, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                }
            }

            // Meal info
            VStack(alignment: .leading, spacing: 6) {
                // Food name (up to 2 lines)
                Text(meal.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Time + Calories combined
                HStack(spacing: 4) {
                    Text(timeString)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("\(Int(meal.calories)) cal")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                }

                // Improved macro display with color dots
                HStack(spacing: 8) {
                    MacroLabel(value: meal.protein, color: .blue, label: "P")
                    MacroLabel(value: meal.carbs, color: .orange, label: "C")
                    MacroLabel(value: meal.fat, color: .green, label: "F")
                }
            }

            Spacer(minLength: 0)
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

/// Color-coded macro label component
struct MacroLabel: View {
    let value: Double
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(Int(value))g")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Test with longer name (2 lines)
        MealCard(
            meal: Meal(
                name: "Grilled Chicken Caesar Salad Bowl",
                emoji: "🥗",
                timestamp: Date(),
                calories: 420,
                protein: 38,
                carbs: 28,
                fat: 18
            )
        )

        // Test with medium name (1 line)
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

        // Test with short name (1 line)
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
