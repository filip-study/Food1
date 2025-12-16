//
//  Meal.swift
//  Food1
//
//  SwiftData model for meal entries with nutrition tracking and micronutrient support.
//
//  WHY THIS ARCHITECTURE:
//  - Stores macronutrients (calories, protein, carbs, fat) directly for fast queries
//  - Optional ingredients relationship enables micronutrient tracking without breaking existing meals
//  - Cascade delete ensures orphaned ingredients don't persist after meal deletion
//  - photoData stores compressed JPEG (not raw UIImage) to optimize storage and SwiftData performance
//  - matchedIconName enables 3-layer image hierarchy (photo → cartoon → emoji) for rich UI
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
    var fiber: Double
    var notes: String?
    var photoData: Data?  // Stores JPEG image data when meal logged via photo recognition

    // Micronutrient tracking: Ingredient breakdown with USDA matching
    @Relationship(deleteRule: .cascade) var ingredients: [MealIngredient]?

    // Matched cartoon icon name (for UI display)
    var matchedIconName: String?

    // MARK: - Cloud Sync Fields

    /// Supabase meal ID (different from local SwiftData id)
    var cloudId: UUID?

    /// Sync status: pending, syncing, synced, error
    var syncStatus: String

    /// Timestamp of last successful sync to Supabase
    var lastSyncedAt: Date?

    /// Device identifier that created this meal (for conflict resolution)
    var deviceId: String?

    /// Meal type for categorization (breakfast, lunch, dinner, snack)
    var mealType: String?

    /// Cloud URL for photo thumbnail (100KB max, stored in Supabase Storage)
    var photoThumbnailUrl: String?

    /// Cloud URL for cartoon image (if generated)
    var cartoonImageUrl: String?

    /// Original user prompt for text-based meal entries (e.g., "3 eggs with mayo and bacon")
    /// Useful for analytics, debugging AI recognition, and improving prompts
    var userPrompt: String?

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        timestamp: Date,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double = 0.0,
        notes: String? = nil,
        photoData: Data? = nil,
        ingredients: [MealIngredient]? = nil,
        matchedIconName: String? = nil,
        cloudId: UUID? = nil,
        syncStatus: String = "pending",
        lastSyncedAt: Date? = nil,
        deviceId: String? = nil,
        mealType: String? = nil,
        photoThumbnailUrl: String? = nil,
        cartoonImageUrl: String? = nil,
        userPrompt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.timestamp = timestamp
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.notes = notes
        self.photoData = photoData
        self.ingredients = ingredients
        self.matchedIconName = matchedIconName
        self.cloudId = cloudId
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
        self.deviceId = deviceId
        self.mealType = mealType
        self.photoThumbnailUrl = photoThumbnailUrl
        self.cartoonImageUrl = cartoonImageUrl
        self.userPrompt = userPrompt
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
                // Original minerals
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
                case "Sodium":
                    profile.sodium += nutrient.amount
                // New minerals
                case "Phosphorus":
                    profile.phosphorus += nutrient.amount
                case "Copper":
                    profile.copper += nutrient.amount
                case "Selenium":
                    profile.selenium += nutrient.amount
                // Original vitamins
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
                case "Folate", "Folate (Vitamin B9)":
                    profile.folate += nutrient.amount
                // New vitamins
                case "Vitamin K":
                    profile.vitaminK += nutrient.amount
                case "Thiamin", "Vitamin B1 (Thiamin)":
                    profile.vitaminB1 += nutrient.amount
                case "Riboflavin", "Vitamin B2 (Riboflavin)":
                    profile.vitaminB2 += nutrient.amount
                case "Niacin", "Vitamin B3 (Niacin)":
                    profile.vitaminB3 += nutrient.amount
                case "Pantothenic acid", "Vitamin B5 (Pantothenic Acid)":
                    profile.vitaminB5 += nutrient.amount
                case "Vitamin B-6", "Vitamin B6":
                    profile.vitaminB6 += nutrient.amount
                default:
                    break
                }
            }
        }

        return profile.toMicronutrients()
            .filter { $0.amount > 0.01 }  // Remove zero/trace amounts
            .sorted { $0.rdaPercent > $1.rdaPercent }  // Sort by RDA % descending (highest first)
    }

    /// Check if meal needs to be synced to cloud
    var needsSync: Bool {
        return syncStatus == "pending" || syncStatus == "error"
    }

    /// Check if meal is currently being synced
    var isSyncing: Bool {
        return syncStatus == "syncing"
    }

    /// Check if meal is synced and up-to-date in cloud
    var isSynced: Bool {
        return syncStatus == "synced" && cloudId != nil
    }

    /// Check if meal has a photo that failed to upload and needs retry
    /// Condition: has local photo, no cloud URL, but meal is synced (so photo upload must have failed)
    var needsPhotoUpload: Bool {
        return photoData != nil &&
               photoThumbnailUrl == nil &&
               syncStatus == "synced" &&
               cloudId != nil
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
