//
//  NutritionFormatterTests.swift
//  Food1Tests
//
//  Tests for NutritionFormatter unit conversion and formatting utilities.
//

import XCTest
@testable import Food1

/// Tests for NutritionFormatter - verifies metric/imperial conversions and formatting
///
/// TEST POLICY: These tests define expected behavior and MUST NOT be modified without explicit user approval.
/// If tests fail after code changes, fix the CODE, not the tests.
///
/// Coverage:
/// 1. Grams to ounces conversion accuracy
/// 2. Ounces to grams conversion accuracy
/// 3. Round-trip conversion (grams → ounces → grams)
/// 4. Format with unit labels (g/oz)
/// 5. FormatValue without labels
/// 6. FormatProgress for current/goal display
final class NutritionFormatterTests: XCTestCase {

    // MARK: - Conversion Constants

    /// Verify the conversion constants are accurate
    func testConversionConstants() {
        // Standard conversion: 1 ounce = 28.3495 grams
        XCTAssertEqual(NutritionFormatter.ouncesToGrams, 28.3495, accuracy: 0.0001,
                       "ouncesToGrams should be 28.3495")

        // Inverse: 1 gram = 0.035274 ounces
        XCTAssertEqual(NutritionFormatter.gramsToOunces, 0.035274, accuracy: 0.000001,
                       "gramsToOunces should be 0.035274")

        // Verify they are inverses (within floating point tolerance)
        let product = NutritionFormatter.gramsToOunces * NutritionFormatter.ouncesToGrams
        XCTAssertEqual(product, 1.0, accuracy: 0.0001,
                       "gramsToOunces × ouncesToGrams should equal 1.0")
    }

    // MARK: - Grams to Ounces Conversion

    /// Test converting grams to ounces
    func testConvert_GramsToOunces() {
        // 28.3495g = 1oz
        let result = NutritionFormatter.convert(grams: 28.3495, to: .imperial)
        XCTAssertEqual(result, 1.0, accuracy: 0.001,
                       "28.3495 grams should convert to ~1 ounce")
    }

    /// Test converting 100g to ounces
    func testConvert_100GramsToOunces() {
        let result = NutritionFormatter.convert(grams: 100, to: .imperial)
        // 100 × 0.035274 = 3.5274
        XCTAssertEqual(result, 3.5274, accuracy: 0.001,
                       "100 grams should convert to ~3.53 ounces")
    }

    /// Test that metric conversion returns grams unchanged
    func testConvert_MetricReturnsGramsUnchanged() {
        let grams = 150.0
        let result = NutritionFormatter.convert(grams: grams, to: .metric)
        XCTAssertEqual(result, grams,
                       "Metric conversion should return grams unchanged")
    }

    /// Test zero conversion
    func testConvert_ZeroGrams() {
        let imperialResult = NutritionFormatter.convert(grams: 0, to: .imperial)
        let metricResult = NutritionFormatter.convert(grams: 0, to: .metric)

        XCTAssertEqual(imperialResult, 0, "Zero grams should convert to zero ounces")
        XCTAssertEqual(metricResult, 0, "Zero grams should remain zero in metric")
    }

    // MARK: - Ounces to Grams Conversion

    /// Test converting 1 ounce to grams
    func testToGrams_1OunceToGrams() {
        let result = NutritionFormatter.toGrams(value: 1.0, from: .imperial)
        XCTAssertEqual(result, 28.3495, accuracy: 0.001,
                       "1 ounce should convert to ~28.35 grams")
    }

    /// Test converting 3.5 ounces to grams
    func testToGrams_MultipleOuncesToGrams() {
        let result = NutritionFormatter.toGrams(value: 3.5, from: .imperial)
        // 3.5 × 28.3495 = 99.22325
        XCTAssertEqual(result, 99.22, accuracy: 0.1,
                       "3.5 ounces should convert to ~99.2 grams")
    }

