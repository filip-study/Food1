//
//  Food1App.swift
//  Food1
//
//  App entry point - orchestrates SwiftData, auth, and navigation.
//
//  WHY THIS ARCHITECTURE:
//  - Uses AppSchemaManager for ModelContainer creation (extracted for testability)
//  - Uses BackgroundEnrichmentManager for background task handling (extracted for clarity)
//  - Auth routing: WelcomeView → OnboardingView (auth) → PersonalizationFlow → PaywallView → MainTabView
//  - PersonalizationFlow: Full-screen onboarding for goals, diet, profile, activity level, and notifications
//  - LaunchScreenView overlay for animated splash screen
//  - Deep link handling for auth callbacks and meal reminders
//
//  EXTRACTED CONCERNS:
//  - AppSchemaManager.swift: Schema definition, migration handling
//  - BackgroundEnrichmentManager.swift: BGTask registration, scheduling, execution
//

import SwiftUI
import SwiftData
import BackgroundTasks
import Auth
import Supabase
import ActivityKit

@main
struct Food1App: App {
    let modelContainer: ModelContainer
    @State private var launchScreenState = LaunchScreenStateManager()
    @State private var showingDatabaseError = false
    @State private var databaseErrorMessage = ""
    @State private var showOnboarding = false
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var migrationService = MigrationService.shared
    @StateObject private var deepLinkHandler = MealReminderDeepLinkHandler.shared
    @StateObject private var onboardingService = OnboardingService.shared
    @Environment(\.scenePhase) private var scenePhase

    #if DEBUG
    /// Demo mode state (DEBUG only) - use ObservedObject since singleton already exists
    @ObservedObject private var demoModeManager = DemoModeManager.shared
    #endif

    /// Reference to background enrichment manager for scheduling
    private let enrichmentManager = BackgroundEnrichmentManager.shared

