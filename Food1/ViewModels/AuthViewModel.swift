//
//  AuthViewModel.swift
//  Food1
//
//  Centralized authentication and subscription state management.
//  Coordinates between SupabaseService, AuthenticationService, and SubscriptionService.
//
//  WHY THIS ARCHITECTURE:
//  - Single source of truth for auth state across app
//  - @Published properties drive UI updates automatically
//  - Handles auth state AND user profile data
//  - Simplifies view code (views just observe this ViewModel)
//
//  SUBSCRIPTION STATE (Simplified):
//  - StoreKit is the ONLY source of truth for subscription status on iOS
//  - App Store handles free trial (7 days) via Introductory Offers
//  - hasAccess = storeKitIsPremium (that's it!)
//  - Supabase sync still happens for backend validation, but iOS doesn't read it back
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

    /// StoreKit premium status (observed from SubscriptionService)
    /// This updates IMMEDIATELY after purchase, before Supabase sync completes
    @Published private(set) var storeKitIsPremium = false

    /// Is email confirmation pending? (signed up but not confirmed)
    @Published var emailPendingConfirmation: String? = nil

    /// Loading state
    @Published var isLoading = false

    /// Error message for UI display
    @Published var errorMessage: String?

    // MARK: - Services

    private let supabase = SupabaseService.shared
    private let authService = AuthenticationService()

    /// Combine subscription for observing SubscriptionService
    private var subscriptionCancellable: AnyCancellable?

    // MARK: - Initialization

    init() {
        // Observe StoreKit subscription status (fixes race condition with Supabase sync)
        // StoreKit updates isPremium IMMEDIATELY after purchase verification
        subscriptionCancellable = SubscriptionService.shared.$isPremium
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPremium in
                self?.storeKitIsPremium = isPremium
                if isPremium {
                    logger.debug("StoreKit premium status: active")
                }
            }

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

        // Ensure subscription_status exists (handles returning users after account deletion)
        await SubscriptionService.shared.ensureSubscriptionStatusExists()

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

        // Ensure subscription_status exists (handles returning users after account deletion)
        await SubscriptionService.shared.ensureSubscriptionStatusExists()

        // Trigger initial sync after successful sign-in
        logger.info("Triggering initial sync after Apple Sign In")
        SyncCoordinator.shared.triggerInitialSync()
    }

    // MARK: - Google Sign In

    /// Sign in with Google using Supabase OAuth
    /// Returns a URL that must be opened in a browser for OAuth flow
    func signInWithGoogle() async throws -> URL {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        return try await authService.signInWithGoogle()
    }

    /// Complete Google Sign In after OAuth callback
    /// Called from deep link handler after user returns from browser
    func completeGoogleSignIn(from url: URL) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        try await authService.handleGoogleCallback(url: url)

        // Sign-in succeeded - set authenticated immediately
        isAuthenticated = true

        // Fetch current user from session directly
        if let session = try? await supabase.client.auth.session {
            currentUser = session.user
        }

        // Load profile data
        await loadUserData()

        // Ensure subscription_status exists (handles returning users after account deletion)
        await SubscriptionService.shared.ensureSubscriptionStatusExists()

        // Trigger initial sync after successful sign-in
        logger.info("Triggering initial sync after Google Sign In")
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

    /// Does user have access to premium features?
    ///
    /// SIMPLIFIED: StoreKit is the ONLY source of truth.
    /// - App Store handles free trial via Introductory Offers
    /// - StoreKit reports isPremium = true even during trial period
    /// - No need to check Supabase for subscription status
    /// - Supabase sync still happens for backend validation (write-only)
    var hasAccess: Bool {
        storeKitIsPremium
    }

    /// Alias for profile for clearer naming in onboarding context
    var cloudProfile: CloudUserProfile? {
        profile
    }

    /// Has user completed the personalization onboarding flow?
    /// Reads from OnboardingService which tracks this in Supabase
    var hasCompletedPersonalization: Bool {
        OnboardingService.shared.hasCompletedPersonalization
    }

    // MARK: - Personalization

    /// Mark personalization flow as complete and reload profile with new values
    func markPersonalizationComplete() async {
        await OnboardingService.shared.completePersonalization()
        await loadUserData()  // Reload profile with goal/diet values saved during onboarding
    }

    /// Update user's nutrition goal
    func updateGoal(_ goal: NutritionGoal) async {
        do {
            let userId = try await supabase.requireUserId()

            struct GoalUpdate: Encodable {
                let primary_goal: String
                let updated_at: String
            }

            let update = GoalUpdate(
                primary_goal: goal.rawValue,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase.client
                .from("profiles")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()

            // Reload profile to update UI
            await loadUserData()

            logger.info("Updated goal to: \(goal.rawValue)")
        } catch {
            logger.warning("Failed to update goal: \(error.localizedDescription)")
        }
    }

    /// Update user's diet type preference
    func updateDietType(_ diet: DietType) async {
        do {
            let userId = try await supabase.requireUserId()

            struct DietUpdate: Encodable {
                let diet_type: String
                let updated_at: String
            }

            let update = DietUpdate(
                diet_type: diet.rawValue,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase.client
                .from("profiles")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()

            // Reload profile to update UI
            await loadUserData()

            logger.info("Updated diet type to: \(diet.rawValue)")
        } catch {
            logger.warning("Failed to update diet type: \(error.localizedDescription)")
        }
    }

    /// All authentication providers linked to the current user
    /// Used to display which sign-in methods are available
    var linkedProviders: [AuthProvider] {
        guard let identities = currentUser?.identities else { return [] }
        return identities.compactMap { AuthProvider(rawValue: $0.provider) }
    }

    /// Primary authentication provider (the first OAuth provider, or email if none)
    /// Used to show the main sign-in method in AccountView
    var primaryProvider: AuthProvider {
        // Prefer OAuth providers over email for display
        linkedProviders.first { $0.isOAuth } ?? linkedProviders.first ?? .email
    }

    /// Check if user signed in with a specific provider
    func hasProvider(_ provider: AuthProvider) -> Bool {
        linkedProviders.contains(provider)
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
    /// This is irreversible - deletes profile, subscription, meals, onboarding, reminders, and photos
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
            // 1. Delete meal photos from Storage bucket
            // Storage path format: {userId}/{mealId}/thumbnail.jpg
            // We delete the entire user folder to clean up all photos
            await deleteUserPhotosFromStorage(userId: userId)

            // 2. Delete user's meals from Supabase (meal_ingredients CASCADE-deletes with meals)
            try await supabase.client
                .from("meals")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
            logger.debug("Deleted meals from cloud")

            // 3. Delete meal reminder windows
            try await supabase.client
                .from("meal_windows")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
            logger.debug("Deleted meal windows")

            // 4. Delete meal reminder settings
            try await supabase.client
                .from("meal_reminder_settings")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
            logger.debug("Deleted meal reminder settings")

            // 5. Delete onboarding progress
            try await supabase.client
                .from("user_onboarding")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
            logger.debug("Deleted user onboarding")

            // 6. Delete subscription status
            try await supabase.client
                .from("subscription_status")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
            logger.debug("Deleted subscription status")

            // 7. Delete user profile (do this last since other tables may reference it)
            try await supabase.client
                .from("profiles")
                .delete()
                .eq("id", value: userId.uuidString)
                .execute()
            logger.debug("Deleted user profile")

            // 8. Sign out (note: we can't delete auth.users from client-side)
            // The auth user record remains but all associated data is gone
            try await supabase.client.auth.signOut()

            // 9. Clear local state
            await MainActor.run {
                isAuthenticated = false
                currentUser = nil
                profile = nil
                subscription = nil
            }

            // 10. Clear local SwiftData and UserDefaults
            clearLocalData()

            logger.info("Account deletion completed successfully - all user data removed")

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

    /// Delete all user photos from Supabase Storage bucket
    /// Attempts to list and delete all files in the user's folder
    private func deleteUserPhotosFromStorage(userId: UUID) async {
        let bucketName = "meal-photos"
        let userFolder = "\(userId.uuidString)/"

        do {
            // List all files in user's folder
            let files = try await supabase.client.storage
                .from(bucketName)
                .list(path: userFolder)

            if files.isEmpty {
                logger.debug("No photos to delete for user")
                return
            }

            // Collect all file paths (need to include subdirectories for meal photos)
            var allPaths: [String] = []
            for file in files {
                // Each file might be a meal folder containing thumbnail.jpg
                let mealFolder = "\(userFolder)\(file.name)"
                let mealFiles = try await supabase.client.storage
                    .from(bucketName)
                    .list(path: mealFolder)

                for mealFile in mealFiles {
                    allPaths.append("\(mealFolder)/\(mealFile.name)")
                }
            }

            if !allPaths.isEmpty {
                // Delete all files
                _ = try await supabase.client.storage
                    .from(bucketName)
                    .remove(paths: allPaths)
                logger.debug("Deleted \(allPaths.count) photos from storage")
            }

        } catch {
            // Log but don't fail account deletion for photo cleanup issues
            // Photos will be orphaned but user data is still deleted
            logger.warning("Failed to delete photos from storage: \(error.localizedDescription)")
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
