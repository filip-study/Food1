//
//  Fast.swift
//  Food1
//
//  SwiftData model for fasting periods.
//
//  WHY THIS ARCHITECTURE:
//  - Simple model tracking when user confirmed a fast
//  - startTime is the last meal timestamp (when fasting began)
//  - confirmedAt is when user tapped "Confirm" in the UI
//  - duration computed from startTime to confirmedAt
//  - No end time tracking (fasts end implicitly when next meal is logged)
//

import Foundation
import SwiftData

@Model
final class Fast {
    var id: UUID
    var startTime: Date      // When fasting started (last meal's timestamp)
    var confirmedAt: Date    // When user confirmed the fast

    /// Duration of the fast in seconds (from startTime to confirmedAt)
    var durationSeconds: Int {
        Int(confirmedAt.timeIntervalSince(startTime))
    }

    /// Duration formatted as "14h 32m" or "1d 2h"
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    init(
        id: UUID = UUID(),
        startTime: Date,
        confirmedAt: Date = Date()
    ) {
        self.id = id
        self.startTime = startTime
        self.confirmedAt = confirmedAt
    }
}
