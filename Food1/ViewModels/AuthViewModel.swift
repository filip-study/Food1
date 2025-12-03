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
            print("No active session: \(error.localizedDescription)")
            isAuthenticated = false
        }
    }

    // MARK: - Load User Data

    /// Load user profile and subscription from Supabase
    private func loadUserData() async {
        do {
            let userId = try await supabase.requireUserId()

            // Load profile
            let profileResponse: CloudUserProfile = try await supabase.client.database
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            self.profile = profileResponse

            // Load subscription status
            let subscriptionResponse: SubscriptionStatus = try await supabase.client.database
                .from("subscription_status")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value

            self.subscription = subscriptionResponse

            print("✅ Loaded user data: \(profile?.email ?? "no email")")

        } catch {
            print("⚠️  Failed to load user data: \(error)")
            print("⚠️  This is normal for first-time sign in - database trigger might need time to create profile")
            // DON'T set errorMessage - allow user to enter app anyway
            // Profile will be loaded on next session or can be created on-demand
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        try await authService.signUp(email: email, password: password)

        // Auth state change will trigger automatically via SupabaseService listener
        // Wait a moment for the listener to fire
        try? await Task.sleep(for: .milliseconds(500))

        isAuthenticated = supabase.isAuthenticated
        currentUser = supabase.currentUser

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

        try await authService.signIn(email: email, password: password)

        // Auth state change will trigger automatically
        try? await Task.sleep(for: .milliseconds(500))

        isAuthenticated = supabase.isAuthenticated
        currentUser = supabase.currentUser

        await loadUserData()
    }

    // MARK: - Apple Sign In

    /// Sign in with Apple
    func signInWithApple(authorization: ASAuthorization) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        try await authService.signInWithApple(authorization: authorization)

        // Auth state change will trigger automatically via SupabaseService listener
        // Wait a moment for the listener to fire
        try? await Task.sleep(for: .milliseconds(500))

        isAuthenticated = supabase.isAuthenticated
        currentUser = supabase.currentUser

        // Load profile data
        await loadUserData()
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

        try await supabase.client.database
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()

        // Reload profile
        await loadUserData()

        print("✅ Profile updated")
    }

    // MARK: - Computed Properties

    /// Is trial still active?
    var isTrialActive: Bool {
        subscription?.isActive ?? false
    }

    /// Days remaining in trial
    var trialDaysRemaining: Int {
        subscription?.trialDaysRemaining ?? 0
    }

    /// Should show trial expiration warning?
    var shouldShowTrialWarning: Bool {
        isTrialActive && trialDaysRemaining <= 3
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

            print("✅ Confirmation email resent to: \(email)")

        } catch {
            errorMessage = "Failed to resend confirmation email. Please try again."
            throw error
        }
    }
}
