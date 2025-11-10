//
//  Food1App.swift
//  Food1
//
//  Created by Filip Olszak on 3/11/25.
//

import SwiftUI
import SwiftData

@main
struct Food1App: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Meal.self,
                MealIngredient.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )

            // Try to initialize with migration
            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                // If migration fails, delete the old store and start fresh
                print("⚠️  Migration failed, resetting ModelContainer: \(error)")

                // Get the store URL and delete it
                let storeURL = modelConfiguration.url
                try? FileManager.default.removeItem(at: storeURL)
                print("✅ Deleted old store at: \(storeURL)")

                // Recreate container
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
                print("✅ Created fresh ModelContainer")
            }
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(modelContainer)
    }
}
