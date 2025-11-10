//
//  FuzzyMatchingService.swift
//  Food1
//
//  Fuzzy matching service for ingredient names to USDA foods
//  Handles GPT-4o ingredient names like "Chicken breast, grilled" → USDA foods
//

import Foundation

/// Service for fuzzy matching ingredient names to local USDA database
class FuzzyMatchingService {
    static let shared = FuzzyMatchingService()

    private init() {}

    // MARK: - Public API

    /// Match ingredient name to best USDA food using local LLM re-ranking
    /// - Parameter ingredientName: Ingredient name from GPT-4o (e.g., "Chicken breast, grilled")
    /// - Returns: Matched USDA food or nil if no good match found
    func match(_ ingredientName: String) async -> USDAFood? {
        // Clean and tokenize ingredient name
        let cleanedName = cleanIngredientName(ingredientName)
        guard !cleanedName.isEmpty else { return nil }

        print("  🔍 Cleaned query: '\(ingredientName)' → '\(cleanedName)'")

        // Search local database for all candidates
        let candidates = LocalUSDAService.shared.search(query: cleanedName, limit: 50)

        guard !candidates.isEmpty else {
            print("  ⚠️  No database matches found")
            return nil
        }

        print("  📋 Found \(candidates.count) candidates, sending to LLM for re-ranking...")

        // Re-rank candidates using local LLM
        guard let bestMatch = await LocalLLMReranker.shared.rerank(
            ingredientName: ingredientName,
            candidates: candidates
        ) else {
            print("  ❌ LLM found no suitable match")
            return nil
        }

        print("  ✅ Final match: '\(bestMatch.description)'")

        return bestMatch
    }

    // MARK: - Name Cleaning

    /// Clean ingredient name for better matching
    /// Removes cooking methods, adjectives, and normalizes text
    private func cleanIngredientName(_ name: String) -> String {
        var cleaned = name.lowercased()

        // Remove cooking methods
        let cookingMethods = [
            "grilled", "baked", "fried", "steamed", "roasted", "boiled",
            "sauteed", "sautéed", "pan-fried", "deep-fried", "stir-fried",
            "broiled", "braised", "poached", "smoked"
        ]

        for method in cookingMethods {
            cleaned = cleaned.replacingOccurrences(of: method, with: "", options: .caseInsensitive)
        }

        // Remove common adjectives
        let adjectives = [
            "fresh", "frozen", "raw", "cooked", "organic", "free-range",
            "grass-fed", "wild-caught", "farm-raised", "extra", "premium",
            "chopped", "diced", "sliced", "minced", "shredded", "grated",
            "whole", "half", "quarter"
        ]

        for adj in adjectives {
            cleaned = cleaned.replacingOccurrences(of: adj, with: "", options: .caseInsensitive)
        }

        // Remove common separators and extra spaces
        cleaned = cleaned
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: "  ", with: " ")  // Run twice for triple spaces
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}
