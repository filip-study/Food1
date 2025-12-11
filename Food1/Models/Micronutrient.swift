//
//  Micronutrient.swift
//  Food1
//
//  Micronutrient data structure with RDA percentage tracking.
//
//  WHY THIS ARCHITECTURE:
//  - RDA color thresholds (Red <20%, Orange 20-50%, Green 50-100%, Blue ≥100%) provide quick visual feedback
//  - Category-based grouping (vitamin/mineral/electrolyte) enables organized UI display
//  - Codable support allows JSON caching in MealIngredient for offline access
//  - rdaPercent calculated per-nutrient enables sorting by deficiency priority
//

import Foundation

/// Category of nutrient for UI grouping
enum NutrientCategory: String, Codable {
    case vitamin
    case mineral
    case electrolyte
    case fiber
    case fattyAcid
    case other

    /// Determine category based on nutrient name
    static func categorize(nutrientName: String) -> NutrientCategory {
        let lower = nutrientName.lowercased()

        // Vitamins
        if lower.contains("vitamin") || lower.contains("folate") ||
           lower.contains("choline") || lower.contains("biotin") {
            return .vitamin
        }

        // Electrolytes (specific minerals with electrolyte function)
        if lower.contains("sodium") || lower.contains("potassium") ||
           lower.contains("chloride") {
            return .electrolyte
        }

        // Minerals
        if lower.contains("calcium") || lower.contains("iron") ||
           lower.contains("magnesium") || lower.contains("zinc") ||
           lower.contains("copper") || lower.contains("manganese") ||
           lower.contains("selenium") || lower.contains("phosphorus") ||
           lower.contains("chromium") || lower.contains("molybdenum") ||
           lower.contains("iodine") {
            return .mineral
        }

        // Fiber
        if lower.contains("fiber") || lower.contains("sugar") {
            return .fiber
        }

        // Fatty Acids
        if lower.contains("fat") || lower.contains("fatty") ||
           lower.contains("omega") || lower.contains("cholesterol") {
            return .fattyAcid
        }

        return .other
    }
}

/// Represents a single micronutrient with amount and RDA percentage
struct Micronutrient: Codable, Identifiable, Hashable {
    var id: String { name }

    let name: String
    let amount: Double
    let unit: String  // "mg", "mcg", "IU", "g"
    let rdaPercent: Double
    let category: NutrientCategory

    /// Formatted amount for display (e.g., "1.5" for small values, "150" for large)
    var formattedAmount: String {
        if amount < 1 {
            return String(format: "%.1f", amount)
        } else {
            return String(format: "%.0f", amount)
        }
    }

    /// Color for RDA percentage display
    var rdaColor: RDAColor {
        switch rdaPercent {
        case 0..<20:
            return .deficient
        case 20..<50:
            return .low
        case 50..<100:
            return .sufficient
        default:
            return .excellent
        }
    }
}

/// RDA color coding for UI
enum RDAColor {
    case deficient   // Red - < 20%
    case low         // Orange - 20-50%
    case sufficient  // Green - 50-100%
    case excellent   // Blue - ≥ 100%
}

/// Micronutrient profile aggregated across all ingredients in a meal
struct MicronutrientProfile: Codable {
    // Original minerals
    var calcium: Double = 0.0
    var iron: Double = 0.0
    var magnesium: Double = 0.0
    var potassium: Double = 0.0
    var zinc: Double = 0.0
    var sodium: Double = 0.0

    // New minerals
    var phosphorus: Double = 0.0
    var copper: Double = 0.0
    var selenium: Double = 0.0

    // Original vitamins
    var vitaminA: Double = 0.0
    var vitaminC: Double = 0.0
    var vitaminD: Double = 0.0
    var vitaminE: Double = 0.0
    var vitaminB12: Double = 0.0
    var folate: Double = 0.0

    // New vitamins
    var vitaminK: Double = 0.0
    var vitaminB1: Double = 0.0
    var vitaminB2: Double = 0.0
    var vitaminB3: Double = 0.0
    var vitaminB5: Double = 0.0
    var vitaminB6: Double = 0.0

