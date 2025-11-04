//
//  DateNavigationHeader.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct DateNavigationHeader: View {
    @Binding var selectedDate: Date
    @State private var showCalendar = false

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
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        return nextDay <= Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Previous day button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.purple)
                    .frame(width: 32, height: 32)
            }

            // Date display with calendar button
            Button(action: {
                showCalendar.toggle()
            }) {
                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                }
            }
            .popover(isPresented: $showCalendar) {
                VStack(spacing: 0) {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                }
                .presentationCompactAdaptation(.popover)
                .frame(minWidth: 320, minHeight: 400)
            }

            // Next day button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canGoForward ? .purple : .gray.opacity(0.3))
                    .frame(width: 32, height: 32)
            }
            .disabled(!canGoForward)
        }
    }
}

#Preview {
    DateNavigationHeader(selectedDate: .constant(Date()))
}
