//
//  SyncCoordinator.swift
//  Food1
//
//  Orchestrates automated sync operations between local SwiftData and Supabase.
//
//  WHY THIS ARCHITECTURE:
//  - Singleton ensures one sync process at a time (prevents duplicate uploads)
//  - Foreground-triggered sync (not timer-based) for battery efficiency
//  - Batch processing (10 meals at a time) reduces server load
//  - Published properties enable UI sync indicators
//
//  SCALABILITY OPTIMIZATIONS (Dec 2024):
//  - JOIN query: Meals + ingredients fetched in ONE request (was N+1 queries)
//  - Incremental sync: Only fetches changes since last sync (not full re-download)
//  - First login = full 30-day sync, subsequent = delta only
//  - Removed periodic 5-min timer: replaced with foreground sync (more efficient)
//
//  WHEN SYNC TRIGGERS:
//  - App launch (if authenticated)
//  - App returns to foreground (covers multi-device sync)
//  - After meal creation/edit
//  - Manual user pull-to-refresh
//
//  SYNC PHASES (in order):
//  1. Upload pending meals (syncStatus = pending/error)
//  2. Retry failed photo uploads (photoData exists but photoThumbnailUrl is nil)
//  3. Download meals + ingredients via JOIN query (incremental if not first sync)
//

