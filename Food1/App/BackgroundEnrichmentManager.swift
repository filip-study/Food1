//
//  BackgroundEnrichmentManager.swift
//  Food1
//
//  Manages background task registration and enrichment scheduling.
//
//  WHY THIS EXISTS:
//  - Background tasks require registration before app finishes launching
//  - Enrichment runs when app is suspended to sync USDA data offline
//  - Extracted from Food1App.swift to isolate background task complexity
//
//  BACKGROUND TASK FLOW:
//  1. Register task identifier on app init (before first UI render)
//  2. Schedule task when app goes to background
//  3. iOS decides when to run based on system conditions
//  4. Task fetches unenriched ingredients and runs enrichment
//
//  IMPORTANT:
//  - Task identifier must match Info.plist BGTaskSchedulerPermittedIdentifiers
//  - BGProcessingTask allows longer runtime but requires CPU/network availability
//  - 10-minute window prevents re-attempting very old ingredients
//

import Foundation
import SwiftData
import BackgroundTasks

/// Manages background enrichment task registration and execution
@MainActor
final class BackgroundEnrichmentManager {

    // MARK: - Properties

    static let shared = BackgroundEnrichmentManager()

    /// Background task identifier - must match Info.plist
    static let enrichmentTaskIdentifier = "com.filipolszak.Food1.enrichment"

    private var modelContainer: ModelContainer?

    private init() {}

    // MARK: - Registration

    /// Register the background enrichment task with the system
    /// - Important: Must be called during app initialization, before any UI is presented
    func register(with container: ModelContainer) {
        self.modelContainer = container

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.enrichmentTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                print("⚠️  Received unexpected task type: \(type(of: task))")
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleEnrichmentTask(processingTask)
        }
    }

    // MARK: - Scheduling

    /// Schedule background enrichment to run when app goes to background
    func scheduleEnrichmentTask() {
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

    // MARK: - Execution

    /// Handle the background enrichment task
    private func handleEnrichmentTask(_ task: BGProcessingTask) {
        guard let container = modelContainer else {
            task.setTaskCompleted(success: false)
            return
        }

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

    // MARK: - Resume on Launch

    /// Resume enrichment for ingredients that weren't processed (app was closed mid-enrichment)
    func resumeUnfinishedEnrichment() async {
        guard let container = modelContainer else { return }

        let context = container.mainContext

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
