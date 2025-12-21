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

    // Manual goals override
    @AppStorage("useAutoGoals") private var useAutoGoals: Bool = true
    @AppStorage("manualCalorieGoal") private var manualCalories: Double = 2000
    @AppStorage("manualProteinGoal") private var manualProtein: Double = 150
    @AppStorage("manualCarbsGoal") private var manualCarbs: Double = 225
    @AppStorage("manualFatGoal") private var manualFat: Double = 65
    @AppStorage("manualFiberGoal") private var manualFiber: Double = 28

    @State private var showingQuickCamera = false
    @State private var showingManualEntry = false
    @State private var showingSettings = false
    @Binding var selectedDate: Date  // Shared with MainTabView for FAB date sync
    @State private var dragOffset: CGFloat = 0

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
            activityLevel: userActivityLevel
        )
    }

    /// User's first name extracted from profile (for personalized greeting)
    private var userFirstName: String? {
        guard let fullName = authViewModel.profile?.fullName, !fullName.isEmpty else {
            return nil
        }
        // Extract first name (first word before space)
        return fullName.components(separatedBy: " ").first
    }

    /// Time-based greeting with optional personalization
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String

        switch hour {
        case 5..<12:
            timeGreeting = "Good morning"
        case 12..<17:
            timeGreeting = "Good afternoon"
        case 17..<22:
            timeGreeting = "Good evening"
        default:
            timeGreeting = "Hello"
        }

        if let name = userFirstName {
            return "\(timeGreeting), \(name)"
        } else {
            return timeGreeting
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

    private var emptyStateContent: (emoji: String, title: String, subtitle: String) {
        let hour = Calendar.current.component(.hour, from: selectedDate)
        switch hour {
        case 5..<11:
            return ("☕", "Good morning!", "Start your day by logging breakfast")
        case 11..<16:
            return ("🥗", "Lunchtime fuel", "Keep your nutrition streak going")
        case 16..<21:
            return ("🍽️", "Dinner awaits", "Log your evening meal")
        default:
            return ("🌙", "Late night snack?", "Every meal counts")
        }
    }


    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background layer
                LinearGradient(
                    colors: colorScheme == .light
                        ? [Color.white, Color.blue.opacity(0.15)]
                        : [Color.black, Color.blue.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Personalized greeting
                        HStack {
                            Text(greetingText)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)

                        // Macro-focused dashboard with personalized goals
                        MetricsDashboardView(
                            currentCalories: totals.calories,
                            currentProtein: totals.protein,
                            currentCarbs: totals.carbs,
                            currentFat: totals.fat,
                            goals: personalizedGoals
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
                                // Empty state with time-based content
                                EmptyStateView(content: emptyStateContent)
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
                }
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
                                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
                            } else if value.translation.width < -threshold {
                                // Swipe left - next day (only if not future)
                                let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
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
            }
        }
    }

// MARK: - Empty State Component
struct EmptyStateView: View {
    let content: (emoji: String, title: String, subtitle: String)

    var body: some View {
        VStack(spacing: 24) {
            // Emoji with blue circle background
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 120, height: 120)

                Text(content.emoji)
                    .font(.system(size: 64))
            }

            VStack(spacing: 10) {
                Text(content.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text(content.subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // CTA text
                Text("Tap + to add your first meal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    let preview = PreviewContainer()
    return TodayView(selectedDate: .constant(Date()))
        .modelContainer(preview.container)
        .environmentObject(AuthViewModel())
}
