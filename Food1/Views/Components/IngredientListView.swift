//
//  IngredientListView.swift
//  Food1
//
//  Displays ingredient list with edit/delete functionality for NutritionReviewView.
//
//  WHY THIS ARCHITECTURE:
//  - MVP decision: No manual "Add Ingredient" button (AI-detected only)
//  - Rationale: Adding manual ingredient requires nutrition lookup, complicates UX
//  - Users can edit names/grams or delete, but not add new ingredients
//  - editingIngredientId tracks which row is expanded for inline editing
//

import SwiftUI

struct IngredientListView: View {
    @Binding var ingredients: [IngredientRowData]
    @State private var editingIngredientId: UUID? = nil

    var body: some View {
        Section {
            if ingredients.isEmpty {
                Text("No ingredients detected")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach($ingredients) { $ingredient in
                    IngredientRow(
                        ingredient: $ingredient,
                        isEditing: editingIngredientId == ingredient.id,
                        onTap: {
                            if editingIngredientId == ingredient.id {
                                editingIngredientId = nil  // Close if already editing
                            } else {
                                editingIngredientId = ingredient.id  // Open for editing
                            }
                        },
                        onDismiss: {
                            editingIngredientId = nil
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteIngredient(ingredient)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Ingredients")
                    .textCase(.uppercase)

                Spacer()

                if !ingredients.isEmpty {
                    Text("\(ingredients.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func deleteIngredient(_ ingredient: IngredientRowData) {
        withAnimation {
            ingredients.removeAll { $0.id == ingredient.id }
        }
        HapticManager.medium()
    }
}

/// Lightweight data structure for ingredient editing (before saving to SwiftData)
struct IngredientRowData: Identifiable {
    let id: UUID
    var name: String
    var grams: Double

    init(id: UUID = UUID(), name: String, grams: Double) {
        self.id = id
        self.name = name
        self.grams = grams
    }

    /// Create from FoodRecognitionService.IngredientData
    init(from ingredientData: FoodRecognitionService.IngredientData) {
        self.id = UUID()
        self.name = ingredientData.name
        self.grams = ingredientData.grams
    }
}
