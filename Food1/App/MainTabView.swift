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
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: NavigationTab = .meals
    @State private var selectedEntryMode: MealEntryMode? = nil  // Triggers fullScreenCover when set
    @State private var showingPaywall = false  // Paywall gate for expired/no subscription
    @State private var selectedDate = Date()  // Shared date state for meal logging
    @State private var showingAddMenu = false  // Controls add button menu + blur backdrop
    @State private var showStreakTooltip = false  // Controls streak tooltip + blur backdrop
    @State private var showingFastingSheet = false  // Controls start fasting options sheet
    @State private var fastingSheetFromCard = false  // True when sheet opened from fasting prompt card (shows recommendation)
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]
    @Query(filter: #Predicate<Fast> { $0.isActive == true }) private var activeFasts: [Fast]

    /// Currently active fast (nil if not fasting)
    private var activeFast: Fast? { activeFasts.first }

    /// Whether user is currently fasting
    private var isFasting: Bool { activeFast != nil }

    /// Most recent meal (for "Start from last meal" option)
    private var mostRecentMeal: Meal? { allMeals.first }

    // Profile data for personalized goals (observed for automatic updates)
    @AppStorage("userAge") private var userAge: Int = 25
    @AppStorage("userWeight") private var userWeight: Double = 70.0
    @AppStorage("userHeight") private var userHeight: Double = 170.0
    @AppStorage("userGender") private var userGender: Gender = .preferNotToSay
    @AppStorage("userActivityLevel") private var userActivityLevel: ActivityLevel = .moderatelyActive
    @AppStorage("userGoal") private var userGoalRaw: String = ""
    @AppStorage("userDietType") private var userDietTypeRaw: String = ""

    // Manual goals override
    @AppStorage("useAutoGoals") private var useAutoGoals: Bool = true
    @AppStorage("manualCalorieGoal") private var manualCalories: Double = 2000
    @AppStorage("manualProteinGoal") private var manualProtein: Double = 150
    @AppStorage("manualCarbsGoal") private var manualCarbs: Double = 225
    @AppStorage("manualFatGoal") private var manualFat: Double = 65
    @AppStorage("manualFiberGoal") private var manualFiber: Double = 28

    /// User's nutrition goal (converted from raw string)
    private var userGoal: NutritionGoal? {
        NutritionGoal(rawValue: userGoalRaw)
    }

    /// User's diet type (converted from raw string)
    private var userDietType: DietType? {
        DietType(rawValue: userDietTypeRaw)
    }

    /// Daily goals - either auto-calculated from profile or manual override
    private var personalizedGoals: DailyGoals {
        if !useAutoGoals && manualCalories > 0 && manualProtein > 0 && manualCarbs > 0 && manualFat > 0 {
            return DailyGoals(
                calories: manualCalories,
                protein: manualProtein,
                carbs: manualCarbs,
                fat: manualFat,
                fiber: manualFiber > 0 ? manualFiber : 28.0
            )
        }
        return DailyGoals.calculate(
            gender: userGender,
            age: userAge,
            weightKg: userWeight,
            heightCm: userHeight,
            activityLevel: userActivityLevel,
            goal: userGoal,
            dietType: userDietType
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

    // MARK: - Streak Calculation (for tooltip overlay)

    /// Current consecutive days with meals (counting backward from today/yesterday)
    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        let todayHasMeals = allMeals.contains {
            calendar.isDate($0.timestamp, inSameDayAs: checkDate)
        }

        if !todayHasMeals {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        while true {
            let hasMeals = allMeals.contains {
                calendar.isDate($0.timestamp, inSameDayAs: checkDate)
            }
            if !hasMeals { break }
            streak += 1
            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }

        return streak
    }

    /// Longest consecutive streak ever achieved
    private var longestStreak: Int {
        let calendar = Calendar.current
        let datesWithMeals = Set(allMeals.map { calendar.startOfDay(for: $0.timestamp) }).sorted()
        guard !datesWithMeals.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<datesWithMeals.count {
            let prevDate = datesWithMeals[i - 1]
            let currDate = datesWithMeals[i]

            if let nextDay = calendar.date(byAdding: .day, value: 1, to: prevDate),
               calendar.isDate(nextDay, inSameDayAs: currDate) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    /// User's first name for greeting placeholder
    private var userFirstName: String? {
        guard let fullName = authViewModel.profile?.fullName, !fullName.isEmpty else {
            return nil
        }
        return fullName.components(separatedBy: " ").first
    }

    /// Time-based greeting
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content views
            Group {
                switch selectedTab {
                case .meals:
                    TodayView(
                        selectedDate: $selectedDate,
                        showStreakTooltip: $showStreakTooltip,
                        onShowFastingSheet: {
                            // Triggered from fasting prompt card - show recommendation
                            fastingSheetFromCard = true
                            showingFastingSheet = true
                        }
                    )
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

            // Blur backdrop for FAB menu only (nav bar stays above this)
            if showingAddMenu {
                Color.black.opacity(0.001)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingAddMenu = false
                        }
                    }
                    .transition(.opacity)
            }

            // Floating pill navigation (always rendered, above FAB blur)
            FloatingPillNavigation(
                selectedTab: $selectedTab,
                onEntryModeSelected: { mode in
                    // Paywall gate: check if user has access before allowing meal entry
                    // Also bypass for demo mode (DEBUG only) and UI testing
                    var shouldBypass = UITestingSupport.shouldBypassPaywall
                    #if DEBUG
                    shouldBypass = shouldBypass || DemoModeManager.shared.isActive
                    #endif

                    if authViewModel.hasAccess || shouldBypass {
                        // Handle fasting mode specially (doesn't need QuickAddMealView)
                        if mode == .fasting {
                            handleFastingAction()
                        } else {
                            selectedEntryMode = mode
                        }
                    } else {
                        HapticManager.medium()
                        showingPaywall = true
                    }
                },
                calorieProgress: todayCalorieProgress,
                hasLoggedMeals: hasLoggedMealsToday,
                isFasting: isFasting,
                showingAddMenu: $showingAddMenu
            )
        }
        // Streak tooltip overlay - covers EVERYTHING including nav bar
        .overlay {
            if showStreakTooltip && currentStreak >= 1 {
                ZStack {
                    // Full-screen blur backdrop (animates in)
                    Color.black.opacity(0.001)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showStreakTooltip = false
                            }
                        }
                        .transition(.opacity)

                    // Streak indicator - appears INSTANTLY (no animation)
                    // This prevents the "disappear/reappear" flicker
                    VStack {
                        HStack(alignment: .top) {
                            // Invisible greeting placeholder for exact positioning
                            VStack(alignment: .leading, spacing: 4) {
                                Text(timeGreeting)
                                    .font(.custom("InstrumentSerif-Regular", size: 26))
                                    .opacity(0)
                                if userFirstName != nil {
                                    Text("Name")
                                        .font(DesignSystem.Typography.bold(size: 26))
                                        .opacity(0)
                                }
                            }
                            Spacer()
                            StreakIndicator(
                                currentStreak: currentStreak,
                                longestStreak: longestStreak,
                                totalMealsLogged: allMeals.count,
                                celebrate: false,
                                isShowingTooltip: $showStreakTooltip
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                        Spacer()
                    }
                    .transaction { $0.animation = nil }  // Disable animation - appear instantly

                    // Tooltip card (animates in with scale)
                    VStack {
                        HStack {
                            Spacer()
                            StreakTooltip(
                                currentStreak: currentStreak,
                                longestStreak: longestStreak,
                                totalMealsLogged: allMeals.count,
                                onDismiss: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showStreakTooltip = false
                                    }
                                }
                            )
                            .padding(.trailing, 16)
                        }
                        Spacer()
                    }
                    .padding(.top, 72)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .topTrailing)))
                }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showingAddMenu)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showStreakTooltip)
        .accessibilityElement(children: .contain)  // Make ZStack an accessibility container
        .accessibilityIdentifier("mainTabView")  // For E2E test detection
        .preferredColorScheme(selectedTheme.colorScheme)
        .fullScreenCover(item: $selectedEntryMode) { mode in
            QuickAddMealView(selectedDate: selectedDate, initialEntryMode: mode)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingFastingSheet, onDismiss: {
            // Reset flag when sheet dismisses
            fastingSheetFromCard = false
        }) {
            StartFastingSheet(
                lastMealDate: mostRecentMeal?.timestamp,
                recommendFromLastMeal: fastingSheetFromCard,
                onStartNow: {
                    startFastNow()
                },
                onStartFromLastMeal: { mealDate in
                    startFastFromLastMeal(mealDate)
                }
            )
        }
    }

    // MARK: - Fasting Actions

    /// Handle fasting action from FAB menu
    /// If not fasting: shows sheet to choose start time
    /// If already fasting: switches to Meals tab to show fasting hero
    private func handleFastingAction() {
        if isFasting {
            // Already fasting - switch to Meals tab (hero is visible there)
            if selectedTab != .meals {
                selectedTab = .meals
            }
            // Reset to today's date to see active fasting hero
            selectedDate = Date()
            HapticManager.light()
        } else {
            // Show fasting options sheet (or start immediately if no meals)
            if mostRecentMeal != nil {
                fastingSheetFromCard = false  // FAB doesn't show recommendation
                showingFastingSheet = true
            } else {
                // No meals logged - just start now
                startFastNow()
            }
        }
    }

    /// Start a new fast from current time
    private func startFastNow() {
        let fast = Fast(
            startTime: Date(),
            confirmedAt: Date(),
            isActive: true,
            endTime: nil
        )
        modelContext.insert(fast)

        // Explicitly save to ensure persistence
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save fast: \(error)")
        }

        // Start Live Activity for lock screen
        Task {
            #if DEBUG
            await FastingActivityManager.shared.startActivity(for: fast, demoMode: DemoModeManager.shared.isActive)
            #else
            await FastingActivityManager.shared.startActivity(for: fast)
            #endif
        }

        // Switch to Meals tab to show fasting hero
        if selectedTab != .meals {
            selectedTab = .meals
        }
        selectedDate = Date()

        HapticManager.success()
    }

    /// Start a new fast from a specific time (e.g., last meal)
    private func startFastFromLastMeal(_ mealDate: Date) {
        let fast = Fast(
            startTime: mealDate,
            confirmedAt: Date(),
            isActive: true,
            endTime: nil
        )
        modelContext.insert(fast)

        // Explicitly save to ensure persistence
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save fast: \(error)")
        }

        // Start Live Activity for lock screen
        Task {
            #if DEBUG
            await FastingActivityManager.shared.startActivity(for: fast, demoMode: DemoModeManager.shared.isActive)
            #else
            await FastingActivityManager.shared.startActivity(for: fast)
            #endif
        }

        // Switch to Meals tab to show fasting hero
        if selectedTab != .meals {
            selectedTab = .meals
        }
        selectedDate = Date()

        HapticManager.success()
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}