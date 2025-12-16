//
//  FloatingPillNavigation.swift
//  Food1
//
//  Main navigation container with two floating pills:
//  - NavigationPill: 3-button navigation (Meals, Stats, My Health)
//  - FloatingAddButton: Standalone + button for adding meals
//
//  WHY THIS ARCHITECTURE:
//  - Dual pill design creates clear visual hierarchy
//  - Separate action button prevents accidental taps
//  - Always visible (no scroll-to-hide) for immediate access
//  - Glassmorphic design aligns with app's Liquid Glass aesthetic
//

import SwiftUI

struct FloatingPillNavigation: View {
    @Binding var selectedTab: NavigationTab
    /// Callback when user selects an entry mode from the add button menu
    var onEntryModeSelected: (MealEntryMode) -> Void
    var calorieProgress: Double? = nil  // Optional: shows progress on add button
    var hasLoggedMeals: Bool = false    // Controls ring visibility

    @State private var showingAddMenu = false  // Controls add button menu visibility

    private let pillSpacing: CGFloat = 20  // Increased from 12 for better visual separation
    private let horizontalPadding: CGFloat = 16
    private let navigationPillWidth: CGFloat = 280

    var body: some View {
        ZStack {
            // Full-screen tap catcher - dismisses menu when tapping outside
            if showingAddMenu {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingAddMenu = false
                        }
                    }
                    .ignoresSafeArea()
            }

            // Floating navigation pills
            GeometryReader { geometry in
                VStack {
                    Spacer()

                    HStack(spacing: 0) {
                        Spacer()

                        HStack(spacing: pillSpacing) {
                            // Main navigation pill (3 buttons)
                            NavigationPill(selectedTab: $selectedTab)
                                .frame(width: navigationPillWidth)

                            // Standalone add button with optional progress visualization
                            FloatingAddButton(
                                onEntryModeSelected: onEntryModeSelected,
                                calorieProgress: calorieProgress,
                                hasLoggedMeals: hasLoggedMeals,
                                visualizationStyle: .ring,  // Using Option A (ring) by default
                                selectedTab: $selectedTab,
                                showingMenu: $showingAddMenu
                            )
                        }

                        Spacer()
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding(safeAreaBottom: geometry.safeAreaInsets.bottom))
                }
            }
        }
    }

    // MARK: - Safe Area Handling
    private func bottomPadding(safeAreaBottom: CGFloat) -> CGFloat {
        // Adaptive padding based on device type
        if safeAreaBottom > 0 {
            // Devices with home indicator (iPhone X and newer)
            return 4
        } else {
            // Devices with physical home button
            return 16
        }
    }
}

#Preview("Light Mode") {
    ZStack(alignment: .bottom) {
        // Mock content
        VStack {
            Text("Content Area")
                .font(.title)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))

        // Navigation
        FloatingPillNavigation(
            selectedTab: .constant(.meals),
            onEntryModeSelected: { mode in print("Selected: \(mode)") }
        )
    }
}

#Preview("Dark Mode") {
    ZStack(alignment: .bottom) {
        // Mock content
        VStack {
            Text("Content Area")
                .font(.title)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))

        // Navigation
        FloatingPillNavigation(
            selectedTab: .constant(.stats),
            onEntryModeSelected: { mode in print("Selected: \(mode)") }
        )
    }
    .preferredColorScheme(.dark)
}