    /// Convert to array of Micronutrient objects with RDA percentages
    func toMicronutrients() -> [Micronutrient] {
        return [
            Micronutrient(
                name: "Calcium",
                amount: calcium,
                unit: "mg",
                rdaPercent: (calcium / RDAValues.calcium) * 100,
                category: .mineral
            ),
            Micronutrient(
                name: "Iron",
                amount: iron,
                unit: "mg",
                rdaPercent: (iron / RDAValues.iron) * 100,
                category: .mineral
            ),
            Micronutrient(
                name: "Magnesium",
                amount: magnesium,
                unit: "mg",
                rdaPercent: (magnesium / RDAValues.magnesium) * 100,
                category: .mineral
            ),
            Micronutrient(
                name: "Potassium",
                amount: potassium,
                unit: "mg",
                rdaPercent: (potassium / RDAValues.potassium) * 100,
                category: .electrolyte
            ),
            Micronutrient(
                name: "Zinc",
                amount: zinc,
                unit: "mg",
                rdaPercent: (zinc / RDAValues.zinc) * 100,
                category: .mineral
            ),
            Micronutrient(
                name: "Vitamin A",
                amount: vitaminA,
                unit: "mcg",
                rdaPercent: (vitaminA / RDAValues.vitaminA) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Vitamin C",
                amount: vitaminC,
                unit: "mg",
                rdaPercent: (vitaminC / RDAValues.vitaminC) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Vitamin D",
                amount: vitaminD,
                unit: "mcg",
                rdaPercent: (vitaminD / RDAValues.vitaminD) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Vitamin E",
                amount: vitaminE,
                unit: "mg",
                rdaPercent: (vitaminE / RDAValues.vitaminE) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Vitamin B12",
                amount: vitaminB12,
                unit: "mcg",
                rdaPercent: (vitaminB12 / RDAValues.vitaminB12) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Folate",
                amount: folate,
                unit: "mcg",
                rdaPercent: (folate / RDAValues.folate) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Sodium",
                amount: sodium,
                unit: "mg",
                rdaPercent: (sodium / RDAValues.sodium) * 100,
                category: .electrolyte
            ),
            // New minerals
            Micronutrient(
                name: "Phosphorus",
                amount: phosphorus,
                unit: "mg",
                rdaPercent: (phosphorus / RDAValues.phosphorus) * 100,
                category: .mineral
            ),
            Micronutrient(
                name: "Copper",
                amount: copper,
                unit: "mg",
                rdaPercent: (copper / RDAValues.copper) * 100,
                category: .mineral
            ),
            Micronutrient(
                name: "Selenium",
                amount: selenium,
                unit: "mcg",
                rdaPercent: (selenium / RDAValues.selenium) * 100,
                category: .mineral
            ),
            // New vitamins
            Micronutrient(
                name: "Vitamin K",
                amount: vitaminK,
                unit: "mcg",
                rdaPercent: (vitaminK / RDAValues.vitaminK) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Thiamin",
                amount: vitaminB1,
                unit: "mg",
                rdaPercent: (vitaminB1 / RDAValues.vitaminB1) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Riboflavin",
                amount: vitaminB2,
                unit: "mg",
                rdaPercent: (vitaminB2 / RDAValues.vitaminB2) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Niacin",
                amount: vitaminB3,
                unit: "mg",
                rdaPercent: (vitaminB3 / RDAValues.vitaminB3) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Pantothenic acid",
                amount: vitaminB5,
                unit: "mg",
                rdaPercent: (vitaminB5 / RDAValues.vitaminB5) * 100,
                category: .vitamin
            ),
            Micronutrient(
                name: "Vitamin B-6",
                amount: vitaminB6,
                unit: "mg",
                rdaPercent: (vitaminB6 / RDAValues.vitaminB6) * 100,
                category: .vitamin
            )
        ]
    }
}
