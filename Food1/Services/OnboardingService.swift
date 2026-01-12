//
//  OnboardingService.swift
//  Food1
//
//  Centralized service for managing user onboarding state.
//  Tracks which onboarding steps users have completed across app versions.
//
//  WHY THIS ARCHITECTURE:
//  - Single source of truth for all onboarding states
//  - Cloud-synced via Supabase (persists across devices/reinstalls)
//  - New onboarding steps automatically show for existing users
//  - Version tracking enables targeted onboarding for specific features
//
//  HOW TO ADD NEW ONBOARDING:
//  1. Add new column to user_onboarding table in Supabase
//  2. Add property to UserOnboarding struct below
//  3. Add case to OnboardingStep enum
//  4. Create the onboarding view
//  5. The system will automatically show it to users who haven't completed it
//

import Foundation
import Supabase
import Combine
import os.log

private let logger = Logger(subsystem: "com.prismae.food1", category: "Onboarding")

/// Represents the post-login onboarding steps (shown AFTER personalization flow)
/// Note: The main personalization flow is handled by OnboardingFlowContainer
enum OnboardingStep: String, CaseIterable, Identifiable {
    case welcome = "welcome"
    case mealReminders = "meal_reminders"
    case profileSetup = "profile_setup"

    var id: String { rawValue }

    /// Display order (lower = shown first)
    var order: Int {
        switch self {
        case .welcome: return 0
        case .mealReminders: return 1
        case .profileSetup: return 2
        }
    }

    /// Whether this step requires Live Activities (skip if not supported)
    var requiresLiveActivities: Bool {
        switch self {
        case .mealReminders: return true
        default: return false
        }
    }
}

/// User onboarding state from Supabase
struct UserOnboarding: Codable {
    let userId: UUID
    var welcomeCompletedAt: Date?
    var mealRemindersCompletedAt: Date?
    var profileSetupCompletedAt: Date?
    var personalizationCompletedAt: Date?  // New: tracks if user completed the personalization flow
    var appVersionFirstSeen: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case welcomeCompletedAt = "welcome_completed_at"
        case mealRemindersCompletedAt = "meal_reminders_completed_at"
        case profileSetupCompletedAt = "profile_setup_completed_at"
        case personalizationCompletedAt = "personalization_completed_at"
        case appVersionFirstSeen = "app_version_first_seen"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Check if personalization flow is complete
    var hasCompletedPersonalization: Bool {
        personalizationCompletedAt != nil
    }

    /// Check if a specific step is completed
    func isCompleted(_ step: OnboardingStep) -> Bool {
        switch step {
        case .welcome:
            return welcomeCompletedAt != nil
        case .mealReminders:
            return mealRemindersCompletedAt != nil
        case .profileSetup:
            return profileSetupCompletedAt != nil
        }
    }

    /// Get all pending (not completed) steps in order
    var pendingSteps: [OnboardingStep] {
        OnboardingStep.allCases
            .filter { !isCompleted($0) }
            .sorted { $0.order < $1.order }
    }
}

/// Service for managing user onboarding state
@MainActor
class OnboardingService: ObservableObject {

    // MARK: - Singleton

    static let shared = OnboardingService()

    // MARK: - Published State

    /// Current user's onboarding state
    @Published private(set) var onboarding: UserOnboarding?

    /// The next onboarding step to show (if any)
    @Published private(set) var pendingStep: OnboardingStep?

    /// Whether we're currently loading onboarding state
    @Published private(set) var isLoading = false

    // MARK: - Services

    private let supabase = SupabaseService.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Load Onboarding State

    /// Load onboarding state from Supabase
    func loadOnboardingState() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userId = try await supabase.requireUserId()

            // Try to fetch existing onboarding record
            do {
                let response: UserOnboarding = try await supabase.client
                    .from("user_onboarding")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value

                self.onboarding = response
                logger.info("Loaded onboarding state for user")

            } catch {
                // No record exists - create one (for existing users)
                logger.info("No onboarding record, creating one for existing user")
                try await createOnboardingRecord(for: userId)
            }

