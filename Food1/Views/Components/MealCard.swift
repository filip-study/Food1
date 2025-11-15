//
//  MealCard.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct MealCard: View {
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric
    @Environment(\.colorScheme) var colorScheme

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
            // Photo or Emoji (cleaner, more compact)
            Group {
                if let imageData = meal.photoData,
                   let uiImage = UIImage(data: imageData) {
                    // Layer 1: Show captured food photo
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                } else {
                    // Layer 2: Fallback to emoji
                    Text(meal.emoji)
                        .font(.system(size: 44))
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemGray6).opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }

            // Meal info with clean hierarchy
            VStack(alignment: .leading, spacing: 6) {
                // Food name (single line, truncated) - PRIMARY
                Text(meal.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Time + Calories combined - SECONDARY
                HStack(spacing: 4) {
                    Text(timeString)
                    Text("•")
                    Text("\(Int(meal.calories)) cal")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.06),
                    radius: 12,
                    x: 0,
                    y: 4
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.04 : 0.02),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal)
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
