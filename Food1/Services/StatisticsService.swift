//
//  StatisticsService.swift
//  Food1
//
//  Core service for computing and querying nutrition statistics
//

import Foundation
import SwiftData

@MainActor
class StatisticsService {
    static let shared = StatisticsService()

    private init() {}

    // MARK: - Query Methods

    /// Get statistics summary for a time period
    func getStatistics(for period: StatsPeriod, in context: ModelContext) -> StatisticsSummary {
        let (startDate, endDate) = period.dateRange
        let aggregates = fetchDailyAggregates(from: startDate, to: endDate, in: context)
        return StatisticsSummary(aggregates: aggregates, period: period)
    }

    /// Fetch daily aggregates for date range
    func fetchDailyAggregates(from startDate: Date, to endDate: Date, in context: ModelContext) -> [DailyAggregate] {
        let predicate = #Predicate<DailyAggregate> { aggregate in
            aggregate.date >= startDate && aggregate.date <= endDate
        }

        let descriptor = FetchDescriptor<DailyAggregate>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get comparison between current and previous period
    func getComparison(for period: StatsPeriod, in context: ModelContext) -> PeriodComparison {
        let current = getStatistics(for: period, in: context)

        // Calculate previous period range
        let calendar = Calendar.current
        let (currentStart, _) = period.dateRange
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: currentStart)!
        let previousStart: Date

        switch period {
        case .week:
            previousStart = calendar.date(byAdding: .day, value: -7, to: currentStart)!
        case .month:
            previousStart = calendar.date(byAdding: .day, value: -30, to: currentStart)!
        case .quarter:
            previousStart = calendar.date(byAdding: .month, value: -3, to: currentStart)!
        case .year:
            previousStart = calendar.date(byAdding: .year, value: -1, to: currentStart)!
        }

        let previousAggregates = fetchDailyAggregates(from: previousStart, to: previousEnd, in: context)
        let previous = StatisticsSummary(aggregates: previousAggregates, period: period)

