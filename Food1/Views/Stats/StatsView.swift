//
//  StatsView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI
import SwiftData
import Charts

enum TimePeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
}

struct StatsView: View {
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric

    @State private var selectedPeriod: TimePeriod = .week
    @State private var statsData: StatsData?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time period selector
                    Picker("Time Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if let stats = statsData {
                        if stats.mealCount >= 3 {
                            // Calorie trend chart
                            CalorieTrendCard(stats: stats, period: selectedPeriod)

                            // Macro distribution
                            MacroDistributionCard(stats: stats)

                            // Micronutrient insights
                            if let microData = stats.micronutrientData {
                                MicronutrientInsightsCard(insights: microData)
                            } else {
                                // Show empty state explaining why no data
                                MicronutrientEmptyStateCard(totalMeals: stats.mealCount)
                            }

                            // Quick stats grid
                            QuickStatsGrid(stats: stats)
                        } else {
                            // Not enough data
                            EmptyStatsView(mealCount: stats.mealCount)
                        }
                    } else {
                        // Loading or no data
                        EmptyStatsView(mealCount: 0)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stats")
            .task(id: selectedPeriod) {
                calculateStats()
            }
            .onChange(of: allMeals.count) { _, _ in
                calculateStats()
            }
            .onAppear {
                // Recalculate on appear to catch background enrichment updates
                calculateStats()
            }
            .refreshable {
                // Allow pull-to-refresh
                calculateStats()
            }
        }
    }

    private func calculateStats() {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: endDate) else {
            return
        }

        // Filter meals in period
        let mealsInPeriod = allMeals.filter { meal in
            meal.timestamp >= startDate && meal.timestamp <= endDate
        }

        guard !mealsInPeriod.isEmpty else {
            statsData = StatsData(
                mealCount: 0,
                dailyData: [],
                avgCalories: 0,
                avgProtein: 0,
                avgCarbs: 0,
                avgFat: 0,
                streak: 0,
                proteinGoalDays: 0,
                micronutrientData: nil
            )
            return
        }

        // Group by day and calculate daily totals
        var dailyMeals: [Date: [Meal]] = [:]
        for meal in mealsInPeriod {
            let day = calendar.startOfDay(for: meal.timestamp)
            dailyMeals[day, default: []].append(meal)
        }

        // Create daily data points
        var dailyData: [DailyNutrition] = []
        var currentDate = startDate
        while currentDate <= endDate {
            let meals = dailyMeals[currentDate] ?? []
            let totals = Meal.calculateTotals(for: meals)

            dailyData.append(DailyNutrition(
                date: currentDate,
                calories: totals.calories,
                protein: totals.protein,
                carbs: totals.carbs,
                fat: totals.fat
            ))

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        // Calculate averages (only for days with meals)
        let daysWithMeals = dailyData.filter { $0.calories > 0 }
        let avgCalories = daysWithMeals.isEmpty ? 0 : daysWithMeals.map(\.calories).reduce(0, +) / Double(daysWithMeals.count)
        let avgProtein = daysWithMeals.isEmpty ? 0 : daysWithMeals.map(\.protein).reduce(0, +) / Double(daysWithMeals.count)
        let avgCarbs = daysWithMeals.isEmpty ? 0 : daysWithMeals.map(\.carbs).reduce(0, +) / Double(daysWithMeals.count)
        let avgFat = daysWithMeals.isEmpty ? 0 : daysWithMeals.map(\.fat).reduce(0, +) / Double(daysWithMeals.count)

        // Calculate streak (consecutive days with meals)
        let streak = calculateStreak(dailyData: dailyData)

        // Count days meeting protein goal
        let proteinGoalDays = daysWithMeals.filter { $0.protein >= DailyGoals.standard.protein }.count

        // Calculate micronutrient insights
        let micronutrientInsights = calculateMicronutrientInsights(from: mealsInPeriod)

        statsData = StatsData(
            mealCount: mealsInPeriod.count,
            dailyData: dailyData,
            avgCalories: avgCalories,
            avgProtein: avgProtein,
            avgCarbs: avgCarbs,
            avgFat: avgFat,
            streak: streak,
            proteinGoalDays: proteinGoalDays,
            micronutrientData: micronutrientInsights
        )
    }

    private func calculateStreak(dailyData: [DailyNutrition]) -> Int {
        var streak = 0
        // Count backwards from today
        for day in dailyData.reversed() {
            if day.calories > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func calculateMicronutrientInsights(from meals: [Meal]) -> MicronutrientInsights? {
        // Debug logging
        print("🔬 Calculating micronutrient insights for \(meals.count) meals")

        // Filter meals with micronutrient data
        let mealsWithMicronutrients = meals.filter { $0.hasMicronutrients }

        print("   - Meals with micronutrient data: \(mealsWithMicronutrients.count)")
        print("   - Meals with ingredients: \(meals.filter { $0.ingredients != nil && !$0.ingredients!.isEmpty }.count)")

        // Debug: Check ingredient enrichment status
        for (index, meal) in meals.prefix(3).enumerated() {
            if let ingredients = meal.ingredients {
                let enrichedCount = ingredients.filter { $0.hasUSDAData }.count
                print("   - Meal \(index + 1) '\(meal.name)': \(ingredients.count) ingredients, \(enrichedCount) enriched")
            }
        }

        guard !mealsWithMicronutrients.isEmpty else {
            print("   ⚠️ No meals with micronutrient data found")
            return nil
        }

        print("   ✅ Processing \(mealsWithMicronutrients.count) meals with micronutrient data")

        // Aggregate all micronutrients across meals
        var aggregatedProfile = MicronutrientProfile()

        for meal in mealsWithMicronutrients {
            let mealNutrients = meal.micronutrients

            for nutrient in mealNutrients {
                switch nutrient.name {
                case "Calcium":
                    aggregatedProfile.calcium += nutrient.amount
                case "Iron":
                    aggregatedProfile.iron += nutrient.amount
                case "Magnesium":
                    aggregatedProfile.magnesium += nutrient.amount
                case "Potassium":
                    aggregatedProfile.potassium += nutrient.amount
                case "Zinc":
                    aggregatedProfile.zinc += nutrient.amount
                case "Vitamin A":
                    aggregatedProfile.vitaminA += nutrient.amount
                case "Vitamin C":
                    aggregatedProfile.vitaminC += nutrient.amount
                case "Vitamin D":
                    aggregatedProfile.vitaminD += nutrient.amount
                case "Vitamin E":
                    aggregatedProfile.vitaminE += nutrient.amount
                case "Vitamin B12":
                    aggregatedProfile.vitaminB12 += nutrient.amount
                case "Folate":
                    aggregatedProfile.folate += nutrient.amount
                case "Sodium":
                    aggregatedProfile.sodium += nutrient.amount
                default:
                    break
                }
            }
        }

        // Calculate averages
        let mealCount = Double(mealsWithMicronutrients.count)
        aggregatedProfile.calcium /= mealCount
        aggregatedProfile.iron /= mealCount
        aggregatedProfile.magnesium /= mealCount
        aggregatedProfile.potassium /= mealCount
        aggregatedProfile.zinc /= mealCount
        aggregatedProfile.vitaminA /= mealCount
        aggregatedProfile.vitaminC /= mealCount
        aggregatedProfile.vitaminD /= mealCount
        aggregatedProfile.vitaminE /= mealCount
        aggregatedProfile.vitaminB12 /= mealCount
        aggregatedProfile.folate /= mealCount
        aggregatedProfile.sodium /= mealCount

        // Convert to micronutrients array
        let avgMicronutrients = aggregatedProfile.toMicronutrients()
            .filter { $0.amount > 0.01 }  // Only non-zero
            .sorted { $0.rdaPercent > $1.rdaPercent }  // Sort by RDA % descending

        // Calculate overall score (average RDA%, weighted by importance)
        let criticalNutrients = ["Vitamin D", "Iron", "Calcium", "Vitamin B12"]
        var weightedSum = 0.0
        var weightTotal = 0.0

        for nutrient in avgMicronutrients {
            let weight = criticalNutrients.contains(nutrient.name) ? 2.0 : 1.0
            weightedSum += min(nutrient.rdaPercent, 100) * weight
            weightTotal += weight
        }

        let overallScore = weightTotal > 0 ? Int(weightedSum / weightTotal) : 0

        // Identify deficiencies (< 50% RDA)
        let deficiencies = avgMicronutrients.filter { $0.rdaPercent < 50 }

        // Identify top performers (>= 80% RDA)
        let topPerformers = avgMicronutrients.filter { $0.rdaPercent >= 80 }

        // Generate smart tip
        let smartTip = generateSmartTip(deficiencies: deficiencies, topPerformers: topPerformers, score: overallScore)

        // Calculate coverage
        let coveragePercent = (Double(mealsWithMicronutrients.count) / Double(meals.count)) * 100

        return MicronutrientInsights(
            averageMicronutrients: avgMicronutrients,
            mealsWithData: mealsWithMicronutrients.count,
            totalMeals: meals.count,
            coveragePercent: coveragePercent,
            overallScore: overallScore,
            deficiencies: deficiencies,
            topPerformers: topPerformers,
            smartTip: smartTip
        )
    }

    private func generateSmartTip(deficiencies: [Micronutrient], topPerformers: [Micronutrient], score: Int) -> String? {
        // No tip if excellent score
        if score >= 90 {
            return "Excellent nutrient balance! Keep it up 🌟"
        }

        // Identify common deficiency patterns
        let deficientNames = deficiencies.prefix(3).map { $0.name }

        if deficientNames.contains("Vitamin D") && deficientNames.contains("Calcium") {
            return "Add dairy, fortified plant milk, or eggs for Vitamin D & Calcium"
        } else if deficientNames.contains("Vitamin D") {
            return "Try eggs, fatty fish, or fortified foods for Vitamin D"
        } else if deficientNames.contains("Iron") && deficientNames.contains("Vitamin C") {
            return "Pair iron-rich foods with Vitamin C for better absorption"
        } else if deficientNames.contains("Iron") {
            return "Add red meat, beans, or spinach for more iron"
        } else if deficiencies.count >= 4 {
            return "Consider adding a daily multivitamin to fill nutrient gaps"
        } else if !deficiencies.isEmpty {
            return "Focus on getting more \(deficiencies.first!.name.lowercased())-rich foods"
        } else {
            return "Great nutrient diversity! All key nutrients on track 👍"
        }
    }
}

// MARK: - Data Models

struct StatsData {
    let mealCount: Int
    let dailyData: [DailyNutrition]
    let avgCalories: Double
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double
    let streak: Int
    let proteinGoalDays: Int
    let micronutrientData: MicronutrientInsights?
}

struct MicronutrientInsights {
    let averageMicronutrients: [Micronutrient]
    let mealsWithData: Int
    let totalMeals: Int
    let coveragePercent: Double
    let overallScore: Int
    let deficiencies: [Micronutrient]
    let topPerformers: [Micronutrient]
    let smartTip: String?
}

struct DailyNutrition: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

// MARK: - Components

struct CalorieTrendCard: View {
    let stats: StatsData
    let period: TimePeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calorie Trend")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            // Average calories
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(stats.avgCalories))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("avg/day")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Chart
            Chart {
                // Goal line
                RuleMark(y: .value("Goal", DailyGoals.standard.calories))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.secondary.opacity(0.5))

                // Calorie line with gradient fill
                ForEach(stats.dailyData) { day in
                    LineMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Calories", day.calories)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Calories", day.calories)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .cyan.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: 0...max(DailyGoals.standard.calories * 1.2, stats.dailyData.map(\.calories).max() ?? 2000))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 200)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct MacroDistributionCard: View {
    let stats: StatsData

    private var macroData: [(name: String, value: Double, color: Color)] {
        [
            ("Protein", stats.avgProtein, .blue),
            ("Carbs", stats.avgCarbs, .orange),
            ("Fat", stats.avgFat, .green)
        ]
    }

    private var totalMacros: Double {
        stats.avgProtein + stats.avgCarbs + stats.avgFat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Average Macro Balance")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 24) {
                // Donut chart
                Chart {
                    ForEach(macroData, id: \.name) { macro in
                        SectorMark(
                            angle: .value("Grams", macro.value),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(macro.color)
                    }
                }
                .frame(width: 120, height: 120)

                // Legend with values
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(macroData, id: \.name) { macro in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(macro.color)
                                .frame(width: 12, height: 12)

                            Text(macro.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(macro.value))g")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)

                                Text("\(Int((macro.value / totalMacros) * 100))%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct QuickStatsGrid: View {
    let stats: StatsData

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    icon: "fork.knife",
                    value: "\(stats.mealCount)",
                    label: "Meals Logged"
                )

                StatCard(
                    icon: "flame.fill",
                    value: "\(Int(stats.avgCalories))",
                    label: "Avg Calories"
                )
            }

            HStack(spacing: 12) {
                StatCard(
                    icon: "calendar",
                    value: "\(stats.streak)",
                    label: stats.streak == 1 ? "Day Streak" : "Day Streak",
                    emoji: stats.streak > 0 ? "🔥" : nil
                )

                StatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(stats.proteinGoalDays)",
                    label: "Protein Goals",
                    emoji: stats.proteinGoalDays > 3 ? "💪" : nil
                )
            }
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    var emoji: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 18))
                }
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }
}

