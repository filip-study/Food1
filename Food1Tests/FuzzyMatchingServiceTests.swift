//
//  FuzzyMatchingServiceTests.swift
//  Food1Tests
//
//  Tests for FuzzyMatchingService core functionality
//

import XCTest
@testable import Food1

/// Tests for FuzzyMatchingService - verifies critical matching logic
///
/// TEST POLICY: These tests define expected behavior and MUST NOT be modified without explicit user approval.
/// If tests fail after code changes, fix the CODE, not the tests.
///
/// Coverage:
/// 1. Name cleaning with word boundary regex (prevents "stRAWberries" → "stberries" bug)
/// 2. Blacklist filtering (skips ingredients with negligible micronutrients)
final class FuzzyMatchingServiceTests: XCTestCase {

    var service: FuzzyMatchingService!

    override func setUp() {
        super.setUp()
        service = FuzzyMatchingService.shared
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Name Cleaning Tests

    /// Test that word boundary regex correctly handles "raw" inside "strawberries"
    /// Bug case: "Strawberries, raw" should clean to "strawberries", NOT "stberries"
    /// Reference: FuzzyMatchingService.swift:357 comment about the stRAWberries bug
    func testNameCleaning_StrawberriesRaw_DoesNotCorruptWord() async {
        // Given: Ingredient name with "raw" both as adjective AND inside word
        let ingredientName = "Strawberries, raw"

        // When: Match the ingredient (which internally cleans the name)
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should successfully match strawberries (not fail due to corrupted "stberries")
        // We verify this by checking we got SOME match, meaning the name wasn't corrupted
        XCTAssertNotNil(food, "Should find a match for 'Strawberries, raw' - cleaning should not corrupt the word")

        // Additional verification: The match should be for strawberries (fdcId 167762)
        // This confirms the name cleaning worked correctly
        if let matchedFood = food {
            XCTAssertTrue(
                matchedFood.description.lowercased().contains("strawberr"),
                "Matched food should be strawberries, but got: \(matchedFood.description)"
            )
        }
    }

    /// Test that cooking methods are removed from ingredient names
    func testNameCleaning_CookingMethods_AreRemoved() async {
        // Given: Ingredient with cooking method
        let ingredientName = "Chicken, grilled"

        // When: Match the ingredient
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should find chicken (the word "grilled" should be stripped during cleaning)
        // Expected shortcut match for "chicken breast" (fdcId 171477)
        XCTAssertNotNil(food, "Should find a match for 'Chicken, grilled' after removing cooking method")

        if let matchedFood = food {
            XCTAssertTrue(
                matchedFood.description.lowercased().contains("chicken"),
                "Matched food should contain 'chicken', but got: \(matchedFood.description)"
            )
        }
    }

    /// Test that adjectives are removed from ingredient names
    func testNameCleaning_Adjectives_AreRemoved() async {
        // Given: Ingredient with multiple adjectives
        let ingredientName = "Fresh, organic spinach"

        // When: Match the ingredient
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should find spinach (adjectives stripped)
        // Expected shortcut match for "spinach" (fdcId 168462)
        XCTAssertNotNil(food, "Should find a match for 'Fresh, organic spinach' after removing adjectives")
        XCTAssertEqual(method, .shortcut, "Should match via shortcut for 'spinach'")

        if let matchedFood = food {
            XCTAssertEqual(matchedFood.fdcId, 168462, "Should match raw spinach (fdcId 168462)")
        }
    }

    /// Test that size descriptors are removed from ingredient names
    func testNameCleaning_SizeDescriptors_AreRemoved() async {
        // Given: Ingredient with size descriptor
        let ingredientName = "Medium eggs"

        // When: Match the ingredient
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should find eggs (size descriptor stripped)
        // Expected shortcut match for "eggs" (fdcId 171287)
        XCTAssertNotNil(food, "Should find a match for 'Medium eggs' after removing size descriptor")
        XCTAssertEqual(method, .shortcut, "Should match via shortcut for 'eggs'")

        if let matchedFood = food {
            XCTAssertEqual(matchedFood.fdcId, 171287, "Should match whole raw eggs (fdcId 171287)")
        }
    }

    // MARK: - Blacklist Tests

    /// Test that "sugar" is blacklisted (returns nil with .blacklisted method)
    /// Blacklist purpose: Skip ingredients with negligible micronutrients to save LLM inference time
    func testBlacklist_Sugar_IsBlacklisted() async {
        // Given: Pure sugar (no meaningful micronutrients)
        let ingredientName = "sugar"

        // When: Match the ingredient
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should return nil with blacklisted method
        XCTAssertNil(food, "Sugar should not be matched (blacklisted)")
        XCTAssertEqual(method, .blacklisted, "Sugar should return .blacklisted method")
    }

    /// Test that "ice" is blacklisted
    func testBlacklist_Ice_IsBlacklisted() async {
        // Given: Ice (no nutritional value)
        let ingredientName = "ice"

        // When: Match the ingredient
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should return nil with blacklisted method
        XCTAssertNil(food, "Ice should not be matched (blacklisted)")
        XCTAssertEqual(method, .blacklisted, "Ice should return .blacklisted method")
    }

    /// Test that "powdered sugar" is blacklisted
    func testBlacklist_PowderedSugar_IsBlacklisted() async {
        // Given: Powdered sugar (specific sugar type in blacklist)
        let ingredientName = "powdered sugar"

        // When: Match the ingredient
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should return nil with blacklisted method
        XCTAssertNil(food, "Powdered sugar should not be matched (blacklisted)")
        XCTAssertEqual(method, .blacklisted, "Powdered sugar should return .blacklisted method")
    }

    /// Test that normal foods are NOT blacklisted
    func testBlacklist_ChickenBreast_IsNotBlacklisted() async {
        // Given: Normal food with micronutrients (should not be blacklisted)
        let ingredientName = "chicken breast"

        // When: Match the ingredient
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should successfully match (not blacklisted)
        XCTAssertNotNil(food, "Chicken breast should be matched (not blacklisted)")
        XCTAssertNotEqual(method, .blacklisted, "Chicken breast should not return .blacklisted method")

        // Additional verification: Should match via shortcut
        XCTAssertEqual(method, .shortcut, "Should match chicken breast via shortcut")
        if let matchedFood = food {
            XCTAssertEqual(matchedFood.fdcId, 171477, "Should match cooked chicken breast (fdcId 171477)")
        }
    }

    // MARK: - Integration Tests

    /// Test complete matching flow with a common food
    func testMatchingFlow_CommonFood_UsesShortcut() async {
        // Given: Common food that's in shortcuts dictionary
        let ingredientName = "banana"

        // When: Match the ingredient
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should match via shortcut (fastest path)
        XCTAssertNotNil(food, "Should find a match for 'banana'")
        XCTAssertEqual(method, .shortcut, "Common food should use shortcut path (not LLM)")

        if let matchedFood = food {
            XCTAssertEqual(matchedFood.fdcId, 173944, "Should match raw banana (fdcId 173944)")
            XCTAssertTrue(
                matchedFood.description.lowercased().contains("banana"),
                "Matched food description should contain 'banana'"
            )
        }
    }

    /// Test that empty/whitespace-only names return nil
    func testMatchingFlow_EmptyName_ReturnsNil() async {
        // Given: Empty ingredient name
        let ingredientName = "   "

        // When: Match the ingredient
        let (food, method) = await service.matchWithMethod(ingredientName)

        // Then: Should return nil
        XCTAssertNil(food, "Empty/whitespace ingredient name should return nil")
        XCTAssertNil(method, "Empty/whitespace ingredient name should return nil method")
    }
}
