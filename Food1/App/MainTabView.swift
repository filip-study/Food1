//
//  MainTabView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingAddMeal = false
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main TabView with invisible spacer for FAB
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem {
                        Label("Today", systemImage: "sun.max.fill")
                    }
                    .tag(0)

                // Invisible spacer tab for FAB
                Color.clear
                    .tabItem {
                        Text("")
                    }
                    .tag(1)
                    .disabled(true)

                StatsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(2)
            }
            .tint(.blue)
            .preferredColorScheme(selectedTheme.colorScheme)

            // Custom raised FAB
            AddMealFAB(showingAddMeal: $showingAddMeal)
                .offset(y: -28)
        }
        .fullScreenCover(isPresented: $showingAddMeal) {
            QuickAddMealView(selectedDate: Date())
        }
    }
}

// MARK: - Add Meal FAB Component
struct AddMealFAB: View {
    @Binding var showingAddMeal: Bool
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            HapticManager.medium()
            showingAddMeal = true
        } label: {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        ColorPalette.accentPrimary,
                        ColorPalette.accentSecondary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .opacity(colorScheme == .dark ? 0.9 : 1.0)

                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 4)
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
        .accessibilityLabel("Add meal")
    }
}

#Preview {
    MainTabView()
}
