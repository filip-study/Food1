//
//  AuthenticationService.swift
//  Food1
//
//  Handles user authentication (sign up, sign in, sign out).
//  Supports Apple Sign In, Google Sign In, and email/password auth.
//
//  WHY THIS ARCHITECTURE:
//  - Single service for all auth operations (consistency)
//  - Published properties for UI state (loading, errors)
//  - Automatic profile + subscription creation on signup (database trigger)
//  - Error messages user-friendly (not raw API errors)
//
//  SUPPORTED AUTH METHODS:
//  - Apple Sign In: Native iOS via AuthenticationServices + Supabase ID token
//  - Google Sign In: Supabase OAuth (browser-based, no native SDK needed)
//  - Email/Password: Supabase native email auth
//
//  FLOW:
//  1. User signs up → Supabase creates auth.users entry
//  2. Database trigger auto-creates profiles + subscription_status rows
//  3. App fetches profile data
//  4. SessionManager maintains auth state
//

import Foundation
import Combine
import Auth
import Supabase
import AuthenticationServices

@MainActor
class AuthenticationService: ObservableObject {

    // MARK: - Properties

    /// Supabase client
    private let supabase = SupabaseService.shared

    /// Loading state
    @Published var isLoading = false

    /// Error message
    @Published var errorMessage: String?

    // MARK: - Sign Up

    /// Create new account with email and password
    @MainActor
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Validate inputs
            guard isValidEmail(email) else {
                throw AuthError.invalidEmail
            }

            guard password.count >= 8 else {
                throw AuthError.passwordTooShort
            }

            // Create account with email confirmation redirect
            let response = try await supabase.client.auth.signUp(
                email: email,
                password: password,
                redirectTo: URL(string: "com.filipolszak.food1://auth/callback")
            )

            print("✅ Account created: \(response.user.id)")

