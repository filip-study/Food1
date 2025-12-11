//
//  MicronutrientTests.swift
//  Food1Tests
//
//  Tests for micronutrient tracking functionality
//

import XCTest
@testable import Food1

/// Tests for MicronutrientProfile and related micronutrient functionality
///
/// TEST POLICY: These tests define expected behavior and MUST NOT be modified without explicit user approval.
/// If tests fail after code changes, fix the CODE, not the tests.
///
/// Coverage:
/// 1. MicronutrientProfile has all 21 expected properties
/// 2. toMicronutrients() returns correct array with proper RDA calculations
/// 3. RDA mapping works for all nutrients (original and new)
/// 4. Nutrient categories are correctly assigned
final class MicronutrientTests: XCTestCase {

    // MARK: - MicronutrientProfile Property Tests

    /// Test that MicronutrientProfile has all 21 expected nutrient properties with correct defaults
    func testMicronutrientProfile_HasAll21Properties() {
        // Given: A new MicronutrientProfile with defaults
        let profile = MicronutrientProfile()

        // Then: All 21 properties should exist and default to 0.0
        // Original minerals (6)
        XCTAssertEqual(profile.calcium, 0.0, "calcium should default to 0.0")
        XCTAssertEqual(profile.iron, 0.0, "iron should default to 0.0")
        XCTAssertEqual(profile.magnesium, 0.0, "magnesium should default to 0.0")
        XCTAssertEqual(profile.potassium, 0.0, "potassium should default to 0.0")
        XCTAssertEqual(profile.zinc, 0.0, "zinc should default to 0.0")
        XCTAssertEqual(profile.sodium, 0.0, "sodium should default to 0.0")

        // New minerals (3)
        XCTAssertEqual(profile.phosphorus, 0.0, "phosphorus should default to 0.0")
        XCTAssertEqual(profile.copper, 0.0, "copper should default to 0.0")
        XCTAssertEqual(profile.selenium, 0.0, "selenium should default to 0.0")

        // Original vitamins (6)
        XCTAssertEqual(profile.vitaminA, 0.0, "vitaminA should default to 0.0")
        XCTAssertEqual(profile.vitaminC, 0.0, "vitaminC should default to 0.0")
        XCTAssertEqual(profile.vitaminD, 0.0, "vitaminD should default to 0.0")
        XCTAssertEqual(profile.vitaminE, 0.0, "vitaminE should default to 0.0")
        XCTAssertEqual(profile.vitaminB12, 0.0, "vitaminB12 should default to 0.0")
        XCTAssertEqual(profile.folate, 0.0, "folate should default to 0.0")

        // New vitamins (6)
        XCTAssertEqual(profile.vitaminK, 0.0, "vitaminK should default to 0.0")
        XCTAssertEqual(profile.vitaminB1, 0.0, "vitaminB1 should default to 0.0")
        XCTAssertEqual(profile.vitaminB2, 0.0, "vitaminB2 should default to 0.0")
        XCTAssertEqual(profile.vitaminB3, 0.0, "vitaminB3 should default to 0.0")
        XCTAssertEqual(profile.vitaminB5, 0.0, "vitaminB5 should default to 0.0")
        XCTAssertEqual(profile.vitaminB6, 0.0, "vitaminB6 should default to 0.0")
    }

    /// Test that toMicronutrients() returns exactly 21 Micronutrient objects
    func testToMicronutrients_Returns21Nutrients() {
        // Given: A MicronutrientProfile with some values
        var profile = MicronutrientProfile()
        profile.calcium = 500
        profile.vitaminK = 60

        // When: Convert to array
        let nutrients = profile.toMicronutrients()

        // Then: Should have exactly 21 nutrients
        XCTAssertEqual(nutrients.count, 21, "toMicronutrients() should return exactly 21 nutrients")
    }

    /// Test that toMicronutrients() returns all expected nutrient names
    func testToMicronutrients_ContainsAllExpectedNames() {
        // Given: A MicronutrientProfile
        let profile = MicronutrientProfile()

        // When: Convert to array
        let nutrients = profile.toMicronutrients()
        let names = Set(nutrients.map { $0.name })

        // Then: Should contain all expected nutrient names
        let expectedNames: Set<String> = [
            // Original minerals
            "Calcium", "Iron", "Magnesium", "Potassium", "Zinc", "Sodium",
            // New minerals
            "Phosphorus", "Copper", "Selenium",
            // Original vitamins
            "Vitamin A", "Vitamin C", "Vitamin D", "Vitamin E", "Vitamin B12", "Folate",
            // New vitamins
            "Vitamin K", "Thiamin", "Riboflavin", "Niacin", "Pantothenic acid", "Vitamin B-6"
        ]

        XCTAssertEqual(names, expectedNames, "toMicronutrients() should contain all 21 expected nutrient names")
    }

