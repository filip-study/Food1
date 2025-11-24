//
//  MonthlyAggregate.swift
//  Food1
//
//  Cached monthly statistics with trends
//

import Foundation
import SwiftData

@Model
final class MonthlyAggregate {
    var year: Int
    var month: Int

    // Monthly totals
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double

    // Daily averages
    var avgDailyCalories: Double
    var avgDailyProtein: Double
    var avgDailyCarbs: Double
    var avgDailyFat: Double

    // Trends (% change from previous month)
    var caloriesTrend: Double
    var proteinTrend: Double
    var carbsTrend: Double
    var fatTrend: Double

    // Goal achievement
    var daysTracked: Int
    var daysMetCalorieGoal: Int
    var daysMetProteinGoal: Int
    var daysMetCarbsGoal: Int
    var daysMetFatGoal: Int

    // Consistency
    var consistencyScore: Double
    var longestStreak: Int

    var lastUpdated: Date
    var version: Int = 1

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
        self.totalCalories = 0
        self.totalProtein = 0
        self.totalCarbs = 0
        self.totalFat = 0
        self.avgDailyCalories = 0
        self.avgDailyProtein = 0
        self.avgDailyCarbs = 0
        self.avgDailyFat = 0
        self.caloriesTrend = 0
        self.proteinTrend = 0
        self.carbsTrend = 0
        self.fatTrend = 0
        self.daysTracked = 0
        self.daysMetCalorieGoal = 0
        self.daysMetProteinGoal = 0
        self.daysMetCarbsGoal = 0
        self.daysMetFatGoal = 0
        self.consistencyScore = 0
        self.longestStreak = 0
        self.lastUpdated = Date()
    }

    // MARK: - Computed Properties

    /// First day of this month
    var startDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Last day of this month
    var endDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
