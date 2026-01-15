//
//  DemoModeManager.swift
//  Food1
//
//  DEBUG-ONLY service for demo mode functionality.
//  Enables screenshot capture and UI testing without real authentication or API calls.
//
//  SECURITY:
//  - Entire file wrapped in #if DEBUG - code is stripped from release builds
//  - No demo credentials stored (authentication is bypassed, not faked)
//  - No API calls made in demo mode (all responses are mocked)
//  - Demo data uses isolated storage, cleared on exit
//
//  ACTIVATION:
//  - Triple-tap on the Prismae logo on the Welcome screen
//  - Only works in DEBUG builds
//

#if DEBUG

import Foundation
import SwiftData
import Combine
import os.log

private let logger = Logger(subsystem: "com.filipolszak.Food1", category: "DemoMode")

/// Manages demo mode state and functionality for development/testing
@MainActor
final class DemoModeManager: ObservableObject {
    static let shared = DemoModeManager()

    /// Whether demo mode is currently active
    @Published private(set) var isActive: Bool = false

    /// Demo mode ModelContainer (separate from production data)
    private(set) var demoContainer: ModelContainer?

    /// Notification posted when demo mode is activated
    static let demoModeActivatedNotification = Notification.Name("DemoModeActivated")

    /// Notification posted when demo mode is deactivated
    static let demoModeDeactivatedNotification = Notification.Name("DemoModeDeactivated")

    private init() {}

    /// Check if demo mode should be activated via launch argument or UserDefaults
    var shouldActivateFromLaunchArgument: Bool {
        // Check both CommandLine argument and UserDefaults (for simctl testing)
        let fromArgs = CommandLine.arguments.contains("-demoMode")
        let fromDefaults = UserDefaults.standard.bool(forKey: "DEMO_MODE")
        logger.info("shouldActivate check: fromArgs=\(fromArgs), fromDefaults=\(fromDefaults)")
        return fromArgs || fromDefaults
    }

    // MARK: - Demo Mode Lifecycle

    /// Activate demo mode with sample data
    /// - Returns: The demo ModelContainer for use in views
    @discardableResult
    func activate() -> ModelContainer? {
        logger.info("activate() called, isActive=\(self.isActive)")
        guard !isActive else { return demoContainer }

        logger.info("Activating demo mode...")

        do {
            // Create in-memory container for demo data
            // IMPORTANT: Must include ALL models from production schema for features to work
            let schema = Schema([
                Meal.self,
                MealIngredient.self,
                DailyAggregate.self,
                WeeklyAggregate.self,
                MonthlyAggregate.self,
                Fast.self
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            demoContainer = try ModelContainer(for: schema, configurations: config)

            // Set demo user defaults for goals/profile
            setupDemoUserDefaults()

            // Populate with sample data (meals + ingredients)
            if let container = demoContainer {
                DemoDataGenerator.populateSampleData(in: container.mainContext)
            }

            isActive = true
            logger.info("isActive set to true, container created")

            // Notify observers
            NotificationCenter.default.post(name: Self.demoModeActivatedNotification, object: nil)

            logger.info("Demo mode activated with sample data")
            return demoContainer

        } catch {
            logger.error("Failed to create demo container: \(error.localizedDescription)")
            return nil
        }
    }

    /// Generate statistics aggregates for demo data
    /// Must be called after activate() completes for Stats view to show data
    func generateStatisticsAggregates() async {
        guard let container = demoContainer else {
            logger.warning("Cannot generate statistics: no demo container")
            return
        }

        logger.info("Generating demo statistics aggregates...")
        await StatisticsService.shared.performInitialMigration(in: container.mainContext)
        logger.info("Demo statistics migration complete")
    }

    /// Deactivate demo mode and clean up
    func deactivate() {
        guard isActive else { return }

        print("[DemoMode] Deactivating demo mode...")

        // Clear demo container (in-memory, so data is lost)
        demoContainer = nil

        // Reset demo user defaults
        clearDemoUserDefaults()

        isActive = false

        // Notify observers
        NotificationCenter.default.post(name: Self.demoModeDeactivatedNotification, object: nil)

        print("[DemoMode] Demo mode deactivated")
    }

    // MARK: - Demo User Defaults

    // MARK: - Demo Profile Configuration

    /// Demo user's display name (shown in greeting on TodayView)
    /// Generic name suitable for marketing screenshots
    static let demoUserName = "Sarah"

    /// Set up demo user profile for realistic goals display
    private func setupDemoUserDefaults() {
        let defaults = UserDefaults.standard

        // Store original values to restore later
        defaults.set(true, forKey: "demoModeWasActive")

        // Set demo user name for personalized greeting
        defaults.set(Self.demoUserName, forKey: "demoUserName")

        // Set demo profile (moderately active adult)
        defaults.set(Gender.female.rawValue, forKey: "userGender")
        defaults.set(28, forKey: "userAge")
        defaults.set(65.0, forKey: "userWeight")  // 65 kg
        defaults.set(165.0, forKey: "userHeight")  // 165 cm
        defaults.set(ActivityLevel.moderatelyActive.rawValue, forKey: "userActivityLevel")
        defaults.set(true, forKey: "useAutoGoals")

        // Use Optimal micronutrient standard for richer stats display
        defaults.set(MicronutrientStandard.optimal.rawValue, forKey: "micronutrientStandard")

        // Unlock all stats periods for demo (bypasses @Query timing issues with in-memory container)
        defaults.set(true, forKey: "stats_monthUnlocked")
        defaults.set(true, forKey: "stats_quarterUnlocked")
        defaults.set(true, forKey: "stats_yearUnlocked")
    }

    /// Clear demo-specific user defaults
    private func clearDemoUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "demoModeWasActive")
        defaults.removeObject(forKey: "demoUserName")

        // Clear demo stats unlocks (so real user must earn them)
        defaults.removeObject(forKey: "stats_monthUnlocked")
        defaults.removeObject(forKey: "stats_quarterUnlocked")
        defaults.removeObject(forKey: "stats_yearUnlocked")
    }

    // MARK: - Mock API Responses

    /// Mock food recognition response for demo mode
    /// Returns a pre-defined meal instead of calling OpenAI
    static func mockFoodRecognition() -> (name: String, emoji: String, calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double, ingredients: [(name: String, grams: Double, calories: Double, protein: Double, carbs: Double, fat: Double)]) {
        // Return a nice demo meal
        return (
            name: "Grilled Salmon with Vegetables",
            emoji: "🐟",
            calories: 520,
            protein: 42,
            carbs: 28,
            fat: 24,
            fiber: 6,
            ingredients: [
                ("Atlantic Salmon Fillet", 150, 310, 34, 0, 18),
                ("Roasted Broccoli", 100, 55, 4, 10, 1),
                ("Sweet Potato", 120, 105, 2, 24, 0),
                ("Olive Oil", 15, 120, 0, 0, 14)
            ]
        )
    }
}

#endif