struct MicronutrientInsightsCard: View {
    let insights: MicronutrientInsights

    private var scoreColor: Color {
        switch insights.overallScore {
        case 0..<40:
            return .red
        case 40..<70:
            return .orange
        case 70..<90:
            return .green
        default:
            return .blue
        }
    }

    private var scoreGradient: LinearGradient {
        switch insights.overallScore {
        case 0..<40:
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        case 40..<70:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case 70..<90:
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var scoreLabel: String {
        switch insights.overallScore {
        case 0..<40:
            return "Needs Work"
        case 40..<70:
            return "Fair"
        case 70..<90:
            return "Good"
        default:
            return "Excellent"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Micronutrient Health")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            // Overall score
            HStack(spacing: 16) {
                // Circular score indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(insights.overallScore) / 100.0)
                        .stroke(scoreGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    Text("\(insights.overallScore)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall Score")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    Text(scoreLabel)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(scoreColor)
                }

                Spacer()
            }

            // Deficiencies section
            if !insights.deficiencies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Need Attention")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.orange)

                    ForEach(insights.deficiencies.prefix(3)) { nutrient in
                        MicronutrientMiniRow(nutrient: nutrient, showWarning: true)
                    }
                }
            }

            // Top performers section
            if !insights.topPerformers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Doing Great")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.green)

                    ForEach(insights.topPerformers.prefix(3)) { nutrient in
                        MicronutrientMiniRow(nutrient: nutrient, showCheckmark: true)
                    }
                }
            }