            // Profile and subscription_status are auto-created by database trigger
            // (see handle_new_user() function in database schema)

        } catch let error as AuthError {
            errorMessage = error.userMessage
            throw error
        } catch {
            let authError = AuthError.from(error)
            errorMessage = authError.userMessage
            throw authError
        }
    }

    // MARK: - Sign In

    /// Sign in with email and password
    /// Returns the Session directly so callers can use it immediately
    /// (rather than relying on async session state which may have timing issues)
    @MainActor
    func signIn(email: String, password: String) async throws -> Auth.Session {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let session = try await supabase.client.auth.signIn(
                email: email,
                password: password
            )

            print("✅ Signed in: \(session.user.id)")
            return session

        } catch let error as AuthError {
            errorMessage = error.userMessage
            throw error
        } catch {
            let authError = AuthError.from(error)
            errorMessage = authError.userMessage
            throw authError
        }
    }

    // MARK: - Sign Out

    /// Sign out current user
    @MainActor
    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await supabase.client.auth.signOut()
            print("👋 Signed out")

        } catch {
            let authError = AuthError.from(error)
            errorMessage = authError.userMessage
            throw authError
        }
    }

    // MARK: - Password Reset

    /// Request password reset email
    @MainActor
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            guard isValidEmail(email) else {
                throw AuthError.invalidEmail
            }

            try await supabase.client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "com.filipolszak.food1://auth/callback")
            )
            print("📧 Password reset email sent to: \(email)")

        } catch let error as AuthError {
            errorMessage = error.userMessage
            throw error
        } catch {
            let authError = AuthError.from(error)
            errorMessage = authError.userMessage
            throw authError
        }
    }

    // MARK: - Apple Sign In

    /// Sign in with Apple using native Apple authentication
    /// Note: Apple only provides the user's name on FIRST sign-in, so we must capture and save it immediately
    @MainActor
    func signInWithApple(authorization: ASAuthorization) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Extract Apple ID credentials
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthError.unknown("Invalid Apple credentials")
            }

            // Get the identity token
            guard let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                throw AuthError.unknown("Failed to get identity token from Apple")
            }

            // Extract name from Apple credentials (only available on first sign-in!)
            let fullName = extractFullName(from: appleIDCredential.fullName)

            // Sign in with Supabase using Apple ID token
            let response = try await supabase.client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString
                )
            )

            print("✅ Apple Sign In successful: \(response.user.id)")

            // Profile and subscription_status are auto-created by database trigger

            // If Apple provided a name or email (first sign-in only), save to profile
            // Note: Apple only provides these on the FIRST sign-in with this Apple ID
            let appleEmail = appleIDCredential.email
            if (fullName != nil && !fullName!.isEmpty) || appleEmail != nil {
                await saveProfileData(userId: response.user.id, fullName: fullName, email: appleEmail)
            }

        } catch let error as AuthError {
            errorMessage = error.userMessage
            throw error
        } catch {
            let authError = AuthError.from(error)
            errorMessage = authError.userMessage
            throw authError
        }
    }

    /// Extract full name string from Apple's PersonNameComponents
    /// Returns nil if no name parts are available
    private func extractFullName(from nameComponents: PersonNameComponents?) -> String? {
        guard let components = nameComponents else { return nil }

        var parts: [String] = []

        if let givenName = components.givenName, !givenName.isEmpty {
            parts.append(givenName)
        }
        if let familyName = components.familyName, !familyName.isEmpty {
            parts.append(familyName)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Save user data (name, email) to their Supabase profile
    /// Uses UPSERT to handle race condition with database trigger (profile may not exist yet)
    /// Only sends non-null fields to avoid overwriting existing data with nulls
    private func saveProfileData(userId: UUID, fullName: String?, email: String?) async {
        // Skip if nothing to save
        guard fullName != nil || email != nil else { return }

        do {
            // Use UPSERT to handle race condition where profile may not exist yet
            // Database trigger creates profile, but there can be a timing gap
            let now = ISO8601DateFormatter().string(from: Date())

            // Build dictionary with only non-null values to avoid overwriting existing data
            var profileData: [String: String] = [
                "id": userId.uuidString,
                "updated_at": now,
                "created_at": now  // Will be ignored on conflict (existing row keeps its created_at)
            ]

            if let name = fullName, !name.isEmpty {
                profileData["full_name"] = name
            }
            if let email = email, !email.isEmpty {
                profileData["email"] = email
            }

            try await supabase.client
                .from("profiles")
                .upsert(profileData, onConflict: "id")
                .execute()

            if let name = fullName {
                print("✅ Saved name to profile: \(name)")
            }
            if let email = email {
                print("✅ Saved email to profile: \(email)")
            }
        } catch {
            // Don't fail sign-in if profile save fails - it's not critical
            print("⚠️ Failed to save profile data: \(error)")
        }
    }

    // MARK: - Google Sign In

    /// Sign in with Google using Supabase OAuth
    /// Opens a browser for Google authentication, then redirects back to the app
    ///
    /// NOTE: Google OAuth credentials are configured in Supabase Dashboard,
    /// NOT in the iOS app. This method triggers the OAuth flow.
    @MainActor
    func signInWithGoogle() async throws -> URL {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Supabase handles the OAuth flow - opens browser for Google auth
            // Returns the URL to open (ASWebAuthenticationSession or Safari)
            let url = try await supabase.client.auth.getOAuthSignInURL(
                provider: .google,
                redirectTo: URL(string: "com.filipolszak.food1://auth/callback")
            )

            print("🔗 Google OAuth URL generated")
            return url

        } catch let error as AuthError {
            errorMessage = error.userMessage
            throw error
        } catch {
            let authError = AuthError.from(error)
            errorMessage = authError.userMessage
            throw authError
        }
    }

    /// Complete Google Sign In after OAuth callback
    /// Called from deep link handler after user returns from browser
    @MainActor
    func handleGoogleCallback(url: URL) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Supabase SDK handles session restoration from the callback URL
            let session = try await supabase.client.auth.session(from: url)
            print("✅ Google Sign In completed via callback")

            // Profile and subscription_status are auto-created by database trigger

            // Extract and save name + email from Google's user data
            // Email is directly on user object, name is in metadata
            let googleEmail = session.user.email
            let metadata = session.user.userMetadata
            let fullName = extractGoogleName(from: metadata)

            // Save both name and email to profile
            if (fullName != nil && !fullName!.isEmpty) || googleEmail != nil {
                await saveProfileData(userId: session.user.id, fullName: fullName, email: googleEmail)
            }

        } catch let error as AuthError {
            errorMessage = error.userMessage
            throw error
        } catch {
            let authError = AuthError.from(error)
            errorMessage = authError.userMessage
            throw authError
        }
    }

    /// Extract full name from Google OAuth user metadata
    /// Google provides name in various fields depending on account settings
    private func extractGoogleName(from metadata: [String: AnyJSON]) -> String? {
        // Try full_name first (most common)
        if let fullName = metadata["full_name"]?.stringValue, !fullName.isEmpty {
            return fullName
        }

        // Try name field
        if let name = metadata["name"]?.stringValue, !name.isEmpty {
            return name
        }

        // Fall back to combining given_name + family_name
        let givenName = metadata["given_name"]?.stringValue ?? ""
        let familyName = metadata["family_name"]?.stringValue ?? ""

        let combined = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return combined.isEmpty ? nil : combined
    }

    // MARK: - Profile Existence

    /// Ensure a profile exists for the current user
    /// This handles returning users after account deletion where the database trigger
    /// didn't fire (because auth.users already existed for OAuth providers)
    func ensureProfileExists() async {
        do {
            let session = try await supabase.client.auth.session
            let userId = session.user.id

            // Check if profile exists
            let response: [CloudUserProfile] = try await supabase.client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .execute()
                .value

            if response.isEmpty {
                // Profile doesn't exist - create it
                // This happens when returning OAuth user's profile was deleted
                let now = ISO8601DateFormatter().string(from: Date())

                let newProfile: [String: String] = [
                    "id": userId.uuidString,
                    "email": session.user.email ?? "",
                    "created_at": now,
                    "updated_at": now
                ]

                try await supabase.client
                    .from("profiles")
                    .insert(newProfile)
                    .execute()

                print("✅ Created missing profile for returning user")
            }
        } catch {
            // Don't fail sign-in - profile will be created on next attempt or by loadUserData
            print("⚠️ Could not ensure profile exists: \(error)")
        }
    }

    /// Ensure user_onboarding row exists for the current user
    /// This handles returning users after account deletion
    func ensureUserOnboardingExists() async {
        do {
            let session = try await supabase.client.auth.session
            let userId = session.user.id

            // Check if user_onboarding exists
            struct OnboardingCheck: Decodable {
                let userId: String

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                }
            }

            let response: [OnboardingCheck] = try await supabase.client
                .from("user_onboarding")
                .select("user_id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            if response.isEmpty {
                // user_onboarding doesn't exist - create it with default values
                let now = ISO8601DateFormatter().string(from: Date())

                // Using [String: String] works with Supabase - null fields omitted = DB defaults
                let newOnboarding: [String: String] = [
                    "user_id": userId.uuidString,
                    "created_at": now,
                    "updated_at": now
                    // personalization_completed_at omitted = NULL = needs onboarding
                ]

                try await supabase.client
                    .from("user_onboarding")
                    .insert(newOnboarding)
                    .execute()

                print("✅ Created missing user_onboarding for returning user")
            }
        } catch {
            // Don't fail sign-in
            print("⚠️ Could not ensure user_onboarding exists: \(error)")
        }
    }

    // MARK: - Validation

    /// Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidEmail
    case passwordTooShort
    case emailAlreadyInUse
    case invalidCredentials
    case networkError
    case oauthCancelled
    case oauthFailed(String)
    case unknown(String)

    var userMessage: String {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .passwordTooShort:
            return "Password must be at least 8 characters."
        case .emailAlreadyInUse:
            return "This email is already registered. Try signing in instead."
        case .invalidCredentials:
            return "Incorrect email or password. Please try again."
        case .networkError:
            return "Network error. Please check your internet connection."
        case .oauthCancelled:
            return "Sign in was cancelled."
        case .oauthFailed(let provider):
            return "Failed to sign in with \(provider). Please try again."
        case .unknown(let message):
            return "An error occurred: \(message)"
        }
    }

    /// Convert Supabase error to user-friendly AuthError
    static func from(_ error: Error) -> AuthError {
        let errorString = error.localizedDescription.lowercased()

        if errorString.contains("email") && errorString.contains("already") {
            return .emailAlreadyInUse
        }

        if errorString.contains("invalid") && (errorString.contains("credentials") || errorString.contains("password")) {
            return .invalidCredentials
        }

        if errorString.contains("network") || errorString.contains("connection") {
            return .networkError
        }

        if errorString.contains("cancel") {
            return .oauthCancelled
        }

        if errorString.contains("oauth") || errorString.contains("provider") {
            return .oauthFailed("OAuth")
        }

        return .unknown(error.localizedDescription)
    }
}
