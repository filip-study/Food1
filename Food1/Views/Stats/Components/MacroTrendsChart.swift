//
//  MacroTrendsChart.swift
//  Food1
//
//  Multi-line macro trends chart - analytical and elegant
//

import SwiftUI
import Charts

// MARK: - Chart Data Point (file-private for header access)

/// Unified chart point for rendering (works for both raw and smoothed data)
fileprivate struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let label: String           // Display label (day or window range)
    let windowSize: Int         // 1 for raw data, >1 for smoothed
}

struct MacroTrendsChart: View {
    let statistics: StatisticsSummary
    let period: StatsPeriod
    @State private var selectedDate: Date?
    @State private var selectedPoint: ChartPoint?
    @State private var lastSelectedDate: Date?
    @Environment(\.colorScheme) private var colorScheme

    // Use standard macro colors from ColorPalette
    private let proteinColor = ColorPalette.macroProtein
    private let carbsColor = ColorPalette.macroCarbs
    private let fatColor = ColorPalette.macroFat
    private let caloriesColor = ColorPalette.calories

    /// Unified chart points - either raw daily or smoothed based on period
    private var chartPoints: [ChartPoint] {
        if period.usesSmoothing {
            // Use smoothed data for Month, Quarter, Year
            return statistics.smoothedData(for: period).map { point in
                ChartPoint(
                    date: point.date,
                    calories: point.calories,
                    protein: point.protein,
                    carbs: point.carbs,
                    fat: point.fat,
                    label: point.windowLabel,
                    windowSize: point.windowSize
                )
            }
        } else {
            // Use raw daily data for Week
            return statistics.dailyData.filter { $0.mealCount > 0 }.map { day in
                ChartPoint(
                    date: day.date,
                    calories: day.calories,
                    protein: day.protein,
                    carbs: day.carbs,
                    fat: day.fat,
                    label: day.dayOfWeek,
                    windowSize: 1
                )
            }
        }
    }

    /// Maximum gap (in days) before showing a dashed line
    private var maxSolidGap: Int {
        period.maxSolidGap
    }