        return PeriodComparison(currentPeriod: current, previousPeriod: previous)
    }

    // MARK: - Update Methods

    /// Update aggregates when a meal is added or modified
    func updateAggregates(for meal: Meal, in context: ModelContext) async {
        let aggregateDate = Calendar.current.startOfDay(for: meal.timestamp)

        // Get or create daily aggregate
        let dailyAggregate = getOrCreateDailyAggregate(for: aggregateDate, in: context)

        // Recompute from all meals for that day
        await recomputeDailyAggregate(dailyAggregate, in: context)

        // Update weekly aggregate
        await updateWeeklyAggregate(containing: aggregateDate, in: context)

        // Update monthly aggregate
        await updateMonthlyAggregate(containing: aggregateDate, in: context)

        try? context.save()
    }

    /// Invalidate and recompute aggregate for a date (when meal deleted)
    func invalidateAggregate(for date: Date, in context: ModelContext) async {
        let aggregateDate = Calendar.current.startOfDay(for: date)

        // Check if any meals remain for this date
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: aggregateDate)!
        let mealPredicate = #Predicate<Meal> { meal in
            meal.timestamp >= aggregateDate && meal.timestamp < nextDay
        }
        let mealCount = (try? context.fetchCount(FetchDescriptor(predicate: mealPredicate))) ?? 0

        if mealCount == 0 {
            // Delete aggregate if no meals
            let predicate = #Predicate<DailyAggregate> { $0.date == aggregateDate }
            if let aggregate = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
                context.delete(aggregate)
            }
        } else {
            // Recompute
            let aggregate = getOrCreateDailyAggregate(for: aggregateDate, in: context)
            await recomputeDailyAggregate(aggregate, in: context)
        }

        // Update weekly/monthly
        await updateWeeklyAggregate(containing: aggregateDate, in: context)
        await updateMonthlyAggregate(containing: aggregateDate, in: context)

        try? context.save()
    }

    // MARK: - Initial Migration

    /// Compute aggregates for all existing meals (run once on first launch)
    func performInitialMigration(in context: ModelContext) async {
        // Check if already migrated
        let aggregateCount = (try? context.fetchCount(FetchDescriptor<DailyAggregate>())) ?? 0
        let mealCount = (try? context.fetchCount(FetchDescriptor<Meal>())) ?? 0

        guard aggregateCount == 0 && mealCount > 0 else {
            print("📊 Statistics migration not needed (aggregates: \(aggregateCount), meals: \(mealCount))")
            return
        }

        print("📊 Starting statistics migration for \(mealCount) meals...")
        let startTime = CFAbsoluteTimeGetCurrent()

        // Fetch all meals
        let meals = (try? context.fetch(FetchDescriptor<Meal>())) ?? []

        // Group by day
        let mealsByDay = Dictionary(grouping: meals) { meal in
            Calendar.current.startOfDay(for: meal.timestamp)
        }

        // Create daily aggregates
        for (date, dayMeals) in mealsByDay {
            let aggregate = DailyAggregate(date: date)
            aggregate.mealCount = dayMeals.count
            aggregate.calories = dayMeals.reduce(0) { $0 + $1.calories }
            aggregate.protein = dayMeals.reduce(0) { $0 + $1.protein }
            aggregate.carbs = dayMeals.reduce(0) { $0 + $1.carbs }
            aggregate.fat = dayMeals.reduce(0) { $0 + $1.fat }
            aggregate.fiber = dayMeals.reduce(0) { $0 + $1.fiber }

            // Timing
            let sorted = dayMeals.sorted { $0.timestamp < $1.timestamp }
            aggregate.firstMealTime = sorted.first?.timestamp
            aggregate.lastMealTime = sorted.last?.timestamp

            // Micronutrients
            var profile = MicronutrientProfile()
            for meal in dayMeals {
                for nutrient in meal.micronutrients {
                    addNutrient(nutrient, to: &profile)
                }
            }
            aggregate.updateMicronutrients(profile)

            context.insert(aggregate)
        }

        // Create weekly aggregates
        let calendar = Calendar.current
        let weekStarts = Set(mealsByDay.keys.map { date in
            calendar.dateInterval(of: .weekOfYear, for: date)!.start
        })

        for weekStart in weekStarts {
            await updateWeeklyAggregate(containing: weekStart, in: context)
        }

        // Create monthly aggregates
        var processedMonths: Set<String> = []
        for date in mealsByDay.keys {
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let key = "\(year)-\(month)"

            if !processedMonths.contains(key) {
                processedMonths.insert(key)
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = 1
                let monthStart = calendar.date(from: components)!
                await updateMonthlyAggregate(containing: monthStart, in: context)
            }
        }

        try? context.save()

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("📊 Migration complete: \(mealsByDay.count) daily aggregates in \(String(format: "%.2f", elapsed))s")
    }

    // MARK: - Private Helpers

    private func getOrCreateDailyAggregate(for date: Date, in context: ModelContext) -> DailyAggregate {
        let predicate = #Predicate<DailyAggregate> { $0.date == date }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            return existing
        }

        let aggregate = DailyAggregate(date: date)
        context.insert(aggregate)
        return aggregate
    }

    private func recomputeDailyAggregate(_ aggregate: DailyAggregate, in context: ModelContext) async {
        let date = aggregate.date
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date)!

        let predicate = #Predicate<Meal> { meal in
            meal.timestamp >= date && meal.timestamp < nextDay
        }

        let meals = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []

        aggregate.mealCount = meals.count
        aggregate.calories = meals.reduce(0) { $0 + $1.calories }
        aggregate.protein = meals.reduce(0) { $0 + $1.protein }
        aggregate.carbs = meals.reduce(0) { $0 + $1.carbs }
        aggregate.fat = meals.reduce(0) { $0 + $1.fat }
        aggregate.fiber = meals.reduce(0) { $0 + $1.fiber }

        let sorted = meals.sorted { $0.timestamp < $1.timestamp }
        aggregate.firstMealTime = sorted.first?.timestamp
        aggregate.lastMealTime = sorted.last?.timestamp

        // Micronutrients
        var profile = MicronutrientProfile()
        for meal in meals {
            for nutrient in meal.micronutrients {
                addNutrient(nutrient, to: &profile)
            }
        }
        aggregate.updateMicronutrients(profile)
        aggregate.lastUpdated = Date()
    }

    private func updateWeeklyAggregate(containing date: Date, in context: ModelContext) async {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date)!
        let weekStart = weekInterval.start
        let weekEnd = calendar.date(byAdding: .day, value: -1, to: weekInterval.end)!

        // Get daily aggregates for this week
        let dailyAggregates = fetchDailyAggregates(from: weekStart, to: weekEnd, in: context)

        // Get or create weekly aggregate
        let predicate = #Predicate<WeeklyAggregate> { $0.weekStartDate == weekStart }
        let weeklyAggregate: WeeklyAggregate
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            weeklyAggregate = existing
        } else {
            weeklyAggregate = WeeklyAggregate(weekStartDate: weekStart)
            context.insert(weeklyAggregate)
        }

        // Compute metrics
        let daysWithMeals = dailyAggregates.filter { $0.mealCount > 0 }
        weeklyAggregate.daysWithMeals = daysWithMeals.count
        weeklyAggregate.totalMeals = dailyAggregates.reduce(0) { $0 + $1.mealCount }

        weeklyAggregate.totalCalories = dailyAggregates.reduce(0) { $0 + $1.calories }
        weeklyAggregate.totalProtein = dailyAggregates.reduce(0) { $0 + $1.protein }
        weeklyAggregate.totalCarbs = dailyAggregates.reduce(0) { $0 + $1.carbs }
        weeklyAggregate.totalFat = dailyAggregates.reduce(0) { $0 + $1.fat }

        if daysWithMeals.count > 0 {
            weeklyAggregate.avgCalories = weeklyAggregate.totalCalories / Double(daysWithMeals.count)
            weeklyAggregate.avgProtein = weeklyAggregate.totalProtein / Double(daysWithMeals.count)
            weeklyAggregate.avgCarbs = weeklyAggregate.totalCarbs / Double(daysWithMeals.count)
            weeklyAggregate.avgFat = weeklyAggregate.totalFat / Double(daysWithMeals.count)
        }

        weeklyAggregate.consistencyScore = Double(daysWithMeals.count) / 7.0 * 100

        // Goal achievement
        let goals = DailyGoals.standard
        weeklyAggregate.daysMetCalorieGoal = dailyAggregates.filter {
            $0.calories >= goals.calories * 0.9 && $0.calories <= goals.calories * 1.1
        }.count
        weeklyAggregate.daysMetProteinGoal = dailyAggregates.filter {
            $0.protein >= goals.protein * 0.9
        }.count

        // Aggregate micronutrients from daily aggregates
        var microProfile = MicronutrientProfile()
        for daily in dailyAggregates {
            let nutrients = daily.micronutrients
            // Minerals
            microProfile.calcium += nutrients.calcium
            microProfile.iron += nutrients.iron
            microProfile.magnesium += nutrients.magnesium
            microProfile.potassium += nutrients.potassium
            microProfile.zinc += nutrients.zinc
            microProfile.sodium += nutrients.sodium
            microProfile.phosphorus += nutrients.phosphorus
            microProfile.copper += nutrients.copper
            microProfile.selenium += nutrients.selenium
            // Vitamins
            microProfile.vitaminA += nutrients.vitaminA
            microProfile.vitaminC += nutrients.vitaminC
            microProfile.vitaminD += nutrients.vitaminD
            microProfile.vitaminE += nutrients.vitaminE
            microProfile.vitaminB12 += nutrients.vitaminB12
            microProfile.folate += nutrients.folate
            microProfile.vitaminK += nutrients.vitaminK
            microProfile.vitaminB1 += nutrients.vitaminB1
            microProfile.vitaminB2 += nutrients.vitaminB2
            microProfile.vitaminB3 += nutrients.vitaminB3
            microProfile.vitaminB5 += nutrients.vitaminB5
            microProfile.vitaminB6 += nutrients.vitaminB6
        }
        weeklyAggregate.updateMicronutrients(microProfile)

        weeklyAggregate.lastUpdated = Date()
    }

    private func updateMonthlyAggregate(containing date: Date, in context: ModelContext) async {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        // Get date range for month
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = month
        startComponents.day = 1
        let monthStart = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.year = year
        endComponents.month = month + 1
        endComponents.day = 0
        let monthEnd = calendar.date(from: endComponents)!

        // Get daily aggregates for this month
        let dailyAggregates = fetchDailyAggregates(from: monthStart, to: monthEnd, in: context)

        // Get or create monthly aggregate
        let predicate = #Predicate<MonthlyAggregate> { $0.year == year && $0.month == month }
        let monthlyAggregate: MonthlyAggregate
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            monthlyAggregate = existing
        } else {
            monthlyAggregate = MonthlyAggregate(year: year, month: month)
            context.insert(monthlyAggregate)
        }

        // Compute totals
        monthlyAggregate.totalCalories = dailyAggregates.reduce(0) { $0 + $1.calories }
        monthlyAggregate.totalProtein = dailyAggregates.reduce(0) { $0 + $1.protein }
        monthlyAggregate.totalCarbs = dailyAggregates.reduce(0) { $0 + $1.carbs }
        monthlyAggregate.totalFat = dailyAggregates.reduce(0) { $0 + $1.fat }

        let daysWithMeals = dailyAggregates.filter { $0.mealCount > 0 }
        monthlyAggregate.daysTracked = daysWithMeals.count

        if daysWithMeals.count > 0 {
            monthlyAggregate.avgDailyCalories = monthlyAggregate.totalCalories / Double(daysWithMeals.count)
            monthlyAggregate.avgDailyProtein = monthlyAggregate.totalProtein / Double(daysWithMeals.count)
            monthlyAggregate.avgDailyCarbs = monthlyAggregate.totalCarbs / Double(daysWithMeals.count)
            monthlyAggregate.avgDailyFat = monthlyAggregate.totalFat / Double(daysWithMeals.count)
        }

        // Consistency
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count
        monthlyAggregate.consistencyScore = Double(daysWithMeals.count) / Double(daysInMonth) * 100

        // Goal achievement
        let goals = DailyGoals.standard
        monthlyAggregate.daysMetCalorieGoal = dailyAggregates.filter {
            $0.calories >= goals.calories * 0.9 && $0.calories <= goals.calories * 1.1
        }.count
        monthlyAggregate.daysMetProteinGoal = dailyAggregates.filter {
            $0.protein >= goals.protein * 0.9
        }.count
        monthlyAggregate.daysMetCarbsGoal = dailyAggregates.filter {
            $0.carbs >= goals.carbs * 0.8 && $0.carbs <= goals.carbs * 1.2
        }.count
        monthlyAggregate.daysMetFatGoal = dailyAggregates.filter {
            $0.fat >= goals.fat * 0.8 && $0.fat <= goals.fat * 1.2
        }.count

        // Calculate longest streak
        var longestStreak = 0
        var currentStreak = 0
        for aggregate in dailyAggregates.sorted(by: { $0.date < $1.date }) {
            if aggregate.mealCount > 0 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        monthlyAggregate.longestStreak = longestStreak

        // Aggregate micronutrients from daily aggregates
        var microProfile = MicronutrientProfile()
        for daily in dailyAggregates {
            let nutrients = daily.micronutrients
            // Minerals
            microProfile.calcium += nutrients.calcium
            microProfile.iron += nutrients.iron
            microProfile.magnesium += nutrients.magnesium
            microProfile.potassium += nutrients.potassium
            microProfile.zinc += nutrients.zinc
            microProfile.sodium += nutrients.sodium
            microProfile.phosphorus += nutrients.phosphorus
            microProfile.copper += nutrients.copper
            microProfile.selenium += nutrients.selenium
            // Vitamins
            microProfile.vitaminA += nutrients.vitaminA
            microProfile.vitaminC += nutrients.vitaminC
            microProfile.vitaminD += nutrients.vitaminD
            microProfile.vitaminE += nutrients.vitaminE
            microProfile.vitaminB12 += nutrients.vitaminB12
            microProfile.folate += nutrients.folate
            microProfile.vitaminK += nutrients.vitaminK
            microProfile.vitaminB1 += nutrients.vitaminB1
            microProfile.vitaminB2 += nutrients.vitaminB2
            microProfile.vitaminB3 += nutrients.vitaminB3
            microProfile.vitaminB5 += nutrients.vitaminB5
            microProfile.vitaminB6 += nutrients.vitaminB6
        }
        monthlyAggregate.updateMicronutrients(microProfile)

        monthlyAggregate.lastUpdated = Date()
    }

    private func addNutrient(_ nutrient: Micronutrient, to profile: inout MicronutrientProfile) {
        switch nutrient.name {
        // Original minerals
        case "Calcium": profile.calcium += nutrient.amount
        case "Iron": profile.iron += nutrient.amount
        case "Magnesium": profile.magnesium += nutrient.amount
        case "Potassium": profile.potassium += nutrient.amount
        case "Zinc": profile.zinc += nutrient.amount
        case "Sodium": profile.sodium += nutrient.amount
        // New minerals
        case "Phosphorus": profile.phosphorus += nutrient.amount
        case "Copper": profile.copper += nutrient.amount
        case "Selenium": profile.selenium += nutrient.amount
        // Original vitamins
        case "Vitamin A": profile.vitaminA += nutrient.amount
        case "Vitamin C": profile.vitaminC += nutrient.amount
        case "Vitamin D": profile.vitaminD += nutrient.amount
        case "Vitamin E": profile.vitaminE += nutrient.amount
        case "Vitamin B12": profile.vitaminB12 += nutrient.amount
        case "Folate", "Folate (Vitamin B9)": profile.folate += nutrient.amount
        // New vitamins
        case "Vitamin K": profile.vitaminK += nutrient.amount
        case "Thiamin", "Vitamin B1 (Thiamin)": profile.vitaminB1 += nutrient.amount
        case "Riboflavin", "Vitamin B2 (Riboflavin)": profile.vitaminB2 += nutrient.amount
        case "Niacin", "Vitamin B3 (Niacin)": profile.vitaminB3 += nutrient.amount
        case "Pantothenic acid", "Vitamin B5 (Pantothenic Acid)": profile.vitaminB5 += nutrient.amount
        case "Vitamin B-6", "Vitamin B6": profile.vitaminB6 += nutrient.amount
        default: break
        }
    }
}
