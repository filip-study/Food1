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

    // Unlock tracking
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]

    // MARK: - Period Unlock Logic

    /// Days with at least 1 meal in the past 30 days
    private var daysWithDataLast30: Int {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        let recentMeals = allMeals.filter { $0.timestamp >= thirtyDaysAgo }
        let uniqueDays = Set(recentMeals.map { calendar.startOfDay(for: $0.timestamp) })
        return uniqueDays.count
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

    /// Month view: 10+ days with data in past 30 days
    private var isMonthUnlocked: Bool {
        daysWithDataLast30 >= 10
    }

    /// Quarter view: Month unlocked + at least 1 meal 40+ days ago
    private var isQuarterUnlocked: Bool {
        isMonthUnlocked && daysSinceOldestMeal >= 40
    }

    /// Year view: 50+ total meals + at least 1 meal 100+ days ago
    private var isYearUnlocked: Bool {
        allMeals.count >= 50 && daysSinceOldestMeal >= 100
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
            ScrollView {
                VStack(spacing: 0) {
                    // Check if selected period is locked
                    if !isPeriodUnlocked(selectedPeriod) {
                        LockedPeriodView(period: selectedPeriod)
                    } else if let stats = statistics {
                        if stats.totalMeals >= 1 {
                            // Chart section - edge-to-edge immersive
                            VStack(spacing: 0) {
                                MacroTrendsChart(statistics: stats, period: selectedPeriod)
                                    .padding(.vertical, 20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1),
                                                        Color.clear
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                            )

                            // Micronutrients section
                            MicronutrientsSection(
                                micronutrients: stats.micronutrients,
                                daysWithMeals: stats.daysWithMeals,
                                gender: userGender,
                                age: userAge,
                                selectedPeriod: selectedPeriod
                            )
                            .padding(.top, 24)
                            .padding(.horizontal, 16)

                            Spacer(minLength: 80)
                        } else {
                            EmptyTrendsView()
                        }
                    } else if isLoading {
                        Spacer()
                        ProgressView()
                            .padding(.top, 100)
                        Spacer()
                    } else {
                        EmptyTrendsView()
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: colorScheme == .light
                        ? [Color.white, Color.blue.opacity(0.05)]
                        : [Color.black, Color.blue.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    CapsulePeriodSelector(
                        selectedPeriod: $selectedPeriod,
                        isPeriodUnlocked: isPeriodUnlocked
                    )
                }
            }
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

// MARK: - Premium Capsule Period Selector

private struct CapsulePeriodSelector: View {
    @Binding var selectedPeriod: StatsPeriod
    let isPeriodUnlocked: (StatsPeriod) -> Bool
    @Namespace private var animation

    private let periods: [(StatsPeriod, String)] = [
        (.week, "Week"),
        (.month, "Month"),
        (.quarter, "3M"),
        (.year, "Year")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(periods, id: \.0) { period, label in
                let isUnlocked = isPeriodUnlocked(period)
                let isSelected = selectedPeriod == period

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedPeriod = period
                    }
                    HapticManager.light()
                } label: {
                    HStack(spacing: 4) {
                        Text(label)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))

                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .opacity(0.7)
                        }
                    }
                    .foregroundColor(isSelected ? .white : (isUnlocked ? .secondary : .secondary.opacity(0.5)))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: isUnlocked
                                                ? [Color.blue, Color.blue.opacity(0.85)]
                                                : [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "selector", in: animation)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Locked Period View

private struct LockedPeriodView: View {
    let period: StatsPeriod

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 8) {
                Text("Not enough data yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Keep logging meals to unlock this view")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Empty State

private struct EmptyTrendsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ColorPalette.macroProtein, ColorPalette.macroCarbs],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)

            Text("No data yet")
                .font(.system(size: 20, weight: .semibold))

            Text("Start logging meals to see your macro trends")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    StatsView()
        .modelContainer(PreviewContainer().container)
}
