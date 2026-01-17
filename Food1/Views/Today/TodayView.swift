//
//  TodayView.swift
//  Food1
//
//  Daily meal log with swipe navigation and metrics dashboard.
//
//  WHY THIS ARCHITECTURE:
//  - Settings in toolbar (leading gear icon) instead of separate tab reduces navigation complexity
//  - Swipe gestures (left/right) enable quick date navigation without opening calendar
//  - Gradient background (white→blue 0.05 light, black→blue 0.08 dark) provides premium visual depth
//  - @Query with filter pattern enables efficient SwiftData lookups without manual refresh
//  - Time-based empty states (morning/afternoon/evening/night) provide contextual encouragement
//

import SwiftUI
import SwiftData
import Combine

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]
    @Query(sort: \Fast.confirmedAt, order: .reverse) private var allFasts: [Fast]
    @Query(filter: #Predicate<Fast> { $0.isActive == true }) private var activeFasts: [Fast]

    /// Currently active fast (nil if not fasting)
    private var activeFast: Fast? { activeFasts.first }

    /// Whether user is currently fasting
    private var isFasting: Bool { activeFast != nil }

    /// Check if demo mode is active for fasting timer acceleration
    private var isDemoMode: Bool {
        #if DEBUG
        return DemoModeManager.shared.isActive
        #else
        return false
        #endif
    }

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
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system
    @AppStorage("manualCalorieGoal") private var manualCalories: Double = 2000
    @AppStorage("manualProteinGoal") private var manualProtein: Double = 150
    @AppStorage("manualCarbsGoal") private var manualCarbs: Double = 225
    @AppStorage("manualFatGoal") private var manualFat: Double = 65
    @AppStorage("manualFiberGoal") private var manualFiber: Double = 28

    @State private var showingQuickCamera = false
    @State private var showingManualEntry = false
    @State private var showingSettings = false
    @Binding var selectedDate: Date  // Shared with MainTabView for FAB date sync
    @Binding var showStreakTooltip: Bool  // Controlled by MainTabView for blur coordination
    var onShowFastingSheet: () -> Void  // Triggers fasting sheet in MainTabView (unified with FAB, shows recommendation)
    @State private var dragOffset: CGFloat = 0
    @State private var shimmerPhase: CGFloat = -100  // For greeting shimmer (starts off-screen left)
    @State private var celebrateStreak = false  // Triggers streak flame animation
    @State private var lastKnownMealCount = 0   // For detecting new meals

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

    /// User's first name extracted from profile (for personalized greeting)
    /// Falls back to demo name when in demo mode (for marketing screenshots)
    private var userFirstName: String? {
        // First try real profile name
        if let fullName = authViewModel.profile?.fullName, !fullName.isEmpty {
            // Extract first name (first word before space)
            return fullName.components(separatedBy: " ").first
        }

        // Fallback to demo name (stored in UserDefaults when demo mode is active)
        // This allows marketing screenshots to show a personalized greeting
        if let demoName = UserDefaults.standard.string(forKey: "demoUserName"), !demoName.isEmpty {
            return demoName
        }

        return nil
    }

    /// Time-based greeting (subtitle below name)
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    private var mealsForSelectedDate: [Meal] {
        allMeals.filter { meal in
            Calendar.current.isDate(meal.timestamp, inSameDayAs: selectedDate)
        }
    }

    private var totals: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        Meal.calculateTotals(for: mealsForSelectedDate)
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// Most recent meal across all days (for fasting timer)
    private var mostRecentMealDate: Date? {
        allMeals.first?.timestamp  // Already sorted by timestamp descending
    }

    /// Fasts confirmed on the selected date (only completed fasts, not active ones)
    private var fastsForSelectedDate: [Fast] {
        allFasts.filter { fast in
            // Exclude active fasts - they show in FastingHeroView, not timeline
            !fast.isActive &&
            Calendar.current.isDate(fast.confirmedAt, inSameDayAs: selectedDate)
        }
    }

    // MARK: - Streak Calculation

    /// Current consecutive days with meals (counting backward from today/yesterday)
    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if today has meals
        let todayHasMeals = allMeals.contains {
            calendar.isDate($0.timestamp, inSameDayAs: checkDate)
        }

        // If no meals today yet, start counting from yesterday
        if !todayHasMeals {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        // Count consecutive days backward
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

        // Get unique dates with meals, sorted ascending
        let datesWithMeals = Set(allMeals.map { calendar.startOfDay(for: $0.timestamp) })
            .sorted()

        guard !datesWithMeals.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<datesWithMeals.count {
            let prevDate = datesWithMeals[i - 1]
            let currDate = datesWithMeals[i]

            // Check if consecutive (exactly 1 day apart)
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

    /// Dynamic daily insight based on nutrition progress
    // private var currentInsight: (icon: String, title: String, message: String, color: Color)? {
    //     guard !mealsForSelectedDate.isEmpty else { return nil }
    //
    //     let t = totals
    //     let g = personalizedGoals
    //
    //     // 1. Protein Goal Hit (Positive reinforcement)
    //     if t.protein >= g.protein {
    //         return ("trophy.fill", "Protein Goal Crushed", "You've hit your protein target for today. Great work!", .blue)
    //     }
    //
    //     // 2. Calorie Warning (Gentle nudge)
    //     if t.calories > g.calories * 1.1 {
    //          return ("exclamationmark.triangle.fill", "Calorie Target", "You're slightly over your calorie goal for today.", .orange)
    //     }
    //
    //     // 3. Protein Focus (If low on protein but high on calories)
    //     if t.calories > g.calories * 0.7 && t.protein < g.protein * 0.5 {
    //          return ("chart.bar.fill", "Prioritize Protein", "Try adding a high-protein source to your next meal.", .purple)
    //     }
    //
    //     // 4. Good Start (Morning/Early)
    //     if t.calories < g.calories * 0.3 && t.protein > g.protein * 0.2 {
    //          return ("sunrise.fill", "Strong Start", "You're on track with a balanced start to the day.", .green)
    //     }
    //
    //     return nil
    // }

    // MARK: - Fast Management

    /// Deletes a fast from the database
    private func deleteFast(_ fast: Fast) {
        modelContext.delete(fast)
        HapticManager.light()
    }

    /// Logs a retroactive (untracked) fast between two dates
    /// Called when user taps "Log it" on untracked fast suggestion card
    private func logUntrackedFast(startTime: Date, endTime: Date) {
        let fast = Fast(
            startTime: startTime,
            confirmedAt: endTime,  // Use endTime so it sorts correctly in timeline
            isActive: false,  // Already completed
            endTime: endTime
        )
        modelContext.insert(fast)
        HapticManager.success()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated mesh gradient background (iOS 18+, falls back to static)
                AdaptiveAnimatedBackground()

                ScrollView {
                    VStack(spacing: 32) {
                        // Personalized greeting header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Time greeting with sweeping shimmer effect
                                Text(timeGreeting)
                                    .font(.custom("InstrumentSerif-Regular", size: 26))
                                    .foregroundStyle(.secondary)
                                    .overlay {
                                        // Shimmer highlight that sweeps left to right
                                        GeometryReader { geo in
                                            Rectangle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            .clear,
                                                            .white.opacity(0.5),
                                                            .clear
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: 60)
                                                .offset(x: shimmerPhase)
                                                .blur(radius: 4)
                                        }
                                        .mask(
                                            Text(timeGreeting)
                                                .font(.custom("InstrumentSerif-Regular", size: 26))
                                        )
                                    }
                                    .task {
                                        // Wait for user's eyes to settle on the interface
                                        try? await Task.sleep(for: .milliseconds(3200))
                                        // Gentle sweep from left to right (zen pace)
                                        shimmerPhase = -60
                                        withAnimation(.easeInOut(duration: 4.2)) {
                                            shimmerPhase = 200
                                        }
                                    }

                                if let name = userFirstName {
                                    // Name in Manrope Bold (primary brand font)
                                    Text(name)
                                        .font(DesignSystem.Typography.bold(size: 26))
                                        .foregroundStyle(.primary)
                                }
                            }

                            Spacer()

                            // Streak indicator (hidden when streak is 0)
                            if currentStreak >= 1 {
                                StreakIndicator(
                                    currentStreak: currentStreak,
                                    longestStreak: longestStreak,
                                    totalMealsLogged: allMeals.count,
                                    celebrate: celebrateStreak,
                                    isShowingTooltip: $showStreakTooltip
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .onAppear {
                            // Initialize meal count tracking
                            lastKnownMealCount = mealsForSelectedDate.count
                        }
                        .onChange(of: mealsForSelectedDate.count) { oldCount, newCount in
                            // Celebrate when a new meal is added today
                            if newCount > oldCount && isViewingToday {
                                celebrateStreak = true
                                // Reset after animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    celebrateStreak = false
                                }
                            }
                        }

                        // Hero section: Fasting Hero or Metrics Dashboard
                        // Shows FastingHeroView when actively fasting and viewing today
                        // Otherwise shows MetricsDashboardView with progress or compact goals
                        if isFasting && isViewingToday, let fast = activeFast {
                            FastingHeroView(fast: fast, demoMode: isDemoMode)
                        } else {
                            MetricsDashboardView(
                                currentCalories: totals.calories,
                                currentProtein: totals.protein,
                                currentCarbs: totals.carbs,
                                currentFat: totals.fat,
                                goals: personalizedGoals,
                                showCompactGoals: mealsForSelectedDate.isEmpty && isViewingToday && !isFasting
                            )
                        }

                        // Daily insight - disabled pending redesign
                        // TODO: Redesign with meaningful, data-driven insights
                        // if let insight = currentInsight {
                        //     InsightCard(
                        //         icon: insight.icon,
                        //         title: insight.title,
                        //         message: insight.message,
                        //         accentColor: insight.color
                        //     )
                        // }

                        // Meal timeline section
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                DateNavigationHeader(selectedDate: $selectedDate)

                                Spacer()

                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityLabel("Settings")
                                .frame(width: 44, height: 44)  // Larger tap target
                            }
                            .padding(.horizontal)

                            if mealsForSelectedDate.isEmpty && fastsForSelectedDate.isEmpty && !isFasting {
                                // Only show fasting prompt for today, not historical dates
                                if Calendar.current.isDateInToday(selectedDate) {
                                    FastingPromptView(
                                        lastMealDate: mostRecentMealDate,
                                        onConfirmFast: {
                                            // Trigger fasting sheet in MainTabView (unified with FAB)
                                            onShowFastingSheet()
                                        }
                                    )
                                } else {
                                    // Historical day with no meals - show simple empty state
                                    EmptyDayView(date: selectedDate)
                                }
                            } else {
                                // Timeline with meals and fasts
                                MealFastTimeline(
                                    meals: mealsForSelectedDate,
                                    fasts: fastsForSelectedDate,
                                    allFasts: allFasts,
                                    reduceMotion: reduceMotion,
                                    onDeleteFast: deleteFast,
                                    onLogUntrackedFast: logUntrackedFast
                                )
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)  // Clearance for tab bar + FAB
                }
                .scrollIndicators(.hidden)

            }
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow horizontal drag
                        if abs(value.translation.width) > abs(value.translation.height) {
                            dragOffset = value.translation.width * 0.3 // Reduce movement for better feel
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if value.translation.width > threshold {
                                // Swipe right - previous day
                                HapticManager.light()
                                selectedDate = selectedDate.addingDays(-1)
                            } else if value.translation.width < -threshold {
                                // Swipe left - next day (only if not future)
                                let nextDay = selectedDate.addingDays(1)
                                if nextDay <= Date() {
                                    HapticManager.light()
                                    selectedDate = nextDay
                                }
                            }
                            dragOffset = 0
                        }
                    }
            )
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingQuickCamera) {
                QuickAddMealView(selectedDate: selectedDate, initialEntryMode: .camera)
            }
            .sheet(isPresented: $showingManualEntry) {
                TextEntryView(selectedDate: selectedDate, onMealCreated: {
                    showingManualEntry = false
                })
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .preferredColorScheme(selectedTheme.resolvedColorScheme)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showStreakTooltip)
        }
    }
}

