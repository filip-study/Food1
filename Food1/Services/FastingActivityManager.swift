//
//  FastingActivityManager.swift
//  Food1
//
//  Service for managing fasting Live Activities on lock screen and Dynamic Island.
//
//  WHY THIS ARCHITECTURE:
//  - Singleton for centralized fasting activity management
//  - Only ONE activity at a time (unlike meal reminders with multiple windows)
//  - Uses native Text(_:style:.timer) for automatic timer updates (battery efficient)
//  - Stage info is pushed only when fasting stage changes (~every 4-12 hours)
//  - Coordinates with MealActivityScheduler to suppress meal reminders during fasting
//

import Foundation
import ActivityKit
import Combine
import UIKit
import os.log

private let logger = Logger(subsystem: "com.prismae.food1", category: "FastingActivity")

/// Manages fasting Live Activities
@MainActor
class FastingActivityManager: ObservableObject {

    // MARK: - Singleton

    static let shared = FastingActivityManager()

    // MARK: - Published State

    /// Currently active fasting Live Activity (only one at a time)
    @Published private(set) var currentActivity: Activity<FastingActivityAttributes>?

    /// Whether a fasting activity is currently active
    var isActivityActive: Bool {
        currentActivity != nil
    }

    // MARK: - Demo Mode

    /// Whether demo mode is active (720x time acceleration)
    /// In demo mode: 1 real second = 720 simulated seconds (1 hour = 5 seconds)
    private var demoMode: Bool = false

    /// The Fast being tracked (needed for timer updates)
    private var trackedFast: Fast?

    // MARK: - Stage Timer

    /// Timer for periodic stage updates
    private var stageUpdateTimer: Timer?

    // MARK: - Initialization

