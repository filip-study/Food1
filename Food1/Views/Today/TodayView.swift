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
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]

    @State private var showingQuickCamera = false
    @State private var showingManualEntry = false
    @State private var showingSettings = false
    @State private var selectedDate = Date()
    @State private var dragOffset: CGFloat = 0

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
                        // Macro-focused dashboard
                        MetricsDashboardView(
                            currentCalories: totals.calories,
                            currentProtein: totals.protein,
                            currentCarbs: totals.carbs,
                            currentFat: totals.fat,
                            goals: .standard
                        )
                        .padding(.top, 20)

                        // Daily insight
                        InsightCard(
                            icon: "flame.fill",
                            title: "Great progress!",
                            message: "You've hit your protein goal 5 days this week.",
                            accentColor: .orange,
                            onTap: { }
                        )

                        // Meal timeline section
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                DateNavigationHeader(selectedDate: $selectedDate)

                                Spacer()

                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary)
                                }
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
                QuickAddMealView(selectedDate: selectedDate)
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
    return TodayView()
        .modelContainer(preview.container)
}
