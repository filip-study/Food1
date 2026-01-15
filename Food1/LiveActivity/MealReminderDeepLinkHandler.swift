//
//  MealReminderDeepLinkHandler.swift
//  Food1
//
//  Handles deep links from Live Activity buttons.
//  Routes prismae://log-meal, prismae://dismiss-reminder, and prismae://end-fast URLs.
//
//  WHY THIS ARCHITECTURE:
//  - Centralized URL handling for all Live Activity actions
//  - Uses URL query parameters to identify which meal window/fast triggered the action
//  - Coordinates with MealActivityScheduler and FastingActivityManager
//

import Foundation
import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.prismae.food1", category: "DeepLink")

/// Handles deep links from Live Activities (meal reminders and fasting)
@MainActor
class MealReminderDeepLinkHandler: ObservableObject {

    // MARK: - Singleton

    static let shared = MealReminderDeepLinkHandler()

    // MARK: - Published State (Meal Reminders)

    /// When set, triggers navigation to meal logging
    @Published var pendingMealWindowId: UUID?

    /// Show the quick add meal view
    @Published var shouldShowQuickAdd: Bool = false

    // MARK: - Published State (Fasting)

    /// Fast ID pending end confirmation
    @Published var pendingEndFastId: UUID?

    /// Show end fast confirmation dialog
    @Published var shouldShowEndFastConfirmation: Bool = false

    // MARK: - Handle URL

    /// Handle incoming URL from Live Activity
    /// - Returns: true if URL was handled, false otherwise
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "prismae" else { return false }

        logger.info("Handling deep link: \(url.absoluteString)")

        switch url.host {
        case "log-meal":
            return handleLogMeal(url: url)

        case "dismiss-reminder":
            return handleDismissReminder(url: url)

        case "end-fast":
            return handleEndFast(url: url)

        default:
            logger.warning("Unknown deep link host: \(url.host ?? "nil")")
            return false
        }
    }

    // MARK: - Log Meal

    private func handleLogMeal(url: URL) -> Bool {
        // Extract window ID from query parameter
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let windowIdString = components.queryItems?.first(where: { $0.name == "window" })?.value,
              let windowId = UUID(uuidString: windowIdString) else {
            logger.warning("Log meal URL missing window ID")
            // Still open quick add even without window context
            shouldShowQuickAdd = true
            return true
        }

        logger.info("Opening meal log for window: \(windowId)")

        // Store the window ID for context
        pendingMealWindowId = windowId

        // Trigger the quick add sheet
        shouldShowQuickAdd = true

        // Update the Live Activity to show "logging" state
        Task {
            await MealActivityScheduler.shared.updateActivityState(
                for: windowId,
                to: .logging
            )
        }

        return true
    }

    // MARK: - Dismiss Reminder

    private func handleDismissReminder(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let windowIdString = components.queryItems?.first(where: { $0.name == "window" })?.value,
              let windowId = UUID(uuidString: windowIdString) else {
            logger.warning("Dismiss URL missing window ID")
            return false
        }

        logger.info("Dismissing reminder for window: \(windowId)")

        // End the Live Activity
        Task {
            await MealActivityScheduler.shared.endActivity(for: windowId, reason: .dismissed)
        }

        return true
    }

    // MARK: - End Fast

    private func handleEndFast(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fastIdString = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let fastId = UUID(uuidString: fastIdString) else {
            logger.warning("End fast URL missing fast ID")
            return false
        }

        logger.info("End fast requested for: \(fastId)")

        // Store the fast ID and show confirmation dialog
        pendingEndFastId = fastId
        shouldShowEndFastConfirmation = true

        return true
    }

    // MARK: - Clear State

    /// Clear pending state after navigation is complete
    func clearPendingState() {
        pendingMealWindowId = nil
        shouldShowQuickAdd = false
    }

    /// Clear fasting state after confirmation handled
    func clearFastingState() {
        pendingEndFastId = nil
        shouldShowEndFastConfirmation = false
    }
}
