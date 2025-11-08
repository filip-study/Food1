//
//  MealIngredient.swift
//  Food1
//
//  Ingredient breakdown for meals with USDA micronutrient tracking
//

import Foundation
import SwiftData

@Model
final class MealIngredient {
    var id: UUID
    var name: String
    var grams: Double

    // USDA FoodData Central ID (nil if not matched yet)
    var usdaFdcId: String?

    // Cached micronutrient data (JSON blob for offline access)
    var cachedMicronutrientsJSON: Data?

    // Flag to track user edits (for analytics)
    var isUserEdited: Bool

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    init(name: String, grams: Double, usdaFdcId: String? = nil) {
        self.id = UUID()
        self.name = name
        self.grams = grams
        self.usdaFdcId = usdaFdcId
        self.isUserEdited = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    /// Check if ingredient has USDA match (for UI badge display)
    var hasUSDAData: Bool {
        usdaFdcId != nil && cachedMicronutrientsJSON != nil
    }

    /// Decode cached micronutrients from JSON
    var micronutrients: [Micronutrient]? {
        guard let data = cachedMicronutrientsJSON else { return nil }
        return try? JSONDecoder().decode([Micronutrient].self, from: data)
    }

    // MARK: - Methods

    /// Cache micronutrients to JSON blob
    func cacheMicronutrients(_ nutrients: [Micronutrient]) {
        cachedMicronutrientsJSON = try? JSONEncoder().encode(nutrients)
        updatedAt = Date()
    }

    /// Update gram amount (triggers user edit flag)
    func updateGrams(_ newGrams: Double) {
        grams = newGrams
        isUserEdited = true
        updatedAt = Date()
    }
}
