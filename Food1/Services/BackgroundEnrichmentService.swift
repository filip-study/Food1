//
//  BackgroundEnrichmentService.swift
//  Food1
//
//  Background service for enriching ingredients with micronutrients from local USDA database
//  100% offline, zero API calls, async processing doesn't block UI
//

import Foundation
import SwiftData

/// Service for automatically enriching ingredients with USDA micronutrient data in background
@MainActor
class BackgroundEnrichmentService {
    static let shared = BackgroundEnrichmentService()

    private init() {}

    // MARK: - Public API

    /// Automatically enrich ingredients with USDA data in background
    /// - Parameter ingredients: Array of MealIngredient objects to enrich
    func enrichIngredients(_ ingredients: [MealIngredient]) async {
        print("\n📊 Starting background enrichment for \(ingredients.count) ingredients\n")

        // Process ingredients sequentially for readable logs
        for (index, ingredient) in ingredients.enumerated() {
            // Skip if already has USDA data
            guard ingredient.usdaFdcId == nil else {
                print("⏭️  [\(index + 1)/\(ingredients.count)] Skipping '\(ingredient.name)' (already enriched)\n")
                continue
            }

            print("🔄 [\(index + 1)/\(ingredients.count)] Processing: '\(ingredient.name)'")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            await enrichIngredient(ingredient)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        }

        print("✅ Background enrichment complete\n")
    }

    // MARK: - Private Methods

    private func enrichIngredient(_ ingredient: MealIngredient) async {
        // 1. Fuzzy match ingredient name to USDA food (with local LLM re-ranking)
        guard let matchedFood = await FuzzyMatchingService.shared.match(ingredient.name) else {
            return
        }

        // 2. Fetch micronutrients from local database
        print("  💊 Fetching micronutrients from database...")
        let micronutrients = LocalUSDAService.shared.getMicronutrients(
            fdcId: matchedFood.fdcId,
            grams: ingredient.grams
        )

        guard !micronutrients.isEmpty else {
            print("  ⚠️  No micronutrients found for fdcId \(matchedFood.fdcId)")
            return
        }

        // 3. Cache micronutrients in ingredient
        ingredient.usdaFdcId = String(matchedFood.fdcId)
        ingredient.cacheMicronutrients(micronutrients)
        ingredient.updatedAt = Date()

        print("  ✅ Cached \(micronutrients.count) micronutrients")
    }
}
