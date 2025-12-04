//
//  RDAValuesTests.swift
//  Food1Tests
//
//  Unit tests for RDAValues - validates FDA recommended daily allowances.
//  PROTECTED: Do not modify without explicit user approval.
//

import XCTest
@testable import Food1

final class RDAValuesTests: XCTestCase {

    // MARK: - Static RDA Values (FDA 2020 Guidelines)

    func testCalciumRDA() {
        XCTAssertEqual(RDAValues.calcium, 1300.0)
    }

    func testIronRDA() {
        XCTAssertEqual(RDAValues.iron, 18.0)
    }

    func testMagnesiumRDA() {
        XCTAssertEqual(RDAValues.magnesium, 400.0)
    }

    func testPotassiumRDA() {
        XCTAssertEqual(RDAValues.potassium, 4700.0)
    }

    func testZincRDA() {
        XCTAssertEqual(RDAValues.zinc, 11.0)
    }

    func testSodiumDailyValue() {
        XCTAssertEqual(RDAValues.sodium, 2300.0)
    }

    func testVitaminCRDA() {
        XCTAssertEqual(RDAValues.vitaminC, 90.0)
    }

    func testVitaminDRDA() {
        XCTAssertEqual(RDAValues.vitaminD, 20.0)
    }

    func testVitaminB12RDA() {
        XCTAssertEqual(RDAValues.vitaminB12, 2.4)
    }

    func testFolateRDA() {
        XCTAssertEqual(RDAValues.folate, 400.0)
    }

    // MARK: - Gender-Specific RDA (Iron)

    func testIronRDA_PremenopausalFemale() {
        // Women under 51 need more iron
        let rda = RDAValues.getRDA(for: "Iron", gender: .female, age: 30)
        XCTAssertEqual(rda, 18.0)
    }

    func testIronRDA_PostmenopausalFemale() {
        // Women 51+ need less iron
        let rda = RDAValues.getRDA(for: "Iron", gender: .female, age: 55)
        XCTAssertEqual(rda, 8.0)
    }

    func testIronRDA_Male() {
        // Men need less iron regardless of age
        let rda = RDAValues.getRDA(for: "Iron", gender: .male, age: 30)
        XCTAssertEqual(rda, 8.0)
    }

    // MARK: - Gender-Specific RDA (Zinc)

    func testZincRDA_Male() {
        let rda = RDAValues.getRDA(for: "Zinc", gender: .male, age: 30)
        XCTAssertEqual(rda, 11.0)
    }

    func testZincRDA_Female() {
        let rda = RDAValues.getRDA(for: "Zinc", gender: .female, age: 30)
        XCTAssertEqual(rda, 8.0)
    }

    // MARK: - Gender-Specific RDA (Vitamin C)

    func testVitaminCRDA_Male() {
        let rda = RDAValues.getRDA(for: "Vitamin C", gender: .male, age: 30)
        XCTAssertEqual(rda, 90.0)
    }

    func testVitaminCRDA_Female() {
        let rda = RDAValues.getRDA(for: "Vitamin C", gender: .female, age: 30)
        XCTAssertEqual(rda, 75.0)
    }

    // MARK: - Age-Specific RDA (Calcium)

    func testCalciumRDA_YoungAdult() {
        let rda = RDAValues.getRDA(for: "Calcium", gender: .male, age: 30)
        XCTAssertEqual(rda, 1300.0)
    }

    func testCalciumRDA_OlderAdult() {
        // Calcium increases for older adults
        let rda = RDAValues.getRDA(for: "Calcium", gender: .male, age: 55)
        XCTAssertEqual(rda, 1200.0)
    }

    // MARK: - Age-Specific RDA (Vitamin B6)

    func testVitaminB6RDA_YoungAdult() {
        let rda = RDAValues.getRDA(for: "Vitamin B6", gender: .male, age: 30)
        XCTAssertEqual(rda, 1.3)
    }

    func testVitaminB6RDA_OlderAdult() {
        // B6 increases for adults 51+
        let rda = RDAValues.getRDA(for: "Vitamin B6", gender: .male, age: 55)
        XCTAssertEqual(rda, 1.7)
    }

    // MARK: - Gender-Specific RDA (Magnesium)

    func testMagnesiumRDA_YoungMale() {
        let rda = RDAValues.getRDA(for: "Magnesium", gender: .male, age: 30)
        XCTAssertEqual(rda, 400.0)
    }

    func testMagnesiumRDA_OlderMale() {
        let rda = RDAValues.getRDA(for: "Magnesium", gender: .male, age: 55)
        XCTAssertEqual(rda, 420.0)
    }

    func testMagnesiumRDA_YoungFemale() {
        let rda = RDAValues.getRDA(for: "Magnesium", gender: .female, age: 30)
        XCTAssertEqual(rda, 310.0)
    }

    func testMagnesiumRDA_OlderFemale() {
        let rda = RDAValues.getRDA(for: "Magnesium", gender: .female, age: 55)
        XCTAssertEqual(rda, 320.0)
    }

    // MARK: - Default Values (preferNotToSay)

    func testDefaultRDA_UsesAverageValues() {
        // When gender is not specified, should use average/default values
        let ironRDA = RDAValues.getRDA(for: "Iron", gender: .preferNotToSay, age: 30)
        XCTAssertEqual(ironRDA, 8.0) // Default is 8mg (male value)

        let zincRDA = RDAValues.getRDA(for: "Zinc", gender: .preferNotToSay, age: 30)
        XCTAssertEqual(zincRDA, 11.0) // Uses static default
    }

    // MARK: - Case Insensitivity

    func testRDALookup_CaseInsensitive() {
        let lowerCase = RDAValues.getRDA(for: "vitamin c", gender: .male, age: 30)
        let upperCase = RDAValues.getRDA(for: "VITAMIN C", gender: .male, age: 30)
        let mixedCase = RDAValues.getRDA(for: "Vitamin C", gender: .male, age: 30)

        XCTAssertEqual(lowerCase, upperCase)
        XCTAssertEqual(lowerCase, mixedCase)
    }

    // MARK: - Unknown Nutrient

    func testUnknownNutrient_ReturnsZero() {
        let rda = RDAValues.getRDA(for: "UnknownNutrient", gender: .male, age: 30)
        XCTAssertEqual(rda, 0.0)
    }

    // MARK: - Fiber RDA (Gender-Specific)

    func testFiberRDA_YoungMale() {
        let rda = RDAValues.getRDA(for: "Total Fiber", gender: .male, age: 30)
        XCTAssertEqual(rda, 38.0)
    }

    func testFiberRDA_YoungFemale() {
        let rda = RDAValues.getRDA(for: "Total Fiber", gender: .female, age: 30)
        XCTAssertEqual(rda, 25.0)
    }

    func testFiberRDA_OlderMale() {
        let rda = RDAValues.getRDA(for: "Total Fiber", gender: .male, age: 55)
        XCTAssertEqual(rda, 30.0)
    }

    func testFiberRDA_OlderFemale() {
        let rda = RDAValues.getRDA(for: "Total Fiber", gender: .female, age: 55)
        XCTAssertEqual(rda, 21.0)
    }
}
