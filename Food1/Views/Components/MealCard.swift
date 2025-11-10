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

    // Determine dominant macro (highest value)
    private var dominantMacro: String {
        let macros = [
            ("protein", meal.protein),
            ("carbs", meal.carbs),
            ("fat", meal.fat)
        ]
        return macros.max(by: { $0.1 < $1.1 })?.0 ?? "protein"
    }

    var body: some View {
        HStack(spacing: 20) {
            // Photo or Emoji (Oura-inspired large format)
            Group {
                if let imageData = meal.photoData,
                   let uiImage = UIImage(data: imageData) {
                    // Layer 1: Show captured food photo
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                } else {
                    // Layer 2: Fallback to emoji
                    Text(meal.emoji)
                        .font(.system(size: 56))
                        .frame(width: 100, height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6).opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }

            // Meal info with enhanced typography
            VStack(alignment: .leading, spacing: 8) {
                // Food name (up to 2 lines) - Larger, bolder
                Text(meal.name)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Time - subtle secondary text
                Text(timeString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                // Calories - Hero metric style
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(meal.calories))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("cal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // Macro display with enhanced spacing
                HStack(spacing: 12) {
                    MacroLabel(value: meal.protein, color: .blue, label: "P", isDominant: dominantMacro == "protein")
                    MacroLabel(value: meal.carbs, color: .orange, label: "C", isDominant: dominantMacro == "carbs")
                    MacroLabel(value: meal.fat, color: .green, label: "F", isDominant: dominantMacro == "fat")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal)
    }
}

/// Color-coded macro label component with visual hierarchy
struct MacroLabel: View {
    let value: Double
    let color: Color
    let label: String
    let isDominant: Bool

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: isDominant ? 8 : 6, height: isDominant ? 8 : 6)
            Text("\(Int(value))g")
                .font(.system(size: isDominant ? 14 : 13, weight: isDominant ? .semibold : .medium))
                .foregroundStyle(isDominant ? .primary : .secondary)
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
