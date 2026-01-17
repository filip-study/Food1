//
//  FastingTests.swift
//  Food1Tests
//
//  Tests for fasting logic: Fast model, FastingStage calculation, and duration formatting.
//

import XCTest
@testable import Food1

/// Tests for fasting logic - verifies stage calculation, duration, and state management
///
/// TEST POLICY: These tests define expected behavior and MUST NOT be modified without explicit user approval.
/// If tests fail after code changes, fix the CODE, not the tests.
///
/// Coverage:
/// 1. Fast model initialization with correct defaults
/// 2. FastingStage calculation at boundary conditions
/// 3. Demo mode acceleration (720x)
/// 4. Duration formatting (hours, days)
/// 5. Fast.end() state transition
/// 6. Stage progress calculation
final class FastingTests: XCTestCase {

    // MARK: - Fast Model Initialization Tests

    /// Test that Fast initializes with correct default values for active fasting
    func testFast_Init_DefaultsToActive() {
        // Given/When: Create a new fast with defaults
        let fast = Fast()

        // Then: Should be active with no end time
        XCTAssertTrue(fast.isActive, "New fast should default to isActive = true")
        XCTAssertNil(fast.endTime, "New fast should have nil endTime")
        XCTAssertNotNil(fast.id, "Fast should have a UUID")
    }

    /// Test Fast initialization with explicit parameters (matching our bug fix)
    func testFast_Init_ExplicitParameters() {
        // Given: Specific start time and confirmation time
        let startTime = Date().addingTimeInterval(-3600 * 14)  // 14 hours ago
        let confirmedAt = Date()

        // When: Create fast with explicit parameters
        let fast = Fast(
            startTime: startTime,
            confirmedAt: confirmedAt,
            isActive: true,
            endTime: nil
        )

        // Then: All values should match
        XCTAssertEqual(fast.startTime, startTime, "startTime should match")
        XCTAssertEqual(fast.confirmedAt, confirmedAt, "confirmedAt should match")
        XCTAssertTrue(fast.isActive, "isActive should be true")
        XCTAssertNil(fast.endTime, "endTime should be nil")
    }

    /// Test Fast initialization for a completed fast
    func testFast_Init_CompletedFast() {
        // Given: A fast that has ended
        let startTime = Date().addingTimeInterval(-3600 * 16)  // 16 hours ago
        let endTime = Date().addingTimeInterval(-3600 * 2)     // 2 hours ago

        // When: Create a completed fast
        let fast = Fast(
            startTime: startTime,
            confirmedAt: startTime,
            isActive: false,
            endTime: endTime
        )

        // Then: Should be completed with end time
        XCTAssertFalse(fast.isActive, "Completed fast should have isActive = false")
        XCTAssertNotNil(fast.endTime, "Completed fast should have endTime")
        XCTAssertEqual(fast.endTime, endTime, "endTime should match")
    }

    // MARK: - FastingStage Calculation Tests

    /// Test stage calculation at 0 hours (Fed stage)
    func testFastingStage_AtZeroHours_IsFed() {
        // Given: 0 seconds of fasting
        let seconds = 0

        // When: Calculate stage
        let stage = FastingStage.stage(forDurationSeconds: seconds)

        // Then: Should be Fed stage
        XCTAssertEqual(stage, .fed, "0 hours should be Fed stage")
        XCTAssertEqual(stage.title, "Digesting", "Fed stage title should be 'Digesting'")
        XCTAssertFalse(stage.isActiveFasting, "Fed stage is not active fasting")
    }

    /// Test stage calculation at 3 hours 59 minutes (still Fed)
    func testFastingStage_JustBefore4Hours_IsFed() {
        // Given: 3 hours 59 minutes (just before transition)
        let seconds = (3 * 3600) + (59 * 60)

        // When: Calculate stage
        let stage = FastingStage.stage(forDurationSeconds: seconds)

        // Then: Should still be Fed
        XCTAssertEqual(stage, .fed, "3h 59m should still be Fed stage")
    }

