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
            Label("Ingredients", systemImage: "list.bullet")
        }
    }

    private func deleteIngredient(_ ingredient: IngredientRowData) {
        withAnimation {
            ingredients.removeAll { $0.id == ingredient.id }
        }
        HapticManager.medium()
    }
}
