//
//  MealReminderWidgetBundle.swift
//  MealReminderWidget
//
//  Widget bundle entry point for Live Activities.
//
//  REGISTERED ACTIVITIES:
//  - MealReminderLiveActivity: Suggests meals at appropriate times
//  - FastingLiveActivity: Shows fasting progress on lock screen/Dynamic Island
//

import WidgetKit
import SwiftUI

@main
struct MealReminderWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity for meal reminders
        MealReminderLiveActivity()

        // Live Activity for fasting progress
        FastingLiveActivity()
    }
}