            // Smart tip
            if let tip = insights.smartTip {
                HStack(alignment: .top, spacing: 8) {
                    Text("💡")
                        .font(.system(size: 16))

                    Text(tip)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }

            // Coverage indicator (if partial)
            if insights.coveragePercent < 100 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("\(Int(insights.coveragePercent))% of meals tracked")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct MicronutrientEmptyStateCard: View {
    let totalMeals: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Micronutrient Health")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("No micronutrient data yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Micronutrients are automatically tracked when meals are logged with photos. The AI identifies ingredients and matches them to USDA nutrition data.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                if totalMeals > 0 {
                    Text("💡 Try logging meals with the camera for detailed micronutrient insights")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct MicronutrientMiniRow: View {
    let nutrient: Micronutrient
    let showWarning: Bool
    let showCheckmark: Bool

    init(nutrient: Micronutrient, showWarning: Bool = false, showCheckmark: Bool = false) {
        self.nutrient = nutrient
        self.showWarning = showWarning
        self.showCheckmark = showCheckmark
    }

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            if showWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
            } else if showCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
            }

            // Name
            Text(nutrient.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 90, alignment: .leading)

            // Percentage
            Text("\(Int(nutrient.rdaPercent))%")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(nutrient.rdaColor.color)
                .frame(width: 40)

            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(nutrient.rdaColor.color)
                        .frame(
                            width: min(geometry.size.width * CGFloat(nutrient.rdaPercent / 100.0), geometry.size.width),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }
}

struct EmptyStatsView: View {
    let mealCount: Int

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text(mealCount == 0 ? "No meals logged yet" : "Keep logging meals!")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            Text(mealCount == 0 ? "Start tracking your nutrition to see insights here" : "Log at least 3 meals to unlock stats and trends")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    StatsView()
        .modelContainer(PreviewContainer().container)
}
