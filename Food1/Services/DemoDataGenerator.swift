//
//  DemoDataGenerator.swift
//  Food1
//
//  DEBUG-ONLY sample data generator for demo mode.
//  Creates realistic meal data with full micronutrient tracking
//  to showcase the Stats view and other features.
//
//  SECURITY:
//  - Entire file wrapped in #if DEBUG - excluded from release builds
//  - All data is in-memory only, no persistence to user's real data
//

#if DEBUG

import Foundation
import SwiftData

/// Generates realistic sample meal data for demo mode
enum DemoDataGenerator {

    /// Populate the context with 14 days of varied meal data
    static func populateSampleData(in context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        // Generate 14 days of meals (2 weeks)
        for dayOffset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

            // Varied meals per day (2-4 meals)
            let mealsForDay = getMealsForDay(dayIndex: dayOffset)

            for (mealTemplate, hour, minute) in mealsForDay {
                guard let timestamp = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else { continue }

                let meal = createMeal(from: mealTemplate, timestamp: timestamp)
                context.insert(meal)
            }
        }

        try? context.save()
        print("[DemoData] Generated \(14 * 3) sample meals over 14 days")
    }

    // MARK: - Meal Templates

    private struct MealTemplate {
        let name: String
        let emoji: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double
        let mealType: String
        let ingredients: [IngredientTemplate]
    }

    private struct IngredientTemplate {
        let name: String
        let grams: Double
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let micronutrients: [Micronutrient]
    }

    // MARK: - Day Meal Patterns

    private static func getMealsForDay(dayIndex: Int) -> [(MealTemplate, Int, Int)] {
        // Rotate through different meal patterns for variety
        let patterns: [[(MealTemplate, Int, Int)]] = [
            // Day pattern 1: Full day
            [(breakfastOatmeal, 8, 0), (lunchSalad, 12, 30), (dinnerSalmon, 19, 0)],
            // Day pattern 2: Late start
            [(breakfastEggs, 10, 0), (lunchBowl, 14, 0), (dinnerChicken, 20, 0)],
            // Day pattern 3: Early bird
            [(breakfastSmoothie, 7, 0), (lunchWrap, 12, 0), (dinnerStirFry, 18, 30)],
            // Day pattern 4: Weekend brunch
            [(brunchAvocadoToast, 11, 0), (snackYogurt, 15, 0), (dinnerPasta, 19, 30)],
            // Day pattern 5: Busy day
            [(breakfastProteinBar, 8, 30), (lunchSandwich, 13, 0), (dinnerSalmon, 19, 0)],
            // Day pattern 6: Healthy day
            [(breakfastSmoothie, 7, 30), (lunchSalad, 12, 0), (dinnerStirFry, 18, 0)],
            // Day pattern 7: Comfort food
            [(breakfastOatmeal, 9, 0), (lunchSoup, 13, 0), (dinnerPasta, 20, 0)]
        ]

        return patterns[dayIndex % patterns.count]
    }

    // MARK: - Sample Meals

    private static let breakfastOatmeal = MealTemplate(
        name: "Oatmeal with Berries & Almonds",
        emoji: "🥣",
        calories: 380,
        protein: 14,
        carbs: 52,
        fat: 14,
        fiber: 8,
        mealType: "breakfast",
        ingredients: [
            IngredientTemplate(
                name: "Rolled Oats",
                grams: 80,
                calories: 300,
                protein: 10,
                carbs: 54,
                fat: 6,
                micronutrients: oatsMicronutrients
            ),
            IngredientTemplate(
                name: "Blueberries",
                grams: 75,
                calories: 43,
                protein: 0.5,
                carbs: 11,
                fat: 0.2,
                micronutrients: blueberriesMicronutrients
            ),
            IngredientTemplate(
                name: "Almonds",
                grams: 20,
                calories: 116,
                protein: 4,
                carbs: 4,
                fat: 10,
                micronutrients: almondsMicronutrients
            )
        ]
    )

    private static let breakfastEggs = MealTemplate(
        name: "Scrambled Eggs with Toast",
        emoji: "🍳",
        calories: 420,
        protein: 24,
        carbs: 30,
        fat: 22,
        fiber: 3,
        mealType: "breakfast",
        ingredients: [
            IngredientTemplate(
                name: "Eggs",
                grams: 120,
                calories: 180,
                protein: 15,
                carbs: 1,
                fat: 12,
                micronutrients: eggsMicronutrients
            ),
            IngredientTemplate(
                name: "Whole Wheat Toast",
                grams: 60,
                calories: 160,
                protein: 6,
                carbs: 28,
                fat: 2,
                micronutrients: wheatToastMicronutrients
            ),
            IngredientTemplate(
                name: "Butter",
                grams: 10,
                calories: 72,
                protein: 0,
                carbs: 0,
                fat: 8,
                micronutrients: butterMicronutrients
            )
        ]
    )

    private static let breakfastSmoothie = MealTemplate(
        name: "Green Protein Smoothie",
        emoji: "🥤",
        calories: 340,
        protein: 28,
        carbs: 38,
        fat: 10,
        fiber: 6,
        mealType: "breakfast",
        ingredients: [
            IngredientTemplate(
                name: "Banana",
                grams: 120,
                calories: 105,
                protein: 1.3,
                carbs: 27,
                fat: 0.4,
                micronutrients: bananaMicronutrients
            ),
            IngredientTemplate(
                name: "Spinach",
                grams: 60,
                calories: 14,
                protein: 1.7,
                carbs: 2,
                fat: 0.2,
                micronutrients: spinachMicronutrients
            ),
            IngredientTemplate(
                name: "Protein Powder",
                grams: 30,
                calories: 120,
                protein: 24,
                carbs: 3,
                fat: 1,
                micronutrients: proteinPowderMicronutrients
            ),
            IngredientTemplate(
                name: "Almond Milk",
                grams: 240,
                calories: 40,
                protein: 1,
                carbs: 2,
                fat: 3,
                micronutrients: almondMilkMicronutrients
            )
        ]
    )

    private static let breakfastProteinBar = MealTemplate(
        name: "Protein Bar & Coffee",
        emoji: "🍫",
        calories: 280,
        protein: 20,
        carbs: 28,
        fat: 10,
        fiber: 4,
        mealType: "breakfast",
        ingredients: [
            IngredientTemplate(
                name: "Protein Bar",
                grams: 60,
                calories: 220,
                protein: 20,
                carbs: 24,
                fat: 8,
                micronutrients: proteinBarMicronutrients
            )
        ]
    )

    private static let brunchAvocadoToast = MealTemplate(
        name: "Avocado Toast with Poached Egg",
        emoji: "🥑",
        calories: 450,
        protein: 18,
        carbs: 35,
        fat: 28,
        fiber: 10,
        mealType: "breakfast",
        ingredients: [
            IngredientTemplate(
                name: "Avocado",
                grams: 100,
                calories: 160,
                protein: 2,
                carbs: 9,
                fat: 15,
                micronutrients: avocadoMicronutrients
            ),
            IngredientTemplate(
                name: "Sourdough Bread",
                grams: 80,
                calories: 200,
                protein: 8,
                carbs: 38,
                fat: 1,
                micronutrients: sourdoughMicronutrients
            ),
            IngredientTemplate(
                name: "Poached Egg",
                grams: 50,
                calories: 72,
                protein: 6,
                carbs: 0.4,
                fat: 5,
                micronutrients: eggsMicronutrients
            )
        ]
    )

    private static let lunchSalad = MealTemplate(
        name: "Grilled Chicken Caesar Salad",
        emoji: "🥗",
        calories: 520,
        protein: 42,
        carbs: 18,
        fat: 32,
        fiber: 6,
        mealType: "lunch",
        ingredients: [
            IngredientTemplate(
                name: "Grilled Chicken Breast",
                grams: 150,
                calories: 248,
                protein: 46,
                carbs: 0,
                fat: 5,
                micronutrients: chickenMicronutrients
            ),
            IngredientTemplate(
                name: "Romaine Lettuce",
                grams: 150,
                calories: 25,
                protein: 2,
                carbs: 5,
                fat: 0.5,
                micronutrients: romaineMicronutrients
            ),
            IngredientTemplate(
                name: "Parmesan Cheese",
                grams: 30,
                calories: 120,
                protein: 10,
                carbs: 1,
                fat: 8,
                micronutrients: parmesanMicronutrients
            ),
            IngredientTemplate(
                name: "Caesar Dressing",
                grams: 30,
                calories: 150,
                protein: 1,
                carbs: 1,
                fat: 16,
                micronutrients: dressingMicronutrients
            )
        ]
    )

    private static let lunchBowl = MealTemplate(
        name: "Quinoa Buddha Bowl",
        emoji: "🍲",
        calories: 580,
        protein: 22,
        carbs: 68,
        fat: 24,
        fiber: 12,
        mealType: "lunch",
        ingredients: [
            IngredientTemplate(
                name: "Quinoa",
                grams: 150,
                calories: 180,
                protein: 7,
                carbs: 32,
                fat: 3,
                micronutrients: quinoaMicronutrients
            ),
            IngredientTemplate(
                name: "Chickpeas",
                grams: 100,
                calories: 164,
                protein: 9,
                carbs: 27,
                fat: 3,
                micronutrients: chickpeaMicronutrients
            ),
            IngredientTemplate(
                name: "Roasted Sweet Potato",
                grams: 120,
                calories: 110,
                protein: 2,
                carbs: 26,
                fat: 0.1,
                micronutrients: sweetPotatoMicronutrients
            ),
            IngredientTemplate(
                name: "Tahini Dressing",
                grams: 30,
                calories: 90,
                protein: 3,
                carbs: 3,
                fat: 8,
                micronutrients: tahiniMicronutrients
            )
        ]
    )

    private static let lunchWrap = MealTemplate(
        name: "Turkey & Hummus Wrap",
        emoji: "🌯",
        calories: 480,
        protein: 32,
        carbs: 42,
        fat: 20,
        fiber: 8,
        mealType: "lunch",
        ingredients: [
            IngredientTemplate(
                name: "Turkey Breast",
                grams: 100,
                calories: 135,
                protein: 28,
                carbs: 0,
                fat: 2,
                micronutrients: turkeyMicronutrients
            ),
            IngredientTemplate(
                name: "Whole Wheat Tortilla",
                grams: 60,
                calories: 150,
                protein: 4,
                carbs: 26,
                fat: 4,
                micronutrients: tortillaMicronutrients
            ),
            IngredientTemplate(
                name: "Hummus",
                grams: 50,
                calories: 80,
                protein: 4,
                carbs: 8,
                fat: 4,
                micronutrients: hummusMicronutrients
            ),
            IngredientTemplate(
                name: "Mixed Vegetables",
                grams: 80,
                calories: 25,
                protein: 1,
                carbs: 5,
                fat: 0,
                micronutrients: mixedVegMicronutrients
            )
        ]
    )

    private static let lunchSandwich = MealTemplate(
        name: "Tuna Sandwich",
        emoji: "🥪",
        calories: 420,
        protein: 28,
        carbs: 38,
        fat: 18,
        fiber: 4,
        mealType: "lunch",
        ingredients: [
            IngredientTemplate(
                name: "Tuna",
                grams: 100,
                calories: 130,
                protein: 28,
                carbs: 0,
                fat: 1,
                micronutrients: tunaMicronutrients
            ),
            IngredientTemplate(
                name: "Whole Wheat Bread",
                grams: 80,
                calories: 180,
                protein: 7,
                carbs: 34,
                fat: 2,
                micronutrients: wheatToastMicronutrients
            ),
            IngredientTemplate(
                name: "Mayonnaise",
                grams: 20,
                calories: 140,
                protein: 0,
                carbs: 0,
                fat: 16,
                micronutrients: mayoMicronutrients
            )
        ]
    )

    private static let lunchSoup = MealTemplate(
        name: "Lentil Vegetable Soup",
        emoji: "🍜",
        calories: 320,
        protein: 18,
        carbs: 48,
        fat: 6,
        fiber: 16,
        mealType: "lunch",
        ingredients: [
            IngredientTemplate(
                name: "Lentils",
                grams: 150,
                calories: 170,
                protein: 13,
                carbs: 30,
                fat: 0.5,
                micronutrients: lentilsMicronutrients
            ),
            IngredientTemplate(
                name: "Mixed Vegetables",
                grams: 150,
                calories: 50,
                protein: 2,
                carbs: 10,
                fat: 0.5,
                micronutrients: mixedVegMicronutrients
            )
        ]
    )

    private static let snackYogurt = MealTemplate(
        name: "Greek Yogurt with Honey",
        emoji: "🍯",
        calories: 180,
        protein: 18,
        carbs: 20,
        fat: 4,
        fiber: 0,
        mealType: "snack",
        ingredients: [
            IngredientTemplate(
                name: "Greek Yogurt",
                grams: 170,
                calories: 100,
                protein: 17,
                carbs: 6,
                fat: 0.7,
                micronutrients: greekYogurtMicronutrients
            ),
            IngredientTemplate(
                name: "Honey",
                grams: 20,
                calories: 64,
                protein: 0.1,
                carbs: 17,
                fat: 0,
                micronutrients: honeyMicronutrients
            )
        ]
    )

    private static let dinnerSalmon = MealTemplate(
        name: "Grilled Salmon with Vegetables",
        emoji: "🐟",
        calories: 580,
        protein: 48,
        carbs: 32,
        fat: 28,
        fiber: 8,
        mealType: "dinner",
        ingredients: [
            IngredientTemplate(
                name: "Atlantic Salmon",
                grams: 180,
                calories: 370,
                protein: 40,
                carbs: 0,
                fat: 22,
                micronutrients: salmonMicronutrients
            ),
            IngredientTemplate(
                name: "Roasted Broccoli",
                grams: 150,
                calories: 52,
                protein: 4,
                carbs: 10,
                fat: 0.6,
                micronutrients: broccoliMicronutrients
            ),
            IngredientTemplate(
                name: "Brown Rice",
                grams: 150,
                calories: 165,
                protein: 4,
                carbs: 34,
                fat: 1.5,
                micronutrients: brownRiceMicronutrients
            )
        ]
    )

    private static let dinnerChicken = MealTemplate(
        name: "Herb Roasted Chicken & Potatoes",
        emoji: "🍗",
        calories: 620,
        protein: 52,
        carbs: 42,
        fat: 26,
        fiber: 5,
        mealType: "dinner",
        ingredients: [
            IngredientTemplate(
                name: "Roasted Chicken Thigh",
                grams: 180,
                calories: 340,
                protein: 38,
                carbs: 0,
                fat: 20,
                micronutrients: chickenMicronutrients
            ),
            IngredientTemplate(
                name: "Roasted Potatoes",
                grams: 200,
                calories: 180,
                protein: 4,
                carbs: 42,
                fat: 0.2,
                micronutrients: potatoMicronutrients
            ),
            IngredientTemplate(
                name: "Green Beans",
                grams: 100,
                calories: 31,
                protein: 2,
                carbs: 7,
                fat: 0.1,
                micronutrients: greenBeansMicronutrients
            )
        ]
    )

    private static let dinnerStirFry = MealTemplate(
        name: "Beef & Vegetable Stir Fry",
        emoji: "🥩",
        calories: 540,
        protein: 38,
        carbs: 48,
        fat: 22,
        fiber: 6,
        mealType: "dinner",
        ingredients: [
            IngredientTemplate(
                name: "Beef Sirloin",
                grams: 150,
                calories: 280,
                protein: 36,
                carbs: 0,
                fat: 14,
                micronutrients: beefMicronutrients
            ),
            IngredientTemplate(
                name: "Jasmine Rice",
                grams: 150,
                calories: 200,
                protein: 4,
                carbs: 44,
                fat: 0.4,
                micronutrients: riceMicronutrients
            ),
            IngredientTemplate(
                name: "Stir Fry Vegetables",
                grams: 150,
                calories: 45,
                protein: 2,
                carbs: 9,
                fat: 0.5,
                micronutrients: stirFryVegMicronutrients
            )
        ]
    )

    private static let dinnerPasta = MealTemplate(
        name: "Spaghetti Bolognese",
        emoji: "🍝",
        calories: 680,
        protein: 32,
        carbs: 78,
        fat: 26,
        fiber: 6,
        mealType: "dinner",
        ingredients: [
            IngredientTemplate(
                name: "Spaghetti",
                grams: 150,
                calories: 220,
                protein: 8,
                carbs: 43,
                fat: 1.3,
                micronutrients: pastaMicronutrients
            ),
            IngredientTemplate(
                name: "Ground Beef",
                grams: 120,
                calories: 290,
                protein: 24,
                carbs: 0,
                fat: 21,
                micronutrients: beefMicronutrients
            ),
            IngredientTemplate(
                name: "Tomato Sauce",
                grams: 120,
                calories: 40,
                protein: 2,
                carbs: 8,
                fat: 0.4,
                micronutrients: tomatoSauceMicronutrients
            ),
            IngredientTemplate(
                name: "Parmesan",
                grams: 20,
                calories: 80,
                protein: 7,
                carbs: 0.6,
                fat: 5,
                micronutrients: parmesanMicronutrients
            )
        ]
    )

    // MARK: - Micronutrient Data (Realistic values per 100g)

    private static let salmonMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin D", amount: 11, unit: "mcg", rdaPercent: 55, category: .vitamin),
        Micronutrient(name: "Vitamin B12", amount: 4.2, unit: "mcg", rdaPercent: 175, category: .vitamin),
        Micronutrient(name: "Selenium", amount: 36, unit: "mcg", rdaPercent: 65, category: .mineral),
        Micronutrient(name: "Phosphorus", amount: 252, unit: "mg", rdaPercent: 36, category: .mineral),
        Micronutrient(name: "Potassium", amount: 490, unit: "mg", rdaPercent: 10, category: .electrolyte),
        Micronutrient(name: "Niacin", amount: 8.4, unit: "mg", rdaPercent: 53, category: .vitamin),
        Micronutrient(name: "Pyridoxine (B6)", amount: 0.8, unit: "mg", rdaPercent: 47, category: .vitamin)
    ]

    private static let chickenMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin B12", amount: 0.3, unit: "mcg", rdaPercent: 13, category: .vitamin),
        Micronutrient(name: "Niacin", amount: 13.7, unit: "mg", rdaPercent: 86, category: .vitamin),
        Micronutrient(name: "Pyridoxine (B6)", amount: 0.6, unit: "mg", rdaPercent: 35, category: .vitamin),
        Micronutrient(name: "Selenium", amount: 28, unit: "mcg", rdaPercent: 51, category: .mineral),
        Micronutrient(name: "Phosphorus", amount: 200, unit: "mg", rdaPercent: 29, category: .mineral),
        Micronutrient(name: "Zinc", amount: 1.0, unit: "mg", rdaPercent: 9, category: .mineral)
    ]

    private static let spinachMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin K", amount: 483, unit: "mcg", rdaPercent: 403, category: .vitamin),
        Micronutrient(name: "Vitamin A", amount: 469, unit: "mcg", rdaPercent: 52, category: .vitamin),
        Micronutrient(name: "Folate (B9)", amount: 194, unit: "mcg", rdaPercent: 49, category: .vitamin),
        Micronutrient(name: "Vitamin C", amount: 28, unit: "mg", rdaPercent: 31, category: .vitamin),
        Micronutrient(name: "Iron", amount: 2.7, unit: "mg", rdaPercent: 15, category: .mineral),
        Micronutrient(name: "Magnesium", amount: 79, unit: "mg", rdaPercent: 19, category: .mineral),
        Micronutrient(name: "Potassium", amount: 558, unit: "mg", rdaPercent: 12, category: .electrolyte)
    ]

    private static let broccoliMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin C", amount: 89, unit: "mg", rdaPercent: 99, category: .vitamin),
        Micronutrient(name: "Vitamin K", amount: 102, unit: "mcg", rdaPercent: 85, category: .vitamin),
        Micronutrient(name: "Folate (B9)", amount: 63, unit: "mcg", rdaPercent: 16, category: .vitamin),
        Micronutrient(name: "Potassium", amount: 316, unit: "mg", rdaPercent: 7, category: .electrolyte),
        Micronutrient(name: "Phosphorus", amount: 66, unit: "mg", rdaPercent: 9, category: .mineral)
    ]

    private static let eggsMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin B12", amount: 1.1, unit: "mcg", rdaPercent: 46, category: .vitamin),
        Micronutrient(name: "Vitamin D", amount: 2.0, unit: "mcg", rdaPercent: 10, category: .vitamin),
        Micronutrient(name: "Selenium", amount: 31, unit: "mcg", rdaPercent: 56, category: .mineral),
        Micronutrient(name: "Riboflavin (B2)", amount: 0.5, unit: "mg", rdaPercent: 38, category: .vitamin),
        Micronutrient(name: "Phosphorus", amount: 198, unit: "mg", rdaPercent: 28, category: .mineral)
    ]

    private static let oatsMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Manganese", amount: 4.9, unit: "mg", rdaPercent: 213, category: .mineral),
        Micronutrient(name: "Phosphorus", amount: 523, unit: "mg", rdaPercent: 75, category: .mineral),
        Micronutrient(name: "Magnesium", amount: 177, unit: "mg", rdaPercent: 42, category: .mineral),
        Micronutrient(name: "Iron", amount: 4.7, unit: "mg", rdaPercent: 26, category: .mineral),
        Micronutrient(name: "Zinc", amount: 4.0, unit: "mg", rdaPercent: 36, category: .mineral),
        Micronutrient(name: "Thiamin (B1)", amount: 0.8, unit: "mg", rdaPercent: 67, category: .vitamin)
    ]

    private static let blueberriesMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin C", amount: 10, unit: "mg", rdaPercent: 11, category: .vitamin),
        Micronutrient(name: "Vitamin K", amount: 19, unit: "mcg", rdaPercent: 16, category: .vitamin),
        Micronutrient(name: "Manganese", amount: 0.3, unit: "mg", rdaPercent: 13, category: .mineral)
    ]

    private static let almondsMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin E", amount: 25.6, unit: "mg", rdaPercent: 171, category: .vitamin),
        Micronutrient(name: "Magnesium", amount: 270, unit: "mg", rdaPercent: 64, category: .mineral),
        Micronutrient(name: "Phosphorus", amount: 481, unit: "mg", rdaPercent: 69, category: .mineral),
        Micronutrient(name: "Calcium", amount: 269, unit: "mg", rdaPercent: 27, category: .mineral),
        Micronutrient(name: "Riboflavin (B2)", amount: 1.1, unit: "mg", rdaPercent: 85, category: .vitamin)
    ]

    private static let bananaMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Potassium", amount: 358, unit: "mg", rdaPercent: 8, category: .electrolyte),
        Micronutrient(name: "Vitamin B6", amount: 0.4, unit: "mg", rdaPercent: 24, category: .vitamin),
        Micronutrient(name: "Vitamin C", amount: 9, unit: "mg", rdaPercent: 10, category: .vitamin),
        Micronutrient(name: "Magnesium", amount: 27, unit: "mg", rdaPercent: 6, category: .mineral)
    ]

    private static let avocadoMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin K", amount: 21, unit: "mcg", rdaPercent: 18, category: .vitamin),
        Micronutrient(name: "Folate (B9)", amount: 81, unit: "mcg", rdaPercent: 20, category: .vitamin),
        Micronutrient(name: "Potassium", amount: 485, unit: "mg", rdaPercent: 10, category: .electrolyte),
        Micronutrient(name: "Vitamin E", amount: 2.1, unit: "mg", rdaPercent: 14, category: .vitamin),
        Micronutrient(name: "Vitamin C", amount: 10, unit: "mg", rdaPercent: 11, category: .vitamin)
    ]

    private static let quinoaMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Manganese", amount: 1.2, unit: "mg", rdaPercent: 52, category: .mineral),
        Micronutrient(name: "Magnesium", amount: 64, unit: "mg", rdaPercent: 15, category: .mineral),
        Micronutrient(name: "Phosphorus", amount: 152, unit: "mg", rdaPercent: 22, category: .mineral),
        Micronutrient(name: "Folate (B9)", amount: 42, unit: "mcg", rdaPercent: 11, category: .vitamin),
        Micronutrient(name: "Iron", amount: 1.5, unit: "mg", rdaPercent: 8, category: .mineral)
    ]

    private static let sweetPotatoMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin A", amount: 709, unit: "mcg", rdaPercent: 79, category: .vitamin),
        Micronutrient(name: "Vitamin C", amount: 2.4, unit: "mg", rdaPercent: 3, category: .vitamin),
        Micronutrient(name: "Potassium", amount: 337, unit: "mg", rdaPercent: 7, category: .electrolyte),
        Micronutrient(name: "Manganese", amount: 0.3, unit: "mg", rdaPercent: 13, category: .mineral)
    ]

    private static let beefMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin B12", amount: 2.6, unit: "mcg", rdaPercent: 108, category: .vitamin),
        Micronutrient(name: "Zinc", amount: 5.3, unit: "mg", rdaPercent: 48, category: .mineral),
        Micronutrient(name: "Selenium", amount: 26, unit: "mcg", rdaPercent: 47, category: .mineral),
        Micronutrient(name: "Niacin", amount: 5.4, unit: "mg", rdaPercent: 34, category: .vitamin),
        Micronutrient(name: "Iron", amount: 2.4, unit: "mg", rdaPercent: 13, category: .mineral),
        Micronutrient(name: "Phosphorus", amount: 198, unit: "mg", rdaPercent: 28, category: .mineral)
    ]

    // Additional simplified micronutrient profiles
    private static let wheatToastMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Selenium", amount: 28, unit: "mcg", rdaPercent: 51, category: .mineral),
        Micronutrient(name: "Manganese", amount: 1.7, unit: "mg", rdaPercent: 74, category: .mineral),
        Micronutrient(name: "Thiamin (B1)", amount: 0.4, unit: "mg", rdaPercent: 33, category: .vitamin)
    ]

    private static let butterMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin A", amount: 68, unit: "mcg", rdaPercent: 8, category: .vitamin)
    ]

    private static let proteinPowderMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Calcium", amount: 100, unit: "mg", rdaPercent: 10, category: .mineral)
    ]

    private static let almondMilkMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Calcium", amount: 188, unit: "mg", rdaPercent: 19, category: .mineral),
        Micronutrient(name: "Vitamin D", amount: 1, unit: "mcg", rdaPercent: 5, category: .vitamin),
        Micronutrient(name: "Vitamin E", amount: 3.3, unit: "mg", rdaPercent: 22, category: .vitamin)
    ]

    private static let proteinBarMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Iron", amount: 2.5, unit: "mg", rdaPercent: 14, category: .mineral),
        Micronutrient(name: "Calcium", amount: 150, unit: "mg", rdaPercent: 15, category: .mineral)
    ]

    private static let sourdoughMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Selenium", amount: 22, unit: "mcg", rdaPercent: 40, category: .mineral),
        Micronutrient(name: "Folate (B9)", amount: 50, unit: "mcg", rdaPercent: 13, category: .vitamin)
    ]

    private static let romaineMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin K", amount: 102, unit: "mcg", rdaPercent: 85, category: .vitamin),
        Micronutrient(name: "Vitamin A", amount: 436, unit: "mcg", rdaPercent: 48, category: .vitamin),
        Micronutrient(name: "Folate (B9)", amount: 136, unit: "mcg", rdaPercent: 34, category: .vitamin)
    ]

    private static let parmesanMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Calcium", amount: 1184, unit: "mg", rdaPercent: 118, category: .mineral),
        Micronutrient(name: "Phosphorus", amount: 694, unit: "mg", rdaPercent: 99, category: .mineral),
        Micronutrient(name: "Vitamin B12", amount: 1.2, unit: "mcg", rdaPercent: 50, category: .vitamin)
    ]

    private static let dressingMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin E", amount: 1.5, unit: "mg", rdaPercent: 10, category: .vitamin)
    ]

    private static let chickpeaMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Folate (B9)", amount: 172, unit: "mcg", rdaPercent: 43, category: .vitamin),
        Micronutrient(name: "Iron", amount: 2.9, unit: "mg", rdaPercent: 16, category: .mineral),
        Micronutrient(name: "Phosphorus", amount: 168, unit: "mg", rdaPercent: 24, category: .mineral),
        Micronutrient(name: "Zinc", amount: 1.5, unit: "mg", rdaPercent: 14, category: .mineral)
    ]

    private static let tahiniMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Calcium", amount: 420, unit: "mg", rdaPercent: 42, category: .mineral),
        Micronutrient(name: "Iron", amount: 8.9, unit: "mg", rdaPercent: 49, category: .mineral),
        Micronutrient(name: "Magnesium", amount: 95, unit: "mg", rdaPercent: 23, category: .mineral)
    ]

    private static let turkeyMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Selenium", amount: 32, unit: "mcg", rdaPercent: 58, category: .mineral),
        Micronutrient(name: "Niacin", amount: 11.8, unit: "mg", rdaPercent: 74, category: .vitamin),
        Micronutrient(name: "Vitamin B6", amount: 0.8, unit: "mg", rdaPercent: 47, category: .vitamin)
    ]

    private static let tortillaMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Iron", amount: 2, unit: "mg", rdaPercent: 11, category: .mineral),
        Micronutrient(name: "Thiamin (B1)", amount: 0.2, unit: "mg", rdaPercent: 17, category: .vitamin)
    ]

    private static let hummusMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Iron", amount: 1.6, unit: "mg", rdaPercent: 9, category: .mineral),
        Micronutrient(name: "Folate (B9)", amount: 38, unit: "mcg", rdaPercent: 10, category: .vitamin)
    ]

    private static let mixedVegMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin A", amount: 200, unit: "mcg", rdaPercent: 22, category: .vitamin),
        Micronutrient(name: "Vitamin C", amount: 12, unit: "mg", rdaPercent: 13, category: .vitamin)
    ]

    private static let tunaMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Selenium", amount: 90, unit: "mcg", rdaPercent: 164, category: .mineral),
        Micronutrient(name: "Vitamin B12", amount: 2.2, unit: "mcg", rdaPercent: 92, category: .vitamin),
        Micronutrient(name: "Niacin", amount: 10.5, unit: "mg", rdaPercent: 66, category: .vitamin)
    ]

    private static let mayoMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin E", amount: 3.3, unit: "mg", rdaPercent: 22, category: .vitamin)
    ]

    private static let lentilsMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Folate (B9)", amount: 181, unit: "mcg", rdaPercent: 45, category: .vitamin),
        Micronutrient(name: "Iron", amount: 3.3, unit: "mg", rdaPercent: 18, category: .mineral),
        Micronutrient(name: "Phosphorus", amount: 180, unit: "mg", rdaPercent: 26, category: .mineral),
        Micronutrient(name: "Potassium", amount: 369, unit: "mg", rdaPercent: 8, category: .electrolyte)
    ]

    private static let greekYogurtMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Calcium", amount: 110, unit: "mg", rdaPercent: 11, category: .mineral),
        Micronutrient(name: "Vitamin B12", amount: 0.8, unit: "mcg", rdaPercent: 33, category: .vitamin),
        Micronutrient(name: "Riboflavin (B2)", amount: 0.3, unit: "mg", rdaPercent: 23, category: .vitamin)
    ]

    private static let honeyMicronutrients: [Micronutrient] = []

    private static let brownRiceMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Manganese", amount: 1.8, unit: "mg", rdaPercent: 78, category: .mineral),
        Micronutrient(name: "Selenium", amount: 10, unit: "mcg", rdaPercent: 18, category: .mineral),
        Micronutrient(name: "Magnesium", amount: 44, unit: "mg", rdaPercent: 10, category: .mineral)
    ]

    private static let potatoMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Potassium", amount: 421, unit: "mg", rdaPercent: 9, category: .electrolyte),
        Micronutrient(name: "Vitamin C", amount: 20, unit: "mg", rdaPercent: 22, category: .vitamin),
        Micronutrient(name: "Vitamin B6", amount: 0.3, unit: "mg", rdaPercent: 18, category: .vitamin)
    ]

    private static let greenBeansMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin C", amount: 12, unit: "mg", rdaPercent: 13, category: .vitamin),
        Micronutrient(name: "Vitamin K", amount: 43, unit: "mcg", rdaPercent: 36, category: .vitamin)
    ]

    private static let riceMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Manganese", amount: 0.5, unit: "mg", rdaPercent: 22, category: .mineral),
        Micronutrient(name: "Selenium", amount: 7.5, unit: "mcg", rdaPercent: 14, category: .mineral)
    ]

    private static let stirFryVegMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin A", amount: 150, unit: "mcg", rdaPercent: 17, category: .vitamin),
        Micronutrient(name: "Vitamin C", amount: 25, unit: "mg", rdaPercent: 28, category: .vitamin),
        Micronutrient(name: "Vitamin K", amount: 45, unit: "mcg", rdaPercent: 38, category: .vitamin)
    ]

    private static let pastaMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Selenium", amount: 26, unit: "mcg", rdaPercent: 47, category: .mineral),
        Micronutrient(name: "Thiamin (B1)", amount: 0.4, unit: "mg", rdaPercent: 33, category: .vitamin),
        Micronutrient(name: "Folate (B9)", amount: 83, unit: "mcg", rdaPercent: 21, category: .vitamin)
    ]

    private static let tomatoSauceMicronutrients: [Micronutrient] = [
        Micronutrient(name: "Vitamin C", amount: 10, unit: "mg", rdaPercent: 11, category: .vitamin),
        Micronutrient(name: "Potassium", amount: 217, unit: "mg", rdaPercent: 5, category: .electrolyte),
        Micronutrient(name: "Vitamin A", amount: 25, unit: "mcg", rdaPercent: 3, category: .vitamin)
    ]

    // MARK: - Create Meal from Template

    private static func createMeal(from template: MealTemplate, timestamp: Date) -> Meal {
        let meal = Meal(
            name: template.name,
            emoji: template.emoji,
            timestamp: timestamp,
            calories: template.calories,
            protein: template.protein,
            carbs: template.carbs,
            fat: template.fat,
            fiber: template.fiber,
            mealType: template.mealType
        )

        // Create ingredients with micronutrients
        var ingredients: [MealIngredient] = []

        for ingredientTemplate in template.ingredients {
            let ingredient = MealIngredient(
                name: ingredientTemplate.name,
                grams: ingredientTemplate.grams,
                calories: ingredientTemplate.calories,
                protein: ingredientTemplate.protein,
                carbs: ingredientTemplate.carbs,
                fat: ingredientTemplate.fat,
                usdaFdcId: "demo_\(ingredientTemplate.name.lowercased().replacingOccurrences(of: " ", with: "_"))"
            )

            // Scale micronutrients based on gram amount (templates are per 100g)
            let scaleFactor = ingredientTemplate.grams / 100.0
            let scaledMicronutrients = ingredientTemplate.micronutrients.map { nutrient in
                Micronutrient(
                    name: nutrient.name,
                    amount: nutrient.amount * scaleFactor,
                    unit: nutrient.unit,
                    rdaPercent: nutrient.rdaPercent * scaleFactor,
                    category: nutrient.category
                )
            }

            ingredient.cacheMicronutrients(scaledMicronutrients)
            ingredient.enrichmentAttempted = true
            ingredient.matchMethod = "Demo"

            ingredients.append(ingredient)
        }

        meal.ingredients = ingredients
        meal.syncStatus = "demo"

        return meal
    }
}

#endif
