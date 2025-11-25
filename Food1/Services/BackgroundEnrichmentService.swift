//
//  BackgroundEnrichmentService.swift
//  Food1
//
//  Background service for enriching ingredients with micronutrients from local USDA database.
//  100% offline, zero API calls, async processing doesn't block UI.
//
//  WHY THIS ARCHITECTURE:
//  - Sequential processing (not parallel) enables readable debug logs and controlled resource usage
//  - enrichmentAttempted flag prevents redundant lookups on app restart or background task re-run
//  - SwiftData observation automatically updates UI when cachedMicronutrientsJSON changes (no manual refresh)
//  - Non-blocking: Meal save completes instantly, enrichment happens after in background (100-200ms typical)
//  - 10-minute recent window (in Food1App) prevents infinite re-attempts on old unmatched ingredients
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
        #if DEBUG
        print("\n📊 Starting background enrichment for \(ingredients.count) ingredients\n")
        #endif

        // Process ingredients sequentially for readable logs
        for (index, ingredient) in ingredients.enumerated() {
            // Skip if already has USDA data
            guard ingredient.usdaFdcId == nil else {
                #if DEBUG
                print("⏭️  [\(index + 1)/\(ingredients.count)] Skipping '\(ingredient.name)' (already enriched)\n")
                #endif
                continue
            }

            #if DEBUG
            print("🔄 [\(index + 1)/\(ingredients.count)] Processing: '\(ingredient.name)'")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #endif
            await enrichIngredient(ingredient)
            #if DEBUG
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            #endif
        }

        #if DEBUG
        print("✅ Background enrichment complete\n")
        #endif
    }

    // MARK: - Private Methods

    private func enrichIngredient(_ ingredient: MealIngredient) async {
        // 1. Fuzzy match ingredient name to USDA food (with local LLM re-ranking)
        let (matchedFood, matchMethod) = await FuzzyMatchingService.shared.matchWithMethod(ingredient.name)

        // Mark as attempted regardless of success
        ingredient.enrichmentAttempted = true

        // Store match method even if no food matched (e.g., blacklisted)
        if matchMethod != nil && matchedFood == nil {
            ingredient.matchMethod = matchMethod?.rawValue
        }

        guard let matchedFood = matchedFood else {
            return
        }

        // 2. Fetch micronutrients from local database
        #if DEBUG
        print("  💊 Fetching micronutrients from database...")
        #endif
        let micronutrients = LocalUSDAService.shared.getMicronutrients(
            fdcId: matchedFood.fdcId,
            grams: ingredient.grams
        )

        guard !micronutrients.isEmpty else {
            #if DEBUG
            print("  ⚠️  No micronutrients found for fdcId \(matchedFood.fdcId)")
            #endif
            return
        }

        // 3. Cache micronutrients in ingredient
        ingredient.usdaFdcId = String(matchedFood.fdcId)
        ingredient.matchMethod = matchMethod?.rawValue
        ingredient.cacheMicronutrients(micronutrients)
        ingredient.updatedAt = Date()

        #if DEBUG
        print("  ✅ Cached \(micronutrients.count) micronutrients (via \(matchMethod?.rawValue ?? "unknown"))")
        #endif
    }
}
