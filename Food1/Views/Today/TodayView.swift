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
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Metrics dashboard
                        MetricsDashboardView(
                            currentCalories: totals.calories,
                            currentProtein: totals.protein,
                            currentCarbs: totals.carbs,
                            currentFat: totals.fat,
                            goals: .standard
                        )

                        // Meal timeline section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(isViewingToday ? "Today's Meals" : "Meals")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text("\(mealsForSelectedDate.count) meals")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
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
                        .padding(.bottom, 80) // Space for FAB
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

                // Quick add button (FAB)
                Button(action: {
                    showingAddMeal = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .purple.opacity(0.4), radius: 12, x: 0, y: 6)
                        )
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
                .symbolEffect(.bounce, value: showingAddMeal)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DateNavigationHeader(selectedDate: $selectedDate)
                }

                ToolbarItem(placement: .primaryAction) {
                    if !isViewingToday {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedDate = Date()
                            }
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.purple)
                                .symbolEffect(.bounce, value: isViewingToday)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                AddMealTabView(selectedDate: selectedDate)
            }
        }
    }
}

#Preview {
    let preview = PreviewContainer()
    return TodayView()
        .modelContainer(preview.container)
}
