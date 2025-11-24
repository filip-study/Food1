//
//  DailyAggregate.swift
//  Food1
//
//  Cached daily statistics for performance optimization
//

import Foundation
import SwiftData

@Model
final class DailyAggregate {
    var date: Date  // Normalized to midnight
    var mealCount: Int
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double

    // Micronutrient totals (cached from meal ingredients)
    var cachedMicronutrientsJSON: Data?

    // Consistency metrics
    var firstMealTime: Date?
    var lastMealTime: Date?

    // Computation metadata
    var lastUpdated: Date
    var version: Int = 1

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.mealCount = 0
        self.calories = 0
        self.protein = 0
        self.carbs = 0
        self.fat = 0
        self.fiber = 0
        self.lastUpdated = Date()
    }

    // MARK: - Computed Properties

    /// Decode micronutrients from JSON cache
    var micronutrients: MicronutrientProfile {
        guard let data = cachedMicronutrientsJSON else {
            return MicronutrientProfile()
        }
        return (try? JSONDecoder().decode(MicronutrientProfile.self, from: data)) ?? MicronutrientProfile()
    }

    /// Update micronutrients cache
    func updateMicronutrients(_ profile: MicronutrientProfile) {
        cachedMicronutrientsJSON = try? JSONEncoder().encode(profile)
    }

    /// Check if goals were met for this day
    func goalsMetStatus(goals: DailyGoals) -> GoalsMetStatus {
        GoalsMetStatus(
            calories: calories >= goals.calories * 0.9 && calories <= goals.calories * 1.1,
            protein: protein >= goals.protein * 0.9,
            carbs: carbs >= goals.carbs * 0.8 && carbs <= goals.carbs * 1.2,
            fat: fat >= goals.fat * 0.8 && fat <= goals.fat * 1.2
        )
    }
}

// MARK: - Supporting Types

struct GoalsMetStatus {
    let calories: Bool
    let protein: Bool
    let carbs: Bool
    let fat: Bool

    var allMet: Bool {
        calories && protein && carbs && fat
    }

    var score: Double {
        let met = [calories, protein, carbs, fat].filter { $0 }.count
        return Double(met) / 4.0
    }
}
