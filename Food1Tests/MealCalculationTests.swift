//
//  MealCalculationTests.swift
//  Food1Tests
//
//  Tests for meal calculation logic: serving size scaling, totals calculation, and DailyGoals.
//

import XCTest
@testable import Food1

/// Tests for meal calculation logic - verifies ingredient scaling, totals, and goals
///
/// TEST POLICY: These tests define expected behavior and MUST NOT be modified without explicit user approval.
/// If tests fail after code changes, fix the CODE, not the tests.
///
/// Coverage:
/// 1. IngredientRowData.updateGrams() proportional scaling
/// 2. IngredientRowData.applyPortionMultiplier() for serving adjustments
/// 3. Meal.calculateTotals() for summing multiple meals
/// 4. DailyGoals.calculate() with fiber (IOM recommendations)
/// 5. DailyGoals.standard fallback values
final class MealCalculationTests: XCTestCase {

    // MARK: - IngredientRowData Scaling Tests

    /// Test that updateGrams scales all macros proportionally
    func testIngredientRowData_UpdateGrams_ScalesProportionally() {
        // Given: An ingredient with 100g and known macros
        var ingredient = IngredientRowData(
            name: "Chicken breast",
            grams: 100,
            calories: 165,
            protein: 31,
            carbs: 0,
            fat: 3.6
        )

        // When: Double the grams
        ingredient.updateGrams(200)

        // Then: All macros should double
        XCTAssertEqual(ingredient.grams, 200, "Grams should be updated to 200")
        XCTAssertEqual(ingredient.calories, 330, accuracy: 0.1, "Calories should double")
        XCTAssertEqual(ingredient.protein, 62, accuracy: 0.1, "Protein should double")
        XCTAssertEqual(ingredient.carbs, 0, accuracy: 0.1, "Carbs should double")
        XCTAssertEqual(ingredient.fat, 7.2, accuracy: 0.1, "Fat should double")
    }

    /// Test that updateGrams scales correctly for half portion
    func testIngredientRowData_UpdateGrams_HalfPortion() {
        // Given: An ingredient with 100g
        var ingredient = IngredientRowData(
            name: "Brown rice",
            grams: 100,
            calories: 111,
            protein: 2.6,
            carbs: 23,
            fat: 0.9
        )

        // When: Halve the grams
        ingredient.updateGrams(50)

        // Then: All macros should halve
        XCTAssertEqual(ingredient.grams, 50)
        XCTAssertEqual(ingredient.calories, 55.5, accuracy: 0.1)
        XCTAssertEqual(ingredient.protein, 1.3, accuracy: 0.1)
        XCTAssertEqual(ingredient.carbs, 11.5, accuracy: 0.1)
        XCTAssertEqual(ingredient.fat, 0.45, accuracy: 0.01)
    }

    /// Test that updateGrams scales from original values (not current values)
    /// This prevents cumulative rounding errors when user makes multiple adjustments
    func testIngredientRowData_UpdateGrams_ScalesFromOriginal() {
        // Given: An ingredient with 100g
        var ingredient = IngredientRowData(
            name: "Eggs",
            grams: 100,
            calories: 155,
            protein: 13,
            carbs: 1.1,
            fat: 11
        )

        // When: Scale up, then scale down to original
        ingredient.updateGrams(200)  // Double
        ingredient.updateGrams(100)  // Back to original

        // Then: Values should be exactly the original (not affected by rounding)
        XCTAssertEqual(ingredient.grams, 100, "Should return to original grams")
        XCTAssertEqual(ingredient.calories, 155, accuracy: 0.01, "Should return to original calories")
        XCTAssertEqual(ingredient.protein, 13, accuracy: 0.01, "Should return to original protein")
    }

    /// Test updateGrams with zero original grams (edge case)
    func testIngredientRowData_UpdateGrams_ZeroOriginalGrams() {
        // Given: An ingredient with 0 grams (edge case)
        var ingredient = IngredientRowData(
            name: "Seasoning",
            grams: 0,
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0
        )

        // When: Try to update grams
        ingredient.updateGrams(50)

        // Then: Grams should update but macros should stay 0 (no division by zero crash)
        XCTAssertEqual(ingredient.grams, 50)
        XCTAssertEqual(ingredient.calories, 0)
        XCTAssertEqual(ingredient.protein, 0)
    }

