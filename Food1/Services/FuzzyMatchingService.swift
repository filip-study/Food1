//
//  FuzzyMatchingService.swift
//  Food1
//
//  Fuzzy matching service for ingredient names to USDA foods
//  Handles GPT-4o ingredient names like "Chicken breast, grilled" → USDA foods
//

import Foundation

// MARK: - Match Method Tracking
enum MatchMethod: String, Codable {
    case shortcut = "Shortcut"      // Direct fdcId lookup from commonFoodShortcuts
    case exactMatch = "Exact"       // 1:1 string match with USDA description
    case llmRerank = "LLM"          // LocalLLMReranker selected best candidate
    case blacklisted = "Blacklisted" // Skipped - ingredient has negligible micronutrients
}

// MARK: - Architecture Overview
//
// This service bridges GPT-4o's natural ingredient names to our local USDA database.
// The core challenge is SEMANTIC matching, not text search - GPT-4o says "Chicken breast"
// but USDA has "Chicken, broilers or fryers, breast, meat only, cooked, roasted".
//
// MATCHING PIPELINE:
// 1. Clean ingredient name (remove cooking methods, adjectives)
// 2. Check shortcuts dictionary (instant match for common foods)
// 3. Search USDA database with LIKE queries
// 4. Send candidates to LocalLLMReranker for semantic selection
//
// WHY THIS ARCHITECTURE:
//
// Why Shortcuts?
// - Zero latency for ~40% of ingredients (based on evaluation of 50 real images)
// - Guaranteed correct matches (manually verified fdcIds)
// - Skip LLM inference entirely for common foods
// - Example: "egg" → fdcId 171287 (Egg, whole, raw, fresh)
//
// Why LLM Reranking (not FTS5)?
// - FTS5 is great for text search but our problem is vocabulary mismatch
// - GPT-4o: "Spinach" vs USDA: "Spinach, raw" / "Spinach, cooked, boiled"
// - FTS5 can find both but can't understand "raw" is better default than "boiled"
// - LocalLLMReranker (Llama-3.2-1B) understands semantic similarity
// - Note: FTS5 is configured in our DB but doesn't solve the core problem
//
// Why NOT Category Pre-filtering?
// - Risk of false negatives outweighs benefits
// - Example: "Oats" could be in "Cereals" or "Grains" depending on USDA categorization
// - Wrong category = ingredient not found = zero micronutrients
// - Better to search all and let LLM filter than accidentally exclude correct match
//
// Why 50 Candidates to LLM?
// - Too few (10-20): might miss correct match buried in results
// - Too many (100+): slower LLM inference, diminishing returns
// - 50 balances coverage vs performance
//
// ADDING NEW SHORTCUTS:
// 1. Run evaluation pipeline on new food images (evaluation/run_evaluation.py)
// 2. Analyze cleaned ingredient names (evaluation/analyze_cleaned.py)
// 3. Find USDA matches (evaluation/find_usda_matches.py)
// 4. Verify fdcId manually: SELECT * FROM usda_foods WHERE fdc_id = X
// 5. Add to commonFoodShortcuts dictionary below
// 6. Key = cleaned name (lowercase, no cooking methods/adjectives)
// 7. Value = USDA fdcId (verified to return correct micronutrients)
//

/// Service for fuzzy matching ingredient names to local USDA database
class FuzzyMatchingService {
    static let shared = FuzzyMatchingService()

