//
//  MigrationService.swift
//  Food1
//
//  Handles one-time migration of existing local meals to Supabase on first auth.
//
//  WHY THIS ARCHITECTURE:
//  - UserDefaults flag prevents re-migration on every launch
//  - Batch processing (10 meals) balances performance and progress updates
//  - Background queue processing doesn't block UI
//  - Progress tracking enables UI progress bar/spinner
//  - Graceful failure: Migration can resume from where it left off
//
//  WHEN MIGRATION TRIGGERS:
//  - First successful authentication (hasCompletedMigration == false)
//  - User has at least 1 local meal
//  - Automatically resumes if previously interrupted
//

import Foundation
import SwiftData
import Combine

@MainActor
class MigrationService: ObservableObject {

    // MARK: - Singleton

    static let shared = MigrationService()

    // MARK: - Properties

    private let syncService = SyncService()
    private let userDefaultsKey = "hasCompletedCloudMigration"
    private let batchSize = 10

    @Published var isMigrating = false
    @Published var migrationProgress: Double = 0  // 0.0 to 1.0
    @Published var migratedCount = 0
    @Published var totalCount = 0
    @Published var migrationError: String?

    // MARK: - Migration Status

    /// Check if migration has been completed
    var hasCompletedMigration: Bool {
        UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    /// Mark migration as complete
    private func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        print("✅ Migration marked as complete")
    }

    /// Reset migration status (for testing/debugging)
    func resetMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("🔄 Migration status reset")
    }

    // MARK: - Migration Detection

    /// Check if migration is needed
    /// - Parameter context: ModelContext
    /// - Returns: True if user has local meals and hasn't migrated yet
    func needsMigration(context: ModelContext) throws -> Bool {
        // Check if there are any unsynced local meals
        let fetchDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.cloudId == nil  // No cloud ID means never synced
            }
        )

        let unsyncedMeals = try context.fetch(fetchDescriptor)
        let needsMigration = !unsyncedMeals.isEmpty

        if needsMigration {
            print("📊 Found \(unsyncedMeals.count) local meals needing migration")
            // If we have unsynced meals but migration was marked complete,
            // reset the flag to allow re-migration
            if hasCompletedMigration {
                print("⚠️  Migration was marked complete but \(unsyncedMeals.count) meals remain unsynced - resetting migration flag")
                resetMigrationStatus()
            }
        }

        return needsMigration
    }

    // MARK: - Migration Execution

    /// Migrate all local meals to Supabase
    /// - Parameter context: ModelContext
    func migrateAllMeals(context: ModelContext) async throws {
        guard !hasCompletedMigration else {
            print("⏭️  Migration already completed")
            return
        }

        isMigrating = true
        migrationError = nil
        migratedCount = 0

        do {
            // Fetch all unsynced meals
            let fetchDescriptor = FetchDescriptor<Meal>(
                predicate: #Predicate { meal in
                    meal.cloudId == nil
                },
                sortBy: [SortDescriptor(\Meal.timestamp, order: .forward)]  // Oldest first
            )

            let mealsToMigrate = try context.fetch(fetchDescriptor)
            totalCount = mealsToMigrate.count

            guard totalCount > 0 else {
                print("✅ No meals to migrate")
                markMigrationComplete()
                isMigrating = false
                return
            }

            print("🚀 Starting migration of \(totalCount) meals...")

            // Migrate in batches
            for batch in mealsToMigrate.chunked(into: batchSize) {
                for meal in batch {
                    do {
                        // Upload meal to cloud
                        try await syncService.uploadMeal(meal, context: context)
                        migratedCount += 1
                        migrationProgress = Double(migratedCount) / Double(totalCount)

                        print("📤 Migrated \(migratedCount)/\(totalCount): \(meal.name)")

                    } catch {
                        print("❌ Failed to migrate meal \(meal.name): \(error)")
                        // Continue with next meal (don't fail entire migration)
                    }
                }
            }

            // Only mark migration complete if all meals synced successfully
            if migratedCount == totalCount {
                markMigrationComplete()
                print("✅ Migration complete: \(migratedCount)/\(totalCount) meals synced")
            } else {
                print("⚠️  Partial migration: \(migratedCount)/\(totalCount) meals synced - will retry on next launch")
            }

        } catch {
            migrationError = error.localizedDescription
            print("❌ Migration failed: \(error)")
            throw MigrationError.migrationFailed(error.localizedDescription)
        }

        isMigrating = false
        migrationProgress = 1.0
    }

    /// Migrate meals in background (non-blocking)
    func migrateInBackground(context: ModelContext) {
        Task {
            do {
                try await migrateAllMeals(context: context)
            } catch {
                print("❌ Background migration failed: \(error)")
            }
        }
    }
}

// MARK: - Errors

enum MigrationError: LocalizedError {
    case migrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        }
    }
}