    // MARK: - Portion Multiplier Tests

    /// Test applyPortionMultiplier with 2x (double serving)
    func testIngredientRowData_ApplyPortionMultiplier_Double() {
        // Given: An ingredient with 150g
        var ingredient = IngredientRowData(
            name: "Salmon",
            grams: 150,
            calories: 280,
            protein: 39,
            carbs: 0,
            fat: 13
        )

        // When: Apply 2x multiplier
        ingredient.applyPortionMultiplier(2.0)

        // Then: All values should double
        XCTAssertEqual(ingredient.grams, 300, accuracy: 0.1)
        XCTAssertEqual(ingredient.calories, 560, accuracy: 0.1)
        XCTAssertEqual(ingredient.protein, 78, accuracy: 0.1)
        XCTAssertEqual(ingredient.fat, 26, accuracy: 0.1)
    }

    /// Test applyPortionMultiplier with 0.5x (half serving)
    func testIngredientRowData_ApplyPortionMultiplier_Half() {
        // Given: An ingredient with 200g
        var ingredient = IngredientRowData(
            name: "Pasta",
            grams: 200,
            calories: 262,
            protein: 9.4,
            carbs: 51,
            fat: 1.3
        )

        // When: Apply 0.5x multiplier
        ingredient.applyPortionMultiplier(0.5)

        // Then: All values should halve
        XCTAssertEqual(ingredient.grams, 100, accuracy: 0.1)
        XCTAssertEqual(ingredient.calories, 131, accuracy: 0.1)
        XCTAssertEqual(ingredient.protein, 4.7, accuracy: 0.1)
        XCTAssertEqual(ingredient.carbs, 25.5, accuracy: 0.1)
    }

    /// Test applyPortionMultiplier with 0.75x (three-quarter serving)
    func testIngredientRowData_ApplyPortionMultiplier_ThreeQuarters() {
        // Given: An ingredient with 100g
        var ingredient = IngredientRowData(
            name: "Beef",
            grams: 100,
            calories: 250,
            protein: 26,
            carbs: 0,
            fat: 15
        )

        // When: Apply 0.75x multiplier
        ingredient.applyPortionMultiplier(0.75)

        // Then: All values should be 75%
        XCTAssertEqual(ingredient.grams, 75, accuracy: 0.1)
        XCTAssertEqual(ingredient.calories, 187.5, accuracy: 0.1)
        XCTAssertEqual(ingredient.protein, 19.5, accuracy: 0.1)
        XCTAssertEqual(ingredient.fat, 11.25, accuracy: 0.1)
    }

    /// Test applyPortionMultiplier scales from original (not cumulative)
    func testIngredientRowData_ApplyPortionMultiplier_NotCumulative() {
        // Given: An ingredient with 100g
        var ingredient = IngredientRowData(
            name: "Avocado",
            grams: 100,
            calories: 160,
            protein: 2,
            carbs: 9,
            fat: 15
        )

        // When: Apply multiple multipliers in sequence
        ingredient.applyPortionMultiplier(2.0)   // 200g, 320cal
        ingredient.applyPortionMultiplier(0.5)   // Should be 50g, 80cal (from original, not from 200g)

        // Then: Result should be 0.5x original, not 0.5x of 2x
        XCTAssertEqual(ingredient.grams, 50, "Should be 50% of original 100g")
        XCTAssertEqual(ingredient.calories, 80, accuracy: 0.1, "Should be 50% of original 160cal")
    }

    // MARK: - IngredientRowData Equatable Tests

    /// Test that two identical ingredients are equal
    func testIngredientRowData_Equatable_IdenticalIngredientsAreEqual() {
        let id = UUID()
        let a = IngredientRowData(id: id, name: "Apple", grams: 100, calories: 52, protein: 0.3, carbs: 14, fat: 0.2)
        let b = IngredientRowData(id: id, name: "Apple", grams: 100, calories: 52, protein: 0.3, carbs: 14, fat: 0.2)

        XCTAssertEqual(a, b, "Identical ingredients should be equal")
    }

