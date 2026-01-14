//
//  NavigationPillButton.swift
//  Food1
//
//  Individual button component within NavigationPill.
//  Provides smooth animations, haptic feedback, and accessibility support.
//

import SwiftUI

struct NavigationPillButton: View {
    let tab: NavigationTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(spacing: 4) {
                Image(tab.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isSelected ? 25 : 22, height: isSelected ? 25 : 22)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)

                Text(tab.label)
                    .font(isSelected ? DesignSystem.Typography.bold(size: 10) : DesignSystem.Typography.medium(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .opacity(isPressed ? 0.7 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.08)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(reduceMotion ? .none : .easeOut(duration: 0.08)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("\(tab.label) tab")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(tab.accessibilityHint)
    }

    private var foregroundColor: Color {
        if isSelected {
            return .primary
        } else {
            return Color.secondary.opacity(0.45)
        }
    }
}

// MARK: - Navigation Tab Enum
enum NavigationTab: Int, CaseIterable, Identifiable {
    case meals = 0
    case stats = 1
    case myHealth = 2

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .meals:
            return "CustomMeals"
        case .stats:
            return "CustomStats"
        case .myHealth:
            return "CustomHealth"
        }
    }

    var label: String {
        switch self {
        case .meals:
            return "Meals"
        case .stats:
            return "Stats"
        case .myHealth:
            return "My Health"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .meals:
            return "Shows today's meal entries"
        case .stats:
            return "Shows nutrition trends and analytics"
        case .myHealth:
            return "Shows health insights and recommendations"
        }
    }
}
