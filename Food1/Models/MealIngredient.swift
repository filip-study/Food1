//
//  MealIngredient.swift
//  Food1
//
//  Ingredient breakdown for meals with USDA micronutrient tracking.
//
//  WHY THIS ARCHITECTURE:
//  - usdaFdcId as String (not Int) matches USDA API format and handles future ID format changes
//  - matchMethod tracking enables debugging/analytics of fuzzy matching pipeline (Shortcut/Exact/LLM/Blacklisted)
//  - enrichmentAttempted flag prevents redundant USDA lookups for unmatched ingredients
//  - cachedMicronutrientsJSON stores offline data as JSON blob for instant access without database queries
//  - isUserEdited tracks manual adjustments for potential ML training data
//

import Foundation
import SwiftData

@Model
final class MealIngredient {
    var id: UUID
    var name: String
    var grams: Double

    // Per-ingredient macros (from AI prediction, enables recalculation on edit)
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    // USDA FoodData Central ID (nil if not matched yet)
    var usdaFdcId: String?

    // Match method used to find USDA food (for debugging)
    // Values: "Shortcut", "Exact", "LLM", "Blacklisted"
    var matchMethod: String?

    // Whether enrichment has been attempted (regardless of success)
    var enrichmentAttempted: Bool = false

    // Cached micronutrient data (JSON blob for offline access)
    var cachedMicronutrientsJSON: Data?

    // MARK: - Transient Cache (not persisted)
    // These caches avoid repeated JSON decoding when accessing micronutrients
    @Transient private var _cachedMicronutrients: [Micronutrient]?
    @Transient private var _lastDecodedHash: Int?

    // Flag to track user edits (for analytics)
    var isUserEdited: Bool

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Cloud Sync Fields

    /// Supabase ingredient ID (different from local SwiftData id)
    var cloudId: UUID?

    /// USDA description from database (for display)
    var usdaDescription: String?

    init(name: String, grams: Double, calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0, usdaFdcId: String? = nil) {
        self.id = UUID()
        self.name = name
        self.grams = grams
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
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

    /// Decode cached micronutrients from JSON (with in-memory caching)
    /// Uses hash-based invalidation to avoid repeated decoding of unchanged data
    var micronutrients: [Micronutrient]? {
        guard let data = cachedMicronutrientsJSON else {
            _cachedMicronutrients = nil
            return nil
        }

        // Return cached if data hasn't changed
        let currentHash = data.hashValue
        if let cached = _cachedMicronutrients, _lastDecodedHash == currentHash {
            return cached
        }

        // Decode and cache
        let decoded = try? JSONDecoder().decode([Micronutrient].self, from: data)
        _cachedMicronutrients = decoded
        _lastDecodedHash = currentHash
        return decoded
    }

    // MARK: - Methods

    /// Cache micronutrients to JSON blob
    func cacheMicronutrients(_ nutrients: [Micronutrient]) {
        cachedMicronutrientsJSON = try? JSONEncoder().encode(nutrients)
        // Clear transient cache so next access re-decodes from fresh data
        _cachedMicronutrients = nil
        _lastDecodedHash = nil
        updatedAt = Date()
    }

    /// Update gram amount (triggers user edit flag)
    func updateGrams(_ newGrams: Double) {
        grams = newGrams
        isUserEdited = true
        updatedAt = Date()
    }
}
