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
    @Binding var showingAddMeal: Bool

    private let pillSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    private let navigationPillWidth: CGFloat = 280

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()

                HStack(spacing: 0) {
                    Spacer()

                    HStack(spacing: pillSpacing) {
                        // Main navigation pill (3 buttons)
                        NavigationPill(selectedTab: $selectedTab)
                            .frame(width: navigationPillWidth)

                        // Standalone add button
                        FloatingAddButton(showingAddMeal: $showingAddMeal)
                    }

                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding(safeAreaBottom: geometry.safeAreaInsets.bottom))
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
            showingAddMeal: .constant(false)
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
            showingAddMeal: .constant(false)
        )
    }
    .preferredColorScheme(.dark)
}
