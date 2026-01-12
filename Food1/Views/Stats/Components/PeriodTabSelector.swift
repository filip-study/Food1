//
//  PeriodTabSelector.swift
//  Food1
//
//  Tab selector for statistics period (Week/Month/Quarter/Year).
//  Shows lock icons for periods that require more data to unlock.
//  Extracted from StatsView for better maintainability.
//

import SwiftUI

struct PeriodTabSelector: View {
    @Binding var selectedPeriod: StatsPeriod
    let isPeriodUnlocked: (StatsPeriod) -> Bool
    @Namespace private var animation

    private let periods: [(StatsPeriod, String)] = [
        (.week, "Week"),
        (.month, "Month"),
        (.quarter, "3 Months"),
        (.year, "Year")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(periods, id: \.0) { period, label in
                let isUnlocked = isPeriodUnlocked(period)
                let isSelected = selectedPeriod == period

                Button {
                    guard isUnlocked else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                    HapticManager.light()
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text(label)
                                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))

                            if !isUnlocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                            }
                        }
                        .foregroundColor(
                            isSelected ? .primary :
                            (isUnlocked ? .secondary : .secondary.opacity(0.55))
                        )

                        // Animated underline indicator
                        ZStack {
                            // Invisible spacer for consistent height
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 3)

                            if isSelected {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color.primary.opacity(0.8))
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "underline", in: animation)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(!isUnlocked)
            }
        }
        .padding(.horizontal, 16)
    }
}
