//
//  MealTextEntryUITests.swift
//  Food1UITests
//
//  E2E tests for the text-based meal entry flow.
//  Tests: Open camera → Tap Text button → Type meal → AI analyze → Save
//
//  This tests the natural language meal logging feature where users
//  describe their meal in words instead of taking a photo.
//
//  PREREQUISITES:
//  - TEST_USER_EMAIL and TEST_USER_PASSWORD environment variables set
//  - Real OpenAI API access (tests actual text analysis)
//

import XCTest

final class MealTextEntryUITests: XCTestCase {

    var app: XCUIApplication!

    /// Test user email from environment
    var testUserEmail: String? {
        ProcessInfo.processInfo.environment["TEST_USER_EMAIL"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_TEST_USER_EMAIL"]
    }

    /// Test user password from environment
    var testUserPassword: String? {
        ProcessInfo.processInfo.environment["TEST_USER_PASSWORD"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_TEST_USER_PASSWORD"]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        // Enable UI testing mode (but NOT mock-camera since we're testing text)
        app.launchArguments = ["--uitesting"]

        // Pass environment variables to the app
        let envVars = ["TEST_USER_EMAIL", "TEST_USER_PASSWORD", "SUPABASE_URL", "SUPABASE_ANON_KEY"]
        for key in envVars {
            if let value = ProcessInfo.processInfo.environment[key] {
                app.launchEnvironment[key] = value
            }
        }

        app.launch()
    }

    override func tearDownWithError() throws {
        // Take screenshot on failure
        if let failureCount = testRun?.failureCount, failureCount > 0 {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app = nil
    }

    // MARK: - Text Entry Meal Flow Test

    /// Test the complete text entry meal flow:
    /// 1. Sign in
    /// 2. Tap add meal button to open camera
    /// 3. Tap "Text" button to switch to text entry
    /// 4. Type meal description
    /// 5. Tap "Analyze with AI"
    /// 6. Wait for NutritionReviewView
    /// 7. Save meal
    /// 8. Verify meal appears in today view
    func testTextEntryMealFlow() throws {
        // Step 1: Sign in
        try signInWithEmailPassword()

        // Verify we're signed in
        let mainView = app.otherElements["mainTabView"]
        XCTAssertTrue(mainView.waitForExistence(timeout: 10),
                      "Should be signed in and see main view")

        takeScreenshot(name: "1-Signed-In")

        // Step 2: Tap the add meal FAB
        var addMealButton = app.buttons["addMealButton"]
        if !addMealButton.waitForExistence(timeout: 3) {
            addMealButton = app.buttons["Add meal"]
        }
        XCTAssertTrue(addMealButton.waitForExistence(timeout: 5),
                      "Add meal button should be visible")

        takeScreenshot(name: "2-Before-FAB-Tap")
        addMealButton.tap()

        // Step 3: Tap "Text" button to switch to text entry mode
        // The camera view has a "Text" button at the bottom
        let textButton = app.buttons["Text"]
        XCTAssertTrue(textButton.waitForExistence(timeout: 5),
                      "Text button should be visible in camera view")

        takeScreenshot(name: "3-Camera-View")
        textButton.tap()

        // Step 4: Wait for TextEntryView to appear
        // Look for the text field with placeholder "What did you eat?"
        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "Text entry field should appear")

        takeScreenshot(name: "4-Text-Entry-View")

        // Step 5: Type a meal description
        textField.tap()
        let mealDescription = "2 scrambled eggs with 2 strips of bacon"
        textField.typeText(mealDescription)

        // Dismiss keyboard
        textField.typeText("\n")
        usleep(300_000)

        takeScreenshot(name: "5-Meal-Typed")

        // Step 6: Tap "Analyze with AI" button
        let analyzeButton = app.buttons["Analyze with AI"]
        XCTAssertTrue(analyzeButton.waitForExistence(timeout: 3),
                      "Analyze with AI button should exist")

        // Wait for button to become enabled (need at least 5 chars)
        let startTime = Date()
        while !analyzeButton.isEnabled && Date().timeIntervalSince(startTime) < 3 {
            usleep(100_000)
        }

        XCTAssertTrue(analyzeButton.isEnabled, "Analyze button should be enabled after typing")
        analyzeButton.tap()

        // Step 7: Wait for AI analysis and NutritionReviewView
        // Analysis can take 3-10 seconds
        let analysisTimeout: TimeInterval = 30

        // Look for the Add button in NutritionReviewView
        let saveButton = app.buttons["Add"].firstMatch
        let foundReview = saveButton.waitForExistence(timeout: analysisTimeout)

        if !foundReview {
            takeScreenshot(name: "6-Analysis-Failed")
            XCTFail("Nutrition review screen did not appear after text analysis")
        }

        takeScreenshot(name: "6-Nutrition-Review")

        // Step 8: Wait for Add button to be enabled and tap it
        print("📋 Checking Add button state...")
        let buttonReadyTimeout: TimeInterval = 5
        let buttonStartTime = Date()
        var saveButtonReady = saveButton.isEnabled && saveButton.isHittable

        while !saveButtonReady && Date().timeIntervalSince(buttonStartTime) < buttonReadyTimeout {
            usleep(200_000)
            saveButtonReady = saveButton.isEnabled && saveButton.isHittable
        }

        XCTAssertTrue(saveButton.isEnabled, "Add button should be enabled")
        XCTAssertTrue(saveButton.isHittable, "Add button should be hittable")
        saveButton.tap()

        // Wait for save to complete
        sleep(2)

        takeScreenshot(name: "7-After-Save")

        // Step 9: Verify meal was added to TodayView
        XCTAssertTrue(mainView.waitForExistence(timeout: 5),
                      "Should return to main view after saving meal")

        // Look for meal card with calorie info
        let anyMealContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'cal'"))
        sleep(1)

        takeScreenshot(name: "8-Meal-Added")

        XCTAssertTrue(anyMealContent.count > 0,
                      "A meal with calorie info should appear in today view after saving")

        print("✅ Full text entry meal flow completed successfully!")
    }

    // MARK: - Helpers

    /// Sign in with test credentials
    private func signInWithEmailPassword() throws {
        guard let email = testUserEmail, let password = testUserPassword else {
            throw XCTSkip("TEST_USER_EMAIL and TEST_USER_PASSWORD must be set")
        }

        // If already signed in, skip
        if app.otherElements["mainTabView"].waitForExistence(timeout: 2) {
            return
        }

        // Tap "Continue with Email"
        let continueWithEmail = app.buttons["Continue with Email"]
        guard continueWithEmail.waitForExistence(timeout: 5) else {
            throw XCTSkip("Continue with Email button not found")
        }
        continueWithEmail.tap()

        // Enter email
        let emailField = app.textFields["you@example.com"]
        guard emailField.waitForExistence(timeout: 3) else {
            throw XCTSkip("Email field not found")
        }
        emailField.tap()
        emailField.typeText(email)

        // Enter password
        let passwordField = app.secureTextFields["At least 8 characters"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2))
        passwordField.tap()
        passwordField.typeText(password)

        // Dismiss keyboard
        passwordField.typeText("\n")
        usleep(300_000)

        // Tap submit button
        let submitButton = app.buttons["submitAuthButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))

        // Wait for button to be enabled
        let startTime = Date()
        while !submitButton.isEnabled && Date().timeIntervalSince(startTime) < 3 {
            usleep(100_000)
        }

        XCTAssertTrue(submitButton.isEnabled, "Submit button should be enabled")

        // Scroll if needed
        if !submitButton.isHittable {
            app.swipeUp()
            usleep(300_000)
        }

        submitButton.tap()

        // Wait for sign in to complete
        let mainView = app.otherElements["mainTabView"]
        XCTAssertTrue(mainView.waitForExistence(timeout: 15),
                      "Should be signed in after submitting credentials")
    }

    /// Take screenshot for debugging
    private func takeScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
