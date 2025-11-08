//
//  Meal.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import Foundation
import SwiftData

@Model
final class Meal {
    var id: UUID
    var name: String
    var emoji: String
    var timestamp: Date
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var notes: String?
    var photoData: Data?  // Stores JPEG image data when meal logged via photo recognition

    // Micronutrient tracking: Ingredient breakdown with USDA matching
    @Relationship(deleteRule: .cascade) var ingredients: [MealIngredient]?

    // Matched cartoon icon name (for UI display)
    var matchedIconName: String?

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        timestamp: Date,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        notes: String? = nil,
        photoData: Data? = nil,
        ingredients: [MealIngredient]? = nil,
        matchedIconName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.timestamp = timestamp
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.notes = notes
        self.photoData = photoData
        self.ingredients = ingredients
        self.matchedIconName = matchedIconName
    }

    // MARK: - Computed Properties

    /// Check if meal has ingredients with micronutrient data
    var hasMicronutrients: Bool {
        guard let ingredients = ingredients, !ingredients.isEmpty else {
            return false
        }
        return ingredients.contains { $0.hasUSDAData }
    }

    /// Aggregate micronutrients across all ingredients
    var micronutrients: [Micronutrient] {
        guard let ingredients = ingredients, !ingredients.isEmpty else {
            return []
        }

        var profile = MicronutrientProfile()

        for ingredient in ingredients {
            guard let nutrients = ingredient.micronutrients else { continue }

            for nutrient in nutrients {
                switch nutrient.name {
                case "Calcium":
                    profile.calcium += nutrient.amount
                case "Iron":
                    profile.iron += nutrient.amount
                case "Magnesium":
                    profile.magnesium += nutrient.amount
                case "Potassium":
                    profile.potassium += nutrient.amount
                case "Zinc":
                    profile.zinc += nutrient.amount
                case "Vitamin A":
                    profile.vitaminA += nutrient.amount
                case "Vitamin C":
                    profile.vitaminC += nutrient.amount
                case "Vitamin D":
                    profile.vitaminD += nutrient.amount
                case "Vitamin E":
                    profile.vitaminE += nutrient.amount
                case "Vitamin B12":
                    profile.vitaminB12 += nutrient.amount
                case "Folate":
                    profile.folate += nutrient.amount
                case "Sodium":
                    profile.sodium += nutrient.amount
                default:
                    break
                }
            }
        }

        return profile.toMicronutrients()
    }

    // Static helper method for calculating totals
    static func calculateTotals(for meals: [Meal]) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let totalCalories = meals.reduce(0) { $0 + $1.calories }
        let totalProtein = meals.reduce(0) { $0 + $1.protein }
        let totalCarbs = meals.reduce(0) { $0 + $1.carbs }
        let totalFat = meals.reduce(0) { $0 + $1.fat }

        return (totalCalories, totalProtein, totalCarbs, totalFat)
    }
}

// Daily goals
struct DailyGoals {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    static let standard = DailyGoals(
        calories: 2000,
        protein: 150,
        carbs: 225,
        fat: 65
    )
}
