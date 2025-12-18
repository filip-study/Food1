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
    var testUserEmail: String? {
        ProcessInfo.processInfo.environment["TEST_USER_EMAIL"]
    }

    /// Test user password from environment
    var testUserPassword: String? {
        ProcessInfo.processInfo.environment["TEST_USER_PASSWORD"]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]

        // Pass test credentials to app
        if let email = testUserEmail {
            app.launchEnvironment["TEST_USER_EMAIL"] = email
        }
        if let password = testUserPassword {
            app.launchEnvironment["TEST_USER_PASSWORD"] = password
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

    /// Navigate to a specific tab
    func navigateToTab(_ tabName: String) {
        let tab = app.tabBars.buttons[tabName]
        if tab.waitForExistence(timeout: 3) {
            tab.tap()
        }
    }

    /// Navigate to Settings tab
    func navigateToSettings() {
        navigateToTab("Settings")
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

    /// Check if user is signed in (main tab bar is visible)
    var isSignedIn: Bool {
        app.tabBars.firstMatch.waitForExistence(timeout: 3)
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

        // Wait for main screen
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10),
                      "Should be signed in and see main tab bar")
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