    init() {
        // Create ModelContainer using extracted schema manager
        modelContainer = AppSchemaManager.createModelContainer()

        // Register background tasks (must happen before first UI render)
        enrichmentManager.register(with: modelContainer)
        MealActivityScheduler.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Auth routing: Show onboarding, confirmation pending, demo mode, or main app
                #if DEBUG
                // DEBUG: Include demo mode check
                if demoModeManager.isActive, let demoContainer = demoModeManager.demoContainer {
                    // Demo mode active: Show main app with demo data (no banner for clean screenshots)
                    MainTabView()
                        .environmentObject(authViewModel)
                        .modelContainer(demoContainer)
                } else if let pendingEmail = authViewModel.emailPendingConfirmation {
                    // Email confirmation pending
                    EmailConfirmationPendingView(email: pendingEmail)
                        .environmentObject(authViewModel)
                } else if authViewModel.isAuthenticated && !authViewModel.hasCompletedPersonalization {
                    // Authenticated but hasn't completed personalization: Show full-screen onboarding
                    OnboardingFlowContainer(onComplete: {
                        Task {
                            await authViewModel.markPersonalizationComplete()
                        }
                    })
                    .environmentObject(authViewModel)
                } else if authViewModel.isAuthenticated && !authViewModel.hasAccess {
                    // Authenticated but no subscription: Show onboarding paywall
                    // User must subscribe (with free trial) to access the app
                    OnboardingPaywallView()
                        .environmentObject(authViewModel)
                } else if authViewModel.isAuthenticated {
                    // Authenticated AND subscribed: Show main app
                    MainTabView()
                        .environmentObject(authViewModel)
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                            enrichmentManager.scheduleEnrichmentTask()
                        }
                } else {
                    // Not authenticated: Show welcome or onboarding
                    if showOnboarding {
                        OnboardingView()
                            .environmentObject(authViewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        WelcomeView(
                            showOnboarding: $showOnboarding,
                            onDemoModeActivated: {
                                activateDemoMode()
                            }
                        )
                        .transition(.opacity)
                    }
                }
                #else
                // RELEASE: No demo mode
                if let pendingEmail = authViewModel.emailPendingConfirmation {
                    // Email confirmation pending
                    EmailConfirmationPendingView(email: pendingEmail)
                        .environmentObject(authViewModel)
                } else if authViewModel.isAuthenticated && !authViewModel.hasCompletedPersonalization {
                    // Authenticated but hasn't completed personalization: Show full-screen onboarding
                    OnboardingFlowContainer(onComplete: {
                        Task {
                            await authViewModel.markPersonalizationComplete()
                        }
                    })
                    .environmentObject(authViewModel)
                } else if authViewModel.isAuthenticated && !authViewModel.hasAccess {
                    // Authenticated but no subscription: Show onboarding paywall
                    // User must subscribe (with free trial) to access the app
                    OnboardingPaywallView()
                        .environmentObject(authViewModel)
                } else if authViewModel.isAuthenticated {
                    // Authenticated AND subscribed: Show main app
                    MainTabView()
                        .environmentObject(authViewModel)
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                            enrichmentManager.scheduleEnrichmentTask()
                        }
                } else {
                    // Not authenticated: Show welcome or onboarding
                    if showOnboarding {
                        OnboardingView()
                            .environmentObject(authViewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        WelcomeView(showOnboarding: $showOnboarding)
                            .transition(.opacity)
                    }
                }
                #endif

                // Migration progress overlay
                if migrationService.isMigrating {
                    MigrationProgressView()
                        .transition(.opacity)
                        .zIndex(2)
                }

                // Animated splash screen overlay
                if launchScreenState.state == .animating {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(3)
                }
            }
            .task {
                // Configure SyncCoordinator FIRST so it's ready when auth triggers sync
                SyncCoordinator.shared.configure(with: modelContainer)

                #if DEBUG
                // Check for demo mode launch argument (-demoMode)
                if demoModeManager.shouldActivateFromLaunchArgument {
                    demoModeManager.activate()

                    // Generate statistics aggregates for Stats view (must complete before UI loads)
                    await demoModeManager.generateStatisticsAggregates()

                    // Still need to wait for and dismiss splash screen
                    try? await Task.sleep(for: .milliseconds(1400))
                    withAnimation(.easeOut(duration: 0.4)) {
                        launchScreenState.finish()
                    }
                    return  // Skip normal auth flow in demo mode
                }
                #endif

                // Check for existing session on launch
                await authViewModel.checkSession()

                // Wait for splash animation to complete FIRST (1.2s animation + 0.2s buffer)
                try? await Task.sleep(for: .milliseconds(1400))

                // Fade out splash screen
                withAnimation(.easeOut(duration: 0.4)) {
                    launchScreenState.finish()
                }

                // Only proceed if authenticated
                guard authViewModel.isAuthenticated else { return }

                // Check if migration is needed (first-time cloud sync)
                let context = modelContainer.mainContext
                do {
                    if try migrationService.needsMigration(context: context) {
                        // Migrate existing local meals to cloud
                        print("🚀 Starting migration of existing meals to cloud...")
                        try await migrationService.migrateAllMeals(context: context)
                    }
                } catch {
                    print("❌ Migration failed: \(error)")
                }

                // Resume unfinished enrichment (after app is fully loaded and migration complete)
                await enrichmentManager.resumeUnfinishedEnrichment()

                // Load centralized onboarding state (shows pending onboarding automatically)
                await onboardingService.loadOnboardingState()

                // Restore fasting Live Activity if there's an active fast
                await restoreFastingActivityIfNeeded()
            }
            .onOpenURL { url in
                // Handle deep links for authentication callbacks and meal reminders
                Task {
                    // First try meal reminder deep links (synchronous)
                    if deepLinkHandler.handleURL(url) {
                        return
                    }
                    // Otherwise handle auth deep links
                    await handleDeepLink(url)
                }
            }
            .sheet(isPresented: $deepLinkHandler.shouldShowQuickAdd) {
                QuickAddMealView(
                    selectedDate: Date(),
                    initialEntryMode: .camera
                )
                .environmentObject(authViewModel)
                .onDisappear {
                    // End the Live Activity when user finishes (logged or cancelled)
                    // User was prompted, so end regardless of outcome
                    if let windowId = deepLinkHandler.pendingMealWindowId {
                        Task {
                            await MealActivityScheduler.shared.endActivity(for: windowId, reason: .logged)
                        }
                    }
                    deepLinkHandler.clearPendingState()
                }
            }
            .alert("End Fast?", isPresented: $deepLinkHandler.shouldShowEndFastConfirmation) {
                Button("End Fast", role: .destructive) {
                    endFastFromDeepLink()
                }
                Button("Keep Fasting", role: .cancel) {
                    deepLinkHandler.clearFastingState()
                }
            } message: {
                Text("This will end your current fasting session and log it to your history.")
            }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Refresh subscription and activities when app comes to foreground
            if newPhase == .active && authViewModel.isAuthenticated {
                Task {
                    // Refresh StoreKit entitlements (updates hasAccess via Combine)
                    await SubscriptionService.shared.updateSubscriptionStatus()
                    // Check and update meal reminder activities
                    await MealActivityScheduler.shared.checkAndScheduleActivities()
                }
            }

