//
//  PreviewContainer.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftData
import Foundation

@MainActor
struct PreviewContainer {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([Meal.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(for: schema, configurations: config)

            // Add sample data for previews
            seedSampleData()
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }

    private func seedSampleData() {
        let context = container.mainContext
        let calendar = Calendar.current
        let now = Date()

        let meals = [
            Meal(
                name: "Oatmeal with Berries",
                emoji: "🥣",
                timestamp: calendar.safeDate(bySettingHour: 8, minute: 0, second: 0, of: now),
                calories: 320,
                protein: 12,
                carbs: 54,
                fat: 8
            ),
            Meal(
                name: "Grilled Chicken Salad",
                emoji: "🥗",
                timestamp: calendar.safeDate(bySettingHour: 12, minute: 30, second: 0, of: now),
                calories: 420,
                protein: 35,
                carbs: 30,
                fat: 18
            ),
            Meal(
                name: "Salmon with Quinoa",
                emoji: "🐟",
                timestamp: calendar.safeDate(bySettingHour: 19, minute: 0, second: 0, of: now),
                calories: 520,
                protein: 42,
                carbs: 48,
                fat: 18
            )
        ]

        for meal in meals {
            context.insert(meal)
        }

        try? context.save()
    }
}
