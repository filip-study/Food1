//
//  WeeklyAggregate.swift
//  Food1
//
//  Cached weekly statistics with consistency metrics
//

import Foundation
import SwiftData

@Model
final class WeeklyAggregate {
    var weekStartDate: Date  // Monday of week
    var year: Int
    var weekNumber: Int

    // 7-day averages
    var avgCalories: Double
    var avgProtein: Double
    var avgCarbs: Double
    var avgFat: Double

    // Totals
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double

    // Consistency metrics
    var daysWithMeals: Int
    var totalMeals: Int
    var consistencyScore: Double  // 0-100

    // Goal achievement
    var daysMetCalorieGoal: Int
    var daysMetProteinGoal: Int

    // Top foods tracking
    var topFoodsJSON: Data?

    var lastUpdated: Date
    var version: Int = 1

    init(weekStartDate: Date) {
        let calendar = Calendar.current
        self.weekStartDate = weekStartDate
        self.year = calendar.component(.yearForWeekOfYear, from: weekStartDate)
        self.weekNumber = calendar.component(.weekOfYear, from: weekStartDate)
        self.avgCalories = 0
        self.avgProtein = 0
        self.avgCarbs = 0
        self.avgFat = 0
        self.totalCalories = 0
        self.totalProtein = 0
        self.totalCarbs = 0
        self.totalFat = 0
        self.daysWithMeals = 0
        self.totalMeals = 0
        self.consistencyScore = 0
        self.daysMetCalorieGoal = 0
        self.daysMetProteinGoal = 0
        self.lastUpdated = Date()
    }

    // MARK: - Computed Properties

    var topFoods: [String: Int] {
        guard let data = topFoodsJSON else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    func updateTopFoods(_ foods: [String: Int]) {
        topFoodsJSON = try? JSONEncoder().encode(foods)
    }
}