    /// Test that metric toGrams returns value unchanged
    func testToGrams_MetricReturnsValueUnchanged() {
        let grams = 200.0
        let result = NutritionFormatter.toGrams(value: grams, from: .metric)
        XCTAssertEqual(result, grams,
                       "Metric toGrams should return value unchanged")
    }

    // MARK: - Round-Trip Conversion

    /// Test round-trip: grams → ounces → grams
    /// Critical for data integrity when user switches units
    func testRoundTrip_GramsToOuncesAndBack() {
        let originalGrams = 150.0

        // Convert to ounces
        let ounces = NutritionFormatter.convert(grams: originalGrams, to: .imperial)

        // Convert back to grams
        let backToGrams = NutritionFormatter.toGrams(value: ounces, from: .imperial)

        XCTAssertEqual(backToGrams, originalGrams, accuracy: 0.01,
                       "Round-trip conversion should preserve original value (150g)")
    }

    /// Test round-trip with common macro values
    func testRoundTrip_CommonMacroValues() {
        let testCases: [Double] = [30, 50, 100, 150, 200]  // Common protein/carb/fat values

        for grams in testCases {
            let ounces = NutritionFormatter.convert(grams: grams, to: .imperial)
            let backToGrams = NutritionFormatter.toGrams(value: ounces, from: .imperial)

            XCTAssertEqual(backToGrams, grams, accuracy: 0.01,
                           "Round-trip should preserve \(grams)g")
        }
    }

    // MARK: - Format with Unit Label

    /// Test format() returns correct string with metric unit
    func testFormat_MetricWithLabel() {
        let result = NutritionFormatter.format(100, unit: .metric)
        XCTAssertEqual(result, "100g",
                       "format(100, metric) should return '100g'")
    }

    /// Test format() rounds to whole numbers for metric
    func testFormat_MetricRoundsToWholeNumbers() {
        // 99.7 should round to 100
        let result = NutritionFormatter.format(99.7, unit: .metric)
        XCTAssertEqual(result, "100g",
                       "format(99.7, metric) should round to '100g'")

        // 99.4 should round to 99
        let result2 = NutritionFormatter.format(99.4, unit: .metric)
        XCTAssertEqual(result2, "99g",
                       "format(99.4, metric) should round to '99g'")
    }

    /// Test format() returns correct string with imperial unit
    func testFormat_ImperialWithLabel() {
        // 28.3495g = 1oz
        let result = NutritionFormatter.format(28.3495, unit: .imperial)
        XCTAssertEqual(result, "1.0oz",
                       "format(28.3495g, imperial) should return '1.0oz'")
    }

    /// Test format() with custom decimal places for imperial
    func testFormat_ImperialCustomDecimals() {
        let result = NutritionFormatter.format(100, unit: .imperial, decimals: 2)
        // 100 × 0.035274 = 3.5274
        XCTAssertEqual(result, "3.53oz",
                       "format(100g, imperial, 2 decimals) should return '3.53oz'")
    }

    // MARK: - FormatValue (without label)

    /// Test formatValue() for metric
    func testFormatValue_Metric() {
        let result = NutritionFormatter.formatValue(150, unit: .metric)
        XCTAssertEqual(result, "150",
                       "formatValue(150, metric) should return '150'")
    }

    /// Test formatValue() for imperial
    func testFormatValue_Imperial() {
        // 100g = 3.5274oz
        let result = NutritionFormatter.formatValue(100, unit: .imperial)
        XCTAssertEqual(result, "3.5",
                       "formatValue(100g, imperial) should return '3.5'")
    }

    /// Test formatValue() rounds metric correctly
    /// Swift uses "round half away from zero" (schoolbook rounding)
    func testFormatValue_MetricRounding() {
        XCTAssertEqual(NutritionFormatter.formatValue(50.4, unit: .metric), "50")
        XCTAssertEqual(NutritionFormatter.formatValue(50.5, unit: .metric), "51")  // Round half up
        XCTAssertEqual(NutritionFormatter.formatValue(50.6, unit: .metric), "51")
    }

