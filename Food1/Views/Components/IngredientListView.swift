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

/// Lightweight data structure for ingredient editing (before saving to SwiftData)
/// Includes per-ingredient macros for real-time recalculation when user edits ingredients
struct IngredientRowData: Identifiable, Equatable {
    let id: UUID
    var name: String
    var grams: Double
    var calories: Double  // Per-ingredient calories
    var protein: Double   // Per-ingredient protein
    var carbs: Double     // Per-ingredient carbs
    var fat: Double       // Per-ingredient fat

    // Original AI values (immutable, used for proportional scaling)
    // Scaling from originals prevents cumulative rounding errors
    private let originalGrams: Double
    private let originalCalories: Double
    private let originalProtein: Double
    private let originalCarbs: Double
    private let originalFat: Double

    // Equatable: compare current values (not originals, which never change)
    static func == (lhs: IngredientRowData, rhs: IngredientRowData) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.grams == rhs.grams &&
        lhs.calories == rhs.calories &&
        lhs.protein == rhs.protein &&
        lhs.carbs == rhs.carbs &&
        lhs.fat == rhs.fat
    }

    init(id: UUID = UUID(), name: String, grams: Double, calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.id = id
        self.name = name
        self.grams = grams
        self.originalGrams = grams
        self.calories = calories
        self.originalCalories = calories
        self.protein = protein
        self.originalProtein = protein
        self.carbs = carbs
        self.originalCarbs = carbs
        self.fat = fat
        self.originalFat = fat
    }

    /// Create from FoodRecognitionService.IngredientData
    init(from ingredientData: FoodRecognitionService.IngredientData) {
        self.id = UUID()
        self.name = ingredientData.name
        self.grams = ingredientData.grams
        self.originalGrams = ingredientData.grams
        self.calories = ingredientData.calories ?? 0
        self.originalCalories = ingredientData.calories ?? 0
        self.protein = ingredientData.protein ?? 0
        self.originalProtein = ingredientData.protein ?? 0
        self.carbs = ingredientData.carbs ?? 0
        self.originalCarbs = ingredientData.carbs ?? 0
        self.fat = ingredientData.fat ?? 0
        self.originalFat = ingredientData.fat ?? 0
    }

    /// Scale all macros proportionally when grams change
    /// Scales from original AI values to prevent cumulative rounding errors
    mutating func updateGrams(_ newGrams: Double) {
        guard originalGrams > 0 else {
            grams = newGrams
            return
        }
        let multiplier = newGrams / originalGrams
        grams = newGrams
        calories = originalCalories * multiplier
        protein = originalProtein * multiplier
        carbs = originalCarbs * multiplier
        fat = originalFat * multiplier
    }

    /// Apply a portion multiplier to scale grams and macros
    /// Used when user adjusts serving size (e.g., 0.75x, 2x)
    mutating func applyPortionMultiplier(_ multiplier: Double) {
        let newGrams = originalGrams * multiplier
        updateGrams(newGrams)
    }
}
