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

    /// Base smoothing window size (days) for trend visualization
    /// Actual window adapts based on data density
    var baseSmoothingWindow: Int {
        switch self {
        case .week: return 1      // No smoothing - daily granularity
        case .month: return 3     // 3-day centered average
        case .quarter: return 5   // ~weekly smoothing
        case .year: return 7      // Weekly average
        }
    }

    /// Maximum gap (days) to bridge with solid line instead of dashed
    /// Gaps larger than this show as dashed lines indicating missing data
    var maxSolidGap: Int {
        switch self {
        case .week: return 1      // Current behavior
        case .month: return 2     // Absorb weekend gaps
        case .quarter: return 4   // Absorb short breaks
        case .year: return 7      // Only week+ gaps show dashed
        }
    }

    /// Whether this period uses smoothed/averaged data for trends
    var usesSmoothing: Bool {
        self != .week
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

        // Goal achievement (using personalized goals from user profile)
        let goals = DailyGoals.fromUserDefaults()
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

// MARK: - Smoothed Data Point

/// A data point representing a smoothed/averaged trend value
/// Used for Month, Quarter, and Year views to show long-term trends
struct SmoothedDataPoint: Identifiable {
    let id = UUID()
    let date: Date                    // Center date of the smoothing window
    let calories: Double              // Averaged value
    let protein: Double
    let carbs: Double
    let fat: Double
    let windowSize: Int               // How many days contributed to this average
    let windowStart: Date             // First date in the window
    let windowEnd: Date               // Last date in the window

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    /// Label for the smoothing window (e.g., "Dec 12-14")
    var windowLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        if Calendar.current.isDate(windowStart, inSameDayAs: windowEnd) {
            return formatter.string(from: date)
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d"
            return "\(formatter.string(from: windowStart))-\(dayFormatter.string(from: windowEnd))"
        }
    }
}

// MARK: - Smoothed Data Computation

extension StatisticsSummary {

    /// Generate smoothed trend data for longer time periods
    /// Uses adaptive window sizing based on data density
    func smoothedData(for period: StatsPeriod) -> [SmoothedDataPoint] {
        // Week view uses raw daily data - no smoothing
        guard period.usesSmoothing else {
            return dailyData.filter { $0.mealCount > 0 }.map { day in
                SmoothedDataPoint(
                    date: day.date,
                    calories: day.calories,
                    protein: day.protein,
                    carbs: day.carbs,
                    fat: day.fat,
                    windowSize: 1,
                    windowStart: day.date,
                    windowEnd: day.date
                )
            }
        }

        // Filter to only days with actual meal data
        // For smoothed periods, exclude "today" entirely - incomplete data skews trend averages
        let calendar = Calendar.current
        let today = Date()
        let daysWithMeals = dailyData.filter { day in
            day.mealCount > 0 && !calendar.isDate(day.date, inSameDayAs: today)
        }

        guard !daysWithMeals.isEmpty else { return [] }

        // Adaptive window: scale based on data density
        // min(baseWindow, max(2, daysWithData / 4))
        let baseWindow = period.baseSmoothingWindow
        let adaptiveWindow = min(baseWindow, max(2, daysWithMeals.count / 4))
        let halfWindow = adaptiveWindow / 2

        // Compute centered rolling average for each data point
        return daysWithMeals.enumerated().map { index, centerDay in
            // Determine window bounds (by index, not calendar days)
            let startIdx = max(0, index - halfWindow)
            let endIdx = min(daysWithMeals.count - 1, index + halfWindow)
            let windowDays = Array(daysWithMeals[startIdx...endIdx])

            // Compute averages
            let count = Double(windowDays.count)
            let avgCalories = windowDays.reduce(0) { $0 + $1.calories } / count
            let avgProtein = windowDays.reduce(0) { $0 + $1.protein } / count
            let avgCarbs = windowDays.reduce(0) { $0 + $1.carbs } / count
            let avgFat = windowDays.reduce(0) { $0 + $1.fat } / count

            return SmoothedDataPoint(
                date: centerDay.date,
                calories: avgCalories,
                protein: avgProtein,
                carbs: avgCarbs,
                fat: avgFat,
                windowSize: windowDays.count,
                windowStart: windowDays.first?.date ?? centerDay.date,
                windowEnd: windowDays.last?.date ?? centerDay.date
            )
        }
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
