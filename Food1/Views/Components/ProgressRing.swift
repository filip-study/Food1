//
//  ProgressRing.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let gradient: [Color]
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    lineWidth: lineWidth
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
        .frame(width: size, height: size)
    }
}

struct MacroRing: View {
    let name: String
    let current: Double
    let goal: Double
    let gradient: [Color]
    let size: CGFloat = 80

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return current / goal
    }

    private var isOverGoal: Bool {
        current > goal
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 8,
                    gradient: isOverGoal ? [.orange, .red] : gradient,
                    size: size
                )

                VStack(spacing: 2) {
                    Text("\(Int(current))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("\(Int(goal))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        ProgressRing(
            progress: 0.75,
            lineWidth: 12,
            gradient: [.blue, .purple],
            size: 120
        )

        HStack(spacing: 20) {
            MacroRing(
                name: "Protein",
                current: 85,
                goal: 150,
                gradient: [.blue, .cyan]
            )

            MacroRing(
                name: "Carbs",
                current: 180,
                goal: 225,
                gradient: [.green, .mint]
            )

            MacroRing(
                name: "Fat",
                current: 48,
                goal: 65,
                gradient: [.orange, .pink]
            )
        }
    }
    .padding()
}
