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
//  - Every 5 minutes (automatic timer, enabled via configure())
//  - On network reconnection
//  - Manual user pull-to-refresh
//
//  SYNC PHASES (in order):
//  1. Upload pending meals (syncStatus = pending/error)
//  2. Retry failed photo uploads (photoData exists but photoThumbnailUrl is nil)
//  3. Download recent meals from cloud (last 30 days)
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
    @Published var pendingPhotosCount = 0

    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// Weak reference to ModelContainer for periodic sync (set via configure)
    private weak var modelContainer: ModelContainer?

    // MARK: - Configuration

    private let syncIntervalSeconds: TimeInterval = 300  // 5 minutes
    private let batchSize = 10
    private let maxRetries = 3

    // MARK: - Initialization

    private init() {
        setupAuthListener()
    }

    // MARK: - Container Configuration

    /// Configure with ModelContainer for periodic sync
    /// Called from Food1App after SwiftData initialization
    func configure(with container: ModelContainer) {
        self.modelContainer = container
        print("✅ SyncCoordinator configured with ModelContainer")
        print("   isAuthenticated: \(supabase.isAuthenticated)")

        // If already authenticated, start periodic sync now
        if supabase.isAuthenticated {
            print("   → User already authenticated, starting sync...")
            startPeriodicSync()
        } else {
            print("   → Waiting for authentication...")
        }
    }

    /// Listen for authentication state changes
    private func setupAuthListener() {
        // Use dropFirst(0) to also receive the current value on subscription
        supabase.$isAuthenticated
            .dropFirst(0)  // Ensures we get the current value immediately
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                print("🔐 Auth state changed: \(isAuthenticated)")
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
    private func startPeriodicSync() {
        guard syncTimer == nil else { return }

        guard modelContainer != nil else {
            print("⏰ Periodic sync waiting for ModelContainer configuration")
            return
        }

        print("⏰ Starting periodic sync (every \(Int(syncIntervalSeconds/60)) minutes)")

        syncTimer = Timer.scheduledTimer(withTimeInterval: syncIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performPeriodicSync()
            }
        }

        // Perform initial sync immediately
        Task {
            await performPeriodicSync()
        }
    }

    /// Perform periodic sync using configured ModelContainer
    private func performPeriodicSync() async {
        guard let container = modelContainer else {
            print("⚠️  Cannot sync: ModelContainer is nil")
            stopPeriodicSync()
            return
        }

        let context = container.mainContext
        await syncAll(context: context)
    }

    /// Stop automatic sync timer
    private func stopPeriodicSync() {
        print("⏹️  Stopping periodic sync")
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - Manual Sync

    /// Trigger initial sync after sign-in (uses configured ModelContainer)
    func triggerInitialSync() {
        guard let container = modelContainer else {
            print("⚠️  Cannot trigger sync: ModelContainer not configured yet")
            return
        }

        Task {
            print("🔄 Starting initial sync...")
            await syncAll(context: container.mainContext)
        }
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

            // Step 3: Download recent meals (last 30 days)
            let downloadedCount = try await syncService.downloadRecentMeals(context: context, days: 30)

            // Step 4: Download ingredients for meals missing them
            let mealsNeedingIngredients = try context.fetch(FetchDescriptor<Meal>(
                predicate: #Predicate { meal in
                    meal.cloudId != nil
                }
            ))
            try await syncService.downloadIngredients(for: mealsNeedingIngredients, context: context)

            // Update state
            lastSyncDate = Date()
            print("✅ Sync complete: uploaded \(uploadedCount), photos retried \(photoRetryCount), downloaded \(downloadedCount)")

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

    /// Retry uploading photos that failed during initial meal sync
    private func retryPendingPhotoUploads(context: ModelContext) async throws -> Int {
        // Count pending photos first
        let fetchDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.photoData != nil &&
                meal.photoThumbnailUrl == nil &&
                meal.syncStatus == "synced" &&
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
