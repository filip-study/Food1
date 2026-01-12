//
//  MealReminderLiveActivity.swift
//  MealReminderWidget
//
//  Live Activity views for meal reminders.
//  Provides lock screen widget and Dynamic Island presentations.
//
//  DESIGN PHILOSOPHY:
//  - Clean, minimal black & white design
//  - Two-tier layout: Meal info + Action buttons
//  - Bold white "Log Meal" button for maximum visibility
//  - No data dependencies - always looks good
//  - Dynamic Island: Compact shows meal + time, expanded shows full CTA
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Brand Colors

private let brandTeal = Color(red: 0.08, green: 0.72, blue: 0.65)
private let brandTealLight = Color(red: 0.20, green: 0.78, blue: 0.72)

// MARK: - Widget Configuration

struct MealReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MealReminderAttributes.self) { context in
            // Lock Screen / StandBy presentation
            LockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.9))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: context.attributes.iconName)
                            .font(.title2)
                            .foregroundStyle(brandTeal)

                        Text(context.attributes.targetTime, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("\(context.attributes.mealName) time")
                            .font(.headline)
                            .lineLimit(1)

                        Text(subtitleForMeal(context.attributes.mealName))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    // Empty - keeping layout balanced
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        // Primary action - Log Meal
                        Link(destination: URL(string: "prismae://log-meal?window=\(context.attributes.windowId)")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.subheadline)
                                Text("Log Meal")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [brandTeal, brandTealLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }

                        // Secondary action - Skip
                        Link(destination: URL(string: "prismae://dismiss-reminder?window=\(context.attributes.windowId)")!) {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                // Compact pill - left side: meal icon
                HStack(spacing: 4) {
                    Image(systemName: context.attributes.iconName)
                        .foregroundStyle(brandTeal)
                }
            } compactTrailing: {
                // Compact pill - right side: target time
                Text(context.attributes.targetTime, style: .time)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
            } minimal: {
                // Minimal presentation (when multiple activities)
                Image(systemName: "fork.knife")
                    .foregroundStyle(brandTeal)
            }
            .keylineTint(brandTeal)
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<MealReminderAttributes>

    private var isExpiring: Bool {
        context.state.status == .expiring
    }

    var body: some View {
        VStack(spacing: 16) {
            // Top: Icon + Meal Info
            HStack(spacing: 14) {
                // Icon
                Image(systemName: context.attributes.iconName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)

                // Meal name and subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.mealName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    if isExpiring {
                        Text("Dismissing soon...")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        Text(subtitleForMeal(context.attributes.mealName))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()
            }

            // Bottom: Action Buttons
            HStack(spacing: 10) {
                // Primary: Log Meal button
                Link(destination: URL(string: "prismae://log-meal?window=\(context.attributes.windowId)")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Log Meal")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Secondary: Skip button
                Link(destination: URL(string: "prismae://dismiss-reminder?window=\(context.attributes.windowId)")!) {
                    Text("Skip")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

// MARK: - Helper Functions

/// Returns an encouraging subtitle based on meal type
private func subtitleForMeal(_ mealName: String) -> String {
    let name = mealName.lowercased()

    switch name {
    case "breakfast":
        return "Start your day right"
    case "lunch":
        return "Fuel your afternoon"
    case "dinner":
        return "Wind down with a good meal"
    case "snack":
        return "A little boost goes a long way"
    default:
        return "Keep your nutrition on track"
    }
}

// MARK: - Previews

#Preview("Lock Screen - Breakfast", as: .content, using: MealReminderAttributes(
    mealName: "Breakfast",
    targetTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
    windowId: UUID(),
    iconName: "sun.horizon.fill"
)) {
    MealReminderLiveActivity()
} contentStates: {
    MealReminderAttributes.ContentState(
        status: .active,
        dismissAt: Date().addingTimeInterval(7200)
    )
}

#Preview("Lock Screen - Lunch", as: .content, using: MealReminderAttributes(
    mealName: "Lunch",
    targetTime: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date())!,
    windowId: UUID(),
    iconName: "sun.max.fill"
)) {
    MealReminderLiveActivity()
} contentStates: {
    MealReminderAttributes.ContentState(
        status: .active,
        dismissAt: Date().addingTimeInterval(7200)
    )
}

#Preview("Lock Screen - Dinner", as: .content, using: MealReminderAttributes(
    mealName: "Dinner",
    targetTime: Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date())!,
    windowId: UUID(),
    iconName: "moon.stars.fill"
)) {
    MealReminderLiveActivity()
} contentStates: {
    MealReminderAttributes.ContentState(
        status: .active,
        dismissAt: Date().addingTimeInterval(7200)
    )
}

#Preview("Lock Screen - Expiring", as: .content, using: MealReminderAttributes(
    mealName: "Lunch",
    targetTime: Date(),
    windowId: UUID(),
    iconName: "sun.max.fill"
)) {
    MealReminderLiveActivity()
} contentStates: {
    MealReminderAttributes.ContentState(
        status: .expiring,
        dismissAt: Date().addingTimeInterval(300)
    )
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: MealReminderAttributes(
    mealName: "Lunch",
    targetTime: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date())!,
    windowId: UUID(),
    iconName: "sun.max.fill"
)) {
    MealReminderLiveActivity()
} contentStates: {
    MealReminderAttributes.ContentState(
        status: .active,
        dismissAt: Date().addingTimeInterval(7200)
    )
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: MealReminderAttributes(
    mealName: "Lunch",
    targetTime: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date())!,
    windowId: UUID(),
    iconName: "sun.max.fill"
)) {
    MealReminderLiveActivity()
} contentStates: {
    MealReminderAttributes.ContentState(
        status: .active,
        dismissAt: Date().addingTimeInterval(7200)
    )
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: MealReminderAttributes(
    mealName: "Lunch",
    targetTime: Date(),
    windowId: UUID(),
    iconName: "sun.max.fill"
)) {
    MealReminderLiveActivity()
} contentStates: {
    MealReminderAttributes.ContentState(
        status: .active,
        dismissAt: Date().addingTimeInterval(7200)
    )
}
