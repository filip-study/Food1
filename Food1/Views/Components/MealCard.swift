//
//  MealCard.swift
//  Food1
//
//  Meal summary card with 3-layer image hierarchy and macro indicators.
//
//  WHY THIS ARCHITECTURE:
//  - Uses MealImageView for 3-layer image hierarchy: photoData → photoThumbnailUrl → emoji
//  - Sparkle badge on AI-generated cartoon icons (visual indicator of AI magic)
//  - 2-line .lineLimit for food names handles 40-char names without overflow
//  - Time moved below name (not inline) provides more horizontal space for longer names
//  - Frosted glass (.thinMaterial 97%) + layered shadows match premium Oura/Function Health aesthetic
//  - Macro order standard: Protein → Fat → Carbs (teal, blue, pink) - consistent across all views
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
        let fat = NutritionFormatter.formatValue(meal.fat, unit: nutritionUnit, decimals: 0)
        let carbs = NutritionFormatter.formatValue(meal.carbs, unit: nutritionUnit, decimals: 0)

        // Order: Cal → Protein → Fat → Carbs
        return "\(Int(meal.calories))cal  •  \(protein)P  •  \(fat)F  •  \(carbs)C"
    }


    var body: some View {
        HStack(spacing: 16) {
            // Photo or Emoji - uses 3-layer hierarchy: photoData → photoThumbnailUrl → emoji
            MealImageView(meal: meal, size: 80, cornerRadius: 14)

            // Meal info with clean hierarchy
            VStack(alignment: .leading, spacing: 6) {
                // Food name (single line, truncated) - PRIMARY
                Text(meal.name)
                    .font(DesignSystem.Typography.semiBold(size: 17))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Time + Calories combined - SECONDARY
                HStack(spacing: 4) {
                    Text(timeString)
                    Text("•")
                    Text("\(Int(meal.calories)) cal")
                }
                .font(DesignSystem.Typography.medium(size: 14))
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
