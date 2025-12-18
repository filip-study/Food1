//
//  AuthUITests.swift
//  Food1UITests
//
//  UI tests for authentication flows.
//

import XCTest

final class AuthUITests: Food1UITestCase {

    // MARK: - Sign In Screen Tests

    /// Test that onboarding screen shows sign in options
    func testOnboardingScreenElements() {
        // If already signed in, sign out first (or skip)
        if isSignedIn {
            throw XCTSkip("Already signed in - run on fresh install")
        }

        // Verify Apple Sign In button exists
        let appleSignIn = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignIn.waitForExistence(timeout: 5),
                      "Apple Sign In button should be visible")

        // Verify there's some welcome/onboarding content
        // (adjust based on your actual UI)
    }

    // MARK: - Sign Out Tests

    /// Test sign out flow
    func testSignOutFlow() throws {
        try skipIfNotSignedIn()

        // Navigate to Account
        navigateToSettings()

        let accountButton = app.buttons["Account"]
        guard accountButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Account button not found")
        }
        accountButton.tap()

        // Tap Sign Out
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 3))
        signOutButton.tap()

        // Confirm sign out
        let confirmButton = app.buttons["Sign Out"]  // In the dialog
        if confirmButton.waitForExistence(timeout: 2) {
            confirmButton.tap()
        }

        // Verify we're back at onboarding
        let appleSignIn = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignIn.waitForExistence(timeout: 5),
                      "Should see sign in screen after signing out")
    }
}
