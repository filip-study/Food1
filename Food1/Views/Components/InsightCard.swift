//
//  InsightCard.swift
//  Food1
//
//  Created by Claude on 2025-11-11.
//

import SwiftUI

struct InsightCard: View {
    let icon: String
    let title: String
    let message: String
    let accentColor: Color
    var onTap: (() -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme
    @State private var appeared = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.light()
            onTap?()
        }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(accentColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(accentColor.opacity(0.12))
                    )

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignSystem.Typography.semiBold(size: 15))
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(DesignSystem.Typography.regular(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .background(
            ZStack(alignment: .leading) {
                // Frosted glass card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.06),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.04 : 0.02),
                        radius: 4,
                        x: 0,
                        y: 2
                    )

                // Left accent bar (Whoop style)
                RoundedRectangle(cornerRadius: 20)
                    .fill(accentColor)
                    .frame(width: 3)
            }
        )
        .padding(.horizontal)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                appeared = true
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50) { isPressing in
            isPressed = isPressing
        } perform: {
            HapticManager.light()
            onTap?()
        }
    }
}

// Example insights for now - will be data-driven later
struct Insight {
    let icon: String
    let title: String
    let message: String
    let accentColor: Color

    static let examples: [Insight] = [
        Insight(
            icon: "flame.fill",
            title: "Great progress!",
            message: "You've hit your protein goal 5 days this week.",
            accentColor: .orange
        ),
        Insight(
            icon: "chart.line.uptrend.xyaxis",
            title: "Tracking streak",
            message: "You're on a 7-day streak of logging meals. Keep it up!",
            accentColor: .blue
        ),
        Insight(
            icon: "lightbulb.fill",
            title: "Nutrition tip",
            message: "Eating protein with breakfast helps maintain energy levels throughout the day.",
            accentColor: .yellow
        ),
        Insight(
            icon: "leaf.fill",
            title: "Weekly summary",
            message: "Your carb intake is well-balanced this week. Great choices!",
            accentColor: .green
        )
    ]
}

#Preview {
    VStack(spacing: 16) {
        ForEach(Insight.examples.indices, id: \.self) { index in
            let insight = Insight.examples[index]
            InsightCard(
                icon: insight.icon,
                title: insight.title,
                message: insight.message,
                accentColor: insight.accentColor,
                onTap: {
                    print("Tapped: \(insight.title)")
                }
            )
        }
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
