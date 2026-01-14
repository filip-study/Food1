//
//  TimeSelectionSheet.swift
//  Food1
//
//  Unified time/date picker sheet with tabbed navigation.
//
//  WHY THIS ARCHITECTURE:
//  - Tabbed interface (Time/Date) avoids confusing "Back to time" flow
//  - Auto-switches back to Time tab after date selection for streamlined UX
//  - Compact date chips for quick selection (Today, Yesterday, or calendar)
//  - Time wheel is primary - most users log at current time
//  - Medium detent keeps context visible
//

import SwiftUI

struct TimeSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var mealTime: Date

    private enum Tab: String, CaseIterable {
        case time = "Time"
        case date = "Date"
    }

    @State private var selectedTab: Tab = .time

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

    // Smart date description for display
    private var dateDescription: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(mealTime) {
            return "Today"
        } else if calendar.isDateInYesterday(mealTime) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: mealTime)
        }
    }

    // Time description
    private var timeDescription: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: mealTime)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary header showing current selection
                HStack(spacing: 16) {
                    // Date chip
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = .date
                        }
                        HapticManager.light()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                            Text(dateDescription)
                                .font(DesignSystem.Typography.medium(size: 15))
                        }
                        .foregroundStyle(selectedTab == .date ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == .date ? Color.blue : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(.plain)

                    // Time chip
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = .time
                        }
                        HapticManager.light()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 14))
                            Text(timeDescription)
                                .font(DesignSystem.Typography.medium(size: 15))
                        }
                        .foregroundStyle(selectedTab == .time ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == .time ? Color.blue : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                // Tab content
                if selectedTab == .time {
                    // Time picker
                    VStack(spacing: 0) {
                        DatePicker(
                            "",
                            selection: $mealTime,
                            in: timeRange,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding(.vertical, 8)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    // Date picker with quick options
                    VStack(spacing: 16) {
                        // Quick date buttons
                        HStack(spacing: 12) {
                            QuickDateButton(
                                title: "Today",
                                isSelected: Calendar.current.isDateInToday(mealTime)
                            ) {
                                setDate(to: Date())
                            }

                            QuickDateButton(
                                title: "Yesterday",
                                isSelected: Calendar.current.isDateInYesterday(mealTime)
                            ) {
                                setDate(to: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 20)

                        // Calendar picker (restricted to registration date - 1 day through today)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { mealTime },
                                set: { newDate in
                                    setDate(to: newDate)
                                }
                            ),
                            in: MealDateRestriction.allowedDateRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal, 8)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }

                Spacer(minLength: 0)
            }
            .navigationTitle("When did you eat?")
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // Set date while preserving time, then auto-switch to time tab
    private func setDate(to newDate: Date) {
        let calendar = Calendar.current

        // Get time components from current mealTime
        let timeComponents = calendar.dateComponents([.hour, .minute], from: mealTime)

        // Get date components from new date
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: newDate)

        // Combine them
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        if let combinedDate = calendar.date(from: combined) {
            // If the combined date is in the future (for today), clamp to now
            if combinedDate > Date() {
                mealTime = Date()
            } else {
                mealTime = combinedDate
            }
        }

        HapticManager.light()

        // Auto-switch back to time tab after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = .time
            }
        }
    }
}

// MARK: - Quick Date Button

private struct QuickDateButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.medium(size: 15))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Text("Main View")
        .sheet(isPresented: .constant(true)) {
            TimeSelectionSheet(mealTime: .constant(Date()))
        }
}
