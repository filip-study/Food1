//
//  Food1UITestCase.swift
//  Food1UITests
//
//  Base class for all Food1 UI tests.
//  Provides common setup, helpers, and test utilities.
//

import XCTest

/// Base class for Food1 UI tests
/// Subclass this instead of XCTestCase for common functionality
class Food1UITestCase: XCTestCase {

    var app: XCUIApplication!

    /// Whether we're running in CI environment
    var isCI: Bool {
        ProcessInfo.processInfo.environment["CI"] == "true"
    }

    /// Test user email from environment
    /// Checks both TEST_USER_EMAIL and TEST_RUNNER_TEST_USER_EMAIL (xcodebuild may use either)
    var testUserEmail: String? {
        ProcessInfo.processInfo.environment["TEST_USER_EMAIL"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_TEST_USER_EMAIL"]
    }

    /// Test user password from environment
    /// Checks both TEST_USER_PASSWORD and TEST_RUNNER_TEST_USER_PASSWORD (xcodebuild may use either)
    var testUserPassword: String? {
        ProcessInfo.processInfo.environment["TEST_USER_PASSWORD"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_TEST_USER_PASSWORD"]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]

        // Pass all relevant environment variables to the app
        // This includes test credentials and any other config
        let envVars = ["TEST_USER_EMAIL", "TEST_USER_PASSWORD", "SUPABASE_URL", "SUPABASE_ANON_KEY"]
        for key in envVars {
            if let value = ProcessInfo.processInfo.environment[key] {
                app.launchEnvironment[key] = value
            }
        }

        app.launch()
    }

    override func tearDownWithError() throws {
        // Take screenshot on failure for debugging
        if let failureCount = testRun?.failureCount, failureCount > 0 {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        app = nil
    }

    // MARK: - Navigation Helpers

    /// Navigate to a specific tab in the floating pill navigation
    /// The app uses custom FloatingPillNavigation, NOT standard TabBar
    func navigateToTab(_ tabName: String) {
        // Try finding button by name (for custom FloatingPillNavigation)
        let tabButton = app.buttons[tabName]
        if tabButton.waitForExistence(timeout: 3) && tabButton.isHittable {
            tabButton.tap()
        }
    }

    /// Navigate to Settings (gear icon in TodayView toolbar)
    /// Settings is NOT a tab - it's a gear icon button that opens a sheet
    func navigateToSettings() {
        // Settings is accessed via gear icon in TodayView, not a tab
        // First ensure we're on the Meals tab (TodayView)
        let mealsButton = app.buttons["Meals"]
        if mealsButton.waitForExistence(timeout: 3) && mealsButton.isHittable {
            mealsButton.tap()
            usleep(300_000)  // 0.3s for animation
        }

        // Tap the Settings gear icon (has accessibilityLabel "Settings")
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        } else {
            // Fallback: try tapping the gear icon by image name
            let gearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'gear' OR label CONTAINS[c] 'setting'")).firstMatch
            if gearButton.waitForExistence(timeout: 3) {
                gearButton.tap()
            }
        }
    }

    /// Navigate to Today tab
    func navigateToToday() {
        navigateToTab("Today")
    }

    /// Navigate to History tab
    func navigateToHistory() {
        navigateToTab("History")
    }

    /// Navigate to Stats tab
    func navigateToStats() {
        navigateToTab("Stats")
    }

    // MARK: - Auth Helpers

    /// Check if user is signed in (main tab view is visible)
    /// Uses the mainTabView accessibility identifier since app uses custom navigation
    var isSignedIn: Bool {
        app.otherElements["mainTabView"].waitForExistence(timeout: 3)
    }

    /// Skip test if not signed in
    func skipIfNotSignedIn() throws {
        if !isSignedIn {
            throw XCTSkip("User not signed in - test requires authenticated user")
        }
    }

    /// Sign in with test credentials (if available)
    func signInWithTestCredentials() throws {
        guard let email = testUserEmail, let password = testUserPassword else {
            throw XCTSkip("Test credentials not available")
        }

        // Find and tap email sign in option
        let emailButton = app.buttons["Sign in with Email"]
        guard emailButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Email sign in not available")
        }
        emailButton.tap()

        // Enter email
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText(email)

        // Enter password
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(password)

        // Tap sign in
        app.buttons["Sign In"].tap()

        // Wait for main screen (uses custom navigation, not TabBar)
        XCTAssertTrue(app.otherElements["mainTabView"].waitForExistence(timeout: 10),
                      "Should be signed in and see main app view")
    }

    // MARK: - Wait Helpers

    /// Wait for an element to exist with custom timeout
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Wait for an element to not exist
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for an element to become enabled
    func waitForElementEnabled(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    // MARK: - Scroll Helpers

    /// Scroll until element is visible
    func scrollToElement(_ element: XCUIElement, maxScrolls: Int = 5) {
        var scrollCount = 0
        while !element.isHittable && scrollCount < maxScrolls {
            app.swipeUp()
            scrollCount += 1
        }
    }

    // MARK: - Screenshot Helpers

    /// Take a screenshot and attach it to the test
    func takeScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
