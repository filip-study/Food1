//
//  Food1App.swift
//  Food1
//
//  Created by Filip Olszak on 3/11/25.
//

import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct Food1App: App {
    let modelContainer: ModelContainer

    // Background task identifier
    private static let enrichmentTaskIdentifier = "com.filipolszak.Food1.enrichment"

    init() {
        do {
            let schema = Schema([
                Meal.self,
                MealIngredient.self,
                DailyAggregate.self,
                WeeklyAggregate.self,
                MonthlyAggregate.self
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

        // Register background task for enrichment
        let container = modelContainer
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.enrichmentTaskIdentifier,
            using: nil
        ) { task in
            Food1App.handleEnrichmentBackgroundTask(task as! BGProcessingTask, container: container)
        }
    }

    /// Schedule background enrichment task when app goes to background
    private func scheduleEnrichmentTask() {
        let request = BGProcessingTaskRequest(identifier: Self.enrichmentTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1) // Run ASAP

        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            print("📋 Scheduled background enrichment task")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to schedule background task: \(error)")
            #endif
        }
    }

    /// Handle the background enrichment task
    private static func handleEnrichmentBackgroundTask(_ task: BGProcessingTask, container: ModelContainer) {
        let enrichmentTask = Task { @MainActor in
            let context = container.mainContext
            let tenMinutesAgo = Date().addingTimeInterval(-600)

            let descriptor = FetchDescriptor<MealIngredient>(
                predicate: #Predicate<MealIngredient> { ingredient in
                    ingredient.enrichmentAttempted == false &&
                    ingredient.usdaFdcId == nil &&
                    ingredient.createdAt > tenMinutesAgo
                }
            )

            do {
                let unenrichedIngredients = try context.fetch(descriptor)
                if !unenrichedIngredients.isEmpty {
                    await BackgroundEnrichmentService.shared.enrichIngredients(unenrichedIngredients)
                }
            } catch {
                #if DEBUG
                print("❌ Background enrichment failed: \(error)")
                #endif
            }
        }

        // Handle task expiration
        task.expirationHandler = {
            enrichmentTask.cancel()
        }

        // Mark complete when done
        Task {
            await enrichmentTask.value
            task.setTaskCompleted(success: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    await resumeUnfinishedEnrichment()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Schedule background task when app goes to background
                    scheduleEnrichmentTask()
                }
        }
        .modelContainer(modelContainer)
    }

    /// Resume enrichment for any ingredients that weren't processed
    /// This handles cases where app was closed during enrichment
    @MainActor
    private func resumeUnfinishedEnrichment() async {
        let context = modelContainer.mainContext

        // Find ingredients that need enrichment:
        // 1. Not attempted yet (enrichmentAttempted == false)
        // 2. No USDA match yet (usdaFdcId == nil)
        // 3. Created recently (within last 10 minutes - might have been interrupted)
        let tenMinutesAgo = Date().addingTimeInterval(-600)

        let descriptor = FetchDescriptor<MealIngredient>(
            predicate: #Predicate<MealIngredient> { ingredient in
                ingredient.enrichmentAttempted == false &&
                ingredient.usdaFdcId == nil &&
                ingredient.createdAt > tenMinutesAgo
            }
        )

        do {
            let unenrichedIngredients = try context.fetch(descriptor)

            if !unenrichedIngredients.isEmpty {
                #if DEBUG
                print("🔄 Resuming enrichment for \(unenrichedIngredients.count) ingredients")
                #endif

                await BackgroundEnrichmentService.shared.enrichIngredients(unenrichedIngredients)

                #if DEBUG
                print("✅ Resumed enrichment complete")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to fetch unenriched ingredients: \(error)")
            #endif
        }
    }
}