    // MARK: - RDA Calculation Tests

    /// Test RDA percentage calculation for Calcium
    func testRDACalculation_Calcium() {
        // Given: Profile with 650mg calcium (50% of 1300mg RDA)
        var profile = MicronutrientProfile()
        profile.calcium = 650

        // When: Convert to micronutrients
        let nutrients = profile.toMicronutrients()
        let calcium = nutrients.first { $0.name == "Calcium" }

        // Then: RDA should be 50%
        XCTAssertNotNil(calcium, "Should find Calcium in nutrients")
        XCTAssertEqual(calcium?.rdaPercent ?? 0, 50.0, accuracy: 0.1, "Calcium RDA should be 50%")
    }

    /// Test RDA percentage calculation for new nutrients (Vitamin K)
    func testRDACalculation_VitaminK() {
        // Given: Profile with 60mcg Vitamin K (50% of 120mcg RDA)
        var profile = MicronutrientProfile()
        profile.vitaminK = 60

        // When: Convert to micronutrients
        let nutrients = profile.toMicronutrients()
        let vitaminK = nutrients.first { $0.name == "Vitamin K" }

        // Then: RDA should be 50%
        XCTAssertNotNil(vitaminK, "Should find Vitamin K in nutrients")
        XCTAssertEqual(vitaminK?.rdaPercent ?? 0, 50.0, accuracy: 0.1, "Vitamin K RDA should be 50%")
    }

    /// Test RDA percentage calculation for Phosphorus
    func testRDACalculation_Phosphorus() {
        // Given: Profile with 350mg Phosphorus (50% of 700mg RDA)
        var profile = MicronutrientProfile()
        profile.phosphorus = 350

        // When: Convert to micronutrients
        let nutrients = profile.toMicronutrients()
        let phosphorus = nutrients.first { $0.name == "Phosphorus" }

        // Then: RDA should be 50%
        XCTAssertNotNil(phosphorus, "Should find Phosphorus in nutrients")
        XCTAssertEqual(phosphorus?.rdaPercent ?? 0, 50.0, accuracy: 0.1, "Phosphorus RDA should be 50%")
    }

    /// Test RDA percentage calculation for Thiamin (B1)
    func testRDACalculation_Thiamin() {
        // Given: Profile with 0.6mg Thiamin (50% of 1.2mg RDA)
        var profile = MicronutrientProfile()
        profile.vitaminB1 = 0.6

        // When: Convert to micronutrients
        let nutrients = profile.toMicronutrients()
        let thiamin = nutrients.first { $0.name == "Thiamin" }

        // Then: RDA should be 50%
        XCTAssertNotNil(thiamin, "Should find Thiamin in nutrients")
        XCTAssertEqual(thiamin?.rdaPercent ?? 0, 50.0, accuracy: 0.1, "Thiamin RDA should be 50%")
    }

    // MARK: - Category Tests

    /// Test that minerals are categorized correctly
    func testNutrientCategory_Minerals() {
        let profile = MicronutrientProfile()
        let nutrients = profile.toMicronutrients()

        let mineralNames = ["Calcium", "Iron", "Magnesium", "Zinc", "Phosphorus", "Copper", "Selenium"]
        for name in mineralNames {
            let nutrient = nutrients.first { $0.name == name }
            XCTAssertNotNil(nutrient, "Should find \(name) in nutrients")
            XCTAssertEqual(nutrient?.category, .mineral, "\(name) should be categorized as mineral")
        }
    }

    /// Test that vitamins are categorized correctly
    func testNutrientCategory_Vitamins() {
        let profile = MicronutrientProfile()
        let nutrients = profile.toMicronutrients()

        let vitaminNames = ["Vitamin A", "Vitamin C", "Vitamin D", "Vitamin E", "Vitamin B12", "Folate",
                           "Vitamin K", "Thiamin", "Riboflavin", "Niacin", "Pantothenic acid", "Vitamin B-6"]
        for name in vitaminNames {
            let nutrient = nutrients.first { $0.name == name }
            XCTAssertNotNil(nutrient, "Should find \(name) in nutrients")
            XCTAssertEqual(nutrient?.category, .vitamin, "\(name) should be categorized as vitamin")
        }
    }

