//
//  NutritionFormatterTests.swift
//  Food1Tests
//
//  Unit tests for NutritionFormatter - validates unit conversions and formatting.
//  PROTECTED: Do not modify without explicit user approval.
//

import XCTest
@testable import Food1

final class NutritionFormatterTests: XCTestCase {

    // MARK: - Conversion Constants

    func testGramsToOuncesConstant() {
        // 1 gram = 0.035274 ounces (standard conversion)
        XCTAssertEqual(NutritionFormatter.gramsToOunces, 0.035274, accuracy: 0.000001)
    }

    func testOuncesToGramsConstant() {
        // 1 ounce = 28.3495 grams (standard conversion)
        XCTAssertEqual(NutritionFormatter.ouncesToGrams, 28.3495, accuracy: 0.0001)
    }

    func testConversionConstantsAreInverse() {
        // gramsToOunces * ouncesToGrams should approximately equal 1
        let product = NutritionFormatter.gramsToOunces * NutritionFormatter.ouncesToGrams
        XCTAssertEqual(product, 1.0, accuracy: 0.0001)
    }

    // MARK: - Metric Conversions (Identity)

    func testConvertGramsToMetric_ReturnsUnchanged() {
        XCTAssertEqual(NutritionFormatter.convert(grams: 100.0, to: .metric), 100.0)
        XCTAssertEqual(NutritionFormatter.convert(grams: 0.0, to: .metric), 0.0)
        XCTAssertEqual(NutritionFormatter.convert(grams: 150.5, to: .metric), 150.5)
    }

    func testToGramsFromMetric_ReturnsUnchanged() {
        XCTAssertEqual(NutritionFormatter.toGrams(value: 100.0, from: .metric), 100.0)
        XCTAssertEqual(NutritionFormatter.toGrams(value: 0.0, from: .metric), 0.0)
    }

    // MARK: - Imperial Conversions

    func testConvertGramsToImperial() {
        // 100g should be approximately 3.5274 oz
        let result = NutritionFormatter.convert(grams: 100.0, to: .imperial)
        XCTAssertEqual(result, 3.5274, accuracy: 0.0001)
    }

    func testToGramsFromImperial() {
        // 1 oz should be 28.3495g
        let result = NutritionFormatter.toGrams(value: 1.0, from: .imperial)
        XCTAssertEqual(result, 28.3495, accuracy: 0.0001)
    }

    func testRoundTripConversion() {
        // Converting 100g to oz and back should return ~100g
        let originalGrams = 100.0
        let ounces = NutritionFormatter.convert(grams: originalGrams, to: .imperial)
        let backToGrams = NutritionFormatter.toGrams(value: ounces, from: .imperial)
        XCTAssertEqual(backToGrams, originalGrams, accuracy: 0.01)
    }

    // MARK: - Formatting

    func testFormatMetric_ReturnsWholeNumberWithG() {
        XCTAssertEqual(NutritionFormatter.format(100.0, unit: .metric), "100g")
        XCTAssertEqual(NutritionFormatter.format(150.4, unit: .metric), "150g")
        XCTAssertEqual(NutritionFormatter.format(150.6, unit: .metric), "151g") // Rounds up
    }

    func testFormatImperial_ReturnsDecimalWithOz() {
        let result = NutritionFormatter.format(100.0, unit: .imperial)
        XCTAssertTrue(result.hasSuffix("oz"))
        XCTAssertTrue(result.contains("3.5")) // ~3.5274 oz
    }

    func testFormatValue_MetricNoUnit() {
        XCTAssertEqual(NutritionFormatter.formatValue(100.0, unit: .metric), "100")
        XCTAssertEqual(NutritionFormatter.formatValue(75.4, unit: .metric), "75")
    }

    func testFormatValue_ImperialNoUnit() {
        let result = NutritionFormatter.formatValue(100.0, unit: .imperial)
        XCTAssertTrue(result.contains("3.5"))
        XCTAssertFalse(result.contains("oz"))
    }

    // MARK: - Unit Labels

    func testUnitLabel_Metric() {
        XCTAssertEqual(NutritionFormatter.unitLabel(.metric), "g")
    }

    func testUnitLabel_Imperial() {
        XCTAssertEqual(NutritionFormatter.unitLabel(.imperial), "oz")
    }

    // MARK: - Progress Formatting

    func testFormatProgress_Metric() {
        let result = NutritionFormatter.formatProgress(current: 150.0, goal: 200.0, unit: .metric)
        XCTAssertEqual(result, "150g / 200g")
    }

    func testFormatProgress_Imperial() {
        let result = NutritionFormatter.formatProgress(current: 28.3495, goal: 56.699, unit: .imperial)
        // Should be approximately "1.0oz / 2.0oz"
        XCTAssertTrue(result.contains("1.0"))
        XCTAssertTrue(result.contains("2.0"))
        XCTAssertTrue(result.contains("oz"))
    }

    // MARK: - Edge Cases

    func testZeroGrams() {
        XCTAssertEqual(NutritionFormatter.format(0.0, unit: .metric), "0g")
        XCTAssertEqual(NutritionFormatter.convert(grams: 0.0, to: .imperial), 0.0)
    }

    func testLargeValues() {
        // 1000g = 1kg, should format correctly
        XCTAssertEqual(NutritionFormatter.format(1000.0, unit: .metric), "1000g")

        // 1000g in oz
        let ozResult = NutritionFormatter.convert(grams: 1000.0, to: .imperial)
        XCTAssertEqual(ozResult, 35.274, accuracy: 0.001)
    }
}
