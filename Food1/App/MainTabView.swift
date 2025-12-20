//
//  MainTabView.swift
//  Food1
//
//  Root navigation with three-tab floating pill structure: Meals, Stats, My Health.
//
//  WHY THIS ARCHITECTURE:
//  - Dual floating pill design creates clear visual hierarchy
//  - Three tabs: Meals (today's log), Stats (nutrition analytics), My Health (insights)
//  - Separate floating add button prevents accidental taps while remaining accessible
//  - Glassmorphic design aligns with app's Liquid Glass aesthetic
//  - AppTheme @AppStorage enables system/light/dark mode persistence
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: NavigationTab = .meals
    @State private var selectedEntryMode: MealEntryMode? = nil  // Triggers fullScreenCover when set
    @State private var showingPaywall = false  // Paywall gate for expired/no subscription
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]

    // Profile data for personalized goals (observed for automatic updates)
    @AppStorage("userAge") private var userAge: Int = 25
    @AppStorage("userWeight") private var userWeight: Double = 70.0
    @AppStorage("userHeight") private var userHeight: Double = 170.0
    @AppStorage("userGender") private var userGender: Gender = .preferNotToSay
    @AppStorage("userActivityLevel") private var userActivityLevel: ActivityLevel = .moderatelyActive

    // Manual goals override
    @AppStorage("useAutoGoals") private var useAutoGoals: Bool = true
    @AppStorage("manualCalorieGoal") private var manualCalories: Double = 2000
    @AppStorage("manualProteinGoal") private var manualProtein: Double = 150
    @AppStorage("manualCarbsGoal") private var manualCarbs: Double = 225
    @AppStorage("manualFatGoal") private var manualFat: Double = 65

    /// Daily goals - either auto-calculated from profile or manual override
    private var personalizedGoals: DailyGoals {
        if !useAutoGoals && manualCalories > 0 && manualProtein > 0 && manualCarbs > 0 && manualFat > 0 {
            return DailyGoals(
                calories: manualCalories,
                protein: manualProtein,
                carbs: manualCarbs,
                fat: manualFat
            )
        }
        return DailyGoals.calculate(
            gender: userGender,
            age: userAge,
            weightKg: userWeight,
            heightCm: userHeight,
            activityLevel: userActivityLevel
        )
    }

    // Calculate today's meals for floating button
    private var todayMeals: [Meal] {
        allMeals.filter { meal in
            Calendar.current.isDateInToday(meal.timestamp)
        }
    }

    // Progressive disclosure: show ring only when meals are logged
    private var hasLoggedMealsToday: Bool {
        return !todayMeals.isEmpty  // Show on ALL tabs once meals are logged
    }

    // Calculate today's calorie progress for floating button
    private var todayCalorieProgress: Double? {
        guard hasLoggedMealsToday else { return nil }    // No progress if no meals

        let totals = Meal.calculateTotals(for: todayMeals)

        guard personalizedGoals.calories > 0 else { return nil }
        return totals.calories / personalizedGoals.calories
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content views
            Group {
                switch selectedTab {
                case .meals:
                    TodayView()
                case .stats:
                    StatsView()
                case .myHealth:
                    MyHealthPlaceholderView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                // Reserve space for floating pills (60pt pill + 16pt spacing)
                Color.clear.frame(height: 76)
            }

            // Floating pill navigation with calorie progress
            FloatingPillNavigation(
                selectedTab: $selectedTab,
                onEntryModeSelected: { mode in
                    // Paywall gate: check if user has access before allowing meal entry
                    // UI testing mode bypasses paywall to allow testing without subscription
                    if authViewModel.hasAccess || UITestingSupport.shouldBypassPaywall {
                        selectedEntryMode = mode
                    } else {
                        // Show paywall instead - trial expired or no subscription
                        HapticManager.medium()
                        showingPaywall = true
                    }
                },
                calorieProgress: todayCalorieProgress,
                hasLoggedMeals: hasLoggedMealsToday
            )
        }
        .accessibilityElement(children: .contain)  // Make ZStack an accessibility container
        .accessibilityIdentifier("mainTabView")  // For E2E test detection
        .preferredColorScheme(selectedTheme.colorScheme)
        .fullScreenCover(item: $selectedEntryMode) { mode in
            QuickAddMealView(selectedDate: Date(), initialEntryMode: mode)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}