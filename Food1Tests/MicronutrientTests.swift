//
//  MicronutrientTests.swift
//  Food1Tests
//
//  Unit tests for Micronutrient model - validates RDA calculations and color coding.
//  PROTECTED: Do not modify without explicit user approval.
//

import XCTest
@testable import Food1

final class MicronutrientTests: XCTestCase {

    // MARK: - RDA Color Thresholds

    func testRDAColor_Deficient_Under20Percent() {
        let nutrient = Micronutrient(
            name: "Iron",
            amount: 1.8,
            unit: "mg",
            rdaPercent: 10.0, // 10% < 20%
            category: .mineral
        )
        XCTAssertEqual(nutrient.rdaColor, .deficient)
    }

    func testRDAColor_Low_20To50Percent() {
        let nutrient = Micronutrient(
            name: "Iron",
            amount: 5.4,
            unit: "mg",
            rdaPercent: 30.0, // 20% <= 30% < 50%
            category: .mineral
        )
        XCTAssertEqual(nutrient.rdaColor, .low)
    }

    func testRDAColor_Sufficient_50To100Percent() {
        let nutrient = Micronutrient(
            name: "Iron",
            amount: 12.6,
            unit: "mg",
            rdaPercent: 70.0, // 50% <= 70% < 100%
            category: .mineral
        )
        XCTAssertEqual(nutrient.rdaColor, .sufficient)
    }

    func testRDAColor_Excellent_100PercentOrMore() {
        let nutrient = Micronutrient(
            name: "Iron",
            amount: 18.0,
            unit: "mg",
            rdaPercent: 100.0, // >= 100%
            category: .mineral
        )
        XCTAssertEqual(nutrient.rdaColor, .excellent)
    }

    func testRDAColor_Excellent_Over100Percent() {
        let nutrient = Micronutrient(
            name: "Vitamin C",
            amount: 135.0,
            unit: "mg",
            rdaPercent: 150.0, // 150% > 100%
            category: .vitamin
        )
        XCTAssertEqual(nutrient.rdaColor, .excellent)
    }

    // MARK: - Boundary Tests

    func testRDAColor_Boundary_19Percent() {
        let nutrient = Micronutrient(name: "Test", amount: 0, unit: "mg", rdaPercent: 19.9, category: .mineral)
        XCTAssertEqual(nutrient.rdaColor, .deficient)
    }

    func testRDAColor_Boundary_20Percent() {
        let nutrient = Micronutrient(name: "Test", amount: 0, unit: "mg", rdaPercent: 20.0, category: .mineral)
        XCTAssertEqual(nutrient.rdaColor, .low)
    }

    func testRDAColor_Boundary_49Percent() {
        let nutrient = Micronutrient(name: "Test", amount: 0, unit: "mg", rdaPercent: 49.9, category: .mineral)
        XCTAssertEqual(nutrient.rdaColor, .low)
    }

    func testRDAColor_Boundary_50Percent() {
        let nutrient = Micronutrient(name: "Test", amount: 0, unit: "mg", rdaPercent: 50.0, category: .mineral)
        XCTAssertEqual(nutrient.rdaColor, .sufficient)
    }

    func testRDAColor_Boundary_99Percent() {
        let nutrient = Micronutrient(name: "Test", amount: 0, unit: "mg", rdaPercent: 99.9, category: .mineral)
        XCTAssertEqual(nutrient.rdaColor, .sufficient)
    }

    func testRDAColor_ZeroPercent() {
        let nutrient = Micronutrient(name: "Test", amount: 0, unit: "mg", rdaPercent: 0.0, category: .mineral)
        XCTAssertEqual(nutrient.rdaColor, .deficient)
    }

    // MARK: - Formatted Amount

    func testFormattedAmount_SmallValue_ShowsDecimal() {
        let nutrient = Micronutrient(name: "B12", amount: 0.5, unit: "mcg", rdaPercent: 20.0, category: .vitamin)
        XCTAssertEqual(nutrient.formattedAmount, "0.5")
    }

    func testFormattedAmount_LargeValue_ShowsWholeNumber() {
        let nutrient = Micronutrient(name: "Calcium", amount: 150.0, unit: "mg", rdaPercent: 15.0, category: .mineral)
        XCTAssertEqual(nutrient.formattedAmount, "150")
    }

    func testFormattedAmount_ExactlyOne_ShowsWholeNumber() {
        let nutrient = Micronutrient(name: "Test", amount: 1.0, unit: "mg", rdaPercent: 10.0, category: .mineral)
        XCTAssertEqual(nutrient.formattedAmount, "1")
    }

    func testFormattedAmount_JustUnderOne_ShowsDecimal() {
        let nutrient = Micronutrient(name: "Test", amount: 0.9, unit: "mg", rdaPercent: 10.0, category: .mineral)
        XCTAssertEqual(nutrient.formattedAmount, "0.9")
    }

    // MARK: - Nutrient Category Classification

    func testCategorize_Vitamins() {
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Vitamin A"), .vitamin)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Vitamin C"), .vitamin)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Vitamin D"), .vitamin)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Vitamin B12"), .vitamin)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Folate"), .vitamin)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Choline"), .vitamin)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Biotin"), .vitamin)
    }

    func testCategorize_Minerals() {
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Calcium"), .mineral)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Iron"), .mineral)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Magnesium"), .mineral)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Zinc"), .mineral)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Copper"), .mineral)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Selenium"), .mineral)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Phosphorus"), .mineral)
    }

    func testCategorize_Electrolytes() {
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Sodium"), .electrolyte)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Potassium"), .electrolyte)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Chloride"), .electrolyte)
    }

    func testCategorize_Fiber() {
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Fiber"), .fiber)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Total Fiber"), .fiber)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Sugar"), .fiber) // Grouped with fiber in this implementation
    }

    func testCategorize_FattyAcids() {
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Omega-3 fatty acids"), .fattyAcid)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Saturated Fat"), .fattyAcid)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "Cholesterol"), .fattyAcid)
    }

    func testCategorize_Unknown() {
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "SomeUnknownNutrient"), .other)
    }

    func testCategorize_CaseInsensitive() {
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "VITAMIN C"), .vitamin)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "iron"), .mineral)
        XCTAssertEqual(NutrientCategory.categorize(nutrientName: "SODIUM"), .electrolyte)
    }

    // MARK: - Identifiable Conformance

    func testMicronutrient_IdIsName() {
        let nutrient = Micronutrient(name: "Iron", amount: 5.0, unit: "mg", rdaPercent: 27.8, category: .mineral)
        XCTAssertEqual(nutrient.id, "Iron")
    }

    // MARK: - Hashable Conformance

    func testMicronutrient_Hashable() {
        let nutrient1 = Micronutrient(name: "Iron", amount: 5.0, unit: "mg", rdaPercent: 27.8, category: .mineral)
        let nutrient2 = Micronutrient(name: "Iron", amount: 5.0, unit: "mg", rdaPercent: 27.8, category: .mineral)

        XCTAssertEqual(nutrient1, nutrient2)
        XCTAssertEqual(nutrient1.hashValue, nutrient2.hashValue)
    }
}
