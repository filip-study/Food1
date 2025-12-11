//
//  StatisticsTypes.swift
//  Food1
//
//  Supporting types for statistics and trends
//

import Foundation

// MARK: - Time Period

enum StatsPeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"

    /// Get date range for this period ending today
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())

        let start: Date
        switch self {
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: end)!
        case .month:
            start = calendar.date(byAdding: .day, value: -29, to: end)!
        case .quarter:
            start = calendar.date(byAdding: .month, value: -3, to: end)!
        case .year:
            start = calendar.date(byAdding: .year, value: -1, to: end)!
        }

        return (start, end)
    }

    /// Number of days in this period
    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

// MARK: - Statistics Summary

struct StatisticsSummary {
    let period: StatsPeriod
    let startDate: Date
    let endDate: Date

    // Totals
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let totalMeals: Int

    // Averages (per day with meals)
    let avgCalories: Double
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double

    // Consistency
    let daysWithMeals: Int
    let consistencyScore: Double  // 0-100
    let currentStreak: Int
    let longestStreak: Int

    // Goal achievement
    let daysMetCalorieGoal: Int
    let daysMetProteinGoal: Int

    // Micronutrients (aggregated)
    let micronutrients: MicronutrientProfile

    // Daily data for charts
    let dailyData: [DailyDataPoint]

