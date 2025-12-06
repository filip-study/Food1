//
//  SyncCoordinator.swift
//  Food1
//
//  Orchestrates automated sync operations between local SwiftData and Supabase.
//
//  WHY THIS ARCHITECTURE:
//  - Singleton ensures one sync process at a time (prevents duplicate uploads)
//  - Timer-based sync every 5 minutes when authenticated
//  - Batch processing (10 meals at a time) reduces server load
//  - Exponential backoff on errors prevents hammering API
//  - Published properties enable UI sync indicators
//
//  WHEN SYNC TRIGGERS:
//  - App launch (if authenticated)
//  - After meal creation/edit
//  - Every 5 minutes (background timer)
//  - On network reconnection
//  - Manual user pull-to-refresh
//

import Foundation
import SwiftData
import Combine

@MainActor
class SyncCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = SyncCoordinator()

    // MARK: - Properties

    private let syncService = SyncService()
    private let supabase = SupabaseService.shared

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var pendingMealsCount = 0

    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    private let syncIntervalSeconds: TimeInterval = 300  // 5 minutes
    private let batchSize = 10
    private let maxRetries = 3

    // MARK: - Initialization

    private init() {
        setupAuthListener()
    }

    /// Listen for authentication state changes
    private func setupAuthListener() {
        supabase.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.startPeriodicSync()
                } else {
                    self?.stopPeriodicSync()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Periodic Sync

    /// Start automatic sync timer (every 5 minutes)
    /// NOTE: Disabled for now - requires ModelContext injection
    /// TODO: Implement with proper ModelContainer dependency injection
    private func startPeriodicSync() {
        guard syncTimer == nil else { return }

        print("⏰ Periodic sync disabled (requires ModelContext)")

        // Periodic sync disabled - will rely on manual triggers:
        // - After meal creation
        // - After USDA enrichment
        // - On app launch
        // - Pull-to-refresh
    }

    /// Stop automatic sync timer
    private func stopPeriodicSync() {
        print("⏹️  Stopping periodic sync")
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - Manual Sync

    /// Trigger full sync (upload pending + download recent)
    /// - Parameter context: ModelContext (required for data access)
    func syncAll(context: ModelContext) async {
        guard supabase.isAuthenticated else {
            print("⏭️  Skipping sync (not authenticated)")
            return
        }

        guard !isSyncing else {
            print("⏭️  Sync already in progress")
            return
        }

        isSyncing = true
        syncError = nil

        do {
            // Upload pending meals
            let uploadedCount = try await uploadPendingMeals(context: context)

            // Download recent meals (last 30 days)
            let downloadedCount = try await syncService.downloadRecentMeals(context: context, days: 30)

            // Update state
            lastSyncDate = Date()
            print("✅ Sync complete: uploaded \(uploadedCount), downloaded \(downloadedCount)")

        } catch {
            syncError = error.localizedDescription
            print("❌ Sync failed: \(error)")
        }

        isSyncing = false
    }

    /// Upload all pending meals (syncStatus = "pending" or "error")
    private func uploadPendingMeals(context: ModelContext) async throws -> Int {
        // Fetch pending meals
        let fetchDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.syncStatus == "pending" || meal.syncStatus == "error"
            },
            sortBy: [SortDescriptor(\Meal.timestamp, order: .reverse)]
        )

        let pendingMeals = try context.fetch(fetchDescriptor)
        pendingMealsCount = pendingMeals.count

        guard !pendingMeals.isEmpty else {
            print("✅ No pending meals to upload")
            return 0
        }

        print("📤 Uploading \(pendingMeals.count) pending meals...")

        var uploadedCount = 0

        // Upload in batches
        for batch in pendingMeals.chunked(into: batchSize) {
            for meal in batch {
                do {
                    try await syncService.uploadMeal(meal, context: context)
                    uploadedCount += 1
                } catch {
                    print("❌ Failed to upload meal \(meal.id): \(error)")
                    // Continue with next meal
                }
            }
        }

        pendingMealsCount = 0
        return uploadedCount
    }

    // MARK: - Single Meal Sync

    /// Upload a single meal immediately (e.g., right after creation)
    func syncMeal(_ meal: Meal, context: ModelContext) async {
        guard supabase.isAuthenticated else {
            print("⏭️  Skipping sync (not authenticated)")
            return
        }

        do {
            try await syncService.uploadMeal(meal, context: context)
            print("✅ Synced meal: \(meal.id)")
        } catch {
            print("❌ Failed to sync meal: \(error)")
            // Will retry on next periodic sync
        }
    }

    /// Delete a meal from cloud
    func deleteMeal(_ meal: Meal) async {
        guard supabase.isAuthenticated else {
            print("⏭️  Skipping delete (not authenticated)")
            return
        }

        do {
            try await syncService.deleteMeal(meal)
            print("✅ Deleted meal from cloud: \(meal.id)")
        } catch {
            print("❌ Failed to delete meal from cloud: \(error)")
        }
    }

    // MARK: - Helpers

    /// Force sync now (for pull-to-refresh)
    /// - Parameter context: ModelContext
    func forceSyncNow(context: ModelContext) async {
        lastSyncDate = nil  // Reset to show sync happening
        await syncAll(context: context)
    }
}

// MARK: - Array Extension (Chunking)

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
