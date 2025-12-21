//
//  MealPatternAnalyzer.swift
//  Food1
//
//  Analyzes meal logging patterns to optimize reminder times.
//  Learns from historical data to adjust when Live Activities appear.
//
//  WHY THIS ARCHITECTURE:
//  - Analyzes local SwiftData meals (no API calls needed)
//  - Uses rolling 2-week window for recency bias
//  - Clusters meal times by hour to detect patterns
//  - Updates learned_time in meal_windows when pattern is strong enough
//  - Conservative: requires minimum data points before adjusting
//

import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.prismae.food1", category: "PatternAnalyzer")

/// Analyzes meal logging patterns for smart reminder timing
@MainActor
class MealPatternAnalyzer {

    // MARK: - Configuration

    /// Minimum meals in a time cluster to consider it valid
    private let minimumClusterSize = 5

    /// How many weeks of data to analyze
    private let analysisWeeks = 2

    /// Maximum adjustment from user's set time (in minutes)
    private let maxAdjustmentMinutes = 60

    // MARK: - Analysis

    /// Analyze meal patterns and update learned times
    /// - Parameters:
    ///   - modelContext: SwiftData context for querying meals
    ///   - windows: Current meal windows to analyze
    /// - Returns: Updated windows with learned times
    func analyzeAndUpdateWindows(
        modelContext: ModelContext,
        windows: [MealWindow]
    ) -> [MealWindow] {

        // Fetch recent meals
        let cutoffDate = Calendar.current.date(
            byAdding: .weekOfYear,
            value: -analysisWeeks,
            to: Date()
        ) ?? Date()

        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { $0.timestamp >= cutoffDate },
            sortBy: [SortDescriptor(\.timestamp)]
        )

        guard let meals = try? modelContext.fetch(descriptor), !meals.isEmpty else {
            logger.info("No recent meals for pattern analysis")
            return windows
        }

        logger.info("Analyzing \(meals.count) meals from last \(self.analysisWeeks) weeks")

        // Group meals by time of day
        let mealsByHour = groupMealsByHour(meals)

        // Update each window with learned time
        var updatedWindows = windows

        for (index, window) in windows.enumerated() {
            if let learnedTime = findBestTimeForWindow(
                window: window,
                mealsByHour: mealsByHour
            ) {
                updatedWindows[index] = MealWindow(
                    id: window.id,
                    userId: window.userId,
                    name: window.name,
                    targetTime: window.targetTime,
                    learnedTime: learnedTime,
                    isEnabled: window.isEnabled,
                    sortOrder: window.sortOrder,
                    createdAt: window.createdAt,
                    updatedAt: Date()
                )

                logger.info("Window '\(window.name)': learned time \(learnedTime.displayString) (was \(window.targetTime.displayString))")
            }
        }

        return updatedWindows
    }

    // MARK: - Grouping

    /// Group meals by hour of day
    private func groupMealsByHour(_ meals: [Meal]) -> [Int: [Date]] {
        var grouped: [Int: [Date]] = [:]

        for meal in meals {
            let hour = Calendar.current.component(.hour, from: meal.timestamp)
            grouped[hour, default: []].append(meal.timestamp)
        }

        return grouped
    }

    // MARK: - Pattern Detection

    /// Find the best learned time for a meal window
    private func findBestTimeForWindow(
        window: MealWindow,
        mealsByHour: [Int: [Date]]
    ) -> TimeComponents? {

        let targetHour = window.targetTime.hour

        // Look at hours within adjustment range
        let minHour = max(0, targetHour - (maxAdjustmentMinutes / 60 + 1))
        let maxHour = min(23, targetHour + (maxAdjustmentMinutes / 60 + 1))

        var bestHour = targetHour
        var bestCount = 0
        var bestAverageMinute = 0

        for hour in minHour...maxHour {
            let mealsInHour = mealsByHour[hour] ?? []

            if mealsInHour.count >= minimumClusterSize && mealsInHour.count > bestCount {
                bestHour = hour
                bestCount = mealsInHour.count

                // Calculate average minute within that hour
                let minutes = mealsInHour.map { Calendar.current.component(.minute, from: $0) }
                bestAverageMinute = minutes.reduce(0, +) / minutes.count
            }
        }

        // Only return learned time if we found a strong pattern
        guard bestCount >= minimumClusterSize else {
            return nil
        }

        // Check if adjustment is within limits
        let learnedTime = TimeComponents(hour: bestHour, minute: bestAverageMinute)
        let adjustment = abs(learnedTime.totalMinutes - window.targetTime.totalMinutes)

        guard adjustment <= maxAdjustmentMinutes else {
            logger.info("Adjustment \(adjustment)min exceeds limit for '\(window.name)'")
            return nil
        }

        return learnedTime
    }

    // MARK: - Meal Window Detection

    /// Detect which meal window a meal belongs to (for learning)
    func detectMealWindow(
        for mealTime: Date,
        windows: [MealWindow]
    ) -> MealWindow? {

        let mealComponents = TimeComponents(from: mealTime)
        let mealMinutes = mealComponents.totalMinutes

        // Find closest window within 2 hours
        let maxDifferenceMinutes = 120

        var closestWindow: MealWindow?
        var closestDifference = Int.max

        for window in windows where window.isEnabled {
            let windowMinutes = window.effectiveTime.totalMinutes
            let difference = abs(mealMinutes - windowMinutes)

            if difference < closestDifference && difference <= maxDifferenceMinutes {
                closestDifference = difference
                closestWindow = window
            }
        }

        return closestWindow
    }
}

// MARK: - Analysis Result

extension MealPatternAnalyzer {

    /// Result of pattern analysis for UI display
    struct AnalysisResult {
        let windowId: UUID
        let windowName: String
        let targetTime: TimeComponents
        let learnedTime: TimeComponents?
        let mealCount: Int
        let confidence: ConfidenceLevel
    }

    enum ConfidenceLevel: String {
        case none = "Not enough data"
        case low = "Emerging pattern"
        case medium = "Consistent pattern"
        case high = "Strong pattern"

        init(mealCount: Int) {
            switch mealCount {
            case 0..<5: self = .none
            case 5..<10: self = .low
            case 10..<20: self = .medium
            default: self = .high
            }
        }
    }
}
