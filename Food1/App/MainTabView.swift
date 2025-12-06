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
    @State private var showingAddMeal = false
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]

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
        let goals = DailyGoals.standard

        guard goals.calories > 0 else { return nil }
        return totals.calories / goals.calories
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
                showingAddMeal: $showingAddMeal,
                calorieProgress: todayCalorieProgress,
                hasLoggedMeals: hasLoggedMealsToday
            )
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .fullScreenCover(isPresented: $showingAddMeal) {
            QuickAddMealView(selectedDate: Date())
        }
    }
}

#Preview {
    MainTabView()
}