    /// Segments of consecutive points - solid lines only connect within segments
    /// Uses period-specific gap tolerance
    private var dataSegments: [[ChartPoint]] {
        let sortedPoints = chartPoints.sorted { $0.date < $1.date }
        var segments: [[ChartPoint]] = []
        var currentSegment: [ChartPoint] = []

        for point in sortedPoints {
            if let lastPoint = currentSegment.last {
                let daysBetween = Calendar.current.dateComponents([.day], from: lastPoint.date, to: point.date).day ?? 0
                if daysBetween > maxSolidGap {
                    // Gap exceeds tolerance - save current segment and start new one
                    if !currentSegment.isEmpty {
                        segments.append(currentSegment)
                    }
                    currentSegment = [point]
                } else {
                    currentSegment.append(point)
                }
            } else {
                currentSegment.append(point)
            }
        }
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }
        return segments
    }

    /// Isolated data points - single-point segments that can't form lines
    /// These are the ONLY points that need dots (no adjacent points to connect to)
    /// Note: First and last segments always have edge extensions, so they're never truly isolated
    private var isolatedPoints: [ChartPoint] {
        // Need at least 3 segments for any to be "middle" (truly isolated)
        guard dataSegments.count >= 3 else { return [] }

        // Only middle segments can be isolated (first has left edge, last has right edge)
        let middleSegments = Array(dataSegments.dropFirst().dropLast())
        return middleSegments.filter { $0.count == 1 }.compactMap { $0.first }
    }

    /// Gap bridges - pairs of consecutive data points that have a gap between them
    /// Only shows dashed lines for gaps that exceed the period's tolerance
    private var gapBridges: [(from: ChartPoint, to: ChartPoint)] {
        let sortedPoints = chartPoints.sorted { $0.date < $1.date }
        var bridges: [(from: ChartPoint, to: ChartPoint)] = []

        var lastPoint: ChartPoint?
        for point in sortedPoints {
            if let last = lastPoint {
                let daysBetween = Calendar.current.dateComponents([.day], from: last.date, to: point.date).day ?? 0
                if daysBetween > maxSolidGap {
                    bridges.append((from: last, to: point))
                }
            }
            lastPoint = point
        }
        return bridges
    }

    /// First and last chart points (for edge extensions)
    private var firstChartPoint: ChartPoint? {
        chartPoints.min { $0.date < $1.date }
    }

    private var lastChartPoint: ChartPoint? {
        chartPoints.max { $0.date < $1.date }
    }

    /// Extended date range for edge-to-edge chart display
    /// Based on ACTUAL data points only - not the full period range
    private var chartDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        // Use first/last REAL data points, not the period's date range
        guard let first = firstChartPoint?.date,
              let last = lastChartPoint?.date else {
            return Date()...Date()
        }
        // Extend half a day on each side for visual edge padding
        let extendedStart = first.addingHours(-12)
        let extendedEnd = last.addingHours(12)
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
    private var segmentsWithEdges: [[ChartPoint]] {
        guard !dataSegments.isEmpty else { return [] }

        var result = dataSegments

        // Add left edge point to first segment
        if let firstSegment = result.first, let firstPoint = firstSegment.first {
            let leftEdgePoint = ChartPoint(
                date: leftEdgeDate,
                calories: firstPoint.calories,
                protein: firstPoint.protein,
                carbs: firstPoint.carbs,
                fat: firstPoint.fat,
                label: "",
                windowSize: 0  // Mark as synthetic edge point
            )
            result[0] = [leftEdgePoint] + firstSegment
        }

        // Add right edge point to last segment
        let lastIndex = result.count - 1
        if let lastSegment = result.last, let lastPoint = lastSegment.last {
            let rightEdgePoint = ChartPoint(
                date: rightEdgeDate,
                calories: lastPoint.calories,
                protein: lastPoint.protein,
                carbs: lastPoint.carbs,
                fat: lastPoint.fat,
                label: "",
                windowSize: 0  // Mark as synthetic edge point
            )
            result[lastIndex] = lastSegment + [rightEdgePoint]
        }

        return result
    }

    /// Chart points plus edge points for calories gradient
    private var chartPointsWithEdges: [ChartPoint] {
        guard let first = firstChartPoint, let last = lastChartPoint else {
            return chartPoints
        }

        let leftEdgePoint = ChartPoint(
            date: leftEdgeDate,
            calories: first.calories,
            protein: first.protein,
            carbs: first.carbs,
            fat: first.fat,
            label: "",
            windowSize: 0
        )

        let rightEdgePoint = ChartPoint(
            date: rightEdgeDate,
            calories: last.calories,
            protein: last.protein,
            carbs: last.carbs,
            fat: last.fat,
            label: "",
            windowSize: 0
        )

        return [leftEdgePoint] + chartPoints + [rightEdgePoint]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Static header with date and legend/values combo
            // Order: Protein → Fat → Carbs
            SmoothedChartHeader(
                selectedPoint: selectedPoint,
                period: period,
                chartPoints: chartPoints,
                proteinColor: proteinColor,
                fatColor: fatColor,
                carbsColor: carbsColor,
                caloriesColor: caloriesColor
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Chart
            Chart {
                // CALORIES GRADIENT - normalized to fit macro scale, extends to edges
                // Actual calorie values shown in legend, this is just visual representation
                ForEach(chartPointsWithEdges) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Calories", point.calories / caloriesScaleFactor),
                        series: .value("Area", "Calories"),
                        stacking: .unstacked
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [caloriesColor.opacity(0.15), caloriesColor.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                // SOLID LINES - segments with edge extensions for edge-to-edge display
                // Order: Protein → Fat → Carbs
                ForEach(Array(segmentsWithEdges.enumerated()), id: \.offset) { segmentIndex, segment in
                    ForEach(segment) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Protein", point.protein),
                            series: .value("Macro", "Protein-\(segmentIndex)")
                        )
                        .foregroundStyle(proteinColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Fat", point.fat),
                            series: .value("Macro", "Fat-\(segmentIndex)")
                        )
                        .foregroundStyle(fatColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Carbs", point.carbs),
                            series: .value("Macro", "Carbs-\(segmentIndex)")
                        )
                        .foregroundStyle(carbsColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    }
                }

                // DOTS only for isolated points (single points with no adjacent data to form lines)
                // Order: Protein → Fat → Carbs
                ForEach(isolatedPoints) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Protein", point.protein)
                    )
                    .foregroundStyle(proteinColor)
                    .symbolSize(30)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Fat", point.fat)
                    )
                    .foregroundStyle(fatColor)
                    .symbolSize(30)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Carbs", point.carbs)
                    )
                    .foregroundStyle(carbsColor)
                    .symbolSize(30)
                }

                // DASHED LINES FOR GAPS - connect data points across missing days
                // Order: Protein → Fat → Carbs
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
                                        // Find the nearest chart point to snap to
                                        guard let nearestPoint = chartPoints.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        }) else { return }

                                        // Only trigger haptic and update when we cross to a NEW point
                                        let isNewPoint = lastSelectedDate == nil ||
                                            !Calendar.current.isDate(nearestPoint.date, inSameDayAs: lastSelectedDate!)

                                        if isNewPoint {
                                            HapticManager.light()
                                            lastSelectedDate = nearestPoint.date
                                            // Snap BOTH the line position AND data to the same point
                                            selectedDate = nearestPoint.date
                                            selectedPoint = nearestPoint
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    lastSelectedDate = nil
                                    // Clear selection after delay without animation
                                    // Animation here causes catmullRom curves to squiggle
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        selectedDate = nil
                                        selectedPoint = nil
                                    }
                                }
                        )
                }
            }
            .frame(height: 280)
            // Use period as identity to prevent squiggly animation when switching tabs
            // SwiftUI will treat each period as a new chart instead of animating between them
            .id(period)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Macro trends chart showing protein, fat, and carbs over \(period.rawValue.lowercased())")
    }

    /// Scale factor to normalize calories into the macro gram range
    /// e.g., 2000 cal / 10 = 200, which fits nicely with carbs ~200-300g
    private let caloriesScaleFactor: Double = 10.0

    private var maxYValue: Double {
        // Base scale on macros (grams) - carbs typically highest
        let maxProtein = chartPoints.map { $0.protein }.max() ?? 150
        let maxCarbs = chartPoints.map { $0.carbs }.max() ?? 250
        let maxFat = chartPoints.map { $0.fat }.max() ?? 100
        // Also consider scaled calories to ensure gradient fits
        let maxScaledCalories = (chartPoints.map { $0.calories }.max() ?? 2000) / caloriesScaleFactor
        return max(maxProtein, maxCarbs, maxFat, maxScaledCalories) * 1.15
    }
}