    /// Test that ingredients with different grams are not equal
    func testIngredientRowData_Equatable_DifferentGramsNotEqual() {
        let id = UUID()
        let a = IngredientRowData(id: id, name: "Apple", grams: 100, calories: 52, protein: 0.3, carbs: 14, fat: 0.2)
        let b = IngredientRowData(id: id, name: "Apple", grams: 150, calories: 78, protein: 0.45, carbs: 21, fat: 0.3)

        XCTAssertNotEqual(a, b, "Ingredients with different grams should not be equal")
    }

    // MARK: - Meal.calculateTotals Tests

    /// Test calculateTotals with empty array
    func testCalculateTotals_EmptyArray() {
        let meals: [Meal] = []
        let totals = Meal.calculateTotals(for: meals)

        XCTAssertEqual(totals.calories, 0)
        XCTAssertEqual(totals.protein, 0)
        XCTAssertEqual(totals.carbs, 0)
        XCTAssertEqual(totals.fat, 0)
    }

    /// Test calculateTotals with single meal
    func testCalculateTotals_SingleMeal() {
        let meal = Meal(
            name: "Lunch",
            emoji: "🥗",
            timestamp: Date(),
            calories: 500,
            protein: 35,
            carbs: 45,
            fat: 20
        )

        let totals = Meal.calculateTotals(for: [meal])

        XCTAssertEqual(totals.calories, 500)
        XCTAssertEqual(totals.protein, 35)
        XCTAssertEqual(totals.carbs, 45)
        XCTAssertEqual(totals.fat, 20)
    }

    /// Test calculateTotals with multiple meals
    func testCalculateTotals_MultipleMeals() {
        let breakfast = Meal(
            name: "Breakfast",
            emoji: "🍳",
            timestamp: Date(),
            calories: 400,
            protein: 25,
            carbs: 30,
            fat: 20
        )

        let lunch = Meal(
            name: "Lunch",
            emoji: "🥗",
            timestamp: Date(),
            calories: 600,
            protein: 40,
            carbs: 50,
            fat: 25
        )

        let dinner = Meal(
            name: "Dinner",
            emoji: "🍝",
            timestamp: Date(),
            calories: 700,
            protein: 45,
            carbs: 60,
            fat: 30
        )

        let totals = Meal.calculateTotals(for: [breakfast, lunch, dinner])

        XCTAssertEqual(totals.calories, 1700, "Total calories: 400 + 600 + 700")
        XCTAssertEqual(totals.protein, 110, "Total protein: 25 + 40 + 45")
        XCTAssertEqual(totals.carbs, 140, "Total carbs: 30 + 50 + 60")
        XCTAssertEqual(totals.fat, 75, "Total fat: 20 + 25 + 30")
    }

    /// Test calculateTotals handles decimal values correctly
    func testCalculateTotals_DecimalValues() {
        let meal1 = Meal(
            name: "Snack 1",
            emoji: "🍎",
            timestamp: Date(),
            calories: 52.3,
            protein: 0.3,
            carbs: 13.8,
            fat: 0.2
        )

        let meal2 = Meal(
            name: "Snack 2",
            emoji: "🥜",
            timestamp: Date(),
            calories: 161.7,
            protein: 7.0,
            carbs: 4.8,
            fat: 14.0
        )

        let totals = Meal.calculateTotals(for: [meal1, meal2])

        XCTAssertEqual(totals.calories, 214.0, accuracy: 0.1)
        XCTAssertEqual(totals.protein, 7.3, accuracy: 0.1)
        XCTAssertEqual(totals.carbs, 18.6, accuracy: 0.1)
        XCTAssertEqual(totals.fat, 14.2, accuracy: 0.1)
    }

    // MARK: - DailyGoals Standard Tests

    /// Test that DailyGoals.standard has reasonable default values
    func testDailyGoals_Standard_HasDefaults() {
        let standard = DailyGoals.standard

        XCTAssertEqual(standard.calories, 2000, "Standard calories should be 2000")
        XCTAssertEqual(standard.protein, 150, "Standard protein should be 150g")
        XCTAssertEqual(standard.carbs, 225, "Standard carbs should be 225g")
        XCTAssertEqual(standard.fat, 65, "Standard fat should be 65g")
        XCTAssertEqual(standard.fiber, 28, "Standard fiber should be 28g (IOM AI)")
    }

    // MARK: - DailyGoals Calculation Tests

