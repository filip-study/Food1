//
//  AuthViewModel.swift
//  Food1
//
//  Centralized authentication state management.
//  Coordinates between SupabaseService and AuthenticationService.
//
//  WHY THIS ARCHITECTURE:
//  - Single source of truth for auth state across app
//  - @Published properties drive UI updates automatically
//  - Handles both auth state AND user profile/subscription data
//  - Simplifies view code (views just observe this ViewModel)
//

import Foundation
import SwiftUI
import Combine
import Auth
import Supabase
import AuthenticationServices
import os.log

/// Logger for auth-related events (filtered in Console.app by subsystem)
private let logger = Logger(subsystem: "com.prismae.food1", category: "Auth")

@MainActor
class AuthViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Is user currently authenticated?
    @Published var isAuthenticated = false

    /// Current user from Supabase auth
    @Published var currentUser: User?

    /// User's cloud profile (demographics, preferences)
    @Published var profile: CloudUserProfile?

    /// User's subscription status (trial, active, expired)
    @Published var subscription: SubscriptionStatus?

    /// Is email confirmation pending? (signed up but not confirmed)
    @Published var emailPendingConfirmation: String? = nil

    /// Loading state
    @Published var isLoading = false

    /// Error message for UI display
    @Published var errorMessage: String?

    // MARK: - Services

    private let supabase = SupabaseService.shared
    private let authService = AuthenticationService()

    // MARK: - Initialization

    init() {
        // Listen to Supabase auth state changes
        Task {
            await observeAuthState()
        }
    }

    // MARK: - Auth State Observer

    /// Observe authentication state changes from Supabase
    private func observeAuthState() async {
        // Initial state
        isAuthenticated = supabase.isAuthenticated
        currentUser = supabase.currentUser

        if isAuthenticated {
            await loadUserData()
        }

        // This will be called automatically by SupabaseService when auth state changes
        // The SupabaseService already has an auth listener, so we just sync with its state
    }

    // MARK: - Check Session on Launch

    /// Check if there's an active session when app launches
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let hasSession = try await supabase.checkSession()
            isAuthenticated = hasSession
            currentUser = supabase.currentUser

            if hasSession {
                await loadUserData()

                // Clear pending confirmation if we successfully loaded profile
                if profile != nil {
                    emailPendingConfirmation = nil
                }
            }
        } catch {
            logger.debug("No active session: \(error.localizedDescription)")
            isAuthenticated = false
        }
    }

    // MARK: - Load User Data

    /// Load user profile and subscription from Supabase
    private func loadUserData() async {
        do {
            let userId = try await supabase.requireUserId()

            // Load profile
            let profileResponse: CloudUserProfile = try await supabase.client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            self.profile = profileResponse

            // Sync cloud profile to local @AppStorage for RDA calculations
            syncCloudProfileToLocal(profileResponse)

            // Load subscription status
            let subscriptionResponse: SubscriptionStatus = try await supabase.client
                .from("subscription_status")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value

            self.subscription = subscriptionResponse

            logger.info("Loaded user data: \(self.profile?.email ?? "no email", privacy: .private)")

        } catch {
            logger.warning("Failed to load user data: \(error.localizedDescription) - normal for first-time sign in")
            // DON'T set errorMessage - allow user to enter app anyway
            // Profile will be loaded on next session or can be created on-demand
        }
    }

    // MARK: - Profile Sync (Cloud ↔ Local)

    /// Sync cloud profile data to local @AppStorage for RDA calculations
    /// Called after loading profile from Supabase to ensure Stats views use correct values
    private func syncCloudProfileToLocal(_ cloudProfile: CloudUserProfile) {
        let defaults = UserDefaults.standard

        // Sync age (used for RDA personalization)
        if let age = cloudProfile.age {
            defaults.set(age, forKey: "userAge")
            logger.debug("Synced age from cloud: \(age)")
        }

        // Sync weight (in kg internally, converted for display based on unit preference)
        if let weightKg = cloudProfile.weightKg {
            defaults.set(weightKg, forKey: "userWeight")
        }

        // Sync height (in cm internally)
        if let heightCm = cloudProfile.heightCm {
            defaults.set(heightCm, forKey: "userHeight")
        }

        // Sync gender (used for RDA personalization)
        if let genderEnum = cloudProfile.genderEnum {
            defaults.set(genderEnum.rawValue, forKey: "userGender")
            logger.debug("Synced gender from cloud: \(genderEnum.rawValue)")
        }

        // Sync activity level
        if let activityEnum = cloudProfile.activityLevelEnum {
            defaults.set(activityEnum.rawValue, forKey: "userActivityLevel")
        }

        // Sync unit preferences
        defaults.set(cloudProfile.weightUnit, forKey: "weightUnit")
        defaults.set(cloudProfile.heightUnit, forKey: "heightUnit")
        defaults.set(cloudProfile.nutritionUnit, forKey: "nutritionUnit")

        logger.debug("Cloud → Local profile sync complete")
    }

    /// Sync local @AppStorage values to cloud (called after profile edit)
    func syncLocalProfileToCloud() async {
        let defaults = UserDefaults.standard

        // Read local values
        let age = defaults.integer(forKey: "userAge")
        let weight = defaults.double(forKey: "userWeight")
        let height = defaults.double(forKey: "userHeight")
        let genderRaw = defaults.string(forKey: "userGender") ?? Gender.preferNotToSay.rawValue
        let activityRaw = defaults.string(forKey: "userActivityLevel") ?? ActivityLevel.moderatelyActive.rawValue

        // Convert to enums
        let gender = Gender(rawValue: genderRaw) ?? .preferNotToSay
        let activityLevel = ActivityLevel(rawValue: activityRaw) ?? .moderatelyActive

        do {
            try await updateProfile(
                fullName: profile?.fullName,
                age: age > 0 ? age : nil,
                weightKg: weight > 0 ? weight : nil,
                heightCm: height > 0 ? height : nil,
                gender: gender,
                activityLevel: activityLevel
            )
            logger.debug("Local → Cloud profile sync complete")
        } catch {
            logger.warning("Failed to sync local profile to cloud: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.signUp(email: email, password: password)
        } catch {
            // Propagate error message to UI
            if let authError = error as? AuthError {
                errorMessage = authError.userMessage
            } else {
                errorMessage = error.localizedDescription
            }
            throw error
        }

        // Sign-up succeeded - set authenticated immediately
        // (see signIn() comment about race condition with async listener)
        isAuthenticated = true

        // Fetch current user from session directly
        if let session = try? await supabase.client.auth.session {
            currentUser = session.user
        }

        // IMPORTANT: Don't load profile data yet!
        // User needs to confirm email first. EmailConfirmationPendingView will be shown.
        // Profile data will be loaded after email confirmation via deep link.

        // Set pending confirmation state
        emailPendingConfirmation = email
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Use error level for CI log capture (info level not captured by default)
        logger.error("🔐 [DEBUG] Starting sign-in for email")

        let session: Auth.Session
        do {
            // authService.signIn() now returns the Session directly
            // This avoids timing issues with async session state
            session = try await authService.signIn(email: email, password: password)
            logger.error("✅ [DEBUG] AuthService.signIn() completed, got session for user: \(session.user.id)")
        } catch {
            // Propagate error message to UI (AuthenticationService sets its own errorMessage,
            // but UI observes AuthViewModel.errorMessage)
            logger.error("❌ Sign-in failed: \(error.localizedDescription)")
            if let authError = error as? AuthError {
                errorMessage = authError.userMessage
                logger.error("   Error message set: \(authError.userMessage)")
            } else {
                errorMessage = error.localizedDescription
                logger.error("   Error message set: \(error.localizedDescription)")
            }
            throw error
        }

        // Sign-in succeeded - use the session we got directly from the signIn response
        // Note: We can't rely on SupabaseService.isAuthenticated or supabase.client.auth.session
        // because the authStateChanges async listener may not have processed the .signedIn event yet.
        // This race condition is especially problematic in CI where timing is different.
        logger.error("🔓 [DEBUG] Setting isAuthenticated = true with user: \(session.user.id)")
        isAuthenticated = true
        currentUser = session.user
        logger.error("🔓 [DEBUG] isAuthenticated is now: \(self.isAuthenticated)")

        await loadUserData()
        logger.error("✅ [DEBUG] Sign-in flow complete, isAuthenticated=\(self.isAuthenticated)")
    }

    // MARK: - Apple Sign In

    /// Sign in with Apple
    func signInWithApple(authorization: ASAuthorization) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        try await authService.signInWithApple(authorization: authorization)

        // Sign-in succeeded - set authenticated immediately
        // (see signIn() comment about race condition with async listener)
        isAuthenticated = true

        // Fetch current user from session directly
        if let session = try? await supabase.client.auth.session {
            currentUser = session.user
        }

        // Load profile data
        await loadUserData()

        // Trigger initial sync after successful sign-in
        logger.info("Triggering initial sync after Apple Sign In")
        SyncCoordinator.shared.triggerInitialSync()
    }

    // MARK: - Sign Out

    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        try await authService.signOut()

        // Clear local state
        isAuthenticated = false
        currentUser = nil
        profile = nil
        subscription = nil
    }

    // MARK: - Update Profile

    /// Update user profile in Supabase
    func updateProfile(
        fullName: String?,
        age: Int?,
        weightKg: Double?,
        heightCm: Double?,
        gender: Gender?,
        activityLevel: ActivityLevel?
    ) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let userId = try await supabase.requireUserId()

        // Convert enums to database strings
        let genderString: String? = {
            switch gender {
            case .male: return "male"
            case .female: return "female"
            case .other: return "other"
            case .preferNotToSay: return "prefer_not_to_say"
            case .none: return nil
            }
        }()

        let activityString: String? = {
            switch activityLevel {
            case .sedentary: return "sedentary"
            case .lightlyActive: return "lightly_active"
            case .moderatelyActive: return "moderately_active"
            case .veryActive: return "very_active"
            case .extremelyActive: return "extremely_active"
            case .none: return nil
            }
        }()

        // Update in database
        struct ProfileUpdate: Encodable {
            let full_name: String?
            let age: Int?
            let weight_kg: Double?
            let height_cm: Double?
            let gender: String?
            let activity_level: String?
            let updated_at: String
        }

        let update = ProfileUpdate(
            full_name: fullName,
            age: age,
            weight_kg: weightKg,
            height_cm: heightCm,
            gender: genderString,
            activity_level: activityString,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase.client
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()

        // Reload profile
        await loadUserData()

        logger.info("Profile updated successfully")
    }

    // MARK: - Computed Properties

    /// Is trial still active?
    var isTrialActive: Bool {
        subscription?.isInTrial ?? false
    }

    /// Days remaining in trial
    var trialDaysRemaining: Int {
        subscription?.trialDaysRemaining ?? 0
    }

    /// Should show trial expiration warning?
    var shouldShowTrialWarning: Bool {
        isTrialActive && trialDaysRemaining <= 3
    }

    /// Has user paid for subscription (not just trial)?
    /// Also verifies the subscription hasn't expired based on Supabase data
    var hasPaidSubscription: Bool {
        guard subscription?.subscriptionType == .active else { return false }

        // If we have an expiration date, verify it hasn't passed
        if let expiresAt = subscription?.subscriptionExpiresAt {
            return expiresAt > Date()
        }

        // No expiration date means indefinite (shouldn't happen for subscriptions, but safe fallback)
        return true
    }

    /// Does user have access to premium features? (trial OR paid subscription)
    /// This is the main gate for premium features
    var hasAccess: Bool {
        isTrialActive || hasPaidSubscription
    }

    // MARK: - Refresh Subscription

    /// Reload subscription status from Supabase (call after purchase)
    func refreshSubscription() async {
        do {
            let userId = try await supabase.requireUserId()

            let subscriptionResponse: SubscriptionStatus = try await supabase.client
                .from("subscription_status")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value

            await MainActor.run {
                self.subscription = subscriptionResponse
            }

            logger.info("Refreshed subscription: \(subscriptionResponse.subscriptionType.rawValue)")

        } catch {
            logger.warning("Failed to refresh subscription: \(error.localizedDescription)")
        }
    }

    // MARK: - Email Confirmation

    /// Resend confirmation email
    func resendConfirmation(email: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Use Supabase resend method
            try await supabase.client.auth.resend(
                email: email,
                type: .signup
            )

            logger.info("Confirmation email resent to: \(email, privacy: .private)")

        } catch {
            errorMessage = "Failed to resend confirmation email. Please try again."
            throw error
        }
    }

    // MARK: - Account Deletion

    /// Permanently delete user account and all associated data
    /// This is irreversible - deletes profile, subscription, and all meals
    func deleteAccount() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Use cached user ID first (more reliable than session lookup which can fail due to timing)
        // Fall back to session lookup if cached user not available
        let userId: UUID
        if let cachedUserId = currentUser?.id {
            userId = cachedUserId
        } else {
            // Fallback to session lookup
            userId = try await supabase.requireUserId()
        }
        logger.info("Starting account deletion for user: \(userId.uuidString, privacy: .private)")

        do {
            // 1. Delete user's meals from Supabase (if synced)
            try await supabase.client
                .from("meals")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
            logger.debug("Deleted meals from cloud")

            // 2. Delete subscription status
            try await supabase.client
                .from("subscription_status")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
            logger.debug("Deleted subscription status")

            // 3. Delete user profile
            try await supabase.client
                .from("profiles")
                .delete()
                .eq("id", value: userId.uuidString)
                .execute()
            logger.debug("Deleted user profile")

            // 4. Delete auth user (this signs them out too)
            // Note: This requires the user to be authenticated
            // The Supabase auth.admin.deleteUser requires service role key
            // For client-side, we sign out and the backend trigger handles cleanup
            try await supabase.client.auth.signOut()

            // 5. Clear local state
            await MainActor.run {
                isAuthenticated = false
                currentUser = nil
                profile = nil
                subscription = nil
            }

            // 6. Clear local SwiftData (meals stored locally)
            clearLocalData()

            logger.info("Account deletion completed successfully")

        } catch {
            logger.error("Account deletion failed: \(error.localizedDescription)")
            logger.error("Full error: \(String(describing: error))")
            // Show more specific error message in CI/debug builds
            #if DEBUG
            errorMessage = "Deletion failed: \(error.localizedDescription)"
            #else
            errorMessage = "Failed to delete account. Please try again or contact support."
            #endif
            throw error
        }
    }

    /// Clear local SwiftData storage (meals, etc.)
    private func clearLocalData() {
        // Clear UserDefaults profile data
        let defaults = UserDefaults.standard
        let keysToRemove = [
            "userAge", "userWeight", "userHeight", "userGender",
            "userActivityLevel", "weightUnit", "heightUnit", "nutritionUnit",
            "micronutrientStandard"
        ]
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
        logger.debug("Cleared local UserDefaults data")

        // Note: SwiftData meals are tied to the local container
        // They will be orphaned when user signs out (no user_id match)
        // A full cleanup would require access to ModelContext here
        // For now, local meals remain but are inaccessible without auth
    }
}
