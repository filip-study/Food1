//
//  RDAValues.swift
//  Food1
//
//  FDA Recommended Daily Allowances (RDA) / Daily Values
//  Reference: https://www.fda.gov/food/nutrition-facts-label/daily-value-nutrition-and-supplement-facts-labels
//

import Foundation

/// FDA Recommended Daily Allowances for adults (hardcoded for performance)
/// Values based on FDA Daily Values (2020 guidelines)
enum RDAValues {
    // MARK: - Minerals (mg)

    /// Calcium RDA: 1300mg (adults 19+ years)
    static let calcium: Double = 1300.0

    /// Iron RDA: 18mg (adult females), 8mg (adult males) - using higher value for safety
    static let iron: Double = 18.0

    /// Magnesium RDA: 420mg (adult males), 320mg (adult females) - using average
    static let magnesium: Double = 400.0

    /// Potassium RDA: 4700mg (adults)
    static let potassium: Double = 4700.0

    /// Zinc RDA: 11mg (adult males), 8mg (adult females) - using average
    static let zinc: Double = 11.0

    /// Sodium Daily Value: 2300mg (upper limit, not RDA)
    static let sodium: Double = 2300.0

    // MARK: - Vitamins (mcg or mg)

    /// Vitamin A RDA: 900mcg RAE (adult males), 700mcg (adult females) - using average
    static let vitaminA: Double = 900.0  // mcg

    /// Vitamin C RDA: 90mg (adult males), 75mg (adult females) - using average
    static let vitaminC: Double = 90.0  // mg

    /// Vitamin D RDA: 20mcg (adults 19-70 years)
    static let vitaminD: Double = 20.0  // mcg

    /// Vitamin E RDA: 15mg (adults)
    static let vitaminE: Double = 15.0  // mg

    /// Vitamin B12 RDA: 2.4mcg (adults)
    static let vitaminB12: Double = 2.4  // mcg

    /// Folate RDA: 400mcg DFE (adults)
    static let folate: Double = 400.0  // mcg

    // MARK: - Future: User Profile-Based RDA

    /// Get RDA value for specific nutrient (future: personalized based on age/gender)
    /// Note: Gender enum is defined in UserProfile.swift
    static func getRDA(for nutrient: String, gender: Gender? = nil, age: Int? = nil) -> Double {
        switch nutrient.lowercased() {
        case "calcium":
            return calcium
        case "iron":
            // Future: if let gender = gender { return gender == .male ? 8.0 : 18.0 }
            return iron
        case "magnesium":
            return magnesium
        case "potassium":
            return potassium
        case "zinc":
            return zinc
        case "sodium":
            return sodium
        case "vitamin a", "vitamina":
            return vitaminA
        case "vitamin c", "vitaminc":
            return vitaminC
        case "vitamin d", "vitamind":
            return vitaminD
        case "vitamin e", "vitamine":
            return vitaminE
        case "vitamin b12", "vitaminb12":
            return vitaminB12
        case "folate":
            return folate
        default:
            return 0.0  // Unknown nutrient
        }
    }
}
