//
//  MealActivityScheduler.swift
//  Food1
//
//  Core service for managing meal reminder Live Activities.
//  Handles activity lifecycle, scheduling, and coordination with pattern learning.
//
//  WHY THIS ARCHITECTURE:
//  - Singleton for centralized activity management
//  - Uses ActivityKit for Live Activity lifecycle (start/update/end)
//  - Background refresh via BGTaskScheduler for auto-start/dismiss
//  - Separates scheduling logic from UI rendering (Widget Extension handles UI)
//  - Stores active activities in memory (ActivityKit persists across app restarts)
//

import Foundation
import UIKit
import ActivityKit
import BackgroundTasks
import Combine
import Supabase
import os.log

private let logger = Logger(subsystem: "com.prismae.food1", category: "MealActivityScheduler")

/// Background task identifier for meal reminder scheduling
let mealReminderTaskIdentifier = "com.prismae.food1.meal-reminder-check"

/// Manages meal reminder Live Activities
@MainActor
class MealActivityScheduler: ObservableObject {

    // MARK: - Singleton

    static let shared = MealActivityScheduler()

    // MARK: - Published State

    /// Currently active Live Activities by window ID
    @Published private(set) var activeActivities: [UUID: Activity<MealReminderAttributes>] = [:]

    /// User's meal windows (loaded from Supabase)
    @Published var mealWindows: [MealWindow] = []

    /// User's reminder settings (loaded from Supabase)
    @Published var settings: MealReminderSettings?

    /// Whether the feature is enabled and configured
    var isEnabled: Bool {
        settings?.isEnabled ?? false
    }

    // MARK: - Services

    private let supabase = SupabaseService.shared

    // MARK: - Initialization

    private init() {
        // Restore any active activities from ActivityKit
        Task {
            await restoreActiveActivities()
        }
    }

    // MARK: - Load Settings

    /// Load meal windows and settings from Supabase
    func loadSettings() async throws {
        let userId = try await supabase.requireUserId()

        // Load settings
        do {
            let settingsResponse: MealReminderSettings = try await supabase.client
                .from("meal_reminder_settings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value

            self.settings = settingsResponse
            logger.info("Loaded meal reminder settings: enabled=\(settingsResponse.isEnabled)")
        } catch {
            // Settings don't exist yet - that's ok for new users
            logger.info("No meal reminder settings found, user needs onboarding")
            self.settings = nil
        }

        // Load meal windows
        do {
            let windowsResponse: [MealWindow] = try await supabase.client
                .from("meal_windows")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("sort_order")
                .execute()
                .value

            self.mealWindows = windowsResponse
            logger.info("Loaded \(windowsResponse.count) meal windows")
        } catch {
            logger.warning("Failed to load meal windows: \(error.localizedDescription)")
            self.mealWindows = []
        }
    }

    // MARK: - Save Settings

    /// Save meal reminder settings to Supabase
    func saveSettings(_ newSettings: MealReminderSettings) async throws {
        try await supabase.client
            .from("meal_reminder_settings")
            .upsert(newSettings.insertPayload)
            .execute()

        self.settings = newSettings
        logger.info("Saved meal reminder settings")

        // Reschedule activities based on new settings
        await checkAndScheduleActivities()
    }

    /// Save meal windows to Supabase
    func saveMealWindows(_ windows: [MealWindow]) async throws {
        let userId = try await supabase.requireUserId()

        // Delete existing windows
        try await supabase.client
            .from("meal_windows")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()

        // Insert new windows with correct user ID
        let payloads = windows.map { window in
            MealWindow.InsertPayload(
                id: window.id,
                userId: userId,
                name: window.name,
                targetTime: window.targetTime,
                learnedTime: window.learnedTime,
                isEnabled: window.isEnabled,
                sortOrder: window.sortOrder
            )
        }

        if !payloads.isEmpty {
            try await supabase.client
                .from("meal_windows")
                .insert(payloads)
                .execute()
        }

        self.mealWindows = windows
        logger.info("Saved \(windows.count) meal windows")

        // Reschedule activities
        await checkAndScheduleActivities()
    }

    // MARK: - Activity Lifecycle

    /// Check current time and start/end activities as needed
    func checkAndScheduleActivities() async {
        guard isEnabled else {
            logger.info("Meal reminders disabled, ending all activities")
            await endAllActivities(reason: .disabled)
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities not authorized by user")
            return
        }

        let now = Date()
        let leadTime = settings?.leadTimeInterval ?? 2700  // 45 min default
        let dismissTime = settings?.autoDismissInterval ?? 7200  // 2 hours default

        for window in mealWindows where window.isEnabled {
            let mealTime = window.dateForToday()

            // Calculate activity window
            let startTime = mealTime.addingTimeInterval(-leadTime)
            let endTime = mealTime.addingTimeInterval(dismissTime)

            let isWithinWindow = now >= startTime && now <= endTime
            let hasActiveActivity = activeActivities[window.id] != nil

            if isWithinWindow && !hasActiveActivity {
                // Should have activity but don't - start one
                await startActivity(for: window)
            } else if !isWithinWindow && hasActiveActivity {
                // Have activity but outside window - end it
                await endActivity(for: window.id, reason: .expired)
            }
        }

        // Schedule next check
        scheduleBackgroundCheck()
    }

    /// Start a Live Activity for a meal window
    /// NOTE: ActivityKit CAN start activities from background app refresh tasks.
    /// The activity will appear on lock screen regardless of app state.
    func startActivity(for window: MealWindow) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Cannot start activity - not authorized by user in Settings")
            return
        }

