//
//  TimeSelectionSheet.swift
//  Food1
//
//  Compact time/date picker sheet with progressive disclosure pattern.
//  Shows time wheel by default, calendar on demand.
//
//  WHY THIS ARCHITECTURE:
//  - Most users log meals at current time → time wheel is primary interface
//  - Date selection is rare edge case → hidden behind secondary button
//  - Bottom sheet with medium detent keeps context visible
//  - Progressive disclosure reduces cognitive load
//

import SwiftUI

struct TimeSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var mealTime: Date
    @State private var showingDatePicker = false

    // Dynamic time range: only restrict to "now" if meal is for today
    private var timeRange: PartialRangeThrough<Date> {
        let calendar = Calendar.current
        if calendar.isDateInToday(mealTime) {
            // Today: can't log future meals
            return ...Date()
        } else {
            // Past date: allow any time (end of that day)
            let endOfSelectedDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: mealTime) ?? mealTime
            return ...endOfSelectedDay
        }
    }

    // Relative time description for display
    private var timeDescription: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: mealTime)
    }

    // Smart date description
    private var dateDescription: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(mealTime) {
            return "Today"
        } else if calendar.isDateInYesterday(mealTime) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: mealTime)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if !showingDatePicker {
                    // PRIMARY VIEW: Time wheel picker
                    VStack(spacing: 16) {
                        Text("What time did you eat?")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "",
                            selection: $mealTime,
                            in: timeRange,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()

                        // Secondary action: Show date picker
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingDatePicker = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                Text("Different day?")
                                    .font(.callout)
                                Text("(\(dateDescription))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.blue)
                    }
                    .transition(.push(from: .leading))

                } else {
                    // SECONDARY VIEW: Calendar picker
                    VStack(spacing: 16) {
                        Text("Which day?")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "",
                            selection: $mealTime,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()

                        // Back button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingDatePicker = false
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Back to time")
                                    .font(.callout)
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.blue)
                    }
                    .transition(.push(from: .trailing))
                }
            }
            .padding()
            .navigationTitle("When?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Main View")
        .sheet(isPresented: .constant(true)) {
            TimeSelectionSheet(mealTime: .constant(Date()))
        }
}