    /// Test stage calculation at exactly 4 hours (Early Fast begins)
    func testFastingStage_AtExactly4Hours_IsEarlyFast() {
        // Given: Exactly 4 hours
        let seconds = 4 * 3600

        // When: Calculate stage
        let stage = FastingStage.stage(forDurationSeconds: seconds)

        // Then: Should be Early Fast
        XCTAssertEqual(stage, .earlyFast, "4 hours should be Early Fast stage")
        XCTAssertEqual(stage.title, "Metabolic Shift", "Early Fast title should be 'Metabolic Shift'")
        XCTAssertTrue(stage.isActiveFasting, "Early Fast is active fasting")
    }

    /// Test stage calculation at 11 hours 59 minutes (still Early Fast)
    func testFastingStage_JustBefore12Hours_IsEarlyFast() {
        // Given: 11 hours 59 minutes
        let seconds = (11 * 3600) + (59 * 60)

        // When: Calculate stage
        let stage = FastingStage.stage(forDurationSeconds: seconds)

        // Then: Should still be Early Fast
        XCTAssertEqual(stage, .earlyFast, "11h 59m should still be Early Fast")
    }

    /// Test stage calculation at exactly 12 hours (Ketosis begins)
    func testFastingStage_AtExactly12Hours_IsKetosis() {
        // Given: Exactly 12 hours
        let seconds = 12 * 3600

        // When: Calculate stage
        let stage = FastingStage.stage(forDurationSeconds: seconds)

        // Then: Should be Ketosis
        XCTAssertEqual(stage, .ketosis, "12 hours should be Ketosis stage")
        XCTAssertEqual(stage.title, "Fat Burning", "Ketosis title should be 'Fat Burning'")
    }

    /// Test stage calculation at exactly 24 hours (Extended begins)
    func testFastingStage_AtExactly24Hours_IsExtended() {
        // Given: Exactly 24 hours
        let seconds = 24 * 3600

        // When: Calculate stage
        let stage = FastingStage.stage(forDurationSeconds: seconds)

        // Then: Should be Extended
        XCTAssertEqual(stage, .extended, "24 hours should be Extended stage")
        XCTAssertEqual(stage.title, "Deep Repair", "Extended title should be 'Deep Repair'")
    }

    /// Test stage calculation at 48 hours (still Extended)
    func testFastingStage_At48Hours_IsStillExtended() {
        // Given: 48 hours
        let seconds = 48 * 3600

        // When: Calculate stage
        let stage = FastingStage.stage(forDurationSeconds: seconds)

        // Then: Should still be Extended (no upper limit)
        XCTAssertEqual(stage, .extended, "48 hours should still be Extended stage")
    }

    // MARK: - Demo Mode Tests

    /// Test that demo mode accelerates time by 720x
    func testFast_DemoMode_Accelerates720x() {
        // Given: A fast that started 5 seconds ago (in real time)
        let startTime = Date().addingTimeInterval(-5)
        let fast = Fast(startTime: startTime, confirmedAt: Date(), isActive: true)

        // When: Get duration in demo mode
        let demoDuration = fast.durationSeconds(demoMode: true)
        let realDuration = fast.durationSeconds(demoMode: false)

        // Then: Demo duration should be 720x real duration
        XCTAssertEqual(demoDuration, realDuration * 720, "Demo mode should be 720x faster")
    }

    /// Test that demo mode affects stage calculation
    func testFast_DemoMode_AffectsStageCalculation() {
        // Given: A fast that started 60 seconds ago (real time)
        // In demo mode: 60 * 720 = 43200 seconds = 12 hours = Ketosis!
        let startTime = Date().addingTimeInterval(-60)
        let fast = Fast(startTime: startTime, confirmedAt: Date(), isActive: true)

        // When: Calculate stages
        let realStage = fast.stage(demoMode: false)
        let demoStage = fast.stage(demoMode: true)

        // Then: Real mode = Fed, Demo mode = Ketosis
        XCTAssertEqual(realStage, .fed, "Real mode: 60s = Fed stage")
        XCTAssertEqual(demoStage, .ketosis, "Demo mode: 60s * 720 = 12h = Ketosis stage")
    }