// MARK: - Fasting Prompt View

/// Prompt shown in the meal timeline when no meals logged today.
/// Shows time since last meal and option to start a fast.
/// Design: Inset/embedded appearance - recessed into background rather than floating.
struct FastingPromptView: View {
    let lastMealDate: Date?
    let onConfirmFast: () -> Void

    @State private var currentTime = Date()
    @Environment(\.colorScheme) var colorScheme

    // Update timer every minute
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// Hours since last meal (for display)
    private var hoursSinceLastMeal: Int? {
        guard let lastMeal = lastMealDate else { return nil }
        return Int(currentTime.timeIntervalSince(lastMeal)) / 3600
    }

    /// Minutes component
    private var minutesSinceLastMeal: Int? {
        guard let lastMeal = lastMealDate else { return nil }
        return (Int(currentTime.timeIntervalSince(lastMeal)) % 3600) / 60
    }

    /// Only show fasting UI after 12 hours
    private var shouldShowFastingPrompt: Bool {
        guard let hours = hoursSinceLastMeal else { return false }
        return hours >= 12
    }

    /// Formatted time string (e.g., "14h 32m" or "1d 2h")
    private var formattedDuration: String {
        guard let hours = hoursSinceLastMeal, let minutes = minutesSinceLastMeal else { return "" }
        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    var body: some View {
        if shouldShowFastingPrompt {
            VStack(spacing: 14) {
                // Duration + context
                HStack(spacing: 6) {
                    Text(formattedDuration)
                        .font(DesignSystem.Typography.medium(size: 15))
                        .foregroundStyle(.secondary)

                    Text("since last meal")
                        .font(DesignSystem.Typography.regular(size: 15))
                        .foregroundStyle(.tertiary)
                }

                // Start Fast button - opens unified sheet from MainTabView
                Button(action: {
                    HapticManager.light()
                    onConfirmFast()
                }) {
                    Text("Start Fast")
                        .font(DesignSystem.Typography.medium(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                // Inset effect: slightly darker fill + inner shadow
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        colorScheme == .dark
                            ? Color.black.opacity(0.2)
                            : Color.black.opacity(0.03)
                    )
            )
            .overlay(
                // Inner shadow: blurred dark stroke masked to inside
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), lineWidth: 3)
                    .blur(radius: 3)
                    .offset(y: 1)
                    .mask(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                    )
            )
            .overlay(
                // Subtle outer stroke for definition
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal)
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .onAppear {
                currentTime = Date()
            }
        } else if lastMealDate == nil {
            // No previous meals at all
            Text("No meals logged yet")
                .font(DesignSystem.Typography.regular(size: 14))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.2)
                                : Color.black.opacity(0.03)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), lineWidth: 3)
                        .blur(radius: 3)
                        .offset(y: 1)
                        .mask(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                        )
                )
                .padding(.horizontal)
        }
        // else: Last meal exists but < 12 hours ago - show nothing
    }
}