// MARK: - Supporting Views

fileprivate struct SmoothedChartHeader: View {
    let selectedPoint: ChartPoint?
    let period: StatsPeriod
    let chartPoints: [ChartPoint]
    let proteinColor: Color
    let fatColor: Color
    let carbsColor: Color
    let caloriesColor: Color

    // Compute period averages from chart points
    private var avgProtein: Double {
        guard !chartPoints.isEmpty else { return 0 }
        return chartPoints.reduce(0) { $0 + $1.protein } / Double(chartPoints.count)
    }

    private var avgCarbs: Double {
        guard !chartPoints.isEmpty else { return 0 }
        return chartPoints.reduce(0) { $0 + $1.carbs } / Double(chartPoints.count)
    }

    private var avgFat: Double {
        guard !chartPoints.isEmpty else { return 0 }
        return chartPoints.reduce(0) { $0 + $1.fat } / Double(chartPoints.count)
    }

    private var avgCalories: Double {
        guard !chartPoints.isEmpty else { return 0 }
        return chartPoints.reduce(0) { $0 + $1.calories } / Double(chartPoints.count)
    }

    private var periodDescription: String {
        guard let firstDate = chartPoints.first?.date,
              let lastDate = chartPoints.last?.date else {
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
            // Context row - shows period or selected point label
            HStack {
                if let point = selectedPoint {
                    Text(point.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                } else {
                    HStack(spacing: 6) {
                        Text(periodDescription)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("avg")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .transition(.opacity)
                }

                Spacer()
            }
            .frame(height: 20)
            .animation(.easeInOut(duration: 0.2), value: selectedPoint?.date)

            // Combined legend/values row - values below labels for stable layout
            // Order: Protein → Fat → Carbs → Cal
            HStack(spacing: 16) {
                MacroLegendValue(
                    label: "Protein",
                    value: selectedPoint?.protein ?? avgProtein,
                    unit: "g",
                    color: proteinColor,
                    isAverage: selectedPoint == nil
                )

                MacroLegendValue(
                    label: "Fat",
                    value: selectedPoint?.fat ?? avgFat,
                    unit: "g",
                    color: fatColor,
                    isAverage: selectedPoint == nil
                )

                MacroLegendValue(
                    label: "Carbs",
                    value: selectedPoint?.carbs ?? avgCarbs,
                    unit: "g",
                    color: carbsColor,
                    isAverage: selectedPoint == nil
                )

                MacroLegendValue(
                    label: "Cal",
                    value: selectedPoint?.calories ?? avgCalories,
                    unit: "",
                    color: caloriesColor,
                    isGradientIndicator: true,
                    isAverage: selectedPoint == nil
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
    var isAverage: Bool = false  // When true, shows value with softer styling

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

                // Value row - averages shown with "~" prefix and softer color
                if let val = value, val > 0 {
                    Text(isAverage ? "~\(formatValue(val, unit: unit))" : formatValue(val, unit: unit))
                        .font(.system(size: 14, weight: isAverage ? .semibold : .bold, design: .rounded))
                        .foregroundColor(isAverage ? color.opacity(0.7) : color)
                } else {
                    Text("–")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.5))
                }
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

// Preview requires a StatisticsSummary which needs DailyAggregates from the database
// Use the StatsView preview for full integration testing
