//
//  MacroTrendsChart.swift
//  Food1
//
//  Multi-line macro trends chart - analytical and elegant
//

import SwiftUI
import Charts

struct MacroTrendsChart: View {
    let dailyData: [DailyDataPoint]
    let period: StatsPeriod
    @State private var selectedDate: Date?
    @State private var selectedData: DailyDataPoint?
    @State private var lastSelectedDate: Date?
    @Environment(\.colorScheme) private var colorScheme

    // Use standard macro colors from ColorPalette
    private let proteinColor = ColorPalette.macroProtein
    private let carbsColor = ColorPalette.macroCarbs
    private let fatColor = ColorPalette.macroFat

    var body: some View {
        VStack(spacing: 0) {
            // Static header with date and legend/values combo
            StaticChartHeader(
                selectedData: selectedData,
                period: period,
                dailyData: dailyData,
                proteinColor: proteinColor,
                carbsColor: carbsColor,
                fatColor: fatColor
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 16)

            // Chart
            Chart {
                // Goal reference lines
                RuleMark(y: .value("Protein Goal", DailyGoals.standard.protein))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [8, 4]))
                    .foregroundStyle(proteinColor.opacity(0.3))

                RuleMark(y: .value("Carbs Goal", DailyGoals.standard.carbs))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [8, 4]))
                    .foregroundStyle(carbsColor.opacity(0.3))

                RuleMark(y: .value("Fat Goal", DailyGoals.standard.fat))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [8, 4]))
                    .foregroundStyle(fatColor.opacity(0.3))

                // Data lines with dots at actual data points
                ForEach(dailyData.filter { $0.mealCount > 0 }) { day in
                    // Lines connecting consecutive data points
                    LineMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Protein", day.protein),
                        series: .value("Macro", "Protein")
                    )
                    .foregroundStyle(proteinColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Carbs", day.carbs),
                        series: .value("Macro", "Carbs")
                    )
                    .foregroundStyle(carbsColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Fat", day.fat),
                        series: .value("Macro", "Fat")
                    )
                    .foregroundStyle(fatColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    // Dots at actual data points to show where real data exists
                    PointMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Protein", day.protein)
                    )
                    .foregroundStyle(proteinColor)
                    .symbolSize(30)

                    PointMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Carbs", day.carbs)
                    )
                    .foregroundStyle(carbsColor)
                    .symbolSize(30)

                    PointMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Fat", day.fat)
                    )
                    .foregroundStyle(fatColor)
                    .symbolSize(30)
                }

                // Selection indicator
                if let selected = selectedDate {
                    RuleMark(x: .value("Selected", selected, unit: .day))
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartYScale(domain: 0...maxYValue)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.1))
                    AxisValueLabel {
                        if let grams = value.as(Double.self) {
                            Text("\(Int(grams))g")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary.opacity(0.7))
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .chartScrollableAxes([])
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        // Clamp date to data range
                                        guard let firstDate = dailyData.first?.date,
                                              let lastDate = dailyData.last?.date else { return }

                                        let clampedDate = min(max(date, firstDate), lastDate)

                                        let newData = dailyData.min(by: {
                                            abs($0.date.timeIntervalSince(clampedDate)) < abs($1.date.timeIntervalSince(clampedDate))
                                        })

                                        if let newData = newData,
                                           lastSelectedDate == nil || !Calendar.current.isDate(newData.date, inSameDayAs: lastSelectedDate!) {
                                            HapticManager.light()
                                            lastSelectedDate = newData.date
                                        }

                                        selectedDate = clampedDate
                                        selectedData = newData
                                    }
                                }
                                .onEnded { _ in
                                    lastSelectedDate = nil
                                    withAnimation(.easeOut(duration: 0.2).delay(0.5)) {
                                        selectedDate = nil
                                        selectedData = nil
                                    }
                                }
                        )
                }
            }
            .frame(height: 280)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Macro trends chart showing protein, carbs, and fat over \(period.rawValue.lowercased())")
    }

    private var maxYValue: Double {
        let maxData = dailyData.map { max($0.protein, $0.carbs) }.max() ?? 250
        let maxGoal = max(DailyGoals.standard.protein, DailyGoals.standard.carbs)
        return max(maxData * 1.1, maxGoal * 1.2)
    }

    private var xAxisStride: Int {
        switch period {
        case .week: return 1
        case .month: return 5
        case .quarter: return 14
        case .year: return 30
        }
    }
}

// MARK: - Supporting Views

private struct StaticChartHeader: View {
    let selectedData: DailyDataPoint?
    let period: StatsPeriod
    let dailyData: [DailyDataPoint]
    let proteinColor: Color
    let carbsColor: Color
    let fatColor: Color

    private var periodDescription: String {
        guard let firstDate = dailyData.first?.date,
              let lastDate = dailyData.last?.date else {
            return period.rawValue
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let start = formatter.string(from: firstDate)
        let end = formatter.string(from: lastDate)
        return "\(start) – \(end)"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Context row - shows period or selected date
            HStack {
                if let data = selectedData {
                    Text(data.shortDate)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                } else {
                    Text(periodDescription)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }

                Spacer()
            }
            .frame(height: 20)
            .animation(.easeInOut(duration: 0.2), value: selectedData?.date)

            // Combined legend/values row
            HStack(spacing: 24) {
                MacroLegendValue(
                    label: "Protein",
                    value: selectedData?.protein,
                    color: proteinColor
                )

                MacroLegendValue(
                    label: "Carbs",
                    value: selectedData?.carbs,
                    color: carbsColor
                )

                MacroLegendValue(
                    label: "Fat",
                    value: selectedData?.fat,
                    color: fatColor
                )

                Spacer()
            }
        }
    }
}

private struct MacroLegendValue: View {
    let label: String
    let value: Double?
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            // Colored dot indicator
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            // Label that transforms to show value
            Group {
                if let value = value {
                    // Show value when selected
                    HStack(spacing: 4) {
                        Text(label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(color)
                        Text("\(Int(value))g")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .leading)),
                        removal: .opacity
                    ))
                } else {
                    // Show just label when idle
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: value != nil)
        }
        .frame(minWidth: 80, alignment: .leading) // Fixed min width prevents jumping
    }
}

#Preview {
    let sampleData = (0..<7).map { i in
        DailyDataPoint(
            date: Calendar.current.date(byAdding: .day, value: -6 + i, to: Date())!,
            calories: Double.random(in: 1500...2200),
            protein: Double.random(in: 100...160),
            carbs: Double.random(in: 180...260),
            fat: Double.random(in: 50...80),
            mealCount: i == 3 ? 0 : Int.random(in: 1...4)
        )
    }

    MacroTrendsChart(dailyData: sampleData, period: .week)
        .padding(20)
        .background(Color(.systemGroupedBackground))
}
