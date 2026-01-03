//
//  StatsView.swift
//  Food1
//
//  Minimal, analytical macro trends view
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("userGender") private var userGender: Gender = .preferNotToSay
    @AppStorage("userAge") private var userAge: Int = 25

    @State private var selectedPeriod: StatsPeriod = .week
    @State private var statistics: StatisticsSummary?
    @State private var isLoading = true

    // Sticky unlock persistence - once unlocked, stays unlocked
    @AppStorage("stats_monthUnlocked") private var monthPermanentlyUnlocked = false
    @AppStorage("stats_quarterUnlocked") private var quarterPermanentlyUnlocked = false
    @AppStorage("stats_yearUnlocked") private var yearPermanentlyUnlocked = false

    // Unlock tracking
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]

    // MARK: - Data Density Helpers

    /// Days with at least 1 meal in a given lookback period
    private func daysWithData(inLast days: Int) -> Int {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: Date())!
        let recentMeals = allMeals.filter { $0.timestamp >= cutoff }
        let uniqueDays = Set(recentMeals.map { calendar.startOfDay(for: $0.timestamp) })
        return uniqueDays.count
    }

    /// Days with data in the past 7 days (for week view)
    private var daysWithDataLast7: Int {
        daysWithData(inLast: 7)
    }

    /// Days with data in the past 30 days
    private var daysWithDataLast30: Int {
        daysWithData(inLast: 30)
    }

    /// Days with data in the past 90 days
    private var daysWithDataLast90: Int {
        daysWithData(inLast: 90)
    }

    /// Days with data in the past 365 days
    private var daysWithDataLast365: Int {
        daysWithData(inLast: 365)
    }

    /// Oldest meal timestamp (nil if no meals)
    private var oldestMealDate: Date? {
        allMeals.min(by: { $0.timestamp < $1.timestamp })?.timestamp
    }

    /// Days since oldest meal
    private var daysSinceOldestMeal: Int {
        guard let oldest = oldestMealDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
    }

    // MARK: - Period Unlock Logic (with sticky persistence)

    /// Month view: 8+ days with data in past 30 days AND 14+ days since first meal
    /// OR previously unlocked (sticky)
    private var isMonthUnlocked: Bool {
        let meetsCurrentCriteria = daysWithDataLast30 >= 8 && daysSinceOldestMeal >= 14
        if meetsCurrentCriteria && !monthPermanentlyUnlocked {
            // Persist the unlock
            DispatchQueue.main.async { monthPermanentlyUnlocked = true }
        }
        return meetsCurrentCriteria || monthPermanentlyUnlocked
    }

    /// Quarter view: 18+ days with data in past 90 days AND 45+ days since first meal
    /// OR previously unlocked (sticky)
    private var isQuarterUnlocked: Bool {
        let meetsCurrentCriteria = daysWithDataLast90 >= 18 && daysSinceOldestMeal >= 45
        if meetsCurrentCriteria && !quarterPermanentlyUnlocked {
            DispatchQueue.main.async { quarterPermanentlyUnlocked = true }
        }
        return meetsCurrentCriteria || quarterPermanentlyUnlocked
    }

    /// Year view: 50+ days with data in past 365 days AND 120+ days since first meal
    /// OR previously unlocked (sticky)
    private var isYearUnlocked: Bool {
        let meetsCurrentCriteria = daysWithDataLast365 >= 50 && daysSinceOldestMeal >= 120
        if meetsCurrentCriteria && !yearPermanentlyUnlocked {
            DispatchQueue.main.async { yearPermanentlyUnlocked = true }
        }
        return meetsCurrentCriteria || yearPermanentlyUnlocked
    }

    /// Minimum days needed to show a meaningful chart (not just 1 lonely point)
    private var hasEnoughDataForChart: Bool {
        guard let stats = statistics else { return false }
        // Need at least 2 days with meals for any meaningful trend line
        return stats.daysWithMeals >= 2
    }

    private func isPeriodUnlocked(_ period: StatsPeriod) -> Bool {
        switch period {
        case .week: return true
        case .month: return isMonthUnlocked
        case .quarter: return isQuarterUnlocked
        case .year: return isYearUnlocked
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated mesh gradient background
                AdaptiveAnimatedBackground()

                ScrollView {
                    VStack(spacing: 0) {
                    // Period selector - integrated at top of content
                    PeriodTabSelector(
                        selectedPeriod: $selectedPeriod,
                        isPeriodUnlocked: isPeriodUnlocked
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Note: Locked periods are disabled in the selector, so we always have an unlocked period here
                    if let stats = statistics {
                        if stats.totalMeals >= 1 && hasEnoughDataForChart {
                            // Chart section - contained card
                            VStack(spacing: 0) {
                                MacroTrendsChart(statistics: stats, period: selectedPeriod)
                                    .padding(.vertical, 20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(colorScheme == .dark
                                        ? Color(.systemGray6).opacity(0.5)
                                        : Color.white.opacity(0.7)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(
                                                colorScheme == .dark
                                                    ? Color.white.opacity(0.08)
                                                    : Color.black.opacity(0.04),
                                                lineWidth: 0.5
                                            )
                                    )
                            )
                            .padding(.horizontal, 16)

                            // Fiber section
                            FiberSection(
                                avgFiber: stats.avgFiber,
                                totalFiber: stats.totalFiber,
                                daysWithMeals: stats.daysWithMeals
                            )
                            .padding(.top, 24)
                            .padding(.horizontal, 16)

                            // Micronutrients section
                            MicronutrientsSection(
                                micronutrients: stats.micronutrients,
                                daysWithMeals: stats.daysWithMeals,
                                gender: userGender,
                                age: userAge,
                                selectedPeriod: selectedPeriod
                            )
                            .padding(.top, 16)
                            .padding(.horizontal, 16)

                            Spacer(minLength: 80)
                        } else {
                            // Not enough data for chart (0 or 1 day)
                            // Show blurred preview of what trends will look like
                            BlurredTrendPreview(period: selectedPeriod)
                        }
                    } else if isLoading {
                        Spacer()
                        ProgressView()
                            .padding(.top, 100)
                        Spacer()
                    } else {
                        // No statistics loaded yet - show blurred preview
                        BlurredTrendPreview(period: selectedPeriod)
                    }
                }
            }
            .scrollIndicators(.hidden)
            }  // Close ZStack
            .navigationBarHidden(true)
            .task(id: selectedPeriod) {
                if isPeriodUnlocked(selectedPeriod) {
                    await loadStatistics()
                }
            }
            .refreshable {
                if isPeriodUnlocked(selectedPeriod) {
                    await loadStatistics()
                }
            }
        }
    }

    private func loadStatistics() async {
        isLoading = true
        await StatisticsService.shared.performInitialMigration(in: modelContext)
        statistics = StatisticsService.shared.getStatistics(for: selectedPeriod, in: modelContext)
        isLoading = false
    }
}

