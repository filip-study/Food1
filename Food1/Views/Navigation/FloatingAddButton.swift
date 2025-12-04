//
//  FloatingAddButton.swift
//  Food1
//
//  Floating circular button with animated gradient shift.
//  Primary action button for adding new meals.
//

import SwiftUI

struct FloatingAddButton: View {
    @Binding var showingAddMeal: Bool
    @State private var isPressed = false
    @State private var gradientRotation: Double = 0
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let buttonSize: CGFloat = 60

    var body: some View {
        Button {
            HapticManager.medium()
            showingAddMeal = true
        } label: {
            ZStack {
                // Animated gradient circle
                Circle()
                    .fill(animatedGradient)
                    .frame(width: buttonSize, height: buttonSize)

                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .shadow(
            color: ColorPalette.accentPrimary.opacity(0.3),
            radius: isPressed ? 8 : 16,
            x: 0,
            y: isPressed ? 2 : 4
        )
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("Add meal")
        .accessibilityHint("Double tap to log a meal by photo or manual entry")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            if !reduceMotion {
                startGradientAnimation()
            }
        }
    }

    // MARK: - Animated Gradient
    private var animatedGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                ColorPalette.accentPrimary,
                ColorPalette.accentPrimary.opacity(0.9),
                ColorPalette.accentSecondary.opacity(0.8),
                ColorPalette.accentPrimary.opacity(0.9),
                ColorPalette.accentPrimary
            ]),
            center: .center,
            startAngle: .degrees(gradientRotation),
            endAngle: .degrees(gradientRotation + 360)
        )
    }

    // MARK: - Animation Control
    private func startGradientAnimation() {
        withAnimation(
            .linear(duration: 20.0)
            .repeatForever(autoreverses: false)
        ) {
            gradientRotation = 360
        }
    }
}

#Preview("Light Mode") {
    VStack {
        Spacer()
        HStack {
            Spacer()
            FloatingAddButton(showingAddMeal: .constant(false))
            Spacer()
        }
        .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
}

#Preview("Dark Mode") {
    VStack {
        Spacer()
        HStack {
            Spacer()
            FloatingAddButton(showingAddMeal: .constant(false))
            Spacer()
        }
        .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
    .preferredColorScheme(.dark)
}
