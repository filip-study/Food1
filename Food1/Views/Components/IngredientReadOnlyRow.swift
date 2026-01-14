//
//  IngredientReadOnlyRow.swift
//  Food1
//
//  Read-only display of meal ingredient with name and grams
//  Used in MealDetailView to show what's in the meal
//

import SwiftUI

struct IngredientReadOnlyRow: View {
    let ingredient: MealIngredient
    var showStatus: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator (optional)
            if showStatus {
                Group {
                    if ingredient.usdaFdcId != nil {
                        // Matched successfully
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue.opacity(0.6))
                    } else if ingredient.matchMethod == "Blacklisted" {
                        // Skipped - no micronutrients
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.gray.opacity(0.4))
                    } else if ingredient.enrichmentAttempted {
                        // Failed to match
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange.opacity(0.5))
                    } else {
                        // Not attempted yet
                        Image(systemName: "circle")
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
                .font(.caption)
                .frame(width: 16)
            }

            // Ingredient name
            Text(ingredient.name.isEmpty ? "Unknown ingredient" : ingredient.name)
                .font(DesignSystem.Typography.medium(size: 15))
                .foregroundColor(ingredient.name.isEmpty ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            // Grams amount
            Text("\(Int(ingredient.grams))g")
                .font(DesignSystem.Typography.semiBold(size: 14))
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ingredient.name.isEmpty ? "Unknown ingredient" : ingredient.name), \(Int(ingredient.grams)) grams\(showStatus && ingredient.usdaFdcId == nil ? ", limited nutrition data" : "")")
    }
}

#Preview {
    let ingredient = MealIngredient(
        name: "Grilled Salmon",
        grams: 150
    )

    return VStack {
        IngredientReadOnlyRow(ingredient: ingredient)
            .padding()

        Divider()

        IngredientReadOnlyRow(ingredient: MealIngredient(name: "Brown Rice", grams: 100))
            .padding()
    }
}