// MARK: - Fiber Section

private struct FiberSection: View {
    let avgFiber: Double
    let totalFiber: Double
    let daysWithMeals: Int

    private var fiberGoal: Double {
        DailyGoals.fromUserDefaults().fiber
    }

    private var progressPercent: Double {
        guard fiberGoal > 0 else { return 0 }
        return min(avgFiber / fiberGoal, 1.0)
    }

    private var progressColor: Color {
        switch progressPercent {
        case 0..<0.5: return .orange
        case 0.5..<0.8: return .yellow
        default: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Fiber", systemImage: "leaf.arrow.triangle.circlepath")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.green)
                Spacer()
            }

            // Main stats row
            HStack(spacing: 24) {
                // Daily average
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1fg", avgFiber))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("daily avg")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: progressPercent)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(progressPercent * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(progressColor)
                    }
                }

                // Goal
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0fg", fiberGoal))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("goal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            // Info text
            if avgFiber < fiberGoal * 0.8 {
                Text("Tip: Add more vegetables, legumes, and whole grains to boost fiber intake.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Micronutrients Section

private struct MicronutrientsSection: View {
    let micronutrients: MicronutrientProfile
    let daysWithMeals: Int
    let gender: Gender
    let age: Int
    let selectedPeriod: StatsPeriod

    // Observe micronutrient standard to trigger view refresh when changed
    @AppStorage("micronutrientStandard") private var micronutrientStandard: MicronutrientStandard = .optimal

    @State private var showingDetailView = false

    private var allNutrientsWithRDA: [NutrientRDA] {
        // Use current standard from settings (Optimal or RDA)
        let standard = micronutrientStandard

        return [
            // Minerals (7)
            NutrientRDA(name: "Calcium", amount: micronutrients.calcium, unit: "mg", nutrientKey: "calcium"),
            NutrientRDA(name: "Iron", amount: micronutrients.iron, unit: "mg", nutrientKey: "iron"),
            NutrientRDA(name: "Magnesium", amount: micronutrients.magnesium, unit: "mg", nutrientKey: "magnesium"),
            NutrientRDA(name: "Zinc", amount: micronutrients.zinc, unit: "mg", nutrientKey: "zinc"),
            NutrientRDA(name: "Phosphorus", amount: micronutrients.phosphorus, unit: "mg", nutrientKey: "phosphorus"),
            NutrientRDA(name: "Copper", amount: micronutrients.copper, unit: "mg", nutrientKey: "copper"),
            NutrientRDA(name: "Selenium", amount: micronutrients.selenium, unit: "mcg", nutrientKey: "selenium"),
            // Electrolytes (2)
            NutrientRDA(name: "Potassium", amount: micronutrients.potassium, unit: "mg", nutrientKey: "potassium"),
            NutrientRDA(name: "Sodium", amount: micronutrients.sodium, unit: "mg", nutrientKey: "sodium"),
            // Vitamins (12)
            NutrientRDA(name: "Vitamin A", amount: micronutrients.vitaminA, unit: "mcg", nutrientKey: "vitamin a"),
            NutrientRDA(name: "Vitamin C", amount: micronutrients.vitaminC, unit: "mg", nutrientKey: "vitamin c"),
            NutrientRDA(name: "Vitamin D", amount: micronutrients.vitaminD, unit: "mcg", nutrientKey: "vitamin d"),
            NutrientRDA(name: "Vitamin E", amount: micronutrients.vitaminE, unit: "mg", nutrientKey: "vitamin e"),
            NutrientRDA(name: "Vitamin K", amount: micronutrients.vitaminK, unit: "mcg", nutrientKey: "vitamin k"),
            NutrientRDA(name: "Thiamin (B1)", amount: micronutrients.vitaminB1, unit: "mg", nutrientKey: "thiamin"),
            NutrientRDA(name: "Riboflavin (B2)", amount: micronutrients.vitaminB2, unit: "mg", nutrientKey: "riboflavin"),
            NutrientRDA(name: "Niacin (B3)", amount: micronutrients.vitaminB3, unit: "mg", nutrientKey: "niacin"),
            NutrientRDA(name: "Pantothenic Acid (B5)", amount: micronutrients.vitaminB5, unit: "mg", nutrientKey: "pantothenic acid"),
            NutrientRDA(name: "Pyridoxine (B6)", amount: micronutrients.vitaminB6, unit: "mg", nutrientKey: "vitamin b-6"),
            NutrientRDA(name: "Vitamin B12", amount: micronutrients.vitaminB12, unit: "mcg", nutrientKey: "vitamin b12"),
            NutrientRDA(name: "Folate (B9)", amount: micronutrients.folate, unit: "mcg", nutrientKey: "folate")
        ].map { nutrient in
            var n = nutrient
            // Use unified getValue() that respects selected standard (Optimal or RDA)
            let target = RDAValues.getValue(for: n.nutrientKey, gender: gender, age: age, standard: standard)
            // Calculate daily average percentage against target
            if target > 0 && daysWithMeals > 0 {
                n.rdaPercent = (n.amount / Double(daysWithMeals) / target) * 100
            }
            return n
        }
    }

    /// Nutrients sorted by RDA%, excluding neutral-tracked ones (Vitamin D, Sodium)
    private var sortedNutrients: [NutrientRDA] {
        allNutrientsWithRDA
            .filter { !neutralTrackingNutrients.contains($0.name) }
            .sorted { $0.rdaPercent > $1.rdaPercent }
    }

    private var topNutrients: [NutrientRDA] {
        Array(sortedNutrients.prefix(3))
    }

    private var bottomNutrients: [NutrientRDA] {
        Array(sortedNutrients.suffix(3).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            Text("Micronutrients")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)

            // Top nutrients
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("HIGHEST")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    Spacer()
                    Text("Daily Avg")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                ForEach(topNutrients, id: \.name) { nutrient in
                    NutrientRDARow(nutrient: nutrient, daysWithMeals: daysWithMeals)
                }
            }

            Divider()

            // Bottom nutrients
            VStack(alignment: .leading, spacing: 12) {
                Text("LOWEST")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                ForEach(bottomNutrients, id: \.name) { nutrient in
                    NutrientRDARow(nutrient: nutrient, daysWithMeals: daysWithMeals)
                }
            }

            // View All button
            Button {
                showingDetailView = true
                HapticManager.light()
            } label: {
                HStack {
                    Text("View All Nutrients")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18))
                }
                .foregroundColor(.blue)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .sheet(isPresented: $showingDetailView) {
            MicronutrientDetailView(
                micronutrients: micronutrients,
                daysWithMeals: daysWithMeals,
                selectedPeriod: selectedPeriod
            )
        }
    }
}

private struct NutrientRDA: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let unit: String
    let nutrientKey: String
    var rdaPercent: Double = 0
}

