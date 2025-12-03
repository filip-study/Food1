//
//  Food1App.swift
//  Food1
//
//  App entry point with SwiftData persistence and background enrichment.
//
//  WHY THIS ARCHITECTURE:
//  - Schema includes all @Model classes for SwiftData to manage relationships correctly
//  - Migration failure handling: Deletes corrupt store and creates fresh container (dev safety, not prod)
//  - Background task registration enables iOS to run enrichment when app is suspended
//  - resumeUnfinishedEnrichment() on launch handles interrupted enrichments (app closed mid-process)
//  - 10-minute window for "recent" ingredients prevents infinite re-attempts on old data
//

import SwiftUI
import SwiftData
import BackgroundTasks
import Auth
import Supabase

@main
struct Food1App: App {
    let modelContainer: ModelContainer
    @State private var launchScreenState = LaunchScreenStateManager()
    @State private var showingDatabaseError = false
    @State private var databaseErrorMessage = ""
    @StateObject private var authViewModel = AuthViewModel()

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
                // PRODUCTION NOTE: This will delete user data. In production, consider:
                // 1. Showing alert before deletion
                // 2. Creating backup before deletion
                // 3. Providing data export/recovery options
                print("⚠️  Migration failed, resetting ModelContainer: \(error)")

                // Get the store URL and delete it
                let storeURL = modelConfiguration.url
                try? FileManager.default.removeItem(at: storeURL)
                print("⚠️  Deleted corrupted database at: \(storeURL)")
                print("⚠️  User will lose existing meal history")

                // Recreate container
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
                print("✅ Created fresh ModelContainer")
            }
        } catch {
            // PRODUCTION: Don't crash - create in-memory container as fallback
            // This allows users to at least use the app temporarily
            print("❌ CRITICAL: Could not initialize ModelContainer: \(error)")
            print("⚠️  Creating temporary in-memory database")

            do {
                let schema = Schema([
                    Meal.self,
                    MealIngredient.self,
                    DailyAggregate.self,
                    WeeklyAggregate.self,
                    MonthlyAggregate.self
                ])
                let inMemoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    allowsSave: false
                )
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [inMemoryConfig]
                )
                print("✅ Created temporary in-memory database")
                print("⚠️  Data will not be saved. Please reinstall the app.")
            } catch {
                // Last resort: This should never happen, but if it does,
                // we have no choice but to crash
                fatalError("CRITICAL: Could not create even in-memory database: \(error)")
            }
        }

        // Register background task for enrichment
        let container = modelContainer
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.enrichmentTaskIdentifier,
            using: nil
        ) { task in
            // Safe cast - if wrong type, skip the task
            guard let processingTask = task as? BGProcessingTask else {
                print("⚠️  Received unexpected task type: \(type(of: task))")
                task.setTaskCompleted(success: false)
                return
            }
            Food1App.handleEnrichmentBackgroundTask(processingTask, container: container)
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
            ZStack {
                // Auth routing: Show onboarding, confirmation pending, or main app
                if let pendingEmail = authViewModel.emailPendingConfirmation {
                    // Email confirmation pending: Show confirmation screen
                    EmailConfirmationPendingView(email: pendingEmail)
                        .environmentObject(authViewModel)
                } else if authViewModel.isAuthenticated {
                    // Authenticated and confirmed: Show main app
                    MainTabView()
                        .environmentObject(authViewModel)
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                            // Schedule background task when app goes to background
                            scheduleEnrichmentTask()
                        }
                } else {
                    // Not authenticated: Show onboarding
                    OnboardingView()
                        .environmentObject(authViewModel)
                }

                // Animated splash screen overlay
                if launchScreenState.state == .animating {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // Check for existing session on launch
                await authViewModel.checkSession()

                // Wait for splash animation to complete FIRST (1.2s animation + 0.2s buffer)
                try? await Task.sleep(for: .milliseconds(1400))

                // Fade out splash screen
                withAnimation(.easeOut(duration: 0.4)) {
                    launchScreenState.finish()
                }

                // THEN resume unfinished enrichment (after app is fully loaded)
                // Only if authenticated
                if authViewModel.isAuthenticated {
                    await resumeUnfinishedEnrichment()
                }
            }
            .onOpenURL { url in
                // Handle deep links for authentication callbacks
                Task {
                    await handleDeepLink(url)
                }
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

    /// Handle deep links for authentication callbacks
    @MainActor
    private func handleDeepLink(_ url: URL) async {
        #if DEBUG
        print("🔗 Deep link received: \(url.absoluteString)")
        #endif

        // Check if this is an authentication callback
        guard url.scheme == "com.filipolszak.food1",
              url.host == "auth",
              url.path == "/callback" else {
            #if DEBUG
            print("⚠️  Not an auth callback URL, ignoring")
            #endif
            return
        }

        // Extract URL components
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            #if DEBUG
            print("⚠️  No query parameters in deep link")
            #endif
            return
        }

        // Look for Supabase auth parameters
        // Supabase sends: access_token, refresh_token, expires_in, token_type
        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                params[item.name] = value
            }
        }

        #if DEBUG
        print("🔑 Deep link params: \(params.keys.joined(separator: ", "))")
        #endif

        // If we have access_token, this is a successful auth callback
        if params["access_token"] != nil {
            do {
                // Supabase SDK handles session restoration from URL
                // We just need to trigger a session check
                try await SupabaseService.shared.client.auth.session(from: url)

                #if DEBUG
                print("✅ Session restored from deep link")
                #endif

                // Refresh auth state
                await authViewModel.checkSession()

            } catch {
                #if DEBUG
                print("❌ Failed to restore session from deep link: \(error)")
                #endif
                authViewModel.errorMessage = "Failed to complete authentication. Please try again."
            }
        } else if let error = params["error"], let errorDescription = params["error_description"] {
            #if DEBUG
            print("❌ Auth error in deep link: \(error) - \(errorDescription)")
            #endif
            authViewModel.errorMessage = errorDescription
        }
    }
}