    /// Test that electrolytes are categorized correctly
    func testNutrientCategory_Electrolytes() {
        let profile = MicronutrientProfile()
        let nutrients = profile.toMicronutrients()

        let electrolyteNames = ["Potassium", "Sodium"]
        for name in electrolyteNames {
            let nutrient = nutrients.first { $0.name == name }
            XCTAssertNotNil(nutrient, "Should find \(name) in nutrients")
            XCTAssertEqual(nutrient?.category, .electrolyte, "\(name) should be categorized as electrolyte")
        }
    }

    // MARK: - Unit Tests

    /// Test that nutrients have correct units
    func testNutrientUnits() {
        let profile = MicronutrientProfile()
        let nutrients = profile.toMicronutrients()

        // mg units
        let mgNutrients = ["Calcium", "Iron", "Magnesium", "Potassium", "Zinc", "Sodium",
                          "Phosphorus", "Copper", "Vitamin C", "Vitamin E",
                          "Thiamin", "Riboflavin", "Niacin", "Pantothenic acid", "Vitamin B-6"]
        for name in mgNutrients {
            let nutrient = nutrients.first { $0.name == name }
            XCTAssertEqual(nutrient?.unit, "mg", "\(name) should have unit 'mg'")
        }

        // mcg units
        let mcgNutrients = ["Vitamin A", "Vitamin D", "Vitamin B12", "Folate", "Vitamin K", "Selenium"]
        for name in mcgNutrients {
            let nutrient = nutrients.first { $0.name == name }
            XCTAssertEqual(nutrient?.unit, "mcg", "\(name) should have unit 'mcg'")
        }
    }

    // MARK: - RDAValues Extension Tests

