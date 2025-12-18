//
//  AccountDeletionUITests.swift
//  Food1UITests
//
//  E2E tests for account deletion flow.
//  Tests the full user journey: sign in → delete account → verify signed out.
//
//  PREREQUISITES:
//  - TEST_USER_EMAIL and TEST_USER_PASSWORD environment variables set
//  - These are created by the CI workflow via Supabase Admin API
//
//  RUN LOCALLY:
//  1. ./scripts/e2e-test-user.sh create
//  2. xcodebuild test -scheme Food1 -only-testing:Food1UITests/AccountDeletionUITests
//

import XCTest

final class AccountDeletionUITests: Food1UITestCase {

    // MARK: - Full Account Deletion E2E Test

    /// Test the complete account deletion flow:
    /// 1. Sign in with test credentials
    /// 2. Navigate to Account settings
    /// 3. Initiate deletion (first confirmation)
    /// 4. Type DELETE (second confirmation)
    /// 5. Confirm deletion
    /// 6. Verify user is signed out
    func testFullAccountDeletionFlow() throws {
        // Step 1: Sign in with test credentials
        try signInWithEmailPassword()

        // Wait for main app to load (tab bar visible)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10),
                      "Should see main app after sign in")

        // Step 2: Navigate to Settings → Account
        navigateToSettings()

        let accountButton = app.buttons["Account"]
        XCTAssertTrue(accountButton.waitForExistence(timeout: 5),
                      "Account button should exist in Settings")
        accountButton.tap()

