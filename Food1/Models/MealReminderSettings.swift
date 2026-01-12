//
//  MealReminderSettings.swift
//  Food1
//
//  Global settings for the meal reminder Live Activity feature.
//  Singleton per user (stored in Supabase with user_id as primary key).
//
//  WHY THIS ARCHITECTURE:
//  - Separate from meal_windows to avoid repeating settings for each window
//  - Cloud-synced so settings persist across devices
//  - Codable for direct Supabase serialization
//

import Foundation

/// Global settings for Lock Screen Activities (meal reminders)
struct MealReminderSettings: Codable, Equatable {
    let userId: UUID
    var isEnabled: Bool                 // Master toggle for the feature
    var leadTimeMinutes: Int            // Show activity X minutes before meal
    var autoDismissMinutes: Int         // Auto-dismiss X minutes after meal time
    var onboardingCompleted: Bool       // Whether user completed initial setup
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isEnabled = "is_enabled"
        case leadTimeMinutes = "lead_time_minutes"
        case autoDismissMinutes = "auto_dismiss_minutes"
        case onboardingCompleted = "onboarding_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Default settings for new users
    static func defaults(for userId: UUID) -> MealReminderSettings {
        let now = Date()
        return MealReminderSettings(
            userId: userId,
            isEnabled: true,
            leadTimeMinutes: 45,
            autoDismissMinutes: 120,
            onboardingCompleted: false,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Lead time as TimeInterval
    var leadTimeInterval: TimeInterval {
        TimeInterval(leadTimeMinutes * 60)
    }

    /// Auto-dismiss time as TimeInterval
    var autoDismissInterval: TimeInterval {
        TimeInterval(autoDismissMinutes * 60)
    }
}

// MARK: - Insert/Upsert Helper

extension MealReminderSettings {
    /// Create an insert payload (all fields except auto-generated createdAt/updatedAt)
    struct InsertPayload: Encodable {
        let userId: UUID
        let isEnabled: Bool
        let leadTimeMinutes: Int
        let autoDismissMinutes: Int
        let onboardingCompleted: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case isEnabled = "is_enabled"
            case leadTimeMinutes = "lead_time_minutes"
            case autoDismissMinutes = "auto_dismiss_minutes"
            case onboardingCompleted = "onboarding_completed"
        }
    }

    /// Create insert payload from settings
    var insertPayload: InsertPayload {
        InsertPayload(
            userId: userId,
            isEnabled: isEnabled,
            leadTimeMinutes: leadTimeMinutes,
            autoDismissMinutes: autoDismissMinutes,
            onboardingCompleted: onboardingCompleted
        )
    }
}
