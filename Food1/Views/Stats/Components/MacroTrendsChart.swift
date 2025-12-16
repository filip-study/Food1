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
    private let caloriesColor = ColorPalette.calories

    /// Days with actual meal data (not gaps)
    private var daysWithData: [DailyDataPoint] {
        dailyData.filter { $0.mealCount > 0 }
    }

    /// Segments of consecutive days with data - solid lines only connect within segments
    private var dataSegments: [[DailyDataPoint]] {
        let sortedData = dailyData.sorted { $0.date < $1.date }
        var segments: [[DailyDataPoint]] = []
        var currentSegment: [DailyDataPoint] = []

        for day in sortedData {
            if day.mealCount > 0 {
                if let lastDay = currentSegment.last {
                    let daysBetween = Calendar.current.dateComponents([.day], from: lastDay.date, to: day.date).day ?? 0
                    if daysBetween > 1 {
                        // Gap detected - save current segment and start new one
                        if !currentSegment.isEmpty {
                            segments.append(currentSegment)
                        }
                        currentSegment = [day]
                    } else {
                        currentSegment.append(day)
                    }
                } else {
                    currentSegment.append(day)
                }
            }
        }
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }
        return segments
    }

    /// Gap bridges - pairs of consecutive data points that have a gap between them
    private var gapBridges: [(from: DailyDataPoint, to: DailyDataPoint)] {
        let sortedData = dailyData.sorted { $0.date < $1.date }
        var bridges: [(from: DailyDataPoint, to: DailyDataPoint)] = []

        var lastDataPoint: DailyDataPoint?
        for day in sortedData {
            if day.mealCount > 0 {
                if let last = lastDataPoint {
                    let daysBetween = Calendar.current.dateComponents([.day], from: last.date, to: day.date).day ?? 0
                    if daysBetween > 1 {
                        bridges.append((from: last, to: day))
                    }
                }
                lastDataPoint = day
            }
        }
        return bridges
    }

    /// First and last data points with actual data (for edge extensions)
    private var firstDataPoint: DailyDataPoint? {
        daysWithData.min { $0.date < $1.date }
    }

    private var lastDataPoint: DailyDataPoint? {
        daysWithData.max { $0.date < $1.date }
    }

    /// Extended date range for edge-to-edge chart display
    /// Based on ACTUAL data points only - not the full period range
    private var chartDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        // Use first/last REAL data points, not the period's date range
        guard let first = firstDataPoint?.date,
              let last = lastDataPoint?.date else {
            return Date()...Date()
        }
        // Extend half a day on each side for visual edge padding
        let extendedStart = calendar.date(byAdding: .hour, value: -12, to: first)!
        let extendedEnd = calendar.date(byAdding: .hour, value: 12, to: last)!
        return extendedStart...extendedEnd
    }

    /// Left edge date for line extensions
    private var leftEdgeDate: Date {
        chartDateRange.lowerBound
    }

    /// Right edge date for line extensions
    private var rightEdgeDate: Date {
        chartDateRange.upperBound
    }

    /// Data segments with edge points integrated for seamless edge-to-edge display
    /// First segment gets a left edge point, last segment gets a right edge point
    private var segmentsWithEdges: [[DailyDataPoint]] {
        guard !dataSegments.isEmpty else { return [] }

        var result = dataSegments

        // Add left edge point to first segment
        if let firstSegment = result.first, let firstPoint = firstSegment.first {
            let leftEdgePoint = DailyDataPoint(
                date: leftEdgeDate,
                calories: firstPoint.calories,
                protein: firstPoint.protein,
                carbs: firstPoint.carbs,
                fat: firstPoint.fat,
                mealCount: 0  // Mark as synthetic
            )
            result[0] = [leftEdgePoint] + firstSegment
        }

        // Add right edge point to last segment
        let lastIndex = result.count - 1
        if let lastSegment = result.last, let lastPoint = lastSegment.last {
            let rightEdgePoint = DailyDataPoint(
                date: rightEdgeDate,
                calories: lastPoint.calories,
                protein: lastPoint.protein,
                carbs: lastPoint.carbs,
                fat: lastPoint.fat,
                mealCount: 0  // Mark as synthetic
            )
            result[lastIndex] = lastSegment + [rightEdgePoint]
        }

        return result
    }

    /// Days with data plus edge points for calories gradient
    private var daysWithDataAndEdges: [DailyDataPoint] {
        guard let first = firstDataPoint, let last = lastDataPoint else {
            return daysWithData
        }

        let leftEdgePoint = DailyDataPoint(
            date: leftEdgeDate,
            calories: first.calories,
            protein: first.protein,
            carbs: first.carbs,
            fat: first.fat,
            mealCount: 0
        )

        let rightEdgePoint = DailyDataPoint(
            date: rightEdgeDate,
            calories: last.calories,
            protein: last.protein,
            carbs: last.carbs,
            fat: last.fat,
            mealCount: 0
        )

        return [leftEdgePoint] + daysWithData + [rightEdgePoint]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Static header with date and legend/values combo
            StaticChartHeader(
                selectedData: selectedData,
                period: period,
                dailyData: dailyData,
                proteinColor: proteinColor,
                carbsColor: carbsColor,
                fatColor: fatColor,
                caloriesColor: caloriesColor
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Chart
            Chart {
                // CALORIES GRADIENT - normalized to fit macro scale, extends to edges
                // Actual calorie values shown in legend, this is just visual representation
                ForEach(daysWithDataAndEdges) { day in
                    AreaMark(
                        x: .value("Date", day.date),
                        y: .value("Calories", day.calories / caloriesScaleFactor),
                        series: .value("Area", "Calories"),
                        stacking: .unstacked
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [caloriesColor.opacity(0.15), caloriesColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                // SOLID LINES - segments with edge extensions for edge-to-edge display
                ForEach(Array(segmentsWithEdges.enumerated()), id: \.offset) { segmentIndex, segment in
                    ForEach(segment) { day in
                        LineMark(
                            x: .value("Date", day.date),
                            y: .value("Protein", day.protein),
                            series: .value("Macro", "Protein-\(segmentIndex)")
                        )
                        .foregroundStyle(proteinColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", day.date),
                            y: .value("Carbs", day.carbs),
                            series: .value("Macro", "Carbs-\(segmentIndex)")
                        )
                        .foregroundStyle(carbsColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", day.date),
                            y: .value("Fat", day.fat),
                            series: .value("Macro", "Fat-\(segmentIndex)")
                        )
                        .foregroundStyle(fatColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    }
                }

                // DOTS at actual data points (not on synthetic edge points)
                ForEach(daysWithData) { day in
                    PointMark(
                        x: .value("Date", day.date),
                        y: .value("Protein", day.protein)
                    )
                    .foregroundStyle(proteinColor)
                    .symbolSize(25)

                    PointMark(
                        x: .value("Date", day.date),
                        y: .value("Carbs", day.carbs)
                    )
                    .foregroundStyle(carbsColor)
                    .symbolSize(25)

                    PointMark(
                        x: .value("Date", day.date),
                        y: .value("Fat", day.fat)
                    )
                    .foregroundStyle(fatColor)
                    .symbolSize(25)
                }

                // DASHED LINES FOR GAPS - connect data points across missing days
                ForEach(Array(gapBridges.enumerated()), id: \.offset) { index, bridge in
                    // Protein dashed bridge
                    LineMark(
                        x: .value("Date", bridge.from.date),
                        y: .value("Value", bridge.from.protein),
                        series: .value("Bridge", "ProteinBridge\(index)")
                    )
                    .foregroundStyle(proteinColor.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                    LineMark(
                        x: .value("Date", bridge.to.date),
                        y: .value("Value", bridge.to.protein),
                        series: .value("Bridge", "ProteinBridge\(index)")
                    )
                    .foregroundStyle(proteinColor.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                    // Carbs dashed bridge
                    LineMark(
                        x: .value("Date", bridge.from.date),
                        y: .value("Value", bridge.from.carbs),
                        series: .value("Bridge", "CarbsBridge\(index)")
                    )
                    .foregroundStyle(carbsColor.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                    LineMark(
                        x: .value("Date", bridge.to.date),
                        y: .value("Value", bridge.to.carbs),
                        series: .value("Bridge", "CarbsBridge\(index)")
                    )
                    .foregroundStyle(carbsColor.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                    // Fat dashed bridge
                    LineMark(
                        x: .value("Date", bridge.from.date),
                        y: .value("Value", bridge.from.fat),
                        series: .value("Bridge", "FatBridge\(index)")
                    )
                    .foregroundStyle(fatColor.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                    LineMark(
                        x: .value("Date", bridge.to.date),
                        y: .value("Value", bridge.to.fat),
                        series: .value("Bridge", "FatBridge\(index)")
                    )
                    .foregroundStyle(fatColor.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }

                // Selection indicator
                if let selected = selectedDate {
                    RuleMark(x: .value("Selected", selected))
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXScale(domain: chartDateRange)
            .chartYScale(domain: 0...maxYValue)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartScrollableAxes([])
            .chartPlotStyle { plotArea in
                plotArea
                    .padding(.horizontal, 0) // No padding - let extensions reach edges
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = value.location.x - geometry[plotFrame].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        // Find the nearest data point to snap to
                                        guard let nearestPoint = dailyData.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        }) else { return }

                                        // Only trigger haptic and update when we cross to a NEW day
                                        let isNewDay = lastSelectedDate == nil ||
                                            !Calendar.current.isDate(nearestPoint.date, inSameDayAs: lastSelectedDate!)

                                        if isNewDay {
                                            HapticManager.light()
                                            lastSelectedDate = nearestPoint.date
                                            // Snap BOTH the line position AND data to the same point
                                            selectedDate = nearestPoint.date
                                            selectedData = nearestPoint
                                        }
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

    /// Scale factor to normalize calories into the macro gram range
    /// e.g., 2000 cal / 10 = 200, which fits nicely with carbs ~200-300g
    private let caloriesScaleFactor: Double = 10.0

    private var maxYValue: Double {
        // Base scale on macros (grams) - carbs typically highest
        let maxProtein = dailyData.map { $0.protein }.max() ?? 150
        let maxCarbs = dailyData.map { $0.carbs }.max() ?? 250
        let maxFat = dailyData.map { $0.fat }.max() ?? 100
        // Also consider scaled calories to ensure gradient fits
        let maxScaledCalories = (dailyData.map { $0.calories }.max() ?? 2000) / caloriesScaleFactor
        return max(maxProtein, maxCarbs, maxFat, maxScaledCalories) * 1.15
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
    let caloriesColor: Color

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

            // Combined legend/values row - values below labels for stable layout
            HStack(spacing: 16) {
                MacroLegendValue(
                    label: "Protein",
                    value: selectedData?.protein,
                    unit: "g",
                    color: proteinColor
                )

                MacroLegendValue(
                    label: "Carbs",
                    value: selectedData?.carbs,
                    unit: "g",
                    color: carbsColor
                )

                MacroLegendValue(
                    label: "Fat",
                    value: selectedData?.fat,
                    unit: "g",
                    color: fatColor
                )

                MacroLegendValue(
                    label: "Cal",
                    value: selectedData?.calories,
                    unit: "",
                    color: caloriesColor,
                    isGradientIndicator: true
                )

                Spacer()
            }
        }
    }
}

private struct MacroLegendValue: View {
    let label: String
    let value: Double?
    let unit: String
    let color: Color
    var isGradientIndicator: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            // Indicator: gradient square for calories, solid dot for macros
            if isGradientIndicator {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.6), color.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: 12)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }

            // Vertical stack: label on top, value below (fixed height for stability)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                // Value row - always present to maintain layout, just changes content
                Text(value != nil ? formatValue(value!, unit: unit) : "–")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(value != nil ? color : .secondary.opacity(0.5))
            }
            .frame(minWidth: 50, alignment: .leading)
        }
    }

    private func formatValue(_ val: Double, unit: String) -> String {
        if unit.isEmpty {
            // Calories - no unit, format as integer
            return "\(Int(val))"
        } else {
            return "\(Int(val))\(unit)"
        }
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