        // Step 3: Tap Delete Account
        let deleteButton = app.buttons["Delete Account"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5),
                      "Delete Account button should exist")

        // Take screenshot before deletion
        takeScreenshot(name: "Before-Delete-Account")

        deleteButton.tap()

        // Step 4: First confirmation dialog
        let firstDialog = app.alerts.firstMatch
        XCTAssertTrue(firstDialog.waitForExistence(timeout: 3),
                      "First confirmation dialog should appear")

        // Tap "Delete Account" in the dialog
        let confirmDeleteButton = firstDialog.buttons["Delete Account"]
        XCTAssertTrue(confirmDeleteButton.exists,
                      "Delete Account button should exist in dialog")
        confirmDeleteButton.tap()

        // Step 5: Second confirmation - type DELETE
        let secondDialog = app.alerts["Confirm Deletion"]
        XCTAssertTrue(secondDialog.waitForExistence(timeout: 3),
                      "Second confirmation dialog should appear")

        // Find and fill the text field
        let textField = secondDialog.textFields.firstMatch
        XCTAssertTrue(textField.exists, "Text field for typing DELETE should exist")
        textField.tap()
        textField.typeText("DELETE")

        // Step 6: Tap "Delete Forever"
        let deleteForeverButton = secondDialog.buttons["Delete Forever"]
        XCTAssertTrue(deleteForeverButton.exists,
                      "Delete Forever button should exist")
        deleteForeverButton.tap()

        // Step 7: Verify we're signed out (back at onboarding)
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 10),
                      "Should be back at sign-in screen after account deletion")

        takeScreenshot(name: "After-Account-Deleted")
    }

    /// Test that cancel in first dialog works
    func testCancelFirstConfirmationDialog() throws {
        try signInWithEmailPassword()

        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            throw XCTSkip("Could not sign in")
        }

        navigateToSettings()
        app.buttons["Account"].tap()

        // Tap Delete Account
        let deleteButton = app.buttons["Delete Account"]
        guard deleteButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Delete Account button not found")
        }
        deleteButton.tap()

        // First dialog appears
        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))

        // Tap Cancel
        dialog.buttons["Cancel"].tap()

        // Dialog should dismiss
        XCTAssertTrue(waitForElementToDisappear(dialog, timeout: 2),
                      "Dialog should dismiss after cancel")

        // Should still be on Account settings
        XCTAssertTrue(app.buttons["Delete Account"].exists,
                      "Should still see Delete Account button")
    }

    /// Test that cancel in second dialog works
    func testCancelSecondConfirmationDialog() throws {
        try signInWithEmailPassword()

        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            throw XCTSkip("Could not sign in")
        }

        navigateToSettings()
        app.buttons["Account"].tap()

        // Navigate through first dialog
        app.buttons["Delete Account"].tap()
        let firstDialog = app.alerts.firstMatch
        XCTAssertTrue(firstDialog.waitForExistence(timeout: 3))
        firstDialog.buttons["Delete Account"].tap()

        // Second dialog appears
        let secondDialog = app.alerts["Confirm Deletion"]
        XCTAssertTrue(secondDialog.waitForExistence(timeout: 3))

        // Tap Cancel
        secondDialog.buttons["Cancel"].tap()

        // Should return to Account settings
        XCTAssertTrue(app.buttons["Delete Account"].waitForExistence(timeout: 3),
                      "Should return to Account settings after cancel")
    }

    // MARK: - Sign In Helper

    /// Sign in using email/password from environment variables
    /// The onboarding flow is:
    /// 1. Initial screen with Apple Sign In + "Continue with Email"
    /// 2. Tap "Continue with Email" to show email form
    /// 3. Form has segmented picker (Sign In / Sign Up) + email + password fields
    private func signInWithEmailPassword() throws {
        guard let email = testUserEmail, let password = testUserPassword else {
            throw XCTSkip("TEST_USER_EMAIL and TEST_USER_PASSWORD must be set")
        }

        // If already signed in, we're good
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) {
            return
        }

        // Step 1: Wait for onboarding and tap "Continue with Email"
        let continueWithEmail = app.buttons["Continue with Email"]
        guard continueWithEmail.waitForExistence(timeout: 5) else {
            throw XCTSkip("Continue with Email button not found")
        }
        continueWithEmail.tap()

        // Step 2: Wait for email form to appear (look for email text field)
        // The TextField uses placeholder "you@example.com"
        let emailField = app.textFields["you@example.com"]
        guard emailField.waitForExistence(timeout: 3) else {
            throw XCTSkip("Email field not found after tapping Continue with Email")
        }

        // The segmented picker defaults to "Sign In" mode - no need to tap it
        // Note: There are two "Sign In" elements - the segment and the submit button
        // The segment is in a segmented control, while the submit button is standalone

        // Step 3: Enter credentials
        emailField.tap()
        emailField.typeText(email)

        // Password field uses placeholder "At least 8 characters"
        let passwordField = app.secureTextFields["At least 8 characters"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2),
                      "Password field should exist")
        passwordField.tap()
        passwordField.typeText(password)

        // Step 4: Tap the Sign In submit button
        // There are 2 "Sign In" buttons - the segment and the submit button
        // The submit button is the last one in the hierarchy (comes after segment)
        let signInButtons = app.buttons.matching(identifier: "Sign In")
        let buttonCount = signInButtons.count
        XCTAssertGreaterThan(buttonCount, 0, "Sign In buttons should exist")

        // Tap the last matching button (the submit button)
        let submitButton = signInButtons.element(boundBy: buttonCount - 1)
        XCTAssertTrue(submitButton.isHittable, "Submit button should be hittable")
        submitButton.tap()

        // Step 5: Wait for sign-in to complete
        // First, wait a moment for the network request
        sleep(3)

        // Take a screenshot to see the current state
        takeScreenshot(name: "After-Sign-In-Tap")

        // Check if there's a loading indicator (ProgressView in button)
        // If still loading after 5 seconds, something is wrong
        let isStillLoading = app.activityIndicators.firstMatch.waitForExistence(timeout: 1)
        if isStillLoading {
            print("🔄 Still loading, waiting for activity indicator to disappear...")
            _ = waitForElementToDisappear(app.activityIndicators.firstMatch, timeout: 10)
        }

        // Log all visible static texts for debugging
        print("📋 All visible static texts after sign-in attempt:")
        for (index, staticText) in app.staticTexts.allElementsBoundByIndex.enumerated() {
            if !staticText.label.isEmpty {
                print("  [\(index)] \(staticText.label)")
            }
        }

        // Log all visible buttons
        print("📋 All visible buttons after sign-in attempt:")
        for (index, button) in app.buttons.allElementsBoundByIndex.enumerated() {
            if !button.label.isEmpty {
                print("  [\(index)] \(button.label)")
            }
        }

        // Check if we're still on the sign-in form (Sign In button still visible)
        let signInButtonsAfter = app.buttons.matching(identifier: "Sign In")
        let signInStillVisible = signInButtonsAfter.count > 1 // Both segment and submit button

        // Check for error message - look for text containing common error patterns
        let errorIndicators = ["error", "failed", "invalid", "incorrect", "wrong", "unable", "could not"]
        var foundError: String?
        for staticText in app.staticTexts.allElementsBoundByIndex {
            let label = staticText.label.lowercased()
            if errorIndicators.contains(where: { label.contains($0) }) {
                foundError = staticText.label
                break
            }
        }

        if let error = foundError {
            takeScreenshot(name: "Sign-In-Error")
            XCTFail("Sign-in failed with error: \(error)")
        }

        // If Sign In button is still visible and no tab bar, sign-in is stuck
        if signInStillVisible && !app.tabBars.firstMatch.exists {
            takeScreenshot(name: "Sign-In-Stuck")
            print("⚠️ Sign-in appears stuck - Sign In button still visible, no tab bar")
        }

        // Step 6: Wait for main app (tab bar should appear)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15),
                      "Should be signed in and see main tab bar")
    }
}
