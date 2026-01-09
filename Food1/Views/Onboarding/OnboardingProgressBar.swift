//
//  OnboardingProgressBar.swift
//  Food1
//
//  Progress indicator showing current step in onboarding flow.
//  Animated capsule pills with smooth fill transitions.
//

import SwiftUI
import UIKit

struct OnboardingProgressBar: View {

    // MARK: - Properties

    let current: Int
    let total: Int

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 4)
                    .animation(.spring(response: 0.4), value: current)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

// MARK: - Gradient Variant

struct OnboardingProgressBarGradient: View {

    let current: Int
    let total: Int
    let gradient: LinearGradient

    init(
        current: Int,
        total: Int,
        gradient: LinearGradient = LinearGradient(
            colors: [.teal, .cyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    ) {
        self.current = current
        self.total = total
        self.gradient = gradient
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))

                // Progress fill
                Capsule()
                    .fill(gradient)
                    .frame(width: progressWidth(in: geometry.size.width))
                    .animation(.spring(response: 0.5), value: current)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        let progress = CGFloat(current + 1) / CGFloat(total)
        return totalWidth * progress
    }
}

// MARK: - Step Counter Variant

struct OnboardingStepCounter: View {

    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("Step \(current + 1)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("of \(total)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        VStack(alignment: .leading) {
            Text("Capsule Pills")
                .font(.caption)
                .foregroundStyle(.secondary)
            OnboardingProgressBar(current: 2, total: 7)
        }

        VStack(alignment: .leading) {
            Text("Gradient Bar")
                .font(.caption)
                .foregroundStyle(.secondary)
            OnboardingProgressBarGradient(current: 3, total: 7)
        }

        VStack(alignment: .leading) {
            Text("Step Counter")
                .font(.caption)
                .foregroundStyle(.secondary)
            OnboardingStepCounter(current: 4, total: 7)
        }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
}
