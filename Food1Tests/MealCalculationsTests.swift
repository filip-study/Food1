//
//  MealCalculationsTests.swift
//  Food1Tests
//
//  Unit tests for Meal calculations - validates nutrition aggregation.
//  PROTECTED: Do not modify without explicit user approval.
//

import XCTest
@testable import Food1

final class MealCalculationsTests: XCTestCase {

    // MARK: - Daily Goals

    func testDailyGoals_StandardValues() {
        let goals = DailyGoals.standard

        XCTAssertEqual(goals.calories, 2000.0)
        XCTAssertEqual(goals.protein, 150.0)
        XCTAssertEqual(goals.carbs, 225.0)
        XCTAssertEqual(goals.fat, 65.0)
    }

    // MARK: - MicronutrientProfile toMicronutrients

    func testMicronutrientProfile_toMicronutrients_CalculatesRDAPercent() {
        var profile = MicronutrientProfile()
        profile.calcium = 650.0 // 50% of 1300mg RDA
        profile.iron = 9.0 // 50% of 18mg RDA
        profile.vitaminC = 45.0 // 50% of 90mg RDA

        let nutrients = profile.toMicronutrients()

        let calcium = nutrients.first { $0.name == "Calcium" }
        XCTAssertNotNil(calcium)
        XCTAssertEqual(calcium?.rdaPercent ?? 0, 50.0, accuracy: 0.1)

        let iron = nutrients.first { $0.name == "Iron" }
        XCTAssertNotNil(iron)
        XCTAssertEqual(iron?.rdaPercent ?? 0, 50.0, accuracy: 0.1)

        let vitaminC = nutrients.first { $0.name == "Vitamin C" }
        XCTAssertNotNil(vitaminC)
        XCTAssertEqual(vitaminC?.rdaPercent ?? 0, 50.0, accuracy: 0.1)
    }

    func testMicronutrientProfile_toMicronutrients_ContainsAllExpectedNutrients() {
        let profile = MicronutrientProfile()
        let nutrients = profile.toMicronutrients()

        let expectedNames = [
            "Calcium", "Iron", "Magnesium", "Potassium", "Zinc",
            "Vitamin A", "Vitamin C", "Vitamin D", "Vitamin E",
            "Vitamin B12", "Folate", "Sodium"
        ]

        for name in expectedNames {
            XCTAssertTrue(nutrients.contains { $0.name == name }, "Missing nutrient: \(name)")
        }

        XCTAssertEqual(nutrients.count, expectedNames.count)
    }

    func testMicronutrientProfile_toMicronutrients_CorrectUnits() {
        var profile = MicronutrientProfile()
        profile.calcium = 100
        profile.vitaminA = 100
        profile.vitaminB12 = 1
        profile.vitaminD = 10

        let nutrients = profile.toMicronutrients()

        // Minerals in mg
        XCTAssertEqual(nutrients.first { $0.name == "Calcium" }?.unit, "mg")
        XCTAssertEqual(nutrients.first { $0.name == "Iron" }?.unit, "mg")
        XCTAssertEqual(nutrients.first { $0.name == "Magnesium" }?.unit, "mg")
        XCTAssertEqual(nutrients.first { $0.name == "Potassium" }?.unit, "mg")
        XCTAssertEqual(nutrients.first { $0.name == "Zinc" }?.unit, "mg")
        XCTAssertEqual(nutrients.first { $0.name == "Sodium" }?.unit, "mg")

        // Vitamins - some mcg, some mg
        XCTAssertEqual(nutrients.first { $0.name == "Vitamin A" }?.unit, "mcg")
        XCTAssertEqual(nutrients.first { $0.name == "Vitamin C" }?.unit, "mg")
        XCTAssertEqual(nutrients.first { $0.name == "Vitamin D" }?.unit, "mcg")
        XCTAssertEqual(nutrients.first { $0.name == "Vitamin E" }?.unit, "mg")
        XCTAssertEqual(nutrients.first { $0.name == "Vitamin B12" }?.unit, "mcg")
        XCTAssertEqual(nutrients.first { $0.name == "Folate" }?.unit, "mcg")
    }

    func testMicronutrientProfile_toMicronutrients_CorrectCategories() {
        var profile = MicronutrientProfile()
        profile.calcium = 100
        profile.potassium = 100
        profile.vitaminC = 10

        let nutrients = profile.toMicronutrients()

        XCTAssertEqual(nutrients.first { $0.name == "Calcium" }?.category, .mineral)
        XCTAssertEqual(nutrients.first { $0.name == "Iron" }?.category, .mineral)
        XCTAssertEqual(nutrients.first { $0.name == "Potassium" }?.category, .electrolyte)
        XCTAssertEqual(nutrients.first { $0.name == "Sodium" }?.category, .electrolyte)
        XCTAssertEqual(nutrients.first { $0.name == "Vitamin C" }?.category, .vitamin)
        XCTAssertEqual(nutrients.first { $0.name == "Vitamin A" }?.category, .vitamin)
    }

    // MARK: - MicronutrientProfile Accumulation

    func testMicronutrientProfile_DefaultsToZero() {
        let profile = MicronutrientProfile()

        XCTAssertEqual(profile.calcium, 0.0)
        XCTAssertEqual(profile.iron, 0.0)
        XCTAssertEqual(profile.magnesium, 0.0)
        XCTAssertEqual(profile.potassium, 0.0)
        XCTAssertEqual(profile.zinc, 0.0)
        XCTAssertEqual(profile.vitaminA, 0.0)
        XCTAssertEqual(profile.vitaminC, 0.0)
        XCTAssertEqual(profile.vitaminD, 0.0)
        XCTAssertEqual(profile.vitaminE, 0.0)
        XCTAssertEqual(profile.vitaminB12, 0.0)
        XCTAssertEqual(profile.folate, 0.0)
        XCTAssertEqual(profile.sodium, 0.0)
    }

    func testMicronutrientProfile_Accumulation() {
        var profile = MicronutrientProfile()

        // Simulate adding nutrients from multiple ingredients
        profile.calcium += 100
        profile.calcium += 200
        profile.iron += 5
        profile.iron += 3

        XCTAssertEqual(profile.calcium, 300.0)
        XCTAssertEqual(profile.iron, 8.0)
    }

    // MARK: - RDA Percentage Calculations

    func testRDAPercent_FullRDA() {
        var profile = MicronutrientProfile()
        profile.calcium = RDAValues.calcium // 100% of RDA
        profile.iron = RDAValues.iron

        let nutrients = profile.toMicronutrients()

        let calcium = nutrients.first { $0.name == "Calcium" }
        XCTAssertEqual(calcium?.rdaPercent ?? 0, 100.0, accuracy: 0.1)

        let iron = nutrients.first { $0.name == "Iron" }
        XCTAssertEqual(iron?.rdaPercent ?? 0, 100.0, accuracy: 0.1)
    }

    func testRDAPercent_OverRDA() {
        var profile = MicronutrientProfile()
        profile.vitaminC = RDAValues.vitaminC * 2 // 200% of RDA

        let nutrients = profile.toMicronutrients()
        let vitaminC = nutrients.first { $0.name == "Vitamin C" }

        XCTAssertEqual(vitaminC?.rdaPercent ?? 0, 200.0, accuracy: 0.1)
    }

    func testRDAPercent_ZeroAmount() {
        let profile = MicronutrientProfile() // All zeros
        let nutrients = profile.toMicronutrients()

        for nutrient in nutrients {
            XCTAssertEqual(nutrient.rdaPercent, 0.0, "Non-zero RDA% for \(nutrient.name)")
        }
    }
}