            // Schedule meal reminder background task when going to background
            if newPhase == .background && authViewModel.isAuthenticated {
                MealActivityScheduler.shared.scheduleBackgroundCheck()
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { oldValue, newValue in
            // When user logs in, identify for analytics and load onboarding state
            if newValue && !oldValue {
                Task {
                    // Identify user for analytics (uses anonymized Supabase UUID)
                    if let userId = try? await SupabaseService.shared.requireUserId() {
                        AnalyticsService.shared.identify(userId: userId)
                        AnalyticsService.shared.track(.signIn)
                    }

                    // Small delay for better UX after login animation
                    try? await Task.sleep(for: .seconds(1.5))
                    await onboardingService.loadOnboardingState()
                }
            }

            // When user logs out, reset analytics identity
            if !newValue && oldValue {
                AnalyticsService.shared.track(.signOut)
                AnalyticsService.shared.reset()
            }
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

    // MARK: - Restore Fasting Activity

    /// Restore fasting Live Activity if there's an active fast
    @MainActor
    private func restoreFastingActivityIfNeeded() async {
        // Check if ActivityKit already has a fasting activity restored
        guard !FastingActivityManager.shared.isActivityActive else {
            return
        }

        // Query for active fast in SwiftData
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Fast>(
            predicate: #Predicate { $0.isActive }
        )

        do {
            if let activeFast = try context.fetch(descriptor).first {
                // Found an active fast - start a Live Activity for it
                #if DEBUG
                await FastingActivityManager.shared.startActivity(for: activeFast, demoMode: DemoModeManager.shared.isActive)
                #else
                await FastingActivityManager.shared.startActivity(for: activeFast)
                #endif
                print("✅ Restored fasting Live Activity for fast: \(activeFast.id)")
            }
        } catch {
            print("❌ Failed to check for active fast: \(error)")
        }
    }

    // MARK: - End Fast from Deep Link

    /// End fast from Live Activity "End Fast" button
    @MainActor
    private func endFastFromDeepLink() {
        guard let fastId = deepLinkHandler.pendingEndFastId else {
            deepLinkHandler.clearFastingState()
            return
        }

        // Find and end the fast in SwiftData
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Fast>(
            predicate: #Predicate { $0.id == fastId && $0.isActive }
        )

        do {
            if let fast = try context.fetch(descriptor).first {
                fast.end()
                try context.save()

                // End Live Activity
                Task {
                    await FastingActivityManager.shared.endActivity()
                }

                HapticManager.success()
                print("✅ Fast ended from deep link: \(fastId)")
            } else {
                print("⚠️ No active fast found for id: \(fastId)")
            }
        } catch {
            print("❌ Failed to end fast: \(error)")
        }

        deepLinkHandler.clearFastingState()
    }

    // MARK: - Demo Mode (DEBUG Only)

    #if DEBUG
    /// Activate demo mode with sample data
    @MainActor
    private func activateDemoMode() {
        print("[DemoMode] Activating demo mode from app...")
        demoModeManager.activate()

        // Generate statistics aggregates for Stats view (same as launch argument path)
        Task {
            await demoModeManager.generateStatisticsAggregates()
        }
    }
    #endif
}

// MARK: - Demo Mode Banner (DEBUG Only)

#if DEBUG
/// Visual indicator that demo mode is active
struct DemoModeBanner: View {
    @StateObject private var demoModeManager = DemoModeManager.shared

    var body: some View {
        if demoModeManager.isActive {
            HStack(spacing: 6) {
                Image(systemName: "theatermask.and.paintbrush")
                    .font(.system(size: 12, weight: .semibold))

                Text("DEMO MODE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)

                Spacer()

                Button {
                    withAnimation {
                        demoModeManager.deactivate()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.top, 50) // Below status bar
        }
    }
}
#endif
