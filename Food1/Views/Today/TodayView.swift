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

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]

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
                                    // Name in Plus Jakarta Sans (matches prismae.net branding)
                                    Text(name)
                                        .font(.custom("PlusJakartaSans-Bold", size: 26))
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

                        // Macro-focused dashboard with personalized goals
                        // Shows compact "Today's Goals" view when no meals logged today,
                        // otherwise shows full progress dashboard
                        MetricsDashboardView(
                            currentCalories: totals.calories,
                            currentProtein: totals.protein,
                            currentCarbs: totals.carbs,
                            currentFat: totals.fat,
                            goals: personalizedGoals,
                            showCompactGoals: mealsForSelectedDate.isEmpty && isViewingToday
                        )

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

                            if mealsForSelectedDate.isEmpty {
                                // Minimal empty state
                                EmptyMealsView()
                            } else {
                                // Meal cards
                                LazyVStack(spacing: 12) {
                                    ForEach(mealsForSelectedDate.sorted(by: { $0.timestamp > $1.timestamp })) { meal in
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
                                    }
                                }
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

// MARK: - Empty Meals View

struct EmptyMealsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(.quaternary)

            Text("No meals yet")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}

#Preview {
    let preview = PreviewContainer()
    return TodayView(selectedDate: .constant(Date()), showStreakTooltip: .constant(false))
        .modelContainer(preview.container)
        .environmentObject(AuthViewModel())
}