    private init() {
        // Restore any active fasting activity from ActivityKit
        Task {
            await restoreActiveActivity()
        }

        // Observe app foreground to immediately refresh activity state
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshActivityOnForeground()
            }
        }
    }

    /// Refresh activity state when app comes to foreground
    /// Ensures elapsed time is immediately up-to-date
    private func refreshActivityOnForeground() async {
        guard let fast = trackedFast, currentActivity != nil else { return }
        logger.debug("Refreshing fasting activity on foreground")
        await updateActivityState(for: fast)
    }

    // MARK: - Activity Lifecycle

    /// Start a Live Activity for the given fast
    /// - Parameters:
    ///   - fast: The Fast to track
    ///   - demoMode: If true, uses 720x time acceleration for testing
    func startActivity(for fast: Fast, demoMode: Bool = false) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Cannot start fasting activity - Live Activities not authorized")
            return
        }

        // Don't start if already have an active activity
        guard currentActivity == nil else {
            logger.debug("Fasting activity already exists")
            return
        }

        // Check ActivityKit's list for existing fasting activities
        if !Activity<FastingActivityAttributes>.activities.isEmpty {
            logger.debug("Fasting activity exists in ActivityKit")
            return
        }

        // Store demo mode and fast reference
        self.demoMode = demoMode
        self.trackedFast = fast

        let attributes = FastingActivityAttributes(
            fastId: fast.id,
            startTime: fast.startTime
        )

        let initialState = createContentState(for: fast)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )

            currentActivity = activity
            logger.info("✅ Started fasting Live Activity: \(activity.id) (demoMode: \(demoMode))")

            // Start stage update timer (faster in demo mode)
            startStageUpdateTimer()

            // Suppress meal reminders while fasting
            await suppressMealReminders()

        } catch {
            logger.error("❌ Failed to start fasting activity: \(error.localizedDescription)")
        }
    }

    /// Update activity state (called periodically for stage changes)
    func updateActivityState(for fast: Fast) async {
        guard let activity = currentActivity else {
            logger.debug("No fasting activity to update")
            return
        }

        let newState = createContentState(for: fast)
        await activity.update(.init(state: newState, staleDate: nil))
        logger.debug("Updated fasting activity state: stage=\(newState.stageName)")
    }

    /// End the fasting Live Activity
    func endActivity() async {
        guard let activity = currentActivity else {
            logger.info("No fasting activity to end")
            return
        }

        // Stop the stage update timer
        stageUpdateTimer?.invalidate()
        stageUpdateTimer = nil

        // Create final state
        let finalState = FastingActivityAttributes.ContentState(
            stageName: "Ended",
            stageIndex: 0,
            secondsToNextStage: nil,
            elapsedDisplay: "—",
            stageProgress: 1.0
        )

        await activity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        currentActivity = nil
        trackedFast = nil
        demoMode = false
        logger.info("✅ Ended fasting Live Activity")

        // Resume meal reminders
        await resumeMealReminders()
    }

    // MARK: - Stage Update Timer

    /// Start timer to update stage info periodically
    private func startStageUpdateTimer() {
        // In demo mode: update every 1 second (since time is 720x faster)
        // In normal mode: update every 60 seconds
        let interval: TimeInterval = demoMode ? 1.0 : 60.0

        stageUpdateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let fast = self.trackedFast else { return }
                await self.updateActivityState(for: fast)
            }
        }
    }

    // MARK: - Meal Reminder Coordination

    /// Suppress meal reminder activities while fasting
    private func suppressMealReminders() async {
        logger.info("Suppressing meal reminders during fasting")
        await MealActivityScheduler.shared.endAllActivities(reason: .fasting)
    }

    /// Resume meal reminder scheduling after fast ends
    private func resumeMealReminders() async {
        logger.info("Resuming meal reminders after fasting")
        await MealActivityScheduler.shared.checkAndScheduleActivities()
    }

    // MARK: - Restore Activity

    /// Restore active fasting activity after app restart
    private func restoreActiveActivity() async {
        for activity in Activity<FastingActivityAttributes>.activities {
            currentActivity = activity
            logger.info("Restored fasting activity: \(activity.id)")
            break  // Only one fasting activity at a time
        }
    }

    // MARK: - Content State

    /// Create content state based on current fasting progress
    private func createContentState(for fast: Fast) -> FastingActivityAttributes.ContentState {
        // Use demo-mode-aware duration calculation
        let durationSeconds = fast.durationSeconds(demoMode: demoMode)
        let stage = FastingStage.stage(forDurationSeconds: durationSeconds)
        let progress = stage.progress(forDurationSeconds: durationSeconds)

        // Calculate seconds to next stage using demo-aware duration
        let secondsToNext = calculateSecondsToNextStage(stage: stage, durationSeconds: durationSeconds)

        // Format elapsed time from demo-aware duration
        let elapsed = formatElapsedCompact(seconds: durationSeconds)

        // In demo mode, format countdown as string (native iOS timer uses real time)
        // In normal mode, pass nil to use battery-efficient native timer
        let countdown: String? = if demoMode, let seconds = secondsToNext {
            formatCountdown(seconds: seconds)
        } else {
            nil
        }

        return FastingActivityAttributes.ContentState(
            stageName: stage.title,
            stageIndex: stage.activityIndex,
            secondsToNextStage: secondsToNext,
            elapsedDisplay: elapsed,
            stageProgress: progress,
            countdownDisplay: countdown
        )
    }

    /// Calculate seconds until next stage based on current duration
    private func calculateSecondsToNextStage(stage: FastingStage, durationSeconds: Int) -> Int? {
        guard let endHour = stage.endHour else {
            return nil  // Extended stage has no next stage
        }
        let endSeconds = endHour * 3600
        return max(endSeconds - durationSeconds, 0)
    }

    /// Format elapsed time compactly (e.g., "45m", "2h", "1d")
    private func formatElapsedCompact(seconds: Int) -> String {
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            let remainingHours = hours % 24
            return remainingHours > 0 ? "\(days)d \(remainingHours)h" : "\(days)d"
        } else if hours > 0 {
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        } else {
            return "\(max(1, minutes))m"
        }
    }

    /// Format countdown time (e.g., "1:30:45" or "45:30")
    /// Used in demo mode where native iOS timer doesn't work
    private func formatCountdown(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - FastingStage Extension

extension FastingStage {
    /// Index for Live Activity styling (matches FastingLiveActivity.stageColor)
    var activityIndex: Int {
        rawValue  // Already 0-3 via enum raw values
    }
}
