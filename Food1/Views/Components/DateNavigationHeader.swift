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
        HStack(spacing: 8) {
            // Previous day button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 28, height: 28)
            }

            // Date display with calendar button
            Button(action: {
                showCalendar.toggle()
            }) {
                Text(formattedDate)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
            }
            .sheet(isPresented: $showCalendar) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "",
                            selection: $selectedDate,
                            in: ...Date(),
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

            // Next day button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(canGoForward ? .blue : .gray.opacity(0.3))
                    .frame(width: 28, height: 28)
            }
            .disabled(!canGoForward)
        }
    }
}

#Preview {
    DateNavigationHeader(selectedDate: .constant(Date()))
}
