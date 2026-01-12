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

// MARK: - Components are now extracted to separate files:
// - FiberSection.swift
// - MicronutrientsSection.swift (includes NutrientRDA, NutrientRDARow)
// - PeriodTabSelector.swift
// - BlurredTrendPreview.swift (includes SampleChartPoint)

#Preview {
    StatsView()
        .modelContainer(PreviewContainer().container)
}