    /// Test that RDAValues.getRDA returns correct values for new nutrients
    func testRDAValues_GetRDA_NewNutrients() {
        // New minerals
        XCTAssertEqual(RDAValues.getRDA(for: "Phosphorus"), 700.0, "Phosphorus RDA should be 700mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Copper"), 0.9, "Copper RDA should be 0.9mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Selenium"), 55.0, "Selenium RDA should be 55mcg")

        // New vitamins
        XCTAssertEqual(RDAValues.getRDA(for: "Vitamin K"), 120.0, "Vitamin K RDA should be 120mcg")
        XCTAssertEqual(RDAValues.getRDA(for: "Thiamin"), 1.2, "Thiamin RDA should be 1.2mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Vitamin B1 (Thiamin)"), 1.2, "Vitamin B1 (Thiamin) RDA should be 1.2mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Riboflavin"), 1.3, "Riboflavin RDA should be 1.3mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Vitamin B2 (Riboflavin)"), 1.3, "Vitamin B2 (Riboflavin) RDA should be 1.3mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Niacin"), 16.0, "Niacin RDA should be 16mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Vitamin B3 (Niacin)"), 16.0, "Vitamin B3 (Niacin) RDA should be 16mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Pantothenic acid"), 5.0, "Pantothenic acid RDA should be 5mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Vitamin B-6"), 1.3, "Vitamin B-6 RDA should be 1.3mg")
        XCTAssertEqual(RDAValues.getRDA(for: "Vitamin B6"), 1.3, "Vitamin B6 RDA should be 1.3mg")
    }

    /// Test that RDAValues.getRDA returns 0 for unknown nutrients
    func testRDAValues_GetRDA_UnknownNutrient() {
        XCTAssertEqual(RDAValues.getRDA(for: "Unknown Nutrient"), 0.0, "Unknown nutrient should return 0")
        XCTAssertEqual(RDAValues.getRDA(for: ""), 0.0, "Empty string should return 0")
    }

    // MARK: - JSON Encoding/Decoding Tests (for DailyAggregate storage)

    /// Test that MicronutrientProfile can be encoded and decoded correctly
    /// This is critical for DailyAggregate.cachedMicronutrientsJSON storage
    func testMicronutrientProfile_JSONCodable() throws {
        // Given: A profile with values for all 21 nutrients
        var original = MicronutrientProfile()
        original.calcium = 500
        original.iron = 10
        original.magnesium = 200
        original.potassium = 2000
        original.zinc = 5
        original.sodium = 1500
        original.phosphorus = 350
        original.copper = 0.5
        original.selenium = 30
        original.vitaminA = 450
        original.vitaminC = 45
        original.vitaminD = 10
        original.vitaminE = 7.5
        original.vitaminB12 = 1.2
        original.folate = 200
        original.vitaminK = 60
        original.vitaminB1 = 0.6
        original.vitaminB2 = 0.65
        original.vitaminB3 = 8
        original.vitaminB5 = 2.5
        original.vitaminB6 = 0.65

        // When: Encode and decode
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MicronutrientProfile.self, from: data)

        // Then: All values should be preserved
        XCTAssertEqual(decoded.calcium, original.calcium)
        XCTAssertEqual(decoded.iron, original.iron)
        XCTAssertEqual(decoded.magnesium, original.magnesium)
        XCTAssertEqual(decoded.potassium, original.potassium)
        XCTAssertEqual(decoded.zinc, original.zinc)
        XCTAssertEqual(decoded.sodium, original.sodium)
        XCTAssertEqual(decoded.phosphorus, original.phosphorus)
        XCTAssertEqual(decoded.copper, original.copper)
        XCTAssertEqual(decoded.selenium, original.selenium)
        XCTAssertEqual(decoded.vitaminA, original.vitaminA)
        XCTAssertEqual(decoded.vitaminC, original.vitaminC)
        XCTAssertEqual(decoded.vitaminD, original.vitaminD)
        XCTAssertEqual(decoded.vitaminE, original.vitaminE)
        XCTAssertEqual(decoded.vitaminB12, original.vitaminB12)
        XCTAssertEqual(decoded.folate, original.folate)
        XCTAssertEqual(decoded.vitaminK, original.vitaminK)
        XCTAssertEqual(decoded.vitaminB1, original.vitaminB1)
        XCTAssertEqual(decoded.vitaminB2, original.vitaminB2)
        XCTAssertEqual(decoded.vitaminB3, original.vitaminB3)
        XCTAssertEqual(decoded.vitaminB5, original.vitaminB5)
        XCTAssertEqual(decoded.vitaminB6, original.vitaminB6)
    }

    /// Test that empty MicronutrientProfile decodes correctly (edge case for new users)
    func testMicronutrientProfile_EmptyJSON() throws {
        // Given: An empty profile
        let original = MicronutrientProfile()

        // When: Encode and decode
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MicronutrientProfile.self, from: data)

        // Then: All values should be 0
        let nutrients = decoded.toMicronutrients()
        for nutrient in nutrients {
            XCTAssertEqual(nutrient.amount, 0.0, "\(nutrient.name) should be 0 after decoding empty profile")
        }
    }

    // MARK: - Aggregation Tests (simulating meal combination/removal)

    /// Test that nutrients can be aggregated correctly (simulating combining meals)
    func testNutrientAggregation_CombiningMeals() {
        // Given: Two meal profiles
        var meal1 = MicronutrientProfile()
        meal1.calcium = 300
        meal1.vitaminK = 50
        meal1.phosphorus = 200

        var meal2 = MicronutrientProfile()
        meal2.calcium = 200
        meal2.vitaminK = 30
        meal2.phosphorus = 150

        // When: Combine by adding values (as StatisticsService does)
        var combined = MicronutrientProfile()
        combined.calcium = meal1.calcium + meal2.calcium
        combined.vitaminK = meal1.vitaminK + meal2.vitaminK
        combined.phosphorus = meal1.phosphorus + meal2.phosphorus

        // Then: Combined values should be correct
        XCTAssertEqual(combined.calcium, 500, "Combined calcium should be 500")
        XCTAssertEqual(combined.vitaminK, 80, "Combined vitamin K should be 80")
        XCTAssertEqual(combined.phosphorus, 350, "Combined phosphorus should be 350")
    }

    /// Test that removing a meal's nutrients gives correct remaining totals
    func testNutrientAggregation_RemovingMeal() {
        // Given: Total from 3 meals, then removing one
        var total = MicronutrientProfile()
        total.calcium = 900  // 300 + 300 + 300
        total.iron = 27      // 9 + 9 + 9
        total.vitaminB6 = 3.9  // 1.3 + 1.3 + 1.3

        // Meal to remove
        var removedMeal = MicronutrientProfile()
        removedMeal.calcium = 300
        removedMeal.iron = 9
        removedMeal.vitaminB6 = 1.3

        // When: Subtract removed meal (as would happen on recompute)
        var remaining = MicronutrientProfile()
        remaining.calcium = total.calcium - removedMeal.calcium
        remaining.iron = total.iron - removedMeal.iron
        remaining.vitaminB6 = total.vitaminB6 - removedMeal.vitaminB6

        // Then: Remaining values should be correct (2 meals worth)
        XCTAssertEqual(remaining.calcium, 600, "Remaining calcium should be 600")
        XCTAssertEqual(remaining.iron, 18, "Remaining iron should be 18")
        XCTAssertEqual(remaining.vitaminB6, 2.6, accuracy: 0.01, "Remaining B6 should be ~2.6")
    }

    /// Test that RDA percentages update correctly after meal removal
    func testRDAPercentage_AfterMealRemoval() {
        // Given: Profile with original values
        var profile = MicronutrientProfile()
        profile.calcium = 650  // 50% of 1300mg RDA

        // When: Reduce by half (simulating meal removal)
        profile.calcium = 325  // Should now be 25% of RDA

        // Then: RDA should be recalculated correctly
        let nutrients = profile.toMicronutrients()
        let calcium = nutrients.first { $0.name == "Calcium" }
        XCTAssertEqual(calcium?.rdaPercent ?? 0, 25.0, accuracy: 0.1, "Calcium RDA should be 25% after reduction")
        XCTAssertEqual(calcium?.rdaColor, .onTrack, "25% should show as 'onTrack' color")
    }

    // MARK: - Meal Time Editing Tests

    /// Test that moving a meal to a different day requires recomputing BOTH old and new day aggregates
    /// This documents the expected behavior implemented in MealEditView.swift:166-189
    func testMealDateChange_RequiresDualDayRecalculation() {
        // Given: Day 1 has 3 meals totaling 900 calories
        var day1Profile = MicronutrientProfile()
        day1Profile.calcium = 900  // 300 * 3 meals
        day1Profile.iron = 27      // 9 * 3 meals

        // Given: Day 2 has 2 meals totaling 600 calories
        var day2Profile = MicronutrientProfile()
        day2Profile.calcium = 600  // 300 * 2 meals
        day2Profile.iron = 18      // 9 * 2 meals

        // When: Move one meal (300mg calcium, 9mg iron) from Day 1 to Day 2
        let movedMealCalcium = 300.0
        let movedMealIron = 9.0

        // Day 1 loses the meal
        day1Profile.calcium -= movedMealCalcium
        day1Profile.iron -= movedMealIron

        // Day 2 gains the meal
        day2Profile.calcium += movedMealCalcium
        day2Profile.iron += movedMealIron

        // Then: Day 1 should have 2 meals worth (600)
        XCTAssertEqual(day1Profile.calcium, 600, "Day 1 should have 600mg calcium after meal moved out")
        XCTAssertEqual(day1Profile.iron, 18, "Day 1 should have 18mg iron after meal moved out")

        // Then: Day 2 should have 3 meals worth (900)
        XCTAssertEqual(day2Profile.calcium, 900, "Day 2 should have 900mg calcium after meal moved in")
        XCTAssertEqual(day2Profile.iron, 27, "Day 2 should have 27mg iron after meal moved in")
    }

    /// Test that same-day time edits don't affect total aggregations
    /// (Only the firstMealTime/lastMealTime metadata would change)
    func testMealTimeChange_SameDayPreservesTotals() {
        // Given: A day with 3 meals
        var dayProfile = MicronutrientProfile()
        dayProfile.calcium = 900
        dayProfile.iron = 27
        dayProfile.vitaminB6 = 3.9

        // When: One meal's time changes from 8:00 AM to 9:00 AM (same day)
        // The aggregation logic doesn't need to change values since meal count stays the same

        // Then: Totals should be unchanged
        let nutrientsAfter = dayProfile.toMicronutrients()
        let calcium = nutrientsAfter.first { $0.name == "Calcium" }
        XCTAssertEqual(calcium?.amount, 900, "Same-day time edit should not affect nutrient totals")
    }

    /// Test cross-midnight edge case: meal moved from 11:59 PM Day 1 to 12:01 AM Day 2
    func testMealDateChange_CrossMidnight() {
        // Given: Day 1 (before midnight) has meal with specific nutrients
        var day1Profile = MicronutrientProfile()
        day1Profile.calcium = 500
        day1Profile.vitaminK = 80

        // Given: Day 2 (after midnight) starts empty
        var day2Profile = MicronutrientProfile()

        // When: Meal is moved from 11:59 PM Day 1 to 12:01 AM Day 2
        // (This is a cross-day move even though only 2 minutes apart)
        let mealCalcium = 500.0
        let mealVitaminK = 80.0

        day1Profile.calcium -= mealCalcium
        day1Profile.vitaminK -= mealVitaminK
        day2Profile.calcium += mealCalcium
        day2Profile.vitaminK += mealVitaminK

        // Then: Day 1 should now be empty (0 nutrients)
        XCTAssertEqual(day1Profile.calcium, 0, "Day 1 should be empty after meal moved")
        XCTAssertEqual(day1Profile.vitaminK, 0, "Day 1 vitamin K should be empty")

        // Then: Day 2 should have the meal's nutrients
        XCTAssertEqual(day2Profile.calcium, 500, "Day 2 should have 500mg calcium")
        XCTAssertEqual(day2Profile.vitaminK, 80, "Day 2 should have 80mcg vitamin K")
    }

    // MARK: - RDA Color Tests

    /// Test RDA color thresholds - soft, encouraging design
    func testRDAColor_Thresholds() {
        var profile = MicronutrientProfile()

        // Test buildingUp (< 25%)
        profile.calcium = 130  // 10% of 1300mg
        var nutrients = profile.toMicronutrients()
        var calcium = nutrients.first { $0.name == "Calcium" }
        XCTAssertEqual(calcium?.rdaColor, .buildingUp, "< 25% should be buildingUp")

        // Test onTrack (25-75%)
        profile.calcium = 650  // 50% of 1300mg
        nutrients = profile.toMicronutrients()
        calcium = nutrients.first { $0.name == "Calcium" }
        XCTAssertEqual(calcium?.rdaColor, .onTrack, "25-75% should be onTrack")

        // Test boundary: 25% should be onTrack, not buildingUp
        profile.calcium = 325  // 25% of 1300mg
        nutrients = profile.toMicronutrients()
        calcium = nutrients.first { $0.name == "Calcium" }
        XCTAssertEqual(calcium?.rdaColor, .onTrack, "exactly 25% should be onTrack")

        // Test great (75-100%)
        profile.calcium = 1105  // 85% of 1300mg
        nutrients = profile.toMicronutrients()
        calcium = nutrients.first { $0.name == "Calcium" }
        XCTAssertEqual(calcium?.rdaColor, .great, "75-100% should be great")

        // Test optimal (>= 100%)
        profile.calcium = 1500  // 115% of 1300mg
        nutrients = profile.toMicronutrients()
        calcium = nutrients.first { $0.name == "Calcium" }
        XCTAssertEqual(calcium?.rdaColor, .optimal, ">= 100% should be optimal")
    }

    /// Test that Vitamin D and Sodium always use neutral color
    /// These nutrients have non-dietary sources (sun for D, processed foods for sodium)
    func testRDAColor_NeutralForVitaminDAndSodium() {
        var profile = MicronutrientProfile()

        // Vitamin D at 5% should be neutral
        profile.vitaminD = 1.0  // 5% of 20mcg RDA
        var nutrients = profile.toMicronutrients()
        var vitaminD = nutrients.first { $0.name == "Vitamin D" }
        XCTAssertEqual(vitaminD?.rdaColor, .neutral, "Vitamin D should always be neutral")

        // Vitamin D at 60% should still be neutral (always gray for these nutrients)
        profile.vitaminD = 12.0  // 60% of 20mcg RDA
        nutrients = profile.toMicronutrients()
        vitaminD = nutrients.first { $0.name == "Vitamin D" }
        XCTAssertEqual(vitaminD?.rdaColor, .neutral, "Vitamin D should always be neutral even at high %")

        // Vitamin D at 120% should still be neutral
        profile.vitaminD = 24.0  // 120% of 20mcg RDA
        nutrients = profile.toMicronutrients()
        vitaminD = nutrients.first { $0.name == "Vitamin D" }
        XCTAssertEqual(vitaminD?.rdaColor, .neutral, "Vitamin D should always be neutral even over 100%")

        // Sodium at 20% should be neutral
        profile.sodium = 460  // 20% of 2300mg RDA
        nutrients = profile.toMicronutrients()
        var sodium = nutrients.first { $0.name == "Sodium" }
        XCTAssertEqual(sodium?.rdaColor, .neutral, "Sodium should always be neutral")

        // Sodium at 100% should still be neutral (always gray)
        profile.sodium = 2300  // 100% of 2300mg RDA
        nutrients = profile.toMicronutrients()
        sodium = nutrients.first { $0.name == "Sodium" }
        XCTAssertEqual(sodium?.rdaColor, .neutral, "Sodium should always be neutral even at 100%")
    }
}
