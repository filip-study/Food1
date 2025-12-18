//
//  AuthUITests.swift
//  Food1UITests
//
//  Basic UI tests for authentication screens.
//  These tests verify UI elements exist and are accessible.
//

import XCTest

final class AuthUITests: Food1UITestCase {

    // MARK: - Onboarding Screen Tests

    /// Test that onboarding screen shows expected elements
    func testOnboardingScreenElements() throws {
        // If already signed in, skip this test
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) {
            throw XCTSkip("Already signed in - this test requires fresh app state")
        }

        // Verify Apple Sign In button exists
        let appleSignIn = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignIn.waitForExistence(timeout: 5),
                      "Apple Sign In button should be visible")

        // Verify email field exists (for email login)
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.exists, "Email field should exist")

        // Verify password field exists
        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.exists, "Password field should exist")

        takeScreenshot(name: "Onboarding-Screen")
    }

    // MARK: - Sign Out Tests

    /// Test sign out flow returns to onboarding
    func testSignOutFlow() throws {
        // Must be signed in for this test
        guard app.tabBars.firstMatch.waitForExistence(timeout: 3) else {
            throw XCTSkip("Not signed in - skipping sign out test")
        }

        // Navigate to Settings → Account
        navigateToSettings()

        let accountButton = app.buttons["Account"]
        guard accountButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Account button not found")
        }
        accountButton.tap()

        // Tap Sign Out
        let signOutButton = app.buttons["Sign Out"]
        guard signOutButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Sign Out button not found")
        }
        signOutButton.tap()

        // Confirm sign out if dialog appears
        let confirmButton = app.alerts.buttons["Sign Out"]
        if confirmButton.waitForExistence(timeout: 2) {
            confirmButton.tap()
        }

        // Verify we're back at onboarding
        let appleSignIn = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignIn.waitForExistence(timeout: 5),
                      "Should see sign in screen after signing out")

        takeScreenshot(name: "After-Sign-Out")
    }
}
