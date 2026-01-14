//
//  DateNavigationHeader.swift
//  Food1
//
//  Inline date picker with left/right arrows and calendar popover.
//
//  WHY THIS ARCHITECTURE:
//  - Inline header (not full-screen calendar) keeps user in context on TodayView
//  - Smart date labels: "Today", "Yesterday", "Tomorrow", or "EEE, MMM d" format
//  - Calendar popover on tap provides quick jump to any date
//  - Left/right arrows enable single-day increments without opening calendar
//  - Button press states with scale + opacity provide tactile feedback
//

import SwiftUI

struct DateNavigationHeader: View {
    @Binding var selectedDate: Date
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var isPreviousPressed = false
    @State private var isNextPressed = false

    private var formattedDate: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    private var canGoForward: Bool {
        let nextDay = selectedDate.addingDays(1)
        return nextDay <= Date()
    }

    /// Check if we can navigate to the previous day (respects registration date restriction)
    private var canGoBack: Bool {
        let previousDay = selectedDate.addingDays(-1)
        return MealDateRestriction.isDateAllowed(previousDay)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Previous day button - only enabled if previous day is allowed
            if canGoBack {
                Button(action: {
                    // Double-check to prevent navigating before registration date
                    let previousDay = selectedDate.addingDays(-1)
                    guard MealDateRestriction.isDateAllowed(previousDay) else { return }

                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = previousDay
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isPreviousPressed ? 0.85 : 1.0)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            withAnimation(.easeInOut(duration: 0.08)) {
                                isPreviousPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.08)) {
                                isPreviousPressed = false
                            }
                        }
                )
            }

            // Date display
            Button(action: {
                showCalendar.toggle()
            }) {
                Text(formattedDate)
                    .font(DesignSystem.Typography.bold(size: 24))
                    .foregroundColor(.primary)
            }
            .sheet(isPresented: $showCalendar) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "",
                            selection: $selectedDate,
                            in: MealDateRestriction.allowedDateRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding()

                        Spacer()
                    }
                    .navigationTitle("Select Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showCalendar = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }

            // Next day button - only shown when viewing past dates
            if canGoForward {
                Button(action: {
                    // Double-check to prevent race condition when tapping rapidly
                    let nextDay = selectedDate.addingDays(1)
                    guard nextDay <= Date() else { return }

                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = nextDay
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isNextPressed ? 0.85 : 1.0)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            withAnimation(.easeInOut(duration: 0.08)) {
                                isNextPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.08)) {
                                isNextPressed = false
                            }
                        }
                )
            }
        }
    }
}

#Preview {
    DateNavigationHeader(selectedDate: .constant(Date()))
}
