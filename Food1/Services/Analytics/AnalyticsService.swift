//
//  AnalyticsService.swift
//  Food1
//
//  PostHog analytics wrapper for event tracking.
//
//  WHY THIS ARCHITECTURE:
//  - Singleton ensures one PostHog instance across app
//  - Credentials loaded from Info.plist (populated via Secrets.xcconfig at build time)
//  - Wrapper provides type-safe event methods
//  - Debug mode skips tracking to avoid polluting production data
//
//  PRIVACY:
//  - No PII collected by default
//  - User ID is anonymized (Supabase UUID)
//  - Location/IP anonymization enabled
//
//  USAGE:
//  - AnalyticsService.shared.track(.mealLogged, properties: ["method": "photo"])
//  - AnalyticsService.shared.identify(userId: uuid)
//

import Foundation
import PostHog

/// Singleton wrapper for PostHog analytics
@MainActor
final class AnalyticsService {

    // MARK: - Singleton

    static let shared = AnalyticsService()

    // MARK: - Properties

    /// Whether analytics is properly configured and active
    private(set) var isConfigured: Bool = false

    // MARK: - Event Types

    /// Strongly-typed analytics events
    enum Event: String {
        // Auth
        case signUp = "user_signed_up"
        case signIn = "user_signed_in"
        case signOut = "user_signed_out"

        // Meals
        case mealLogged = "meal_logged"
        case mealDeleted = "meal_deleted"
        case mealEdited = "meal_edited"

        // Food Recognition
        case photoTaken = "photo_taken"
        case recognitionStarted = "recognition_started"
        case recognitionCompleted = "recognition_completed"
        case recognitionFailed = "recognition_failed"

        // Subscription
        case paywallViewed = "paywall_viewed"
        case subscriptionStarted = "subscription_started"
        case trialStarted = "trial_started"

        // Features
        case statsViewed = "stats_viewed"
        case historyViewed = "history_viewed"
        case settingsOpened = "settings_opened"

        // Onboarding
        case onboardingStarted = "onboarding_started"
        case onboardingCompleted = "onboarding_completed"
        case onboardingSkipped = "onboarding_skipped"
    }

    // MARK: - Initialization

    private init() {
        configure()
    }

    /// Configure PostHog with credentials from Info.plist
    private func configure() {
        // Skip in DEBUG builds to avoid polluting production analytics
        #if DEBUG
        print("📊 [Analytics] DEBUG build - analytics disabled")
        isConfigured = false
        return
        #else

        // Load API key from Info.plist
        guard let apiKey = Bundle.main.infoDictionary?["POSTHOG_API_KEY"] as? String,
              !apiKey.isEmpty,
              apiKey != "$(POSTHOG_API_KEY)" else {
            print("⚠️  [Analytics] POSTHOG_API_KEY not configured")
            isConfigured = false
            return
        }

        // Load host from Info.plist (defaults to PostHog cloud US)
        var host = "https://us.i.posthog.com"
        if let configuredHost = Bundle.main.infoDictionary?["POSTHOG_HOST"] as? String,
           !configuredHost.isEmpty,
           configuredHost != "$(POSTHOG_HOST)" {
            host = configuredHost
        }

        // Configure PostHog
        let config = PostHogConfig(apiKey: apiKey, host: host)

        // Privacy settings
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false  // We track manually for more control
        config.sendFeatureFlagEvent = false

        PostHogSDK.shared.setup(config)
        isConfigured = true

        print("✅ [Analytics] PostHog configured successfully")
        #endif
    }

    // MARK: - User Identity

    /// Identify user after authentication (uses Supabase UUID)
    func identify(userId: UUID) {
        guard isConfigured else { return }

        PostHogSDK.shared.identify(userId.uuidString)

        #if DEBUG
        print("📊 [Analytics] Identified user: \(userId.uuidString.prefix(8))...")
        #endif
    }

    /// Reset identity on sign out
    func reset() {
        guard isConfigured else { return }

        PostHogSDK.shared.reset()

        #if DEBUG
        print("📊 [Analytics] User identity reset")
        #endif
    }

    // MARK: - Event Tracking

    /// Track an event with optional properties
    func track(_ event: Event, properties: [String: Any]? = nil) {
        guard isConfigured else {
            #if DEBUG
            print("📊 [Analytics] Would track: \(event.rawValue) \(properties ?? [:])")
            #endif
            return
        }

        PostHogSDK.shared.capture(event.rawValue, properties: properties)

        #if DEBUG
        print("📊 [Analytics] Tracked: \(event.rawValue)")
        #endif
    }

    /// Track a custom event (for one-off events not in the Event enum)
    func trackCustom(_ eventName: String, properties: [String: Any]? = nil) {
        guard isConfigured else {
            #if DEBUG
            print("📊 [Analytics] Would track custom: \(eventName)")
            #endif
            return
        }

        PostHogSDK.shared.capture(eventName, properties: properties)

        #if DEBUG
        print("📊 [Analytics] Tracked custom: \(eventName)")
        #endif
    }

    // MARK: - Screen Tracking

    /// Track screen view
    func trackScreen(_ screenName: String, properties: [String: Any]? = nil) {
        guard isConfigured else {
            #if DEBUG
            print("📊 [Analytics] Would track screen: \(screenName)")
            #endif
            return
        }

        PostHogSDK.shared.screen(screenName, properties: properties)
    }

    // MARK: - User Properties

    /// Set user properties for segmentation
    /// Note: In PostHog v3, user properties must be set via identify with distinctId
    func setUserProperties(_ properties: [String: Any]) {
        guard isConfigured else { return }

        // PostHog v3 requires distinctId for identify
        let distinctId = PostHogSDK.shared.getDistinctId()
        PostHogSDK.shared.identify(distinctId, userProperties: properties)
    }

    // MARK: - Feature Flags

    /// Check if a feature flag is enabled
    func isFeatureEnabled(_ flagKey: String) -> Bool {
        guard isConfigured else { return false }

        return PostHogSDK.shared.isFeatureEnabled(flagKey)
    }

    /// Get feature flag value
    func getFeatureFlagValue(_ flagKey: String) -> Any? {
        guard isConfigured else { return nil }

        return PostHogSDK.shared.getFeatureFlag(flagKey)
    }

    // MARK: - Flush

    /// Force flush pending events (call before app termination if needed)
    func flush() {
        guard isConfigured else { return }

        PostHogSDK.shared.flush()
    }
}
