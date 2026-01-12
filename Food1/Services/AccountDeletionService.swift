//
//  AccountDeletionService.swift
//  Food1
//
//  Handles permanent account deletion via backend API.
//  The backend deletes all user data including auth.users entry.
//
//  SIMPLIFIED ARCHITECTURE:
//  - iOS calls backend /delete-account endpoint
//  - Backend uses Supabase Admin API to delete auth.users (triggers CASCADE)
//  - Backend explicitly deletes from all tables for reliability
//  - iOS only handles local cleanup (UserDefaults, SwiftData)
//
//  WHY BACKEND HANDLES DELETION:
//  - Supabase doesn't allow client-side deletion from auth.users
//  - Backend has service role key for admin operations
//  - Single place to maintain deletion logic
//  - GDPR/Apple compliance: complete data removal
//

import Foundation
import os.log
import Supabase

/// Logger for account deletion events
private let logger = Logger(subsystem: "com.prismae.food1", category: "AccountDeletion")

/// Service responsible for account deletion via backend API
/// Calls /delete-account endpoint which handles all Supabase cleanup
actor AccountDeletionService {

    static let shared = AccountDeletionService()

    private init() {}

    // MARK: - Backend Deletion

    /// Delete account via backend API
    /// - Returns: True if deletion was successful
    /// - Throws: If backend call fails
    func deleteAccountViaBackend() async throws {
        logger.info("Requesting account deletion via backend")

        // Get Supabase access token for authentication
        guard let token = await getSupabaseToken() else {
            throw AccountDeletionError.notAuthenticated
        }

        // Build the delete endpoint URL
        // proxyEndpoint is like "https://food-vision-api.example.workers.dev/analyze"
        // We need to replace the path with "/delete-account"
        let baseURL = APIConfig.proxyEndpoint
            .replacingOccurrences(of: "/analyze", with: "")
            .replacingOccurrences(of: "/match-usda", with: "")
        let deleteURL = URL(string: "\(baseURL)/delete-account")!

        // Build request
        var request = URLRequest(url: deleteURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(APIConfig.authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(token, forHTTPHeaderField: "X-Supabase-Token")
        request.timeoutInterval = 30

        logger.debug("Calling backend delete endpoint: \(deleteURL.absoluteString)")

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountDeletionError.invalidResponse
        }

        // Parse response
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        switch httpResponse.statusCode {
        case 200:
            // Success
            logger.info("Backend deletion successful")

        case 207:
            // Partial success (data deleted but auth.users remains)
            // This is acceptable - user can still create new account
            logger.warning("Partial deletion: \(json?["details"] as? String ?? "unknown")")

        case 401:
            throw AccountDeletionError.notAuthenticated

        case 500:
            let details = json?["details"] as? String ?? "Server error"
            throw AccountDeletionError.serverError(details)

        default:
            let message = json?["error"] as? String ?? "Unknown error"
            throw AccountDeletionError.backendError(httpResponse.statusCode, message)
        }
    }

    // MARK: - Local Cleanup

    /// Clear local UserDefaults profile data
    /// Called after backend deletion to ensure no local state persists
    @MainActor
    func clearLocalUserDefaults() {
        let defaults = UserDefaults.standard
        let keysToRemove = [
            "userAge", "userWeight", "userHeight", "userGender",
            "userActivityLevel", "weightUnit", "heightUnit", "nutritionUnit",
            "micronutrientStandard", "userGoal", "userDietType"
        ]
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
        logger.debug("Cleared local UserDefaults data")
    }

    // MARK: - Helpers

    /// Get current Supabase access token
    private func getSupabaseToken() async -> String? {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            return session.accessToken
        } catch {
            logger.error("Could not get Supabase token: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Errors

enum AccountDeletionError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(String)
    case backendError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in and try again."
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let details):
            return "Server error: \(details)"
        case .backendError(let code, let message):
            return "Deletion failed (code \(code)): \(message)"
        }
    }
}