    // MARK: - Common Food Shortcuts
    // Verified USDA fdcIds for common ingredients - skip LLM for these
    // Add any food that's common in real-world usage, not just evaluation frequency
    private let commonFoodShortcuts: [String: Int] = [
        // Eggs
        "egg": 171287,              // Egg, whole, raw, fresh
        "eggs": 171287,             // Egg, whole, raw, fresh
        "egg scrambled": 172187,    // Egg, whole, cooked, scrambled

        // Proteins
        "chicken breast": 171477,   // Chicken, broilers or fryers, breast, meat only, cooked, roasted
        "chicken breast fried": 171078, // Chicken, broilers or fryers, breast, meat only, cooked, fried
        "chicken breast battered": 171515, // Chicken breast tenders, breaded, uncooked
        "chicken breast breaded": 171515, // Chicken breast tenders, breaded, uncooked
        "salmon": 171998,           // Fish, salmon, Atlantic, wild, cooked
        "tuna": 171986,             // Fish, tuna, light, canned in water, drained
        "shrimp": 175180,           // Crustaceans, shrimp, cooked
        "bacon": 167914,            // Pork, cured, bacon, cooked, baked
        "pork bacon": 167914,       // Pork, cured, bacon, cooked, baked
        "ground beef": 174036,      // Beef, ground, 80% lean meat / 20% fat, raw
        "beef ground": 174036,      // Beef, ground, 80% lean meat / 20% fat, raw
        "beef steak": 171804,       // Beef, top sirloin, steak

        // Dairy
        "milk": 171265,             // Milk, whole, 3.25% milkfat
        "yogurt plain": 171284,     // Yogurt, plain, whole milk
        "butter": 173410,           // Butter, salted
        "butter salted": 173410,    // Butter, salted
        "butter unsalted": 173430,  // Butter, without salt
        "cheddar cheese": 173414,   // Cheese, cheddar
        "cheese cheddar": 173414,   // Cheese, cheddar
        "mozzarella cheese": 170845, // Cheese, mozzarella, whole milk
        "cheese mozzarella": 170845, // Cheese, mozzarella, whole milk
        "feta cheese": 173420,      // Cheese, feta
        "cheese feta": 173420,      // Cheese, feta
        "parmesan cheese": 170848,  // Cheese, parmesan, hard
        "cheese parmesan": 170848,  // Cheese, parmesan, hard
        "cream heavy": 170859,      // Cream, fluid, heavy whipping
        "cream heavy whipping": 170859, // Cream, fluid, heavy whipping
        "whipped cream": 170860,    // Cream, whipped, cream topping
        "almond milk": 174832,      // Beverages, almond milk, unsweetened

        // Fruits
        "banana": 173944,           // Bananas, raw
        "strawberries": 167762,     // Strawberries, raw
        "blueberries": 171711,      // Blueberries, raw
        "raspberries": 167755,      // Raspberries, raw
        "blackberries": 173946,     // Blackberries, raw
        "grapes": 174683,           // Grapes, red or green, raw
        "orange": 169918,           // Oranges, raw
        "watermelon": 167765,       // Watermelon, raw
        "pineapple": 169124,        // Pineapple, raw
        "pineapple chunks canned": 169126, // Pineapple, canned, juice pack, solids and liquids
        "pineapple canned": 169126, // Pineapple, canned, juice pack, solids and liquids
        "avocado": 171705,          // Avocados, raw, all commercial varieties

        // Vegetables
        "spinach": 168462,          // Spinach, raw
        "broccoli": 170379,         // Broccoli, raw
        "tomato": 170457,           // Tomatoes, red, ripe, raw
        "tomatoes": 170457,         // Tomatoes, red, ripe, raw
        "cucumber": 168409,         // Cucumber, with peel, raw
        "lettuce": 169249,          // Lettuce, green leaf, raw
        "lettuce romaine": 169247,  // Lettuce, cos or romaine, raw
        "carrots": 170393,          // Carrots, raw
        "mushrooms": 169251,        // Mushrooms, white, raw
        "onion": 170000,            // Onions, raw
        "onions": 170000,           // Onions, raw
        "green onions": 170005,     // Onions, spring or scallions
        "scallions": 170005,        // Onions, spring or scallions
        "garlic": 169230,           // Garlic, raw
        "asparagus": 168389,        // Asparagus, raw
        "potatoes": 170026,         // Potatoes, flesh and skin, raw
        "basil": 172232,            // Basil, fresh
        "cilantro": 169997,         // Coriander (cilantro) leaves, raw
        "parsley": 170416,          // Parsley, fresh
        "mint leaves": 173475,      // Spearmint, fresh
        "mint": 173475,             // Spearmint, fresh
        "bell peppers": 170108,     // Peppers, sweet, red, raw
        "bell pepper": 170108,      // Peppers, sweet, red, raw
        "red bell pepper": 170108,  // Peppers, sweet, red, raw
        "green bell pepper": 170427, // Peppers, sweet, green, raw

        // Grains & Carbs
        "rice white": 168878,       // Rice, white, long-grain, enriched, cooked
        "oats": 171662,             // Cereals, oats, instant, fortified, plain
        "bread wheat": 172688,      // Bread, whole-wheat, commercially prepared
        "bread white": 167532,      // Bread, white wheat
        "spaghetti": 169737,        // Pasta, cooked, enriched
        "pasta penne": 169736,      // Pasta, dry, enriched
        "tortilla flour": 167535,   // Tortillas, ready-to-bake or -fry, flour
        "tortilla corn": 175036,    // Tortillas, ready-to-bake or -fry, corn
        "tortillas corn": 175036,   // Tortillas, ready-to-bake or -fry, corn
        "pancake plain": 175047,    // Pancakes, buttermilk
        "french fries": 168946,     // Potatoes, french fried
        "burger bun": 172796,       // Rolls, hamburger or hotdog, plain
        "english muffin plain": 174093, // English muffins, whole grain white
        "croutons": 172751,         // Croutons, plain

        // Nuts & Seeds
        "almonds": 170567,          // Nuts, almonds
        "cashews": 170162,          // Nuts, cashew nuts, raw
        "walnuts": 170187,          // Nuts, walnuts, english
        "pistachios": 170184,       // Nuts, pistachio nuts, raw
        "peanut butter": 172470,    // Peanut butter, smooth style
        "pumpkin seeds": 170556,    // Seeds, pumpkin and squash seed kernels

        // Condiments & Oils
        "olive oil": 171413,        // Oil, olive, salad or cooking
        "vegetable oil": 172370,    // Oil, vegetable, soybean, refined
        "tomato sauce": 170054,     // Tomato products, canned, sauce
        "ketchup": 168556,          // Catsup
        "maple syrup": 169661,      // Syrups, maple
        "hummus": 174289,           // Hummus, commercial

        // Other
        "chocolate chips": 167976,  // Candies, semisweet chocolate
        "cocoa powder": 169593,     // Cocoa, dry powder, unsweetened
        "raisins seedless": 168164, // Raisins, golden, seedless
        "raisins": 168164,          // Raisins, golden, seedless
        "cranberries dried": 171723, // Cranberries, dried, sweetened
        "dried fruits mixed": 168164, // Raisins (best generic for mixed dried fruit)
        "mixed dried fruits": 168164, // Raisins (best generic for mixed dried fruit)
        "dried fruit mix": 168164,  // Raisins (best generic for mixed dried fruit)
    ]