// MARK: - Empty Day View (Historical)

/// Simple empty state for historical days with no meals.
/// Unlike FastingPromptView, this doesn't show fasting prompts for past dates.
struct EmptyDayView: View {
    let date: Date
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Text("No meals logged")
                .font(DesignSystem.Typography.medium(size: 15))
                .foregroundStyle(.secondary)

            Text(formattedDate)
                .font(DesignSystem.Typography.regular(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark
                        ? Color.black.opacity(0.2)
                        : Color.black.opacity(0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), lineWidth: 3)
                .blur(radius: 3)
                .offset(y: 1)
                .mask(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                )
        )
        .padding(.horizontal)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Meal & Fast Timeline

/// Unified timeline displaying meals and fasts sorted by time.
/// Fasts have connecting lines, meals are standard cards.
/// Shows untracked fast suggestions for 12+ hour gaps between meals.
struct MealFastTimeline: View {
    let meals: [Meal]
    let fasts: [Fast]
    let allFasts: [Fast]  // All fasts for checking coverage across days
    let reduceMotion: Bool
    let onDeleteFast: (Fast) -> Void
    let onLogUntrackedFast: (Date, Date) -> Void  // (startTime, endTime) for retroactive fasts

    /// Minimum gap in hours to suggest logging a fast
    private let untrackedFastThresholdHours: Double = 12.0

