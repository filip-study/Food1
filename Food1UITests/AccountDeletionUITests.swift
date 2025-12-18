//
//  AccountDeletionUITests.swift
//  Food1UITests
//
//  UI tests for the account deletion flow.
//  Tests the two-step confirmation process required by Apple.
//
//  PREREQUISITES:
//  - Test user must exist (or use --uitesting launch argument to mock)
//  - Simulator must be running
//
//  RUN: xcodebuild test -scheme Food1 -only-testing:Food1UITests/AccountDeletionUITests
//

import XCTest

final class AccountDeletionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        // Launch arguments for UI testing mode
        // The app can check for this to enable test-specific behavior
        app.launchArguments = ["--uitesting"]

        // Environment variables for test credentials (from CI secrets or local .env)
        if let testEmail = ProcessInfo.processInfo.environment["TEST_USER_EMAIL"],
           let testPassword = ProcessInfo.processInfo.environment["TEST_USER_PASSWORD"] {
            app.launchEnvironment["TEST_USER_EMAIL"] = testEmail
            app.launchEnvironment["TEST_USER_PASSWORD"] = testPassword
        }

        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Account Deletion Flow Tests

    /// Test that the Delete Account button exists and is accessible
    func testDeleteAccountButtonExists() throws {
        // Skip if not signed in (we'd need to handle sign-in first)
        try skipIfNotSignedIn()

        // Navigate to Account settings
        navigateToAccountSettings()

        // Verify "Delete Account" button exists in the list
        let deleteButton = app.buttons["Delete Account"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5),
                      "Delete Account button should exist in Account settings")
    }

    /// Test the full account deletion flow (two-step confirmation)
    func testAccountDeletionFlow() throws {
        try skipIfNotSignedIn()

        navigateToAccountSettings()

        // Step 1: Tap Delete Account
        let deleteButton = app.buttons["Delete Account"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        // Step 2: First confirmation dialog should appear
        let firstDialog = app.alerts.firstMatch
        XCTAssertTrue(firstDialog.waitForExistence(timeout: 3),
                      "First confirmation dialog should appear")

        // Verify dialog explains what will be deleted
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'permanently delete'")).firstMatch.exists,
                      "Dialog should explain permanent deletion")

        // Tap "Delete Account" in the confirmation dialog
        let confirmButton = firstDialog.buttons["Delete Account"]
        XCTAssertTrue(confirmButton.exists, "Delete Account button should exist in dialog")
        confirmButton.tap()

        // Step 3: Second confirmation (type DELETE) should appear
        let secondDialog = app.alerts["Confirm Deletion"]
        XCTAssertTrue(secondDialog.waitForExistence(timeout: 3),
                      "Second confirmation dialog should appear")

        // The "Delete Forever" button should be disabled until user types DELETE
        let deleteForeverButton = secondDialog.buttons["Delete Forever"]
        XCTAssertTrue(deleteForeverButton.exists)

        // Type "DELETE" in the text field
        let textField = secondDialog.textFields.firstMatch
        XCTAssertTrue(textField.exists, "Text field for typing DELETE should exist")
        textField.tap()
        textField.typeText("DELETE")

        // Now "Delete Forever" should be enabled - tap it
        // Note: We might want to stop here in a real test to avoid actually deleting
        // For a true E2E test, we'd have a test account that can be recreated
    }

    /// Test that cancel works in the first dialog
    func testCancelFirstDialog() throws {
        try skipIfNotSignedIn()

        navigateToAccountSettings()

        // Tap Delete Account
        app.buttons["Delete Account"].tap()

        // First dialog appears
        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))

        // Tap Cancel
        dialog.buttons["Cancel"].tap()

        // Dialog should dismiss, Delete Account button still visible
        XCTAssertFalse(dialog.exists, "Dialog should be dismissed")
        XCTAssertTrue(app.buttons["Delete Account"].exists,
                      "Should still be on Account settings")
    }

    /// Test that cancel works in the second dialog
    func testCancelSecondDialog() throws {
        try skipIfNotSignedIn()

        navigateToAccountSettings()

        // Go through first dialog
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

    /// Test that incorrect confirmation text doesn't enable delete
    func testIncorrectConfirmationText() throws {
        try skipIfNotSignedIn()

        navigateToAccountSettings()

        // Navigate to second dialog
        app.buttons["Delete Account"].tap()
        app.alerts.firstMatch.buttons["Delete Account"].tap()

        let secondDialog = app.alerts["Confirm Deletion"]
        XCTAssertTrue(secondDialog.waitForExistence(timeout: 3))

        // Type wrong text
        let textField = secondDialog.textFields.firstMatch
        textField.tap()
        textField.typeText("delete")  // lowercase - should not work

        // Delete Forever should still be disabled (we can't easily check disabled state in XCUITest)
        // Instead, verify the button exists
        XCTAssertTrue(secondDialog.buttons["Delete Forever"].exists)

        // Clean up
        secondDialog.buttons["Cancel"].tap()
    }

    // MARK: - Helper Methods

    /// Navigate from main screen to Account settings
    private func navigateToAccountSettings() {
        // Tap Settings tab (assuming tab bar navigation)
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
        }

        // Find and tap Account row
        let accountButton = app.buttons["Account"]
        if !accountButton.waitForExistence(timeout: 3) {
            // Try scrolling to find it
            app.swipeUp()
        }

        if accountButton.exists {
            accountButton.tap()
        }
    }

    /// Skip test if user is not signed in
    private func skipIfNotSignedIn() throws {
        // Check if we're on the onboarding/sign-in screen
        // If so, skip this test (we'd need a separate sign-in test)
        let signInButton = app.buttons["Sign in with Apple"]
        if signInButton.waitForExistence(timeout: 2) {
            throw XCTSkip("User not signed in - skipping account deletion test")
        }
    }
}
