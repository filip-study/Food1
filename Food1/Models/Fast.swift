//
//  Fast.swift
//  Food1
//
//  SwiftData model for fasting periods.
//
//  WHY THIS ARCHITECTURE:
//  - Fast supports both active (in-progress) and completed fasts
//  - isActive: true = currently fasting, false = completed
//  - startTime: When fasting began (tap from FAB or last meal timestamp for retroactive)
//  - confirmedAt: When user initiated/confirmed the fast
//  - endTime: When fast ended (nil while active, set when meal logged)
//  - Duration computed live for active fasts (startTime → now)
//  - FastingStage enum provides stage-based progress with scientific benefits
//

import Foundation
import SwiftData

// MARK: - Fasting Stage

/// Fasting stages with user-friendly names and scientific descriptions.
/// - fed: 0-4h (digestion, not truly fasting yet)
/// - earlyFast: 4-12h (metabolic shift begins)
/// - ketosis: 12-24h (fat burning zone)
/// - extended: 24h+ (deep cellular repair)
///
/// Demo mode accelerates time (1h = 5s) for UI testing.
enum FastingStage: Int, CaseIterable, Identifiable {
    case fed = 0           // 0-4h (not truly fasting)
    case earlyFast = 1     // 4-12h
    case ketosis = 2       // 12-24h
    case extended = 3      // 24h+

    var id: Int { rawValue }

    /// Stage display name (user-friendly, not overly scientific)
    var title: String {
        switch self {
        case .fed: return "Digesting"
        case .earlyFast: return "Metabolic Shift"
        case .ketosis: return "Fat Burning"
        case .extended: return "Deep Repair"
        }
    }

    /// Brief description (2-3 words) for compact UI
    var shortDescription: String {
        switch self {
        case .fed: return "Processing food"
        case .earlyFast: return "Switching fuel"
        case .ketosis: return "Burning fat"
        case .extended: return "Cellular cleanup"
        }
    }

    /// Detailed scientific explanation for info sheet
    var detailedDescription: String {
        switch self {
        case .fed:
            return "Your body is still digesting your last meal. Insulin levels are elevated as nutrients are absorbed. True fasting benefits begin after this phase."
        case .earlyFast:
            return "Your body is shifting from using food for energy to tapping into stored reserves. Insulin drops, blood sugar stabilizes, and glycogen stores begin depleting."
        case .ketosis:
            return "Fat burning ramps up significantly as your body runs on stored fat. Cellular cleanup (autophagy) begins. Growth hormone starts rising to preserve muscle."
        case .extended:
            return "Deep cellular repair is underway. Your body is recycling damaged components and growth hormone is elevated. This is where significant metabolic benefits occur."
        }
    }

    /// Whether this stage represents actual fasting (fed state does not)
    var isActiveFasting: Bool {
        self != .fed
    }

    /// Start hour for this stage (in real hours)
    var startHour: Int {
        switch self {
        case .fed: return 0
        case .earlyFast: return 4
        case .ketosis: return 12
        case .extended: return 24
        }
    }

    /// End hour for this stage (nil for extended = no upper limit)
    var endHour: Int? {
        switch self {
        case .fed: return 4
        case .earlyFast: return 12
        case .ketosis: return 24
        case .extended: return nil
        }
    }

    /// Time range display string
    var timeRange: String {
        if let end = endHour {
            return "\(startHour)-\(end)h"
        }
        return "\(startHour)h+"
    }

    /// Get the stage for a given duration in seconds
    static func stage(forDurationSeconds seconds: Int) -> FastingStage {
        let hours = Double(seconds) / 3600.0

        switch hours {
        case ..<4: return .fed
        case 4..<12: return .earlyFast
        case 12..<24: return .ketosis
        default: return .extended
        }
    }

    /// Progress within this stage (0.0 to 1.0)
    func progress(forDurationSeconds seconds: Int) -> Double {
        let hours = Double(seconds) / 3600.0
        let startHourDouble = Double(startHour)

        guard let endHourDouble = endHour.map({ Double($0) }) else {
            // Extended stage: progress based on hours beyond 24h (caps at 48h for visual)
            let hoursIntoExtended = hours - startHourDouble
            return min(hoursIntoExtended / 24.0, 1.0)  // Full at 48h
        }

        let stageLength = endHourDouble - startHourDouble
        let hoursIntoStage = hours - startHourDouble
        return min(max(hoursIntoStage / stageLength, 0), 1.0)
    }
}

// MARK: - Fast Model

@Model
final class Fast {
    var id: UUID
    var startTime: Date         // When fasting started
    var confirmedAt: Date       // When user initiated/confirmed the fast
    var isActive: Bool          // true = currently fasting, false = completed
    var endTime: Date?          // When fast ended (nil while active)

    /// Current duration in seconds.
    /// For active fasts: startTime → now
    /// For completed fasts: startTime → endTime (or confirmedAt for legacy data)
    var currentDurationSeconds: Int {
        let endDate = isActive ? Date() : (endTime ?? confirmedAt)
        return Int(endDate.timeIntervalSince(startTime))
    }

    /// Duration in seconds with demo mode acceleration.
    /// Demo mode: 1 hour = 5 seconds (720x speed)
    func durationSeconds(demoMode: Bool) -> Int {
        let realSeconds = currentDurationSeconds
        if demoMode {
            return realSeconds * 720  // 720x acceleration
        }
        return realSeconds
    }

    /// Current fasting stage based on duration
    var currentStage: FastingStage {
        FastingStage.stage(forDurationSeconds: currentDurationSeconds)
    }

    /// Seconds remaining until next fasting stage (nil if in extended stage)
    var secondsUntilNextStage: Int? {
        let stage = currentStage
        guard let endHour = stage.endHour else {
            return nil  // Extended stage has no next stage
        }

        let currentHours = Double(currentDurationSeconds) / 3600.0
        let hoursRemaining = Double(endHour) - currentHours
        return max(Int(hoursRemaining * 3600), 0)
    }

    /// Current stage with demo mode acceleration
    func stage(demoMode: Bool) -> FastingStage {
        FastingStage.stage(forDurationSeconds: durationSeconds(demoMode: demoMode))
    }

    /// Duration formatted as "14h 32m" or "1d 2h"
    var formattedDuration: String {
        formatDuration(seconds: currentDurationSeconds)
    }

    /// Duration formatted with demo mode consideration
    func formattedDuration(demoMode: Bool) -> String {
        formatDuration(seconds: durationSeconds(demoMode: demoMode))
    }

    /// Duration formatted with seconds: "14h 32m 45s"
    func formattedDurationWithSeconds(demoMode: Bool) -> String {
        let totalSeconds = durationSeconds(demoMode: demoMode)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h \(minutes)m"
        }
        return "\(hours)h \(minutes)m \(seconds)s"
    }

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    /// Whether this fast is at or beyond 72 hours (show warning)
    func isExtendedWarning(demoMode: Bool) -> Bool {
        let hours = durationSeconds(demoMode: demoMode) / 3600
        return hours >= 72
    }

    // MARK: - Initialization

    /// Create a new fast (typically when user taps "Fasting" in FAB)
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        confirmedAt: Date = Date(),
        isActive: Bool = true,
        endTime: Date? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.confirmedAt = confirmedAt
        self.isActive = isActive
        self.endTime = endTime
    }

    // MARK: - Actions

    /// End the fast (called when a meal is logged)
    func end() {
        guard isActive else { return }
        isActive = false
        endTime = Date()
    }
}
