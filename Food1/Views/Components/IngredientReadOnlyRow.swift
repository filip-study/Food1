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
                Image(systemName: ingredient.usdaFdcId != nil ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundColor(ingredient.usdaFdcId != nil ? .blue.opacity(0.6) : .gray.opacity(0.4))
                    .frame(width: 16)
            }

            // Ingredient name
            Text(ingredient.name.isEmpty ? "Unknown ingredient" : ingredient.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ingredient.name.isEmpty ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            // Grams amount
            Text("\(Int(ingredient.grams))g")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
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
