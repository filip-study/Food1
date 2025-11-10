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
    // MARK: - Minerals (mg or mcg)

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

    /// Phosphorus RDA: 700mg (adults)
    static let phosphorus: Double = 700.0

    /// Copper RDA: 0.9mg (adults)
    static let copper: Double = 0.9

    /// Manganese RDA: 2.3mg (adult males), 1.8mg (adult females) - using average
    static let manganese: Double = 2.0

    /// Selenium RDA: 55mcg (adults)
    static let selenium: Double = 55.0

    /// Chromium RDA: 35mcg (adult males), 25mcg (adult females) - using average
    static let chromium: Double = 30.0

    /// Molybdenum RDA: 45mcg (adults)
    static let molybdenum: Double = 45.0

    /// Iodine RDA: 150mcg (adults)
    static let iodine: Double = 150.0

    /// Chloride Daily Value: 2300mg (adults)
    static let chloride: Double = 2300.0

    // MARK: - Vitamins (mcg or mg)

    /// Vitamin A RDA: 900mcg RAE (adult males), 700mcg (adult females) - using average
    static let vitaminA: Double = 900.0  // mcg

    /// Vitamin B1 (Thiamin) RDA: 1.2mg (adult males), 1.1mg (adult females) - using average
    static let vitaminB1: Double = 1.2  // mg

    /// Vitamin B2 (Riboflavin) RDA: 1.3mg (adult males), 1.1mg (adult females) - using average
    static let vitaminB2: Double = 1.3  // mg

    /// Vitamin B3 (Niacin) RDA: 16mg (adult males), 14mg (adult females) - using average
    static let vitaminB3: Double = 16.0  // mg

    /// Vitamin B5 (Pantothenic Acid) RDA: 5mg (adults)
    static let vitaminB5: Double = 5.0  // mg

    /// Vitamin B6 RDA: 1.3mg (adults 19-50 years)
    static let vitaminB6: Double = 1.3  // mg

    /// Vitamin B7 (Biotin) RDA: 30mcg (adults)
    static let vitaminB7: Double = 30.0  // mcg

    /// Vitamin B9 (Folate) RDA: 400mcg DFE (adults)
    static let folate: Double = 400.0  // mcg

    /// Vitamin B12 RDA: 2.4mcg (adults)
    static let vitaminB12: Double = 2.4  // mcg

    /// Vitamin C RDA: 90mg (adult males), 75mg (adult females) - using average
    static let vitaminC: Double = 90.0  // mg

    /// Vitamin D RDA: 20mcg (adults 19-70 years)
    static let vitaminD: Double = 20.0  // mcg

    /// Vitamin E RDA: 15mg (adults)
    static let vitaminE: Double = 15.0  // mg

    /// Vitamin K RDA: 120mcg (adult males), 90mcg (adult females) - using average
    static let vitaminK: Double = 120.0  // mcg

    /// Choline RDA: 550mg (adult males), 425mg (adult females) - using average
    static let choline: Double = 550.0  // mg

    // MARK: - Fiber (g)

    /// Total Fiber Daily Value: 28g (adults)
    static let totalFiber: Double = 28.0  // g

    /// Soluble Fiber Daily Value: 10g (general recommendation)
    static let solubleFiber: Double = 10.0  // g

    /// Insoluble Fiber Daily Value: 18g (general recommendation)
    static let insolubleFiber: Double = 18.0  // g

    // MARK: - Future: User Profile-Based RDA

    /// Get RDA value for specific nutrient (future: personalized based on age/gender)
    /// Note: Gender enum is defined in UserProfile.swift
    static func getRDA(for nutrient: String, gender: Gender? = nil, age: Int? = nil) -> Double {
        let lower = nutrient.lowercased()

        // Minerals
        if lower.contains("calcium") { return calcium }
        if lower.contains("iron") { return iron }
        if lower.contains("magnesium") { return magnesium }
        if lower.contains("potassium") { return potassium }
        if lower.contains("zinc") { return zinc }
        if lower.contains("sodium") { return sodium }
        if lower.contains("phosphorus") { return phosphorus }
        if lower.contains("copper") { return copper }
        if lower.contains("manganese") { return manganese }
        if lower.contains("selenium") { return selenium }
        if lower.contains("chromium") { return chromium }
        if lower.contains("molybdenum") { return molybdenum }
        if lower.contains("iodine") { return iodine }
        if lower.contains("chloride") { return chloride }

        // Vitamins
        if lower.contains("vitamin a") || lower == "vitamina" { return vitaminA }
        if lower.contains("vitamin b1") || lower.contains("thiamin") { return vitaminB1 }
        if lower.contains("vitamin b2") || lower.contains("riboflavin") { return vitaminB2 }
        if lower.contains("vitamin b3") || lower.contains("niacin") { return vitaminB3 }
        if lower.contains("vitamin b5") || lower.contains("pantothenic") { return vitaminB5 }
        if lower.contains("vitamin b6") { return vitaminB6 }
        if lower.contains("vitamin b7") || lower.contains("biotin") { return vitaminB7 }
        if lower.contains("vitamin b9") || lower.contains("folate") || lower.contains("folic") { return folate }
        if lower.contains("vitamin b12") || lower == "vitaminb12" { return vitaminB12 }
        if lower.contains("vitamin c") || lower == "vitaminc" { return vitaminC }
        if lower.contains("vitamin d") || lower == "vitamind" { return vitaminD }
        if lower.contains("vitamin e") || lower == "vitamine" { return vitaminE }
        if lower.contains("vitamin k") || lower == "vitamink" { return vitaminK }
        if lower.contains("choline") { return choline }

        // Fiber
        if lower.contains("total fiber") { return totalFiber }
        if lower.contains("soluble fiber") { return solubleFiber }
        if lower.contains("insoluble fiber") { return insolubleFiber }

        // For general "fiber" queries, return total fiber
        if lower == "fiber" { return totalFiber }

        return 0.0  // Unknown nutrient (fatty acids, water, cholesterol don't have RDAs)
    }
}
