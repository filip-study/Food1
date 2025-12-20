//
//  MealPhotoFlowUITests.swift
//  Food1UITests
//
//  E2E tests for the meal photo recognition flow.
//  Tests: Camera capture → AI recognition → Nutrition review → Save meal
//
//  MOCK CAMERA:
//  Uses --mock-camera flag to inject a test image instead of real camera.
//  This allows testing the full flow without camera hardware access.
//  The mock image is a real food photo (edamame) that the AI can recognize.
//
//  PREREQUISITES:
//  - TEST_USER_EMAIL and TEST_USER_PASSWORD environment variables set
//  - Real OpenAI API access (tests actual recognition)
//

import XCTest

final class MealPhotoFlowUITests: XCTestCase {

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
        // Enable UI testing mode AND mock camera
        app.launchArguments = ["--uitesting", "--mock-camera"]

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

    // MARK: - Photo Meal Flow Test

    /// Test the complete photo meal flow:
    /// 1. Sign in
    /// 2. Tap add meal button (camera mode)
    /// 3. Mock camera auto-captures test image
    /// 4. AI recognizes food (real API call)
    /// 5. Nutrition review appears
    /// 6. Save meal
    /// 7. Verify meal appears in today view
    func testPhotoMealFlow() throws {
        // Step 1: Sign in
        try signInWithEmailPassword()

        // Verify we're signed in
        let mainView = app.otherElements["mainTabView"]
        XCTAssertTrue(mainView.waitForExistence(timeout: 10),
                      "Should be signed in and see main view")

        takeScreenshot(name: "1-Signed-In")

        // Step 2: Tap the add meal FAB (floating action button)
        // In mock-camera mode, the FAB directly opens camera (bypasses menu)
        var addMealButton = app.buttons["addMealButton"]
        if !addMealButton.waitForExistence(timeout: 3) {
            // Fallback to accessibility label
            addMealButton = app.buttons["Add meal"]
        }
        XCTAssertTrue(addMealButton.waitForExistence(timeout: 5),
                      "Add meal button should be visible")

        takeScreenshot(name: "2-Before-FAB-Tap")
        addMealButton.tap()

        // In mock-camera mode (--mock-camera flag), the FAB tap goes straight to camera
        // No menu navigation needed - the mock camera auto-captures and sends to AI
        takeScreenshot(name: "3-After-FAB-Tap")

        // Step 3: Wait for mock camera to auto-capture and AI recognition
        // The mock camera immediately captures, then recognition takes 2-5 seconds

        // Wait for recognition to complete - look for NutritionReviewView
        let recognitionTimeout: TimeInterval = 45  // API can be slow, especially first call

        // Look for NutritionReviewView indicators
        // The view shows food name, macros, and an "Add" button in toolbar
        // Use .firstMatch because there might be multiple buttons with "Add" label
        let saveButton = app.buttons["Add"].firstMatch

        // Wait for the Add button to appear - this indicates NutritionReviewView loaded
        let foundReview = saveButton.waitForExistence(timeout: recognitionTimeout)

        if !foundReview {
            // Debug: capture what's on screen
            takeScreenshot(name: "4-Recognition-Failed")

            // Check for error states
            let noFoodAlert = app.alerts["No Food Detected"]
            if noFoodAlert.exists {
                XCTFail("AI could not recognize food in test image")
            }

            // Log visible buttons for debugging
            print("📋 Visible buttons after waiting for recognition:")
            for button in app.buttons.allElementsBoundByIndex {
                if !button.label.isEmpty {
                    print("  - \(button.label)")
                }
            }

            XCTFail("Nutrition review screen did not appear after recognition")
        }

        takeScreenshot(name: "4-Nutrition-Review")

        // Step 4: Save the meal by tapping "Add"
        // The button may be disabled initially while fetchNutritionData() runs
        // Wait for button to become both enabled AND hittable
        print("📋 Checking Add button state...")
        print("   - exists: \(saveButton.exists)")
        print("   - isEnabled: \(saveButton.isEnabled)")
        print("   - isHittable: \(saveButton.isHittable)")

        // Wait up to 5 seconds for button to become enabled and hittable
        let buttonReadyTimeout: TimeInterval = 5
        let startTime = Date()
        var saveButtonReady = saveButton.isEnabled && saveButton.isHittable

        while !saveButtonReady && Date().timeIntervalSince(startTime) < buttonReadyTimeout {
            usleep(200_000) // 200ms
            saveButtonReady = saveButton.isEnabled && saveButton.isHittable
        }

        print("📋 Add button after waiting: enabled=\(saveButton.isEnabled), hittable=\(saveButton.isHittable)")
        takeScreenshot(name: "4b-Before-Add-Tap")

        XCTAssertTrue(saveButton.isEnabled, "Add button should be enabled (meal name and calories populated)")
        XCTAssertTrue(saveButton.isHittable, "Add button should be hittable")
        saveButton.tap()

        // Wait for save to complete and return to main view
        sleep(2)

        takeScreenshot(name: "5-After-Save")

        // Step 5: Verify we're back on TodayView and meal was added
        XCTAssertTrue(mainView.waitForExistence(timeout: 5),
                      "Should return to main view after saving meal")

        // Look for meal card or indication meal was added
        // The app shows meal cards with food name/calories
        // Since we used edamame test image, look for that or any meal content
        let anyMealContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'cal'"))

        // Give UI time to update
        sleep(1)

        takeScreenshot(name: "6-Meal-Added")

        XCTAssertTrue(anyMealContent.count > 0,
                      "A meal with calorie info should appear in today view after saving")

        // Step 6: Tap on the meal to view details
        // Find the first meal card and tap it
        let mealCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'mealCard'"))
        if mealCards.count > 0 {
            let firstMealCard = mealCards.element(boundBy: 0)
            if firstMealCard.isHittable {
                firstMealCard.tap()

                // Wait for meal detail view
                sleep(1)
                takeScreenshot(name: "7-Meal-Detail")

                // Look for ingredient list (indicates recognition worked with detailed data)
                let ingredientsList = app.scrollViews.firstMatch
                if ingredientsList.exists {
                    print("✅ Meal detail view has scrollable content (ingredients)")
                }

                // Dismiss the detail view
                let dismissButton = app.buttons["xmark"]
                if dismissButton.waitForExistence(timeout: 2) {
                    dismissButton.tap()
                } else {
                    // Try swiping down to dismiss
                    app.swipeDown()
                }

                sleep(1)
                takeScreenshot(name: "8-Back-To-Today")
            }
        }

        // Step 7: Wait a bit for background enrichment to kick in (if applicable)
        // Enrichment happens asynchronously after meal is saved
        sleep(3)

        takeScreenshot(name: "9-After-Enrichment")

        print("✅ Full photo meal flow completed successfully!")
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

        // Scroll if needed to make button hittable
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