    // MARK: - Duration Formatting Tests

    /// Test duration formatting for hours and minutes
    func testFast_FormattedDuration_HoursAndMinutes() {
        // Given: A fast that started 14 hours 32 minutes ago
        let seconds = (14 * 3600) + (32 * 60)
        let startTime = Date().addingTimeInterval(-Double(seconds))
        let fast = Fast(startTime: startTime, confirmedAt: Date(), isActive: true)

        // When: Format duration
        let formatted = fast.formattedDuration

        // Then: Should be "14h 32m"
        XCTAssertEqual(formatted, "14h 32m", "Should format as hours and minutes")
    }

    /// Test duration formatting for days and hours
    func testFast_FormattedDuration_DaysAndHours() {
        // Given: A fast that started 26 hours ago (1 day 2 hours)
        let seconds = 26 * 3600
        let startTime = Date().addingTimeInterval(-Double(seconds))
        let fast = Fast(startTime: startTime, confirmedAt: Date(), isActive: true)

        // When: Format duration
        let formatted = fast.formattedDuration

        // Then: Should be "1d 2h"
        XCTAssertEqual(formatted, "1d 2h", "Should format as days and hours when >= 24h")
    }

    /// Test duration formatting at exactly 24 hours
    func testFast_FormattedDuration_Exactly24Hours() {
        // Given: Exactly 24 hours
        let seconds = 24 * 3600
        let startTime = Date().addingTimeInterval(-Double(seconds))
        let fast = Fast(startTime: startTime, confirmedAt: Date(), isActive: true)

        // When: Format duration
        let formatted = fast.formattedDuration

        // Then: Should be "1d 0h"
        XCTAssertEqual(formatted, "1d 0h", "24h should format as 1d 0h")
    }

    // MARK: - Fast.end() Tests

    /// Test that end() transitions fast from active to completed
    func testFast_End_TransitionsToCompleted() {
        // Given: An active fast
        let fast = Fast(isActive: true, endTime: nil)
        XCTAssertTrue(fast.isActive, "Precondition: fast should be active")
        XCTAssertNil(fast.endTime, "Precondition: endTime should be nil")

        // When: End the fast
        fast.end()

        // Then: Should be completed with end time
        XCTAssertFalse(fast.isActive, "Fast should no longer be active")
        XCTAssertNotNil(fast.endTime, "Fast should have an endTime")
    }

    /// Test that end() is idempotent (calling twice doesn't change anything)
    func testFast_End_IsIdempotent() {
        // Given: An active fast
        let fast = Fast(isActive: true, endTime: nil)

        // When: End the fast twice
        fast.end()
        let firstEndTime = fast.endTime

        // Small delay to ensure different timestamps would be different
        Thread.sleep(forTimeInterval: 0.01)
        fast.end()
        let secondEndTime = fast.endTime

        // Then: endTime should not change on second call
        XCTAssertEqual(firstEndTime, secondEndTime, "end() should be idempotent")
    }

    /// Test that end() does nothing for already completed fasts
    func testFast_End_DoesNothingForCompletedFast() {
        // Given: A completed fast
        let originalEndTime = Date().addingTimeInterval(-3600)
        let fast = Fast(isActive: false, endTime: originalEndTime)

        // When: Try to end it again
        fast.end()

        // Then: endTime should not change
        XCTAssertEqual(fast.endTime, originalEndTime, "end() should not modify completed fast")
        XCTAssertFalse(fast.isActive, "Fast should remain inactive")
    }

    // MARK: - Stage Progress Tests