    // MARK: - Blacklist (Skip Matching)
    // Ingredients with negligible micronutrients - don't waste LLM inference on these
    // These are mostly pure sugar/fat with no meaningful vitamins/minerals
    private let blacklistedIngredients: Set<String> = [
        // Sugars & syrups (negligible micronutrients)
        "sugar",
        "sugar powdered",
        "powdered sugar",
        "sugars powdered",
        "brown sugar",
        "syrup",
        "syrup caramel",
        "caramel syrup",
        "corn syrup",
        "simple syrup",

        // Pure fats with no micronutrients
        "shortening",
        "lard",

        // Artificial/processed items
        "food coloring",
        "artificial sweetener",

        // Garnishes with no nutritional value
        "foam garnish",
        "garnish",
        "decoration",

        // Water/ice
        "ice",
        "shaved ice",
        "ice cubes",
    ]

    private init() {}

    // MARK: - Public API

    /// Match ingredient name to best USDA food using local LLM re-ranking
    /// - Parameter ingredientName: Ingredient name from GPT-4o (e.g., "Chicken breast, grilled")
    /// - Returns: Matched USDA food or nil if no good match found
    func match(_ ingredientName: String) async -> USDAFood? {
        let (food, _) = await matchWithMethod(ingredientName)
        return food
    }

