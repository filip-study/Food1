//
//  FastingActivityAttributes.swift
//  MealReminderWidget
//
//  ActivityKit attributes for fasting Live Activities.
//  Copy of main app's FastingActivityAttributes for widget target.
//
//  WHY THIS ARCHITECTURE:
//  - Widget extensions need their own copy of ActivityAttributes
//  - Same structure as main app version
//  - iOS handles timer updates automatically via Text(_:style:.timer)
//

import ActivityKit
import Foundation

/// Attributes for fasting Live Activity
struct FastingActivityAttributes: ActivityAttributes {

    // MARK: - Content State (Dynamic)

    /// Dynamic content that can be updated while activity is running
    public struct ContentState: Codable, Hashable {
        /// Current fasting stage name (e.g., "Early Fast", "Ketosis")
        var stageName: String

        /// Stage index (0=fed, 1=earlyFast, 2=ketosis, 3=extended) for styling
        var stageIndex: Int

        /// Seconds remaining until next stage (nil if in extended stage)
        var secondsToNextStage: Int?

        /// Pre-formatted elapsed time for compact display (e.g., "2h", "45m")
        var elapsedDisplay: String

        /// Progress within current stage (0.0 to 1.0) for progress bar
        var stageProgress: Double

        /// Pre-formatted countdown for demo mode (nil = use native iOS timer)
        /// In demo mode, native timers don't work because they use real wall-clock time
        var countdownDisplay: String?
    }

    // MARK: - Static Attributes

    /// Unique identifier for this fast
    var fastId: UUID

    /// When the fast started (immutable - used for timer calculation)
    var startTime: Date
}
