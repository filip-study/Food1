//
//  Micronutrient.swift
//  Food1
//
//  Micronutrient data structure with RDA percentage tracking
//

import Foundation

/// Represents a single micronutrient with amount and RDA percentage
struct Micronutrient: Codable, Identifiable, Hashable {
    var id: String { name }

    let name: String
    let amount: Double
    let unit: String  // "mg", "mcg", "IU"
    let rdaPercent: Double

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
    var calcium: Double = 0.0
    var iron: Double = 0.0
    var magnesium: Double = 0.0
    var potassium: Double = 0.0
    var zinc: Double = 0.0
    var vitaminA: Double = 0.0
    var vitaminC: Double = 0.0
    var vitaminD: Double = 0.0
    var vitaminE: Double = 0.0
    var vitaminB12: Double = 0.0
    var folate: Double = 0.0
    var sodium: Double = 0.0

    /// Convert to array of Micronutrient objects with RDA percentages
    func toMicronutrients() -> [Micronutrient] {
        return [
            Micronutrient(
                name: "Calcium",
                amount: calcium,
                unit: "mg",
                rdaPercent: (calcium / RDAValues.calcium) * 100
            ),
            Micronutrient(
                name: "Iron",
                amount: iron,
                unit: "mg",
                rdaPercent: (iron / RDAValues.iron) * 100
            ),
            Micronutrient(
                name: "Magnesium",
                amount: magnesium,
                unit: "mg",
                rdaPercent: (magnesium / RDAValues.magnesium) * 100
            ),
            Micronutrient(
                name: "Potassium",
                amount: potassium,
                unit: "mg",
                rdaPercent: (potassium / RDAValues.potassium) * 100
            ),
            Micronutrient(
                name: "Zinc",
                amount: zinc,
                unit: "mg",
                rdaPercent: (zinc / RDAValues.zinc) * 100
            ),
            Micronutrient(
                name: "Vitamin A",
                amount: vitaminA,
                unit: "mcg",
                rdaPercent: (vitaminA / RDAValues.vitaminA) * 100
            ),
            Micronutrient(
                name: "Vitamin C",
                amount: vitaminC,
                unit: "mg",
                rdaPercent: (vitaminC / RDAValues.vitaminC) * 100
            ),
            Micronutrient(
                name: "Vitamin D",
                amount: vitaminD,
                unit: "mcg",
                rdaPercent: (vitaminD / RDAValues.vitaminD) * 100
            ),
            Micronutrient(
                name: "Vitamin E",
                amount: vitaminE,
                unit: "mg",
                rdaPercent: (vitaminE / RDAValues.vitaminE) * 100
            ),
            Micronutrient(
                name: "Vitamin B12",
                amount: vitaminB12,
                unit: "mcg",
                rdaPercent: (vitaminB12 / RDAValues.vitaminB12) * 100
            ),
            Micronutrient(
                name: "Folate",
                amount: folate,
                unit: "mcg",
                rdaPercent: (folate / RDAValues.folate) * 100
            ),
            Micronutrient(
                name: "Sodium",
                amount: sodium,
                unit: "mg",
                rdaPercent: (sodium / RDAValues.sodium) * 100
            )
        ]
    }
}