private struct NutrientRDARow: View {
    let nutrient: NutrientRDA
    let daysWithMeals: Int

    private var dailyAvg: Double {
        guard daysWithMeals > 0 else { return 0 }
        return nutrient.amount / Double(daysWithMeals)
    }

    private var rdaColor: Color {
        // Vitamin D and Sodium always use light gray (dietary tracking alone isn't meaningful)
        if neutralTrackingNutrients.contains(nutrient.name) {
            return Color.secondary.opacity(0.5)
        }

        // Soft, encouraging color scheme
        switch nutrient.rdaPercent {
        case ..<25: return Color(red: 0.55, green: 0.6, blue: 0.7)   // Soft blue-gray
        case 25..<75: return Color(red: 0.4, green: 0.7, blue: 0.7)  // Soft teal
        case 75..<100: return Color(red: 0.4, green: 0.75, blue: 0.5) // Green
        default: return Color(red: 0.3, green: 0.7, blue: 0.4)       // Deeper green
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(rdaColor)
                .frame(width: 8, height: 8)

            // Name
            Text(nutrient.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            // Amount
            Text(formatAmount(dailyAvg, unit: nutrient.unit))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            // RDA %
            Text("\(Int(nutrient.rdaPercent))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(rdaColor)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private func formatAmount(_ value: Double, unit: String) -> String {
        if value >= 1000 {
            return String(format: "%.1f%@", value / 1000, unit == "mg" ? "g" : "mg")
        } else if value >= 100 {
            return String(format: "%.0f%@", value, unit)
        } else if value >= 10 {
            return String(format: "%.1f%@", value, unit)
        } else {
            return String(format: "%.2f%@", value, unit)
        }
    }
}

// MARK: - Period Tab Selector (Underline Style)

private struct PeriodTabSelector: View {
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

// MARK: - Blurred Preview State (has data but not enough for chart)

private struct BlurredTrendPreview: View {
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
        let calendar = Calendar.current
        let today = Date()

        return Self.sampleMacros.enumerated().map { index, macros in
            let daysAgo = Self.sampleMacros.count - 1 - index
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
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
                            .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Log another day to see your patterns")
                    .font(.system(size: 14))
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
private struct SampleChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let protein: Double
    let carbs: Double
    let fat: Double
    let calories: Double
}

#Preview {
    StatsView()
        .modelContainer(PreviewContainer().container)
}
