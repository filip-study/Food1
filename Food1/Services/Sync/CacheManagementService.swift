//
//  CacheManagementService.swift
//  Food1
//
//  Manages local SwiftData cache by pruning meals older than 30 days.
//
//  WHY THIS ARCHITECTURE:
//  - Keeps local database lean (only last 30 days for fast queries)
//  - Meals stay in Supabase forever (for stats and long-term trends)
//  - Automatic daily pruning during idle time
//  - Synced meals safe to delete locally (cloudId != nil)
//  - Older meals fetchable on-demand from Supabase if needed
//
//  PERFORMANCE:
//  - Reduces SwiftData index size for faster queries
//  - Lower memory footprint when loading meal history
//  - Typical reduction: 1000 meals → 30 meals (~97% smaller database)
//

import Foundation
import SwiftData

@MainActor
class CacheManagementService {

    // MARK: - Singleton

    static let shared = CacheManagementService()

    // MARK: - Configuration

    private let cacheWindowDays = 30  // Keep last 30 days in local cache
    private let pruneIntervalHours: TimeInterval = 24  // Run daily

    private var lastPruneDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastCachePruneDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastCachePruneDate") }
    }

    private init() {}

    // MARK: - Public API

    /// Check if cache pruning is needed (runs max once per day)
    func shouldPruneCache() -> Bool {
        guard let lastPrune = lastPruneDate else {
            // Never pruned before
            return true
        }

        let hoursSinceLastPrune = Date().timeIntervalSince(lastPrune) / 3600
        return hoursSinceLastPrune >= pruneIntervalHours
    }

    /// Prune meals older than 30 days from local SwiftData
    /// - Parameter context: ModelContext
    /// - Returns: Number of meals deleted
    func pruneCacheIfNeeded(context: ModelContext) async throws -> Int {
        guard shouldPruneCache() else {
            print("⏭️  Cache pruning not needed yet")
            return 0
        }

        return try await pruneCache(context: context)
    }

    /// Force prune cache (for manual testing or troubleshooting)
    func forcePruneCache(context: ModelContext) async throws -> Int {
        return try await pruneCache(context: context)
    }

    // MARK: - Private Methods

    private func pruneCache(context: ModelContext) async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -cacheWindowDays, to: Date())!

        print("🧹 Pruning meals older than \(cutoffDate)...")

        // Fetch old meals that are synced to cloud (safe to delete locally)
        let fetchDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.timestamp < cutoffDate &&  // Older than 30 days
                meal.cloudId != nil &&          // Synced to cloud
                meal.syncStatus == "synced"     // Sync completed successfully
            }
        )

        let oldMeals = try context.fetch(fetchDescriptor)
        let deleteCount = oldMeals.count

        guard deleteCount > 0 else {
            print("✅ No old meals to prune")
            lastPruneDate = Date()
            return 0
        }

        // Delete old meals from local SwiftData
        // (They remain in Supabase for long-term stats)
        for meal in oldMeals {
            context.delete(meal)
        }

        try context.save()

        lastPruneDate = Date()
        print("✅ Pruned \(deleteCount) meals from local cache (preserved in cloud)")

        return deleteCount
    }

    // MARK: - Stats

    /// Get cache statistics
    func getCacheStats(context: ModelContext) throws -> CacheStats {
        // Total meals in local database
        let totalDescriptor = FetchDescriptor<Meal>()
        let totalMeals = try context.fetch(totalDescriptor).count

        // Meals older than 30 days
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -cacheWindowDays, to: Date())!
        let oldDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.timestamp < cutoffDate
            }
        )
        let oldMeals = try context.fetch(oldDescriptor).count

        // Synced meals
        let syncedDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.syncStatus == "synced"
            }
        )
        let syncedMeals = try context.fetch(syncedDescriptor).count

        // Purgeable meals (old + synced)
        let purgeableDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.timestamp < cutoffDate &&
                meal.cloudId != nil &&
                meal.syncStatus == "synced"
            }
        )
        let purgeableMeals = try context.fetch(purgeableDescriptor).count

        return CacheStats(
            totalMeals: totalMeals,
            oldMeals: oldMeals,
            syncedMeals: syncedMeals,
            purgeableMeals: purgeableMeals,
            lastPruneDate: lastPruneDate
        )
    }
}

// MARK: - Cache Stats

struct CacheStats {
    let totalMeals: Int
    let oldMeals: Int
    let syncedMeals: Int
    let purgeableMeals: Int
    let lastPruneDate: Date?

    var cacheEfficiency: Double {
        guard totalMeals > 0 else { return 1.0 }
        return 1.0 - (Double(purgeableMeals) / Double(totalMeals))
    }
}
