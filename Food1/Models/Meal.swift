//
//  Meal.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import Foundation
import SwiftData

@Model
final class Meal {
    var id: UUID
    var name: String
    var emoji: String
    var timestamp: Date
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var notes: String?
    var photoData: Data?  // Stores JPEG image data when meal logged via photo recognition

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        timestamp: Date,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        notes: String? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.timestamp = timestamp
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.notes = notes
        self.photoData = photoData
    }

    // Static helper method for calculating totals
    static func calculateTotals(for meals: [Meal]) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let totalCalories = meals.reduce(0) { $0 + $1.calories }
        let totalProtein = meals.reduce(0) { $0 + $1.protein }
        let totalCarbs = meals.reduce(0) { $0 + $1.carbs }
        let totalFat = meals.reduce(0) { $0 + $1.fat }

        return (totalCalories, totalProtein, totalCarbs, totalFat)
    }
}

// Daily goals
struct DailyGoals {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    static let standard = DailyGoals(
        calories: 2000,
        protein: 150,
        carbs: 225,
        fat: 65
    )
}
