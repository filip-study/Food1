//
//  FoodIconMapper.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//
//  Maps meal names to pre-generated cartoon icons from FoodIcons.xcassets
//  Uses fuzzy matching with keyword detection for 70-80% coverage
//

import UIKit

/// Service that maps meal names to cartoon food icons from asset catalog
/// NOTE: Currently disabled - kept for potential future use
@MainActor
class FoodIconMapper {

    // MARK: - Properties

    /// Memory cache for loaded icons (improves performance)
    private let cache = NSCache<NSString, UIImage>()

    /// Available icon names in FoodIcons.xcassets
    /// Starting with 50 most common foods for testing
    private let availableIcons: [String] = [
        // Proteins (15)
        "chicken", "grilled-chicken", "fried-chicken", "chicken-breast",
        "beef", "steak", "ground-beef", "burger",
        "salmon", "fish", "shrimp", "tuna",
        "eggs", "scrambled-eggs", "bacon",

        // Vegetables (10)
        "salad", "green-salad", "caesar-salad",
        "broccoli", "carrots", "spinach",
        "tomatoes", "peppers", "potatoes", "sweet-potatoes",

        // Grains & Carbs (10)
        "rice", "brown-rice", "pasta", "spaghetti",
        "bread", "toast", "sandwich",
        "oatmeal", "cereal", "quinoa",

        // Fruits (5)
        "apple", "banana", "berries", "strawberries", "avocado",

        // Popular Meals (7)
        "pizza", "burrito", "taco", "soup",
        "stir-fry", "curry", "wrap",

        // Snacks (3)
        "yogurt", "nuts", "protein-shake"
    ]

    /// Keyword mappings for fuzzy matching
    /// Maps common food keywords to icon names
    private lazy var keywordMap: [String: String] = {
        var map: [String: String] = [:]

        // Direct mappings
        for icon in availableIcons {
            map[icon] = icon
        }

        // Synonyms and variations
        map["chkn"] = "chicken"
        map["chick"] = "chicken"
        map["grill"] = "grilled-chicken"
        map["fried"] = "fried-chicken"

        map["beaf"] = "beef"
        map["meat"] = "beef"
        map["patty"] = "burger"

        map["fish"] = "salmon"
        map["prawn"] = "shrimp"

        map["veggies"] = "salad"
        map["greens"] = "green-salad"
        map["caesar"] = "caesar-salad"

        map["potato"] = "potatoes"
        map["tater"] = "potatoes"

        map["noodle"] = "noodles"
        map["penne"] = "pasta"
        map["macaroni"] = "pasta"
        map["mac"] = "pasta"

        map["toast"] = "bread"
        map["sandwhich"] = "sandwich"  // Common misspelling

        map["oat"] = "oatmeal"
        map["porridge"] = "oatmeal"

        map["strawberry"] = "strawberries"
        map["blueberry"] = "blueberries"
        map["berry"] = "berries"

        map["choco"] = "chocolate"
        map["cookies"] = "cookie"

        map["protein"] = "protein-shake"
        map["whey"] = "protein-shake"

        return map
    }()

    // MARK: - Public Methods

    /// Finds and returns the best matching cartoon icon for a meal name
    /// - Parameter mealName: The name of the meal (e.g., "Grilled Chicken Caesar Salad")
    /// - Returns: UIImage from asset catalog if match found, nil otherwise
    func findIcon(for mealName: String) -> UIImage? {
        // Check cache first
        let cacheKey = mealName as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // Normalize meal name
        let normalized = normalize(mealName)

        // Try direct match first
        if let icon = loadIcon(named: normalized) {
            cache.setObject(icon, forKey: cacheKey)
            return icon
        }

        // Try fuzzy matching with keywords
        if let iconName = fuzzyMatch(normalized) {
            if let icon = loadIcon(named: iconName) {
                cache.setObject(icon, forKey: cacheKey)
                return icon
            }
        }

        // No match found
        return nil
    }

    /// Returns the icon name that would be matched for a meal (for storing in Meal.matchedIconName)
    /// - Parameter mealName: The name of the meal
    /// - Returns: Icon name if match found, nil otherwise
    func findIconName(for mealName: String) -> String? {
        let normalized = normalize(mealName)

        // Try direct match first
        if availableIcons.contains(normalized) {
            return normalized
        }

        // Try fuzzy matching
        return fuzzyMatch(normalized)
    }

    // MARK: - Private Methods

    /// Normalizes meal name for matching (lowercase, trim, remove punctuation)
    private func normalize(_ text: String) -> String {
        return text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "-")
    }

    /// Attempts to fuzzy match meal name to available icons using keywords
    private func fuzzyMatch(_ normalizedName: String) -> String? {
        let words = normalizedName.split(separator: "-").map(String.init)

        // Try to match any word in the meal name to icon keywords
        for word in words {
            // Direct keyword match
            if let iconName = keywordMap[word] {
                if availableIcons.contains(iconName) {
                    return iconName
                }
            }

            // Partial keyword match (word contains keyword)
            for (keyword, iconName) in keywordMap {
                if word.contains(keyword) && availableIcons.contains(iconName) {
                    return iconName
                }
            }
        }

        // Try reverse: check if any icon name is contained in the meal name
        for iconName in availableIcons {
            if normalizedName.contains(iconName) {
                return iconName
            }
        }

        return nil
    }

    /// Loads icon from FoodIcons.xcassets by name
    private func loadIcon(named iconName: String) -> UIImage? {
        // Icon naming convention: "FoodIcons/icon-name"
        // For now, just try loading directly
        // TODO: Update to use "FoodIcons/" prefix once asset catalog is created
        return UIImage(named: iconName)
    }
}