    /// Test DailyGoals.calculate for typical male user
    func testDailyGoals_Calculate_Male() {
        let goals = DailyGoals.calculate(
            gender: .male,
            age: 30,
            weightKg: 80,
            heightCm: 180,
            activityLevel: .moderatelyActive
        )

        // BMR (Mifflin-St Jeor, male): (10 × 80) + (6.25 × 180) - (5 × 30) + 5 = 1780
        // TDEE: 1780 × 1.55 = 2759
        XCTAssertEqual(goals.calories, 2759, accuracy: 10, "TDEE should be ~2759")

        // Macros: 30% protein, 35% carbs, 35% fat
        // Protein: 2759 × 0.30 / 4 = 207g
        XCTAssertEqual(goals.protein, 207, accuracy: 5, "Protein should be ~207g")

        // Carbs: 2759 × 0.35 / 4 = 241g
        XCTAssertEqual(goals.carbs, 241, accuracy: 5, "Carbs should be ~241g")

        // Fat: 2759 × 0.35 / 9 = 107g
        XCTAssertEqual(goals.fat, 107, accuracy: 5, "Fat should be ~107g")

        // Fiber for male under 51: 38g
        XCTAssertEqual(goals.fiber, 38, "Male under 51 should have 38g fiber goal")
    }

    /// Test DailyGoals.calculate for typical female user
    func testDailyGoals_Calculate_Female() {
        let goals = DailyGoals.calculate(
            gender: .female,
            age: 28,
            weightKg: 60,
            heightCm: 165,
            activityLevel: .lightlyActive
        )

        // BMR (Mifflin-St Jeor, female): (10 × 60) + (6.25 × 165) - (5 × 28) - 161 = 1329.25
        // TDEE: 1329.25 × 1.375 = 1828
        XCTAssertEqual(goals.calories, 1828, accuracy: 10, "TDEE should be ~1828")

        // Fiber for female under 51: 25g
        XCTAssertEqual(goals.fiber, 25, "Female under 51 should have 25g fiber goal")
    }

    /// Test DailyGoals.calculate for older male (51+)
    func testDailyGoals_Calculate_OlderMale_FiberReduction() {
        let goals = DailyGoals.calculate(
            gender: .male,
            age: 55,
            weightKg: 85,
            heightCm: 175,
            activityLevel: .sedentary
        )

        // Fiber for male 51+: 30g (reduced from 38g)
        XCTAssertEqual(goals.fiber, 30, "Male 51+ should have 30g fiber goal")
    }

    /// Test DailyGoals.calculate for older female (51+)
    func testDailyGoals_Calculate_OlderFemale_FiberReduction() {
        let goals = DailyGoals.calculate(
            gender: .female,
            age: 60,
            weightKg: 65,
            heightCm: 160,
            activityLevel: .sedentary
        )

        // Fiber for female 51+: 21g (reduced from 25g)
        XCTAssertEqual(goals.fiber, 21, "Female 51+ should have 21g fiber goal")
    }

    /// Test DailyGoals.calculate for non-binary user (average of male/female)
    func testDailyGoals_Calculate_Other_UsesAverage() {
        let goalsOther = DailyGoals.calculate(
            gender: .other,
            age: 30,
            weightKg: 70,
            heightCm: 170,
            activityLevel: .moderatelyActive
        )

        let goalsMale = DailyGoals.calculate(
            gender: .male,
            age: 30,
            weightKg: 70,
            heightCm: 170,
            activityLevel: .moderatelyActive
        )

        let goalsFemale = DailyGoals.calculate(
            gender: .female,
            age: 30,
            weightKg: 70,
            heightCm: 170,
            activityLevel: .moderatelyActive
        )

        let expectedCalories = (goalsMale.calories + goalsFemale.calories) / 2
        XCTAssertEqual(goalsOther.calories, expectedCalories, accuracy: 5,
                       "Other gender should use average of male/female calories")

        // Fiber for other under 51: 31.5g (average of 38 and 25)
        XCTAssertEqual(goalsOther.fiber, 31.5, "Other gender under 51 should have 31.5g fiber")
    }

