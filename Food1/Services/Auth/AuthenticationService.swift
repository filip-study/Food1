//
//  AuthenticationService.swift
//  Food1
//
//  Handles user authentication (sign up, sign in, sign out).
//  Email/password authentication with automatic profile creation.
//
//  WHY THIS ARCHITECTURE:
//  - Single service for all auth operations (consistency)
//  - Published properties for UI state (loading, errors)
//  - Automatic profile + subscription creation on signup (database trigger)
//  - Error messages user-friendly (not raw API errors)
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

            // If Apple provided a name (first sign-in only), save it to profile
            if let name = fullName, !name.isEmpty {
                await saveNameToProfile(userId: response.user.id, fullName: name)
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

    /// Save the user's name to their Supabase profile
    private func saveNameToProfile(userId: UUID, fullName: String) async {
        do {
            struct NameUpdate: Encodable {
                let full_name: String
                let updated_at: String
            }

            let update = NameUpdate(
                full_name: fullName,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase.client
                .from("profiles")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()

            print("✅ Saved Apple name to profile: \(fullName)")
        } catch {
            // Don't fail sign-in if name save fails - it's not critical
            print("⚠️ Failed to save name to profile: \(error)")
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

        return .unknown(error.localizedDescription)
    }
}