    init(aggregates: [DailyAggregate], period: StatsPeriod = .week) {
        self.period = period
        self.startDate = aggregates.first?.date ?? Date()
        self.endDate = aggregates.last?.date ?? Date()

        // Calculate totals
        self.totalCalories = aggregates.reduce(0) { $0 + $1.calories }
        self.totalProtein = aggregates.reduce(0) { $0 + $1.protein }
        self.totalCarbs = aggregates.reduce(0) { $0 + $1.carbs }
        self.totalFat = aggregates.reduce(0) { $0 + $1.fat }
        self.totalMeals = aggregates.reduce(0) { $0 + $1.mealCount }

        // Calculate averages
        let daysWithData = aggregates.filter { $0.mealCount > 0 }.count
        self.daysWithMeals = daysWithData

        if daysWithData > 0 {
            self.avgCalories = totalCalories / Double(daysWithData)
            self.avgProtein = totalProtein / Double(daysWithData)
            self.avgCarbs = totalCarbs / Double(daysWithData)
            self.avgFat = totalFat / Double(daysWithData)
        } else {
            self.avgCalories = 0
            self.avgProtein = 0
            self.avgCarbs = 0
            self.avgFat = 0
        }

        // Calculate consistency
        self.consistencyScore = Double(daysWithData) / Double(max(period.dayCount, 1)) * 100

        // Calculate streaks
        let (current, longest) = Self.calculateStreaks(aggregates: aggregates)
        self.currentStreak = current
        self.longestStreak = longest

        // Goal achievement
        let goals = DailyGoals.standard
        self.daysMetCalorieGoal = aggregates.filter {
            $0.calories >= goals.calories * 0.9 && $0.calories <= goals.calories * 1.1
        }.count
        self.daysMetProteinGoal = aggregates.filter {
            $0.protein >= goals.protein * 0.9
        }.count

        // Aggregate micronutrients (all 21 nutrients)
        var profile = MicronutrientProfile()
        for aggregate in aggregates {
            let nutrients = aggregate.micronutrients
            // Original minerals (6)
            profile.calcium += nutrients.calcium
            profile.iron += nutrients.iron
            profile.magnesium += nutrients.magnesium
            profile.potassium += nutrients.potassium
            profile.zinc += nutrients.zinc
            profile.sodium += nutrients.sodium
            // New minerals (3)
            profile.phosphorus += nutrients.phosphorus
            profile.copper += nutrients.copper
            profile.selenium += nutrients.selenium
            // Original vitamins (6)
            profile.vitaminA += nutrients.vitaminA
            profile.vitaminC += nutrients.vitaminC
            profile.vitaminD += nutrients.vitaminD
            profile.vitaminE += nutrients.vitaminE
            profile.vitaminB12 += nutrients.vitaminB12
            profile.folate += nutrients.folate
            // New vitamins (6)
            profile.vitaminK += nutrients.vitaminK
            profile.vitaminB1 += nutrients.vitaminB1
            profile.vitaminB2 += nutrients.vitaminB2
            profile.vitaminB3 += nutrients.vitaminB3
            profile.vitaminB5 += nutrients.vitaminB5
            profile.vitaminB6 += nutrients.vitaminB6
        }
        self.micronutrients = profile

        // Convert to daily data points - fill in ALL days in the period
        let (periodStart, periodEnd) = period.dateRange
        let calendar = Calendar.current

        // Create lookup for existing aggregates
        var aggregateByDate: [Date: DailyAggregate] = [:]
        for aggregate in aggregates {
            let normalizedDate = calendar.startOfDay(for: aggregate.date)
            aggregateByDate[normalizedDate] = aggregate
        }

        // Generate data points for all days in period
        var allDailyData: [DailyDataPoint] = []
        var currentDate = periodStart
        while currentDate <= periodEnd {
            let normalizedDate = calendar.startOfDay(for: currentDate)

            if let aggregate = aggregateByDate[normalizedDate] {
                allDailyData.append(DailyDataPoint(
                    date: normalizedDate,
                    calories: aggregate.calories,
                    protein: aggregate.protein,
                    carbs: aggregate.carbs,
                    fat: aggregate.fat,
                    mealCount: aggregate.mealCount
                ))
            } else {
                // No data for this day - create empty placeholder
                allDailyData.append(DailyDataPoint(
                    date: normalizedDate,
                    calories: 0,
                    protein: 0,
                    carbs: 0,
                    fat: 0,
                    mealCount: 0
                ))
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        self.dailyData = allDailyData
    }

    private static func calculateStreaks(aggregates: [DailyAggregate]) -> (current: Int, longest: Int) {
        let sorted = aggregates.sorted { $0.date < $1.date }
        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 0

        for aggregate in sorted {
            if aggregate.mealCount > 0 {
                tempStreak += 1
                longestStreak = max(longestStreak, tempStreak)
            } else {
                tempStreak = 0
            }
        }

        // Current streak is from most recent day backward
        for aggregate in sorted.reversed() {
            if aggregate.mealCount > 0 {
                currentStreak += 1
            } else {
                break
            }
        }

        return (currentStreak, longestStreak)
    }
}

// MARK: - Daily Data Point

struct DailyDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let mealCount: Int

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Weekly Trend

struct WeeklyTrend: Identifiable {
    let id = UUID()
    let weekStart: Date
    let avgCalories: Double
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double
    let consistencyScore: Double
    let daysWithMeals: Int

    init(from aggregate: WeeklyAggregate) {
        self.weekStart = aggregate.weekStartDate
        self.avgCalories = aggregate.avgCalories
        self.avgProtein = aggregate.avgProtein
        self.avgCarbs = aggregate.avgCarbs
        self.avgFat = aggregate.avgFat
        self.consistencyScore = aggregate.consistencyScore
        self.daysWithMeals = aggregate.daysWithMeals
    }

    var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: weekStart)
    }
}

// MARK: - Comparison

struct PeriodComparison {
    let currentPeriod: StatisticsSummary
    let previousPeriod: StatisticsSummary

    var caloriesDelta: Double {
        guard previousPeriod.avgCalories > 0 else { return 0 }
        return ((currentPeriod.avgCalories - previousPeriod.avgCalories) / previousPeriod.avgCalories) * 100
    }

    var proteinDelta: Double {
        guard previousPeriod.avgProtein > 0 else { return 0 }
        return ((currentPeriod.avgProtein - previousPeriod.avgProtein) / previousPeriod.avgProtein) * 100
    }

    var carbsDelta: Double {
        guard previousPeriod.avgCarbs > 0 else { return 0 }
        return ((currentPeriod.avgCarbs - previousPeriod.avgCarbs) / previousPeriod.avgCarbs) * 100
    }

    var fatDelta: Double {
        guard previousPeriod.avgFat > 0 else { return 0 }
        return ((currentPeriod.avgFat - previousPeriod.avgFat) / previousPeriod.avgFat) * 100
    }

    var consistencyDelta: Double {
        currentPeriod.consistencyScore - previousPeriod.consistencyScore
    }
}