    /// Test progress within Fed stage
    func testFastingStage_Progress_WithinFedStage() {
        // Given: 2 hours into Fed stage (Fed is 0-4h, so 2h = 50%)
        let seconds = 2 * 3600

        // When: Calculate progress
        let progress = FastingStage.fed.progress(forDurationSeconds: seconds)

        // Then: Should be 50%
        XCTAssertEqual(progress, 0.5, accuracy: 0.01, "2h in 0-4h range = 50%")
    }

    /// Test progress within Ketosis stage
    func testFastingStage_Progress_WithinKetosisStage() {
        // Given: 18 hours (Ketosis is 12-24h, so 18h = 50% of way through)
        let seconds = 18 * 3600

        // When: Calculate progress
        let progress = FastingStage.ketosis.progress(forDurationSeconds: seconds)

        // Then: Should be 50%
        XCTAssertEqual(progress, 0.5, accuracy: 0.01, "18h in 12-24h range = 50%")
    }

    /// Test progress in Extended stage (caps at 48h = 100%)
    func testFastingStage_Progress_ExtendedStage_CapsAt48Hours() {
        // Given: 48 hours (Extended has no end, but progress caps at 48h)
        let seconds = 48 * 3600

        // When: Calculate progress
        let progress = FastingStage.extended.progress(forDurationSeconds: seconds)

        // Then: Should be 100% (capped)
        XCTAssertEqual(progress, 1.0, accuracy: 0.01, "48h should cap at 100% progress")
    }

    // MARK: - Extended Warning Tests

    /// Test extended warning at 71 hours (no warning)
    func testFast_ExtendedWarning_At71Hours_NoWarning() {
        // Given: 71 hours of fasting
        let seconds = 71 * 3600
        let startTime = Date().addingTimeInterval(-Double(seconds))
        let fast = Fast(startTime: startTime, confirmedAt: Date(), isActive: true)

        // When: Check warning
        let hasWarning = fast.isExtendedWarning(demoMode: false)

        // Then: No warning yet
        XCTAssertFalse(hasWarning, "71h should not trigger warning")
    }

    /// Test extended warning at exactly 72 hours (warning)
    func testFast_ExtendedWarning_At72Hours_ShowsWarning() {
        // Given: 72 hours of fasting
        let seconds = 72 * 3600
        let startTime = Date().addingTimeInterval(-Double(seconds))
        let fast = Fast(startTime: startTime, confirmedAt: Date(), isActive: true)

        // When: Check warning
        let hasWarning = fast.isExtendedWarning(demoMode: false)

        // Then: Warning should show
        XCTAssertTrue(hasWarning, "72h should trigger warning")
    }

    // MARK: - Stage Time Range Tests

    /// Test time range strings for all stages
    func testFastingStage_TimeRanges() {
        XCTAssertEqual(FastingStage.fed.timeRange, "0-4h", "Fed time range")
        XCTAssertEqual(FastingStage.earlyFast.timeRange, "4-12h", "Early Fast time range")
        XCTAssertEqual(FastingStage.ketosis.timeRange, "12-24h", "Ketosis time range")
        XCTAssertEqual(FastingStage.extended.timeRange, "24h+", "Extended time range")
    }

    // MARK: - Completed Fast Duration Tests

    /// Test that completed fast uses endTime for duration calculation
    func testFast_CompletedDuration_UsesEndTime() {
        // Given: A completed fast (16h duration)
        let startTime = Date().addingTimeInterval(-3600 * 20)  // 20 hours ago
        let endTime = Date().addingTimeInterval(-3600 * 4)     // 4 hours ago (16h fast)
        let fast = Fast(startTime: startTime, confirmedAt: startTime, isActive: false, endTime: endTime)

        // When: Get duration
        let duration = fast.currentDurationSeconds

        // Then: Should be ~16 hours (not 20 hours)
        let expectedSeconds = 16 * 3600
        XCTAssertEqual(duration, expectedSeconds, accuracy: 60, "Completed fast should use endTime")
    }
}