            // Determine next pending step
            updatePendingStep()

        } catch {
            logger.error("Failed to load onboarding state: \(error.localizedDescription)")
            // Don't block app if onboarding fails to load
            self.onboarding = nil
            self.pendingStep = nil
        }
    }

    /// Create onboarding record for a user (handles existing users who don't have one)
    private func createOnboardingRecord(for userId: UUID) async throws {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        struct InsertPayload: Encodable {
            let userId: UUID
            let appVersionFirstSeen: String?

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case appVersionFirstSeen = "app_version_first_seen"
            }
        }

        let payload = InsertPayload(userId: userId, appVersionFirstSeen: appVersion)

        try await supabase.client
            .from("user_onboarding")
            .insert(payload)
            .execute()

        // Fetch the created record
        let response: UserOnboarding = try await supabase.client
            .from("user_onboarding")
            .select()
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value

        self.onboarding = response
        logger.info("Created onboarding record for user")
    }

    // MARK: - Complete Onboarding Step

    /// Mark an onboarding step as completed
    func completeStep(_ step: OnboardingStep) async {
        guard var currentOnboarding = onboarding else {
            logger.warning("Cannot complete step - no onboarding record")
            return
        }

        let now = Date()

        // Update the appropriate field
        switch step {
        case .welcome:
            currentOnboarding.welcomeCompletedAt = now
        case .mealReminders:
            currentOnboarding.mealRemindersCompletedAt = now
        case .profileSetup:
            currentOnboarding.profileSetupCompletedAt = now
        }

        // Prepare update payload
        struct UpdatePayload: Encodable {
            var welcomeCompletedAt: Date?
            var mealRemindersCompletedAt: Date?
            var profileSetupCompletedAt: Date?
            let updatedAt: Date

            enum CodingKeys: String, CodingKey {
                case welcomeCompletedAt = "welcome_completed_at"
                case mealRemindersCompletedAt = "meal_reminders_completed_at"
                case profileSetupCompletedAt = "profile_setup_completed_at"
                case updatedAt = "updated_at"
            }
        }

        let payload = UpdatePayload(
            welcomeCompletedAt: currentOnboarding.welcomeCompletedAt,
            mealRemindersCompletedAt: currentOnboarding.mealRemindersCompletedAt,
            profileSetupCompletedAt: currentOnboarding.profileSetupCompletedAt,
            updatedAt: now
        )

        do {
            try await supabase.client
                .from("user_onboarding")
                .update(payload)
                .eq("user_id", value: currentOnboarding.userId.uuidString)
                .execute()

            self.onboarding = currentOnboarding
            logger.info("Completed onboarding step: \(step.rawValue)")

            // Update pending step
            updatePendingStep()

        } catch {
            logger.error("Failed to save onboarding completion: \(error.localizedDescription)")
        }
    }

    /// Skip an onboarding step (marks as completed)
    func skipStep(_ step: OnboardingStep) async {
        await completeStep(step)
    }

    // MARK: - Personalization Flow

    /// Check if user has completed the personalization flow
    var hasCompletedPersonalization: Bool {
        onboarding?.hasCompletedPersonalization ?? false
    }

    /// Mark the personalization flow as complete
    func completePersonalization() async {
        guard var currentOnboarding = onboarding else {
            logger.warning("Cannot complete personalization - no onboarding record")
            return
        }

        let now = Date()
        currentOnboarding.personalizationCompletedAt = now

        struct UpdatePayload: Encodable {
            let personalizationCompletedAt: Date
            let updatedAt: Date

            enum CodingKeys: String, CodingKey {
                case personalizationCompletedAt = "personalization_completed_at"
                case updatedAt = "updated_at"
            }
        }

        let payload = UpdatePayload(
            personalizationCompletedAt: now,
            updatedAt: now
        )

        do {
            try await supabase.client
                .from("user_onboarding")
                .update(payload)
                .eq("user_id", value: currentOnboarding.userId.uuidString)
                .execute()

            self.onboarding = currentOnboarding
            logger.info("Completed personalization flow")

        } catch {
            logger.error("Failed to save personalization completion: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear State

    /// Clear all cached onboarding state
    /// Called when user signs out or deletes account to prevent stale state
    /// on next sign-in (especially important for account deletion where
    /// the server data is gone but in-memory cache would remain)
    func clearState() {
        onboarding = nil
        pendingStep = nil
        logger.info("Cleared onboarding state cache")
    }

    // MARK: - Helpers

    /// Update the pending step based on current state
    private func updatePendingStep() {
        guard let onboarding = onboarding else {
            pendingStep = nil
            return
        }

        // Find first incomplete step
        // NOTE: We show Live Activity onboarding regardless of current permission status
        // The onboarding view will handle prompting the user for permission
        // Previously we skipped this step if areActivitiesEnabled was false, but that
        // created a chicken-and-egg problem where users were never prompted
        let pending = onboarding.pendingSteps.first

        pendingStep = pending

        if let step = pending {
            logger.info("Next pending onboarding: \(step.rawValue)")
        } else {
            logger.info("All onboarding complete")
        }
    }

    /// Check if all onboarding is complete
    var isOnboardingComplete: Bool {
        pendingStep == nil
    }

    /// Reset onboarding for testing (DEBUG only)
    #if DEBUG
    func resetOnboarding() async {
        guard let userId = onboarding?.userId else { return }

        struct ResetPayload: Encodable {
            let welcomeCompletedAt: Date? = nil
            let mealRemindersCompletedAt: Date? = nil
            let profileSetupCompletedAt: Date? = nil
            let personalizationCompletedAt: Date? = nil
            let updatedAt = Date()

            enum CodingKeys: String, CodingKey {
                case welcomeCompletedAt = "welcome_completed_at"
                case mealRemindersCompletedAt = "meal_reminders_completed_at"
                case profileSetupCompletedAt = "profile_setup_completed_at"
                case personalizationCompletedAt = "personalization_completed_at"
                case updatedAt = "updated_at"
            }
        }

        do {
            try await supabase.client
                .from("user_onboarding")
                .update(ResetPayload())
                .eq("user_id", value: userId.uuidString)
                .execute()

            await loadOnboardingState()
            logger.info("Reset onboarding for testing")
        } catch {
            logger.error("Failed to reset onboarding: \(error.localizedDescription)")
        }
    }
    #endif
}

// MARK: - ActivityKit Import for Live Activity Check

import ActivityKit
