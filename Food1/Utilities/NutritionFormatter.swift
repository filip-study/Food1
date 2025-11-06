//
//  NutritionFormatter.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//

import Foundation

enum NutritionUnit: String, CaseIterable, Identifiable {
    case metric = "Metric (grams)"
    case imperial = "Imperial (ounces)"

    var id: String { self.rawValue }

    var shortLabel: String {
        switch self {
        case .metric: return "g"
        case .imperial: return "oz"
        }
    }
}

struct NutritionFormatter {
    static let gramsToOunces: Double = 0.035274
    static let ouncesToGrams: Double = 28.3495

    /// Convert grams to the target unit
    static func convert(grams: Double, to unit: NutritionUnit) -> Double {
        switch unit {
        case .metric:
            return grams
        case .imperial:
            return grams * gramsToOunces
        }
    }

    /// Convert from the specified unit to grams (for storage)
    static func toGrams(value: Double, from unit: NutritionUnit) -> Double {
        switch unit {
        case .metric:
            return value
        case .imperial:
            return value * ouncesToGrams
        }
    }

    /// Format a nutrition value with the appropriate unit label
    static func format(_ grams: Double, unit: NutritionUnit, decimals: Int = 1) -> String {
        let value = convert(grams: grams, to: unit)

        switch unit {
        case .metric:
            // Show whole numbers for metric
            return "\(Int(value.rounded()))g"
        case .imperial:
            // Show decimal for imperial
            return String(format: "%.\(decimals)foz", value)
        }
    }

    /// Format a nutrition value without unit label (just the number)
    static func formatValue(_ grams: Double, unit: NutritionUnit, decimals: Int = 1) -> String {
        let value = convert(grams: grams, to: unit)

        switch unit {
        case .metric:
            return "\(Int(value.rounded()))"
        case .imperial:
            return String(format: "%.\(decimals)f", value)
        }
    }

    /// Get the unit label for display
    static func unitLabel(_ unit: NutritionUnit) -> String {
        unit.shortLabel
    }

    /// Format current/goal display (e.g., "150g / 200g" or "5.3oz / 7.1oz")
    static func formatProgress(current: Double, goal: Double, unit: NutritionUnit) -> String {
        let currentValue = convert(grams: current, to: unit)
        let goalValue = convert(grams: goal, to: unit)
        let label = unit.shortLabel

        switch unit {
        case .metric:
            return "\(Int(currentValue.rounded()))\(label) / \(Int(goalValue.rounded()))\(label)"
        case .imperial:
            return String(format: "%.1f%@ / %.1f%@", currentValue, label, goalValue, label)
        }
    }
}
