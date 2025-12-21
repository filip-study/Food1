//
//  MealReminderAttributes.swift
//  Food1
//
//  ActivityKit attributes for meal reminder Live Activities.
//  Shared between main app (ActivityKit) and Widget Extension (WidgetKit).
//
//  WHY THIS ARCHITECTURE:
//  - ActivityAttributes defines the static context (meal name, target time)
//  - ContentState defines dynamic data that can be updated (remaining time, status)
//  - Both main app and widget extension import this file
//  - ActivityKit handles state synchronization automatically
//

import ActivityKit
import Foundation

/// Attributes for meal reminder Live Activity
struct MealReminderAttributes: ActivityAttributes {

    // MARK: - Content State (Dynamic)

    /// Dynamic content that can be updated while activity is running
    public struct ContentState: Codable, Hashable {
        /// Current status of the reminder
        var status: ReminderStatus

        /// Time the activity should auto-dismiss (for countdown display)
        var dismissAt: Date

        /// User's calorie progress for today (optional, for rich display)
        var todayCalories: Int?

        /// User's calorie goal (optional)
        var calorieGoal: Int?
    }

    // MARK: - Static Attributes

    /// Name of the meal window (e.g., "Lunch", "Dinner")
    var mealName: String

    /// Target time for this meal
    var targetTime: Date

    /// Meal window ID (for identifying which window triggered this)
    var windowId: UUID

    /// Icon name for the meal (SF Symbol)
    var iconName: String
}

// MARK: - Reminder Status

/// Status of the meal reminder
enum ReminderStatus: String, Codable, Hashable {
    /// Reminder is active, waiting for user action
    case active

    /// User dismissed the reminder manually
    case dismissed

    /// User tapped "Log Meal" - opening app
    case logging

    /// Activity is about to auto-dismiss
    case expiring
}

// MARK: - Activity Stale Date

extension MealReminderAttributes {
    /// How long after target time before activity becomes stale
    /// (iOS may remove stale activities automatically)
    static let staleAfterMinutes: Int = 240  // 4 hours
}
