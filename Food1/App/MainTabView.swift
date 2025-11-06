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

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
        }
        .tint(.blue) // Tab bar accent color
        .preferredColorScheme(selectedTheme.colorScheme)
    }
}

#Preview {
    MainTabView()
}