import Foundation
import SwiftData
import Combine
import UIKit

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
    @Published var pendingPhotosCount = 0

    private var cancellables = Set<AnyCancellable>()
    private var foregroundObserver: NSObjectProtocol?

    /// Weak reference to ModelContainer for sync (set via configure)
    private weak var modelContainer: ModelContainer?

    /// Minimum interval between foreground syncs to avoid excessive syncing
    /// when user rapidly switches apps
    private let minForegroundSyncInterval: TimeInterval = 60  // 1 minute
    private var lastForegroundSyncTime: Date?

    // MARK: - Configuration

    private let batchSize = 10

    // MARK: - Initialization

    private init() {
        setupAuthListener()
        setupForegroundObserver()
    }

    deinit {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Container Configuration

    /// Configure with ModelContainer for sync operations
    /// Called from Food1App after SwiftData initialization
    func configure(with container: ModelContainer) {
        self.modelContainer = container
        print("✅ SyncCoordinator configured with ModelContainer")
        print("   isAuthenticated: \(supabase.isAuthenticated)")

        // If already authenticated, perform initial sync now
        if supabase.isAuthenticated {
            print("   → User already authenticated, starting initial sync...")
            performInitialSync()
        } else {
            print("   → Waiting for authentication...")
        }
    }

    /// Listen for authentication state changes
    private func setupAuthListener() {
        supabase.$isAuthenticated
            .dropFirst()  // Skip initial value (handled by configure)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                print("🔐 Auth state changed: \(isAuthenticated)")
                if isAuthenticated {
                    self?.performInitialSync()
                }
                // No cleanup needed on logout - just stop syncing
            }
            .store(in: &cancellables)
    }

    // MARK: - Foreground Sync

    /// Setup observer for app returning to foreground
    /// This replaces periodic timer - more efficient and covers multi-device sync
    private func setupForegroundObserver() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppWillEnterForeground()
            }
        }
    }

    /// Called when app returns to foreground - sync if enough time has passed
    private func handleAppWillEnterForeground() async {
        guard supabase.isAuthenticated else {
            print("⏭️  Foreground sync skipped (not authenticated)")
            return
        }

        guard let container = modelContainer else {
            print("⚠️  Foreground sync skipped: ModelContainer is nil")
            return
        }

        // Throttle: Don't sync if we synced recently (prevents excessive syncing
        // when user rapidly switches between apps)
        if let lastSync = lastForegroundSyncTime,
           Date().timeIntervalSince(lastSync) < minForegroundSyncInterval {
            print("⏭️  Foreground sync throttled (last sync \(Int(Date().timeIntervalSince(lastSync)))s ago)")
            return
        }

        print("📱 App entered foreground - syncing...")
        lastForegroundSyncTime = Date()
        await syncAll(context: container.mainContext)
    }

    /// Perform initial sync after authentication or app launch
    private func performInitialSync() {
        guard let container = modelContainer else {
            print("⚠️  Cannot sync: ModelContainer not configured yet")
            return
        }

        Task {
            print("🔄 Starting initial sync...")
            await syncAll(context: container.mainContext)
        }
    }

    // MARK: - Manual Sync

    /// Trigger initial sync after sign-in (called from AuthViewModel)
    func triggerInitialSync() {
        performInitialSync()
    }

    /// Trigger full sync (upload pending + retry failed photos + download recent)
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
            // Step 1: Upload pending meals
            let uploadedCount = try await uploadPendingMeals(context: context)

            // Step 2: Retry failed photo uploads
            let photoRetryCount = try await retryPendingPhotoUploads(context: context)

            // Step 3: Download recent meals with ingredients (JOIN query - single request)
            // Ingredients are now fetched embedded in meal data, eliminating N+1 queries
            let downloadedCount = try await syncService.downloadRecentMeals(context: context, days: 30)

            // Note: downloadIngredients is no longer needed here - ingredients come with JOIN query
            // The old approach made N separate queries (one per meal) which doesn't scale

            // Update state
            lastSyncDate = Date()
            print("✅ Sync complete: uploaded \(uploadedCount), photos retried \(photoRetryCount), downloaded \(downloadedCount)")

        } catch {
            syncError = error.localizedDescription
            print("❌ Sync failed: \(error)")
        }

        isSyncing = false
    }

    /// Upload all pending meals (syncStatus = .pending or .error)
    private func uploadPendingMeals(context: ModelContext) async throws -> Int {
        // Fetch pending meals using stored syncStatusRaw for predicate compatibility
        let pendingStatus = SyncStatus.pending.rawValue
        let errorStatus = SyncStatus.error.rawValue
        let fetchDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.syncStatusRaw == pendingStatus || meal.syncStatusRaw == errorStatus
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

    /// Retry uploading photos that failed during initial meal sync
    private func retryPendingPhotoUploads(context: ModelContext) async throws -> Int {
        // Count pending photos first using stored syncStatusRaw for predicate compatibility
        let syncedStatus = SyncStatus.synced.rawValue
        let fetchDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.photoData != nil &&
                meal.photoThumbnailUrl == nil &&
                meal.syncStatusRaw == syncedStatus &&
                meal.cloudId != nil
            }
        )

        let pendingPhotos = try context.fetch(fetchDescriptor)
        pendingPhotosCount = pendingPhotos.count

        guard pendingPhotosCount > 0 else {
            return 0
        }

        print("📸 Found \(pendingPhotosCount) photos needing retry...")

        let retriedCount = try await syncService.retryPendingPhotoUploads(context: context)

        pendingPhotosCount = 0
        return retriedCount
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
            // Will retry on next foreground sync or pull-to-refresh
        }
    }

    /// Delete a meal from cloud
    /// - Returns: true if cloud delete succeeded (or meal wasn't synced to cloud), false if failed
    @discardableResult
    func deleteMeal(_ meal: Meal) async -> Bool {
        // If meal was never synced to cloud, no cloud delete needed
        guard meal.cloudId != nil else {
            print("⏭️  Meal has no cloudId, no cloud delete needed")
            return true
        }

        guard supabase.isAuthenticated else {
            print("⏭️  Skipping delete (not authenticated)")
            return false  // Can't delete from cloud if not authenticated
        }

        do {
            try await syncService.deleteMeal(meal)
            print("✅ Deleted meal from cloud: \(meal.id)")
            return true
        } catch {
            print("❌ Failed to delete meal from cloud: \(error)")
            return false
        }
    }

    // MARK: - Helpers

    /// Force sync now (for pull-to-refresh)
    /// - Parameter context: ModelContext
    func forceSyncNow(context: ModelContext) async {
        lastSyncDate = nil  // Reset to show sync happening
        await syncAll(context: context)
    }

    // MARK: - Account Deletion Cleanup

    /// Delete all local SwiftData meals and related data
    /// Called when user deletes account to prevent orphaned data from reappearing
    /// on re-signup (important because Apple Sign In reuses the same auth.users entry)
    func clearAllLocalData() async {
        guard let container = modelContainer else {
            print("⚠️  Cannot clear local data: ModelContainer not configured")
            return
        }

        let context = container.mainContext

        do {
            // Delete all Meal objects (MealIngredient is cascade-deleted)
            let mealDescriptor = FetchDescriptor<Meal>()
            let allMeals = try context.fetch(mealDescriptor)
            print("🗑️  Deleting \(allMeals.count) local meals...")

            for meal in allMeals {
                context.delete(meal)
            }

            // Save changes
            try context.save()
            print("✅ Cleared all local SwiftData meals")

        } catch {
            print("❌ Failed to clear local data: \(error)")
        }
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