    // MARK: - FormatProgress

    /// Test formatProgress() for metric
    func testFormatProgress_Metric() {
        let result = NutritionFormatter.formatProgress(current: 100, goal: 150, unit: .metric)
        XCTAssertEqual(result, "100g / 150g",
                       "formatProgress should show 'current / goal' with units")
    }

    /// Test formatProgress() for imperial
    func testFormatProgress_Imperial() {
        // 100g = 3.5oz, 150g = 5.3oz
        let result = NutritionFormatter.formatProgress(current: 100, goal: 150, unit: .imperial)
        XCTAssertEqual(result, "3.5oz / 5.3oz",
                       "formatProgress should convert to ounces with 1 decimal")
    }

    /// Test formatProgress() at goal (current == goal)
    func testFormatProgress_AtGoal() {
        let result = NutritionFormatter.formatProgress(current: 150, goal: 150, unit: .metric)
        XCTAssertEqual(result, "150g / 150g",
                       "formatProgress should handle current == goal")
    }

    /// Test formatProgress() over goal
    func testFormatProgress_OverGoal() {
        let result = NutritionFormatter.formatProgress(current: 200, goal: 150, unit: .metric)
        XCTAssertEqual(result, "200g / 150g",
                       "formatProgress should handle current > goal")
    }

    // MARK: - Unit Label

    /// Test unitLabel() returns correct short labels
    func testUnitLabel() {
        XCTAssertEqual(NutritionFormatter.unitLabel(.metric), "g",
                       "unitLabel for metric should be 'g'")
        XCTAssertEqual(NutritionFormatter.unitLabel(.imperial), "oz",
                       "unitLabel for imperial should be 'oz'")
    }

    // MARK: - NutritionUnit Enum

    /// Test NutritionUnit shortLabel property
    func testNutritionUnit_ShortLabel() {
        XCTAssertEqual(NutritionUnit.metric.shortLabel, "g")
        XCTAssertEqual(NutritionUnit.imperial.shortLabel, "oz")
    }

    /// Test NutritionUnit rawValue (used for @AppStorage)
    func testNutritionUnit_RawValue() {
        XCTAssertEqual(NutritionUnit.metric.rawValue, "Metric (grams)")
        XCTAssertEqual(NutritionUnit.imperial.rawValue, "Imperial (ounces)")
    }

    /// Test NutritionUnit can be initialized from rawValue (for @AppStorage decoding)
    func testNutritionUnit_InitFromRawValue() {
        let metric = NutritionUnit(rawValue: "Metric (grams)")
        let imperial = NutritionUnit(rawValue: "Imperial (ounces)")

        XCTAssertEqual(metric, .metric)
        XCTAssertEqual(imperial, .imperial)
    }

    // MARK: - Edge Cases

    /// Test very small values don't lose precision
    func testConvert_SmallValues() {
        // 1g = 0.035274oz
        let result = NutritionFormatter.convert(grams: 1, to: .imperial)
        XCTAssertEqual(result, 0.035274, accuracy: 0.000001,
                       "1 gram should convert to ~0.035274 ounces")
    }

    /// Test very large values work correctly
    func testConvert_LargeValues() {
        // 1000g = 35.274oz
        let result = NutritionFormatter.convert(grams: 1000, to: .imperial)
        XCTAssertEqual(result, 35.274, accuracy: 0.01,
                       "1000 grams should convert to ~35.27 ounces")
    }

    /// Test negative values (edge case - shouldn't happen but shouldn't crash)
    func testConvert_NegativeValues() {
        let result = NutritionFormatter.convert(grams: -50, to: .imperial)
        XCTAssertLessThan(result, 0,
                          "Negative grams should produce negative ounces")
    }
}
