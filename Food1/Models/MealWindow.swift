//
//  MealWindow.swift
//  Food1
//
//  Model for user's meal time windows (cloud-synced via Supabase).
//  Each user can have 1-6 customizable meal windows.
//
//  WHY THIS ARCHITECTURE:
//  - Codable struct (not SwiftData) since this is cloud-first configuration
//  - sort_order enables drag-to-reorder in UI
//  - TimeComponents helper for TIME column handling (Supabase stores as "HH:MM:SS")
//

import Foundation

/// Represents a user's meal time window (e.g., Breakfast at 8:00 AM)
struct MealWindow: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var name: String                    // "Breakfast", "Lunch", "Dinner", or custom
    var targetTime: TimeComponents      // User's set time (e.g., 08:00)
    var isEnabled: Bool
    var sortOrder: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case targetTime = "target_time"
        case isEnabled = "is_enabled"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Create a Date for today at this meal's target time
    func dateForToday() -> Date {
        targetTime.dateForToday()
    }

    /// Create a Date for a specific day at this meal's target time
    func dateFor(date: Date) -> Date {
        targetTime.dateFor(date: date)
    }

    /// Icon for this meal based on time of day
    var icon: String {
        let hour = targetTime.hour
        if hour < 10 {
            return "sun.horizon.fill"       // Breakfast (before 10am)
        } else if hour < 14 {
            return "sun.max.fill"           // Lunch (10am-2pm)
        } else if hour < 17 {
            return "cloud.sun.fill"         // Afternoon snack
        } else {
            return "moon.stars.fill"        // Dinner (after 5pm)
        }
    }

    /// Default meal windows for new users
    static var defaults: [MealWindow] {
        let now = Date()
        return [
            MealWindow(
                id: UUID(),
                userId: UUID(), // Will be replaced with actual user ID
                name: "Breakfast",
                targetTime: TimeComponents(hour: 8, minute: 0),
                isEnabled: true,
                sortOrder: 0,
                createdAt: now,
                updatedAt: now
            ),
            MealWindow(
                id: UUID(),
                userId: UUID(),
                name: "Lunch",
                targetTime: TimeComponents(hour: 12, minute: 30),
                isEnabled: true,
                sortOrder: 1,
                createdAt: now,
                updatedAt: now
            ),
            MealWindow(
                id: UUID(),
                userId: UUID(),
                name: "Dinner",
                targetTime: TimeComponents(hour: 18, minute: 30),
                isEnabled: true,
                sortOrder: 2,
                createdAt: now,
                updatedAt: now
            )
        ]
    }
}

// MARK: - Time Components

/// Represents a time of day (hour + minute), used for Postgres TIME columns
struct TimeComponents: Codable, Equatable, Hashable {
    var hour: Int       // 0-23
    var minute: Int     // 0-59

    init(hour: Int, minute: Int) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let timeString = try container.decode(String.self)

        // Parse "HH:MM:SS" or "HH:MM" format from Postgres
        let components = timeString.split(separator: ":")
        guard components.count >= 2,
              let h = Int(components[0]),
              let m = Int(components[1]) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid time format: \(timeString)"
            )
        }

        self.hour = h
        self.minute = m
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(format: "%02d:%02d:00", hour, minute))
    }

    /// Create a Date for today at this time
    func dateForToday() -> Date {
        dateFor(date: Date())
    }

    /// Create a Date for a specific day at this time
    func dateFor(date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    /// Create from a Date (extracts hour and minute)
    init(from date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
    }

    /// Formatted string for display (e.g., "8:00 AM")
    var displayString: String {
        let date = dateForToday()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Total minutes since midnight (for comparisons)
    var totalMinutes: Int {
        hour * 60 + minute
    }
}

// MARK: - Insert/Upsert Helper

extension MealWindow {
    /// Create an insert payload (excludes auto-generated createdAt/updatedAt)
    struct InsertPayload: Encodable {
        let id: UUID
        let userId: UUID
        let name: String
        let targetTime: TimeComponents
        let isEnabled: Bool
        let sortOrder: Int

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case name
            case targetTime = "target_time"
            case isEnabled = "is_enabled"
            case sortOrder = "sort_order"
        }
    }

    /// Create insert payload from window
    var insertPayload: InsertPayload {
        InsertPayload(
            id: id,
            userId: userId,
            name: name,
            targetTime: targetTime,
            isEnabled: isEnabled,
            sortOrder: sortOrder
        )
    }

    /// Create window with specific user ID (for default creation)
    func withUserId(_ userId: UUID) -> MealWindow {
        return MealWindow(
            id: UUID(),
            userId: userId,
            name: self.name,
            targetTime: self.targetTime,
            isEnabled: self.isEnabled,
            sortOrder: self.sortOrder,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
