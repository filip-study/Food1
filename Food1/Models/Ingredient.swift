//
//  Ingredient.swift
//  Food1
//
//  Created by Claude on 2025-11-08.
//

import Foundation
import SwiftData

/// Represents a single ingredient in a meal with its gram amount and USDA nutrient data reference
@Model
final class Ingredient {
    var id: UUID
    var name: String                    // e.g., "grilled chicken breast", "romaine lettuce"
    var grams: Double                   // Estimated grams from GPT-4o (with 15% conservative reduction)
    var usdaFoodID: String?             // FDC ID from USDA database (e.g., "171477")
    var confidence: Double              // Fuzzy matching confidence (0.0-1.0)

    // Relationship
    var meal: Meal?

    init(
        id: UUID = UUID(),
        name: String,
        grams: Double,
        usdaFoodID: String? = nil,
        confidence: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.grams = grams
        self.usdaFoodID = usdaFoodID
        self.confidence = confidence
    }

    /// Returns true if this ingredient has been matched to a USDA food
    var isMatched: Bool {
        usdaFoodID != nil && confidence > 0.5
    }
}