    /// Test DailyGoals.calculate falls back to standard for invalid input
    func testDailyGoals_Calculate_InvalidInput_FallsBackToStandard() {
        // Zero weight
        let zeroWeight = DailyGoals.calculate(
            gender: .male,
            age: 30,
            weightKg: 0,
            heightCm: 180,
            activityLevel: .moderatelyActive
        )
        XCTAssertEqual(zeroWeight.calories, DailyGoals.standard.calories,
                       "Zero weight should fall back to standard")

        // Zero height
        let zeroHeight = DailyGoals.calculate(
            gender: .male,
            age: 30,
            weightKg: 80,
            heightCm: 0,
            activityLevel: .moderatelyActive
        )
        XCTAssertEqual(zeroHeight.calories, DailyGoals.standard.calories,
                       "Zero height should fall back to standard")

        // Zero age
        let zeroAge = DailyGoals.calculate(
            gender: .male,
            age: 0,
            weightKg: 80,
            heightCm: 180,
            activityLevel: .moderatelyActive
        )
        XCTAssertEqual(zeroAge.calories, DailyGoals.standard.calories,
                       "Zero age should fall back to standard")
    }

    // MARK: - Activity Level Multiplier Tests

    /// Test that different activity levels produce expected TDEE differences
    func testDailyGoals_ActivityLevels_ProduceDifferentTDEE() {
        let sedentary = DailyGoals.calculate(
            gender: .male, age: 30, weightKg: 80, heightCm: 180, activityLevel: .sedentary
        )

        let lightlyActive = DailyGoals.calculate(
            gender: .male, age: 30, weightKg: 80, heightCm: 180, activityLevel: .lightlyActive
        )

        let moderatelyActive = DailyGoals.calculate(
            gender: .male, age: 30, weightKg: 80, heightCm: 180, activityLevel: .moderatelyActive
        )

        let veryActive = DailyGoals.calculate(
            gender: .male, age: 30, weightKg: 80, heightCm: 180, activityLevel: .veryActive
        )

        let extremelyActive = DailyGoals.calculate(
            gender: .male, age: 30, weightKg: 80, heightCm: 180, activityLevel: .extremelyActive
        )

        // Each level should produce progressively higher TDEE
        XCTAssertLessThan(sedentary.calories, lightlyActive.calories)
        XCTAssertLessThan(lightlyActive.calories, moderatelyActive.calories)
        XCTAssertLessThan(moderatelyActive.calories, veryActive.calories)
        XCTAssertLessThan(veryActive.calories, extremelyActive.calories)

        // Verify approximate multiplier effects
        // Sedentary: 1.2, Extremely Active: 1.9
        // Ratio should be approximately 1.9/1.2 = 1.583
        let ratio = extremelyActive.calories / sedentary.calories
        XCTAssertEqual(ratio, 1.583, accuracy: 0.01,
                       "Extremely Active should be ~1.58x Sedentary")
    }

    // MARK: - Macro Split Tests

    /// Test that macro split adds up to total calories (within rounding)
    func testDailyGoals_MacroSplit_AddsUpToTDEE() {
        let goals = DailyGoals.calculate(
            gender: .male,
            age: 30,
            weightKg: 80,
            heightCm: 180,
            activityLevel: .moderatelyActive
        )

        // Calculate calories from macros: protein×4 + carbs×4 + fat×9
        let caloriesFromMacros = (goals.protein * 4) + (goals.carbs * 4) + (goals.fat * 9)

        XCTAssertEqual(caloriesFromMacros, goals.calories, accuracy: 10,
                       "Calories from macros should match TDEE")
    }

    /// Test that macro percentages are approximately 30/35/35
    func testDailyGoals_MacroSplit_Percentages() {
        let goals = DailyGoals.calculate(
            gender: .male,
            age: 30,
            weightKg: 80,
            heightCm: 180,
            activityLevel: .moderatelyActive
        )

        let proteinCalPct = (goals.protein * 4) / goals.calories * 100
        let carbsCalPct = (goals.carbs * 4) / goals.calories * 100
        let fatCalPct = (goals.fat * 9) / goals.calories * 100

        XCTAssertEqual(proteinCalPct, 30, accuracy: 2, "Protein should be ~30% of calories")
        XCTAssertEqual(carbsCalPct, 35, accuracy: 2, "Carbs should be ~35% of calories")
        XCTAssertEqual(fatCalPct, 35, accuracy: 2, "Fat should be ~35% of calories")
    }
}
