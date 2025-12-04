//
//  FuzzyMatchingTests.swift
//  Food1Tests
//
//  Unit tests for FuzzyMatchingService - validates shortcuts and blacklist.
//  PROTECTED: Do not modify without explicit user approval.
//

import XCTest
@testable import Food1

final class FuzzyMatchingTests: XCTestCase {

    // MARK: - Shortcut Coverage Tests
    // These tests verify that common foods have shortcuts defined

    func testShortcuts_CommonProteins() async {
        let service = FuzzyMatchingService.shared

        // These should all return matches via shortcuts (fast path)
        let proteins = ["egg", "eggs", "chicken breast", "salmon", "tuna", "bacon", "ground beef"]

        for protein in proteins {
            let result = await service.match(protein)
            XCTAssertNotNil(result, "Missing shortcut for: \(protein)")
        }
    }

    func testShortcuts_CommonDairy() async {
        let service = FuzzyMatchingService.shared

        let dairy = ["milk", "butter", "cheddar cheese", "mozzarella cheese", "yogurt plain"]

        for item in dairy {
            let result = await service.match(item)
            XCTAssertNotNil(result, "Missing shortcut for: \(item)")
        }
    }

    func testShortcuts_CommonFruits() async {
        let service = FuzzyMatchingService.shared

        let fruits = ["banana", "strawberries", "blueberries", "orange", "avocado", "grapes"]

        for fruit in fruits {
            let result = await service.match(fruit)
            XCTAssertNotNil(result, "Missing shortcut for: \(fruit)")
        }
    }

    func testShortcuts_CommonVegetables() async {
        let service = FuzzyMatchingService.shared

        let vegetables = ["spinach", "broccoli", "tomato", "carrots", "onion", "garlic", "lettuce"]

        for veg in vegetables {
            let result = await service.match(veg)
            XCTAssertNotNil(result, "Missing shortcut for: \(veg)")
        }
    }

    func testShortcuts_CommonGrains() async {
        let service = FuzzyMatchingService.shared

        let grains = ["oats", "oatmeal", "rice white", "spaghetti", "bread white"]

        for grain in grains {
            let result = await service.match(grain)
            XCTAssertNotNil(result, "Missing shortcut for: \(grain)")
        }
    }

    // MARK: - Match Method Tests

    func testMatchWithMethod_Shortcut() async {
        let service = FuzzyMatchingService.shared

        // "egg" should match via shortcut
        let (food, method) = await service.matchWithMethod("egg")

        XCTAssertNotNil(food)
        XCTAssertEqual(method, .shortcut)
    }

    func testMatchWithMethod_Blacklisted() async {
        let service = FuzzyMatchingService.shared

        // "sugar" should be blacklisted (negligible micronutrients)
        let (food, method) = await service.matchWithMethod("sugar")

        XCTAssertNil(food)
        XCTAssertEqual(method, .blacklisted)
    }

    func testMatchWithMethod_BlacklistedItems() async {
        let service = FuzzyMatchingService.shared

        let blacklisted = ["sugar", "ice", "food coloring", "garnish", "powdered sugar"]

        for item in blacklisted {
            let (food, method) = await service.matchWithMethod(item)
            XCTAssertNil(food, "Should be nil for blacklisted: \(item)")
            XCTAssertEqual(method, .blacklisted, "Should be blacklisted: \(item)")
        }
    }

    // MARK: - Name Cleaning Tests (via observable behavior)

    func testNameCleaning_RemovesCookingMethods() async {
        let service = FuzzyMatchingService.shared

        // "chicken breast grilled" should clean to "chicken breast" and match shortcut
        let (food, method) = await service.matchWithMethod("chicken breast grilled")

        XCTAssertNotNil(food)
        // Should still match via shortcut after cleaning
        XCTAssertEqual(method, .shortcut)
    }

    func testNameCleaning_RemovesAdjectives() async {
        let service = FuzzyMatchingService.shared

        // "fresh spinach" should clean to "spinach" and match shortcut
        let (food, method) = await service.matchWithMethod("fresh spinach")

        XCTAssertNotNil(food)
        XCTAssertEqual(method, .shortcut)
    }

    func testNameCleaning_PreservesWordBoundaries() async {
        let service = FuzzyMatchingService.shared

        // "strawberries" should NOT become "stberries" (word boundary bug)
        // This was a real bug found in evaluation
        let (food, _) = await service.matchWithMethod("strawberries")

        XCTAssertNotNil(food)
        XCTAssertTrue(food?.description.lowercased().contains("strawberr") ?? false)
    }

    func testNameCleaning_HandlesRawKeyword() async {
        let service = FuzzyMatchingService.shared

        // "strawberries, raw" should match (not break due to "raw" in "strawberries")
        let (food, _) = await service.matchWithMethod("strawberries, raw")

        XCTAssertNotNil(food)
    }

    // MARK: - Edge Cases

    func testMatch_EmptyString() async {
        let service = FuzzyMatchingService.shared

        let result = await service.match("")
        XCTAssertNil(result)
    }

    func testMatch_WhitespaceOnly() async {
        let service = FuzzyMatchingService.shared

        let result = await service.match("   ")
        XCTAssertNil(result)
    }

    func testMatch_CaseInsensitive() async {
        let service = FuzzyMatchingService.shared

        // Should match regardless of case
        let result1 = await service.match("EGG")
        let result2 = await service.match("egg")
        let result3 = await service.match("Egg")

        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertNotNil(result3)
    }

    // MARK: - Shortcut Consistency Tests

    func testShortcuts_PluralAndSingular() async {
        let service = FuzzyMatchingService.shared

        // Both singular and plural should work
        let egg = await service.match("egg")
        let eggs = await service.match("eggs")

        XCTAssertNotNil(egg)
        XCTAssertNotNil(eggs)
        // They should match the same USDA food
        XCTAssertEqual(egg?.fdcId, eggs?.fdcId)
    }

    func testShortcuts_AlternateOrderings() async {
        let service = FuzzyMatchingService.shared

        // "cheddar cheese" and "cheese cheddar" should both work
        let cheddarCheese = await service.match("cheddar cheese")
        let cheeseCheddar = await service.match("cheese cheddar")

        XCTAssertNotNil(cheddarCheese)
        XCTAssertNotNil(cheeseCheddar)
        XCTAssertEqual(cheddarCheese?.fdcId, cheeseCheddar?.fdcId)
    }
}