    /// Combined timeline items sorted by timestamp (newest first)
    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []

        for meal in meals {
            items.append(.meal(meal))
        }
        for fast in fasts {
            items.append(.fast(fast))
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    /// Check if any fast covers the period between two dates
    private func isFastCoveringPeriod(from startDate: Date, to endDate: Date) -> Bool {
        allFasts.contains { fast in
            // Fast overlaps if it started before endDate and ended after startDate
            let fastEnd = fast.endTime ?? Date()
            return fast.startTime < endDate && fastEnd > startDate
        }
    }

    /// Calculate gap between current meal and next (older) item
    private func gapToNextItem(at index: Int) -> (hours: Double, previousMealDate: Date)? {
        let items = timelineItems
        guard index < items.count - 1 else { return nil }

        let currentItem = items[index]
        let nextItem = items[index + 1]

        // Only suggest for meal-to-meal gaps (not meal-to-fast)
        guard case .meal = currentItem,
              case .meal(let previousMeal) = nextItem else {
            return nil
        }

        let gap = currentItem.timestamp.timeIntervalSince(previousMeal.timestamp)
        let hours = gap / 3600.0

        return (hours: hours, previousMealDate: previousMeal.timestamp)
    }

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                switch item {
                case .meal(let meal):
                    NavigationLink(destination: MealDetailView(meal: meal)) {
                        MealCard(meal: meal)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            HapticManager.light()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: reduceMotion ? .opacity : .scale.combined(with: .opacity),
                        removal: .opacity
                    ))

                    // Show untracked fast suggestion if 12+ hour gap to previous meal
                    if let gap = gapToNextItem(at: index),
                       gap.hours >= untrackedFastThresholdHours,
                       !isFastCoveringPeriod(from: gap.previousMealDate, to: meal.timestamp) {
                        UntrackedFastSuggestionCard(
                            fastStartTime: gap.previousMealDate,
                            fastEndTime: meal.timestamp,
                            durationHours: gap.hours,
                            onLogFast: {
                                onLogUntrackedFast(gap.previousMealDate, meal.timestamp)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: reduceMotion ? .opacity : .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                case .fast(let fast):
                    // Determine if adjacent items exist for connectors
                    let hasItemAbove = index > 0
                    let hasItemBelow = index < timelineItems.count - 1

                    FastEntryView(
                        fast: fast,
                        showTopConnector: hasItemAbove,
                        showBottomConnector: hasItemBelow
                    )
                    .transition(.asymmetric(
                        insertion: reduceMotion ? .opacity : .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                    .contextMenu {
                        Button(role: .destructive) {
                            onDeleteFast(fast)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Untracked Fast Suggestion Card

/// Suggestion card shown in timeline when there's a 12+ hour gap between meals
/// with no logged fast. Allows user to retroactively log the fasting period.
struct UntrackedFastSuggestionCard: View {
    let fastStartTime: Date
    let fastEndTime: Date
    let durationHours: Double
    let onLogFast: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var formattedDuration: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)
        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Flame icon (amber to match fasting theme)
            Image(systemName: "flame.fill")
                .font(.system(size: 18))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ColorPalette.calories, Color.orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text("You fasted \(formattedDuration)")
                    .font(DesignSystem.Typography.medium(size: 14))
                    .foregroundColor(.primary)

                Text("before this meal")
                    .font(DesignSystem.Typography.regular(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Log it button
            Button(action: {
                HapticManager.medium()
                onLogFast()
            }) {
                Text("Log it")
                    .font(DesignSystem.Typography.semiBold(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ColorPalette.calories.opacity(0.9))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    ColorPalette.calories.opacity(colorScheme == .dark ? 0.2 : 0.12),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])  // Dashed border for suggestion
                )
        )
        .padding(.horizontal)
    }
}

/// Timeline item wrapper for unified sorting
private enum TimelineItem: Identifiable {
    case meal(Meal)
    case fast(Fast)

    var id: String {
        switch self {
        case .meal(let meal): return "meal-\(meal.id)"
        case .fast(let fast): return "fast-\(fast.id)"
        }
    }

    var timestamp: Date {
        switch self {
        case .meal(let meal): return meal.timestamp
        case .fast(let fast): return fast.confirmedAt
        }
    }
}

// MARK: - Empty Meals View (Legacy - kept for reference)

struct EmptyMealsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(.quaternary)

            Text("No meals yet")
                .font(DesignSystem.Typography.regular(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}

#Preview {
    let preview = PreviewContainer()
    return TodayView(
        selectedDate: .constant(Date()),
        showStreakTooltip: .constant(false),
        onShowFastingSheet: { print("Fasting sheet triggered") }
    )
    .modelContainer(preview.container)
    .environmentObject(AuthViewModel())
}
