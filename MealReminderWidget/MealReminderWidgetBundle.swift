//
//  MealReminderWidgetBundle.swift
//  MealReminderWidget
//
//  Widget bundle entry point for meal reminder Live Activities.
//

import WidgetKit
import SwiftUI

@main
struct MealReminderWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity for meal reminders
        MealReminderLiveActivity()
    }
}
