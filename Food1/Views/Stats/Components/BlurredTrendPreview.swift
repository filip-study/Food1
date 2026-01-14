//
//  BlurredTrendPreview.swift
//  Food1
//
//  Blurred preview of macro trends shown when user doesn't have enough data yet.
//  Encourages users to log more days to unlock their trend visualizations.
//  Extracted from StatsView for better maintainability.
//

import SwiftUI
import Charts

struct BlurredTrendPreview: View {
    let period: StatsPeriod
    @Environment(\.colorScheme) private var colorScheme

    // Static sample data points - deterministic to avoid re-rendering jitter
    // Values create dynamic, interesting trend lines that show what real data looks like
    private static let sampleMacros: [(protein: Double, carbs: Double, fat: Double)] = [
        (72, 145, 52),   // Lower start
        (95, 220, 78),   // Big jump up
        (68, 160, 48),   // Drop down
        (110, 195, 85),  // Spike protein
        (85, 250, 65),   // Spike carbs
        (98, 175, 72),   // Recovery
        (88, 200, 68)    // End moderate
    ]

    private var samplePoints: [SampleChartPoint] {
        let today = Date()

        return Self.sampleMacros.enumerated().map { index, macros in
            let daysAgo = Self.sampleMacros.count - 1 - index
            let date = today.addingDays(-daysAgo)
            let calories = macros.protein * 4 + macros.carbs * 4 + macros.fat * 9

            return SampleChartPoint(
                date: date,
                protein: macros.protein,
                carbs: macros.carbs,
                fat: macros.fat,
                calories: calories
            )
        }
    }

    var body: some View {
        ZStack {
            // Blurred sample chart
            VStack(spacing: 0) {
                // Fake header (blurred with chart)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Jan 1 – Jan 7")
                            .font(DesignSystem.Typography.medium(size: 13))
                            .foregroundColor(.secondary)
                        HStack(spacing: 16) {
                            sampleLegendItem(color: ColorPalette.macroProtein, label: "~85g")
                            sampleLegendItem(color: ColorPalette.macroFat, label: "~65g")
                            sampleLegendItem(color: ColorPalette.macroCarbs, label: "~180g")
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // Sample chart
                Chart {
                    // Calories gradient area
                    ForEach(samplePoints) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Calories", point.calories / 10)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ColorPalette.calories.opacity(0.15), ColorPalette.calories.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Macro lines
                    ForEach(samplePoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Protein", point.protein),
                            series: .value("Macro", "Protein")
                        )
                        .foregroundStyle(ColorPalette.macroProtein)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Fat", point.fat),
                            series: .value("Macro", "Fat")
                        )
                        .foregroundStyle(ColorPalette.macroFat)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Carbs", point.carbs),
                            series: .value("Macro", "Carbs")
                        )
                        .foregroundStyle(ColorPalette.macroCarbs)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .frame(height: 280)
            }
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(.ultraThinMaterial)
            )
            .blur(radius: 6)
            .opacity(0.7)

            // Overlay message
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorPalette.macroProtein, ColorPalette.macroCarbs],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Trends unlock with more data")
                    .font(DesignSystem.Typography.semiBold(size: 17))
                    .foregroundColor(.primary)

                Text("Log another day to see your patterns")
                    .font(DesignSystem.Typography.regular(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
            )
        }
    }

    private func sampleLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(color.opacity(0.7))
        }
    }
}

/// Sample data point for preview chart
struct SampleChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let protein: Double
    let carbs: Double
    let fat: Double
    let calories: Double
}
