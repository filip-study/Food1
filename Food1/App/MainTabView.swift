//
//  MainTabView.swift
//  Food1
//
//  Root navigation with two-tab structure: Meals (today's log) and Stats (analytics).
//
//  WHY THIS ARCHITECTURE:
//  - Two-tab minimal design keeps focus on core functionality (log meals, view stats)
//  - Settings accessed via TodayView toolbar (not separate tab) reduces clutter
//  - Custom MinimalTabButton provides premium UI with smooth animations
//  - AppTheme @AppStorage enables system/light/dark mode persistence
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingAddMeal = false
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content views
            Group {
                if selectedTab == 0 {
                    TodayView()
                } else {
                    StatsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Premium bottom tab bar
            VStack(spacing: 0) {
                // Top border
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 0.5)

                // Tab bar content
                HStack(spacing: 0) {
                    // Meals tab
                    MinimalTabButton(
                        icon: "fork.knife",
                        label: "Meals",
                        isSelected: selectedTab == 0
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = 0
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Center FAB - elevated above the bar
                    IntegratedAddMealFAB(showingAddMeal: $showingAddMeal)
                        .frame(width: 80)
                        .offset(y: -14)

                    // Stats tab
                    MinimalTabButton(
                        icon: "chart.bar.fill",
                        label: "Stats",
                        isSelected: selectedTab == 1
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = 1
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 49)
            }
            .background(
                Color(UIColor.systemBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .fullScreenCover(isPresented: $showingAddMeal) {
            QuickAddMealView(selectedDate: Date())
        }
    }
}

// MARK: - Minimal Tab Button
struct MinimalTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .medium : .regular))
                    .symbolRenderingMode(.monochrome)

                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
            }
            .foregroundColor(isSelected ? ColorPalette.accentPrimary : Color.secondary.opacity(0.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.08)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.08)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Integrated Add Meal FAB
struct IntegratedAddMealFAB: View {
    @Binding var showingAddMeal: Bool
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            HapticManager.medium()
            showingAddMeal = true
        } label: {
            ZStack {
                // Gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorPalette.accentPrimary,
                                ColorPalette.accentPrimary.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .shadow(
            color: ColorPalette.accentPrimary.opacity(0.25),
            radius: isPressed ? 3 : 6,
            x: 0,
            y: isPressed ? 1 : 2
        )
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("Add meal")
    }
}

#Preview {
    MainTabView()
}