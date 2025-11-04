//
//  MockData.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import Foundation

extension Meal {
    static var mockMeals: [Meal] {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!

        return [
            // Today's meals
            Meal(
                name: "Oatmeal with Berries",
                emoji: "🥣",
                timestamp: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: now)!,
                calories: 320,
                protein: 12,
                carbs: 54,
                fat: 8,
                notes: "Added honey and almonds"
            ),
            Meal(
                name: "Green Smoothie",
                emoji: "🥤",
                timestamp: calendar.date(bySettingHour: 10, minute: 15, second: 0, of: now)!,
                calories: 180,
                protein: 8,
                carbs: 32,
                fat: 4
            ),
            Meal(
                name: "Grilled Chicken Salad",
                emoji: "🥗",
                timestamp: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: now)!,
                calories: 420,
                protein: 38,
                carbs: 28,
                fat: 18,
                notes: "With olive oil dressing"
            ),

            // Yesterday's meals
            Meal(
                name: "Pancakes with Maple Syrup",
                emoji: "🥞",
                timestamp: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: yesterday)!,
                calories: 450,
                protein: 10,
                carbs: 65,
                fat: 15
            ),
            Meal(
                name: "Turkey Sandwich",
                emoji: "🥪",
                timestamp: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: yesterday)!,
                calories: 380,
                protein: 28,
                carbs: 42,
                fat: 12
            ),
            Meal(
                name: "Salmon with Quinoa",
                emoji: "🐟",
                timestamp: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: yesterday)!,
                calories: 520,
                protein: 42,
                carbs: 48,
                fat: 18,
                notes: "Roasted vegetables on the side"
            ),

            // Two days ago
            Meal(
                name: "Avocado Toast",
                emoji: "🥑",
                timestamp: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: twoDaysAgo)!,
                calories: 280,
                protein: 8,
                carbs: 28,
                fat: 16
            ),
            Meal(
                name: "Greek Salad",
                emoji: "🥗",
                timestamp: calendar.date(bySettingHour: 13, minute: 30, second: 0, of: twoDaysAgo)!,
                calories: 320,
                protein: 12,
                carbs: 18,
                fat: 22
            ),
            Meal(
                name: "Pasta Bolognese",
                emoji: "🍝",
                timestamp: calendar.date(bySettingHour: 20, minute: 0, second: 0, of: twoDaysAgo)!,
                calories: 580,
                protein: 32,
                carbs: 68,
                fat: 18
            )
        ]
    }

    // Alternative scenario - less healthy day for testing different moods
    static var mockMealsUnhealthy: [Meal] {
        let calendar = Calendar.current
        let now = Date()

        return [
            Meal(
                name: "Chocolate Croissant",
                emoji: "🥐",
                timestamp: calendar.date(byAdding: .hour, value: -6, to: now)!,
                calories: 380,
                protein: 6,
                carbs: 42,
                fat: 21
            ),
            Meal(
                name: "Large Latte",
                emoji: "☕",
                timestamp: calendar.date(byAdding: .hour, value: -5, to: now)!,
                calories: 220,
                protein: 9,
                carbs: 28,
                fat: 8
            )
        ]
    }
}
