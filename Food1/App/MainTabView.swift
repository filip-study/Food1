//
//  MainTabView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
                .tag(1)

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.purple) // Tab bar accent color
        .preferredColorScheme(selectedTheme.colorScheme)
    }
}

#Preview {
    MainTabView()
}
