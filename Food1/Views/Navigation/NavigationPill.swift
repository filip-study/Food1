//
//  NavigationPill.swift
//  Food1
//
//  Glassmorphic pill containing 3 navigation buttons (Meals, Stats, My Health).
//  Uses ultra-thin material background with subtle shadows and borders.
//  Animated selection indicator slides between active tabs.
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
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15),
                radius: 20,
                x: 0,
                y: 10
            )
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
