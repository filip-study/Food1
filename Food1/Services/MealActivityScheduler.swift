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
    func startActivity(for window: MealWindow) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Cannot start activity - not authorized")
            return
        }

        // Ensure app is in foreground - Live Activities can only be started from foreground
        guard await MainActor.run(body: {
            UIApplication.shared.applicationState == .active
        }) else {
            logger.debug("Skipping activity start - app not in foreground")
            return
        }

        // Small delay to ensure ActivityKit is ready (race condition fix)
        try? await Task.sleep(for: .milliseconds(100))

        // Don't start if already active
        guard activeActivities[window.id] == nil else {
            logger.info("Activity already exists for window: \(window.name)")
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

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: dismissAt),
                pushType: nil  // No push updates for now
            )

            activeActivities[window.id] = activity
            logger.info("Started Live Activity for: \(window.name), id=\(activity.id), state=\(String(describing: activity.activityState))")

            // Log all current activities for debugging
            let allActivities = Activity<MealReminderAttributes>.activities
            logger.debug("Total active activities: \(allActivities.count)")
            for act in allActivities {
                logger.debug("  - \(act.attributes.mealName): state=\(String(describing: act.activityState))")
            }

        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
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
                await MealActivityScheduler.shared.handleBackgroundTask(task as! BGAppRefreshTask)
            }
        }
    }

    /// Handle background refresh task
    func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        logger.info("Background task running")

        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Check and update activities
        await checkAndScheduleActivities()

        task.setTaskCompleted(success: true)
    }

    /// Schedule next background check
    func scheduleBackgroundCheck() {
        let request = BGAppRefreshTaskRequest(identifier: mealReminderTaskIdentifier)

        // Find next meal window start time
        if let nextStartTime = nextActivityStartTime() {
            request.earliestBeginDate = nextStartTime
            logger.info("Scheduled background check for: \(nextStartTime)")
        } else {
            // Default to 1 hour from now
            request.earliestBeginDate = Date().addingTimeInterval(3600)
        }

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to schedule background task: \(error.localizedDescription)")
        }
    }

    /// Calculate next activity start time
    private func nextActivityStartTime() -> Date? {
        guard isEnabled else { return nil }

        let now = Date()
        let leadTime = settings?.leadTimeInterval ?? 2700

        let startTimes = mealWindows
            .filter { $0.isEnabled }
            .map { $0.dateForToday().addingTimeInterval(-leadTime) }
            .filter { $0 > now }
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
