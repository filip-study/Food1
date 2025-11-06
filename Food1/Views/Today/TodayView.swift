//
//  TodayView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]

    @State private var showingAddMeal = false
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

    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: 24) {
                        // Metrics dashboard
                        MetricsDashboardView(
                            currentCalories: totals.calories,
                            currentProtein: totals.protein,
                            currentCarbs: totals.carbs,
                            currentFat: totals.fat,
                            goals: .standard,
                            onAddMeal: { showingAddMeal = true }
                        )

                        // Meal timeline section
                        VStack(alignment: .leading, spacing: 16) {
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
                                // Empty state
                                VStack(spacing: 16) {
                                    Image(systemName: "fork.knife.circle")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.gray.opacity(0.5))

                                    Text("No meals logged yet")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    Text("Tap the + button to add your first meal")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.tertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                // Meal cards
                                LazyVStack(spacing: 12) {
                                    ForEach(mealsForSelectedDate.sorted(by: { $0.timestamp > $1.timestamp })) { meal in
                                        NavigationLink(destination: MealDetailView(meal: meal)) {
                                            MealCard(meal: meal)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                    }
                                }
                            }
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
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
                                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
                                } else if value.translation.width < -threshold {
                                    // Swipe left - next day (only if not future)
                                    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
                                    if nextDay <= Date() {
                                        selectedDate = nextDay
                                    }
                                }
                                dragOffset = 0
                            }
                        }
                )
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddMeal) {
                AddMealTabView(selectedDate: selectedDate)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    let preview = PreviewContainer()
    return TodayView()
        .modelContainer(preview.container)
}
