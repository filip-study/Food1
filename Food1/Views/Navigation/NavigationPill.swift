//
//  NavigationPill.swift
//  Food1
//
//  Glassmorphic pill containing 3 navigation buttons (Meals, Stats, My Health).
//  Uses liquid glass design with multi-layer depth, gradient borders, and premium shadows.
//  Matches iOS 26 Liquid Glass app icon aesthetic.
//

import SwiftUI

struct NavigationPill: View {
    @Binding var selectedTab: NavigationTab
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Namespace private var selectionIndicator

    private let pillHeight: CGFloat = 60
    private let pillCornerRadius: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(NavigationTab.allCases) { tab in
                    NavigationPillButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: {
                            withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedTab = tab
                            }
                        }
                    )
                    .frame(width: geometry.size.width / 3)

                    // Divider between buttons
                    if tab != NavigationTab.allCases.last {
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 0.5, height: 28)
                    }
                }
            }
            .frame(height: pillHeight)
        }
        .frame(height: pillHeight)
        .background(pillBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }

    // MARK: - Background Styling
    @ViewBuilder
    private var pillBackground: some View {
        LiquidGlassBackground(shape: Capsule(), glowColor: ColorPalette.accentPrimary)
    }

}

#Preview("Light Mode") {
    VStack {
        Spacer()
        NavigationPill(selectedTab: .constant(.meals))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
}

#Preview("Dark Mode") {
    VStack {
        Spacer()
        NavigationPill(selectedTab: .constant(.stats))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
    .preferredColorScheme(.dark)
}
