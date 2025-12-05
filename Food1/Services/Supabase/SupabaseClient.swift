//
//  SupabaseClient.swift
//  Food1
//
//  Singleton client for Supabase backend services.
//  Handles authentication, database queries, and storage operations.
//
//  WHY THIS ARCHITECTURE:
//  - Singleton ensures one client instance across app (Supabase SDK requirement)
//  - Credentials loaded from Info.plist (populated via Secrets.xcconfig at build time)
//  - Session stored in Keychain for security (not UserDefaults)
//  - Automatic token refresh handled by Supabase SDK
//
//  SECURITY:
//  - anon key is safe to expose (row-level security protects data)
//  - User tokens stored in iOS Keychain only
//  - No secrets hardcoded in source code
//

import Foundation
import Combine
import Auth
import Supabase

/// Singleton wrapper for Supabase backend services
@MainActor
class SupabaseService: ObservableObject {

    // MARK: - Singleton

    static let shared = SupabaseService()

    // MARK: - Properties

    /// Supabase client instance
    let client: SupabaseClient

    /// Current authenticated user
    @Published var currentUser: User?

    /// Authentication state
    @Published var isAuthenticated: Bool = false

    // MARK: - Initialization

    private init() {
        // Load credentials from Info.plist (populated via xcconfig)
        guard let supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !supabaseURL.isEmpty,
              supabaseURL != "$(SUPABASE_URL)",
              let url = URL(string: supabaseURL) else {
            #if DEBUG
            // In DEBUG/test builds, use dummy values instead of crashing
            // Tests don't need real Supabase connection
            print("⚠️  SUPABASE_URL not configured - using test dummy values")
            client = SupabaseClient(
                supabaseURL: URL(string: "https://test.supabase.co")!,
                supabaseKey: "test-anon-key"
            )
            return
            #else
            fatalError("SUPABASE_URL not configured. Check Secrets.xcconfig and Info.plist.")
            #endif
        }

        guard let supabaseKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !supabaseKey.isEmpty,
              supabaseKey != "$(SUPABASE_ANON_KEY)" else {
            #if DEBUG
            // In DEBUG/test builds, use dummy values instead of crashing
            print("⚠️  SUPABASE_ANON_KEY not configured - using test dummy values")
            client = SupabaseClient(
                supabaseURL: url,
                supabaseKey: "test-anon-key"
            )
            return
            #else
            fatalError("SUPABASE_ANON_KEY not configured. Check Secrets.xcconfig and Info.plist.")
            #endif
        }

        // Initialize Supabase client
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey
        )

        // Listen for auth state changes
        Task {
            await setupAuthListener()
        }
    }

    // MARK: - Auth State Listener

    /// Set up listener for authentication state changes
    private func setupAuthListener() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let session = session {
                    print("✅ User signed in: \(session.user.id)")
                    currentUser = session.user
                    isAuthenticated = true
                }

            case .signedOut:
                print("👋 User signed out")
                currentUser = nil
                isAuthenticated = false

            case .userUpdated:
                if let session = session {
                    print("🔄 User updated: \(session.user.id)")
                    currentUser = session.user
                }

            case .tokenRefreshed:
                if let session = session {
                    print("🔑 Token refreshed: \(session.user.id)")
                    currentUser = session.user
                }

            default:
                break
            }
        }
    }

    // MARK: - Session Management

    /// Check if there's an active session on app launch
    func checkSession() async throws -> Bool {
        let session = try await client.auth.session
        currentUser = session.user
        isAuthenticated = true
        return true
    }

    /// Get current session (throws if not authenticated)
    func requireSession() async throws -> Session {
        guard let session = try? await client.auth.session else {
            throw SupabaseError.notAuthenticated
        }
        return session
    }

    /// Get current user ID (throws if not authenticated)
    func requireUserId() async throws -> UUID {
        let session = try await requireSession()
        return session.user.id
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case keychainError(String)
    case configurationError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated. Please sign in."
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}