    /// Match ingredient name and return both food and match method (for debugging)
    /// - Parameter ingredientName: Ingredient name from GPT-4o
    /// - Returns: Tuple of (USDAFood?, MatchMethod?)
    func matchWithMethod(_ ingredientName: String) async -> (USDAFood?, MatchMethod?) {
        // Clean and tokenize ingredient name
        let cleanedName = cleanIngredientName(ingredientName)
        guard !cleanedName.isEmpty else { return (nil, nil) }

        print("  🔍 Cleaned query: '\(ingredientName)' → '\(cleanedName)'")

        // Check blacklist first - skip ingredients with negligible micronutrients
        if blacklistedIngredients.contains(cleanedName) {
            print("  ⏭️  Blacklisted (no micronutrients): '\(cleanedName)'")
            return (nil, .blacklisted)
        }

        // Try shortcut first - verified common ingredients
        if let fdcId = commonFoodShortcuts[cleanedName] {
            if let food = LocalUSDAService.shared.getFood(byId: fdcId) {
                print("  ⚡ Shortcut match: '\(food.description)'")
                return (food, .shortcut)
            }
        }

        // Search local database for candidates
        // First try with original name to preserve ", raw" etc for exact matches
        let normalizedIngredient = ingredientName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates = LocalUSDAService.shared.search(query: normalizedIngredient, limit: 50)

        // If no results with original, try cleaned name
        if candidates.isEmpty {
            candidates = LocalUSDAService.shared.search(query: cleanedName, limit: 50)
        }

        guard !candidates.isEmpty else {
            print("  ⚠️  No database matches found")
            return (nil, nil)
        }

        // Check for exact match (1:1 string match) before invoking LLM
        // Example: GPT-4o says "Raspberries, raw" and USDA has exact "Raspberries, raw"

        for candidate in candidates {
            let normalizedDescription = candidate.description.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedCommonName = (candidate.commonName ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if normalizedDescription == normalizedIngredient || normalizedCommonName == normalizedIngredient {
                print("  ⚡ Exact match found: '\(candidate.description)' (skipped LLM)")
                return (candidate, .exactMatch)
            }
        }

        print("  📋 Found \(candidates.count) candidates, sending to LLM for re-ranking...")

        // Re-rank candidates using local LLM
        #if DEBUG
        print("  🤖 LLM invocation #1 for '\(ingredientName)'")
        #endif

        if let bestMatch = await LocalLLMReranker.shared.rerank(
            ingredientName: ingredientName,
            candidates: candidates
        ) {
            print("  ✅ Final match: '\(bestMatch.description)'")
            return (bestMatch, .llmRerank)
        }

        // LLM failed - try fallback with broader OR search if we used AND query
        // This catches cases where AND was too restrictive
        let fallbackCandidates = LocalUSDAService.shared.search(query: cleanedName, limit: 50)

        if !fallbackCandidates.isEmpty && fallbackCandidates.count != candidates.count {
            #if DEBUG
            print("  🔄 LLM retry with \(fallbackCandidates.count) fallback candidates")
            print("  🤖 LLM invocation #2 for '\(ingredientName)'")
            #endif

            if let bestMatch = await LocalLLMReranker.shared.rerank(
                ingredientName: ingredientName,
                candidates: fallbackCandidates
            ) {
                print("  ✅ Final match (retry): '\(bestMatch.description)'")
                return (bestMatch, .llmRerank)
            }
        }

        print("  ❌ LLM found no suitable match after \(fallbackCandidates.isEmpty ? "1" : "2") attempts")
        return (nil, nil)
    }

    // MARK: - Name Cleaning
    //
    // CRITICAL: Use word boundary regex (\b) for all replacements!
    // Bug found in evaluation: "Strawberries, raw" → "Stberries, " when using
    // simple string replacement because "raw" appears inside "stRAWberries".
    // Word boundaries ensure we only match complete words.
    //

    /// Clean ingredient name for better matching
    /// Removes cooking methods, adjectives, and normalizes text
    private func cleanIngredientName(_ name: String) -> String {
        var cleaned = name.lowercased()

        // Remove cooking methods (using word boundaries to avoid "stRAWberries" → "stberries")
        let cookingMethods = [
            "grilled", "baked", "fried", "steamed", "roasted", "boiled",
            "sauteed", "sautéed", "pan-fried", "deep-fried", "stir-fried",
            "broiled", "braised", "poached", "smoked"
        ]

        for method in cookingMethods {
            let pattern = "\\b\(method)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
        }

        // Remove common adjectives (using word boundaries)
        let adjectives = [
            "fresh", "frozen", "raw", "cooked", "organic", "free-range",
            "grass-fed", "wild-caught", "farm-raised", "extra", "premium",
            "chopped", "diced", "sliced", "minced", "shredded", "grated",
            "whole", "half", "quarter"
        ]

        for adj in adjectives {
            let pattern = "\\b\(adj)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
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
