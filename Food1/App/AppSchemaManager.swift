//
//  AppSchemaManager.swift
//  Food1
//
//  Creates and manages the SwiftData ModelContainer with migration handling.
//
//  WHY THIS EXISTS:
//  - Centralized schema definition prevents scattered @Model references
//  - Migration failure handling: Delete corrupt store and start fresh (dev safety net)
//  - In-memory fallback: If all else fails, allow temporary usage without crash
//  - Extracted from Food1App.swift to separate data layer from UI initialization
//
//  MIGRATION STRATEGY:
//  - On failure: Delete corrupted database and recreate fresh
//  - PRODUCTION NOTE: This loses user data. Before App Store launch, consider:
//    1. Show alert before deletion
//    2. Create backup before deletion
//    3. Provide data export/recovery options
//
//  SCHEMA:
//  - Meal: Core meal record with macros, timestamp, photo
//  - MealIngredient: Individual ingredients with USDA enrichment data
//  - DailyAggregate, WeeklyAggregate, MonthlyAggregate: Pre-computed stats
//

import Foundation
import SwiftData

/// Manages SwiftData schema and container creation
struct AppSchemaManager {

    /// The complete schema definition for SwiftData
    static let schema = Schema([
        Meal.self,
        MealIngredient.self,
        DailyAggregate.self,
        WeeklyAggregate.self,
        MonthlyAggregate.self
    ])

    /// Creates a configured ModelContainer with migration handling
    /// - Returns: A configured ModelContainer ready for use
    /// - Note: Never throws - returns in-memory fallback if all else fails
    static func createModelContainer() -> ModelContainer {
        do {
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )

            // Try to initialize with migration
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                // If migration fails, delete the old store and start fresh
                print("⚠️  Migration failed, resetting ModelContainer: \(error)")

                // Get the store URL and delete it
                let storeURL = modelConfiguration.url
                try? FileManager.default.removeItem(at: storeURL)
                print("⚠️  Deleted corrupted database at: \(storeURL)")
                print("⚠️  User will lose existing meal history")

                // Recreate container
                let container = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
                print("✅ Created fresh ModelContainer")
                return container
            }
        } catch {
            // PRODUCTION: Don't crash - create in-memory container as fallback
            print("❌ CRITICAL: Could not initialize ModelContainer: \(error)")
            print("⚠️  Creating temporary in-memory database")

            do {
                let inMemoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    allowsSave: false
                )
                let container = try ModelContainer(
                    for: schema,
                    configurations: [inMemoryConfig]
                )
                print("✅ Created temporary in-memory database")
                print("⚠️  Data will not be saved. Please reinstall the app.")
                return container
            } catch {
                // Last resort: This should never happen
                fatalError("CRITICAL: Could not create even in-memory database: \(error)")
            }
        }
    }
}