        // Don't start if already active
        guard activeActivities[window.id] == nil else {
            logger.debug("Activity already exists for window: \(window.name)")
            return
        }

        // Also check ActivityKit's list in case our cache is stale
        let existingActivities = Activity<MealReminderAttributes>.activities
        if existingActivities.contains(where: { $0.attributes.windowId == window.id }) {
            logger.debug("Activity exists in ActivityKit for window: \(window.name)")
            return
        }

        let dismissAt = window.dateForToday().addingTimeInterval(settings?.autoDismissInterval ?? 7200)

        let attributes = MealReminderAttributes(
            mealName: window.name,
            targetTime: window.dateForToday(),
            windowId: window.id,
            iconName: window.icon
        )

        let initialState = MealReminderAttributes.ContentState(
            status: .active,
            dismissAt: dismissAt
        )

        // Log app state for debugging background execution
        let appState = await MainActor.run { UIApplication.shared.applicationState }
        let stateDescription = switch appState {
            case .active: "foreground"
            case .inactive: "inactive"
            case .background: "background"
            @unknown default: "unknown"
        }
        logger.info("Attempting to start activity for \(window.name) from \(stateDescription) state")

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: dismissAt),
                pushType: nil
            )

            activeActivities[window.id] = activity
            logger.info("✅ Started Live Activity for: \(window.name), id=\(activity.id)")

        } catch let error as ActivityAuthorizationError {
            logger.error("❌ Activity authorization error for \(window.name): \(error.localizedDescription)")
        } catch {
            logger.error("❌ Failed to start Live Activity for \(window.name): \(error.localizedDescription), error type: \(type(of: error))")
        }
    }

    /// Update activity state (e.g., when user taps "Log Meal")
    func updateActivityState(for windowId: UUID, to status: ReminderStatus) async {
        guard let activity = activeActivities[windowId] else {
            logger.warning("No activity found for window: \(windowId)")
            return
        }

        let newState = MealReminderAttributes.ContentState(
            status: status,
            dismissAt: activity.content.state.dismissAt,
            todayCalories: activity.content.state.todayCalories,
            calorieGoal: activity.content.state.calorieGoal
        )

        await activity.update(.init(state: newState, staleDate: nil))
        logger.info("Updated activity state to: \(status.rawValue)")
    }

    /// End a specific activity
    func endActivity(for windowId: UUID, reason: EndReason) async {
        guard let activity = activeActivities[windowId] else {
            logger.info("No activity to end for window: \(windowId)")
            return
        }

        let finalState = MealReminderAttributes.ContentState(
            status: reason == .dismissed ? .dismissed : .expiring,
            dismissAt: Date()
        )

        await activity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        activeActivities.removeValue(forKey: windowId)
        logger.info("Ended activity for window: \(windowId), reason: \(reason.rawValue)")
    }

    /// End all active activities
    func endAllActivities(reason: EndReason) async {
        for windowId in activeActivities.keys {
            await endActivity(for: windowId, reason: reason)
        }
    }

    // MARK: - Restore Activities

    /// Restore active activities after app restart
    private func restoreActiveActivities() async {
        for activity in Activity<MealReminderAttributes>.activities {
            let windowId = activity.attributes.windowId
            activeActivities[windowId] = activity
            logger.info("Restored activity for: \(activity.attributes.mealName)")
        }
    }

    // MARK: - Background Scheduling

    /// Register background task handler
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: mealReminderTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                guard let refreshTask = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                await MealActivityScheduler.shared.handleBackgroundTask(refreshTask)
            }
        }
    }

    /// Handle background refresh task
    func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        logger.info("🔄 Background task executing at \(Date())")

        // Set expiration handler
        task.expirationHandler = {
            logger.warning("⚠️ Background task expired before completion")
            task.setTaskCompleted(success: false)
        }

        // Check and update activities
        await checkAndScheduleActivities()

        logger.info("✅ Background task completed successfully")
        task.setTaskCompleted(success: true)
    }

    /// Schedule next background check
    /// NOTE: iOS does NOT guarantee background tasks run at the requested time.
    /// We schedule for ideal time but also rely on app foreground events as primary trigger.
    func scheduleBackgroundCheck() {
        guard isEnabled else {
            logger.debug("Skipping background schedule - reminders disabled")
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: mealReminderTaskIdentifier)

        // Find next meal window start time (including tomorrow if needed)
        if let nextStartTime = nextActivityStartTime() {
            // Schedule slightly before the ideal time to give iOS flexibility
            let scheduledTime = nextStartTime.addingTimeInterval(-300) // 5 min buffer
            request.earliestBeginDate = scheduledTime

            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            logger.info("📅 Scheduled background check for \(formatter.string(from: scheduledTime)) (next meal: \(formatter.string(from: nextStartTime)))")
        } else {
            // No upcoming meals today - schedule periodic check every 2 hours as fallback
            request.earliestBeginDate = Date().addingTimeInterval(7200)
            logger.info("📅 Scheduled fallback background check in 2 hours")
        }

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch BGTaskScheduler.Error.unavailable {
            logger.warning("⚠️ Background tasks unavailable (likely simulator or restricted)")
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            logger.debug("Background task already scheduled")
        } catch {
            logger.error("❌ Failed to schedule background task: \(error.localizedDescription)")
        }
    }

    /// Calculate next activity start time (includes tomorrow if all today's meals are past)
    private func nextActivityStartTime() -> Date? {
        guard isEnabled else { return nil }

        let now = Date()
        let leadTime = settings?.leadTimeInterval ?? 2700

        // Try today's meals first
        var startTimes = mealWindows
            .filter { $0.isEnabled }
            .map { $0.dateForToday().addingTimeInterval(-leadTime) }
            .filter { $0 > now }
            .sorted()

        if let nextToday = startTimes.first {
            return nextToday
        }

        // All today's meals are past - look at tomorrow
        let tomorrow = now.addingDays(1)
        startTimes = mealWindows
            .filter { $0.isEnabled }
            .map { window in
                window.dateFor(date: tomorrow).addingTimeInterval(-leadTime)
            }
            .sorted()

        return startTimes.first
    }
}

// MARK: - End Reason

extension MealActivityScheduler {
    enum EndReason: String {
        case dismissed   // User dismissed manually
        case expired     // Auto-dismissed after timeout
        case disabled    // Feature was disabled
        case logged      // User logged a meal
    }
}
