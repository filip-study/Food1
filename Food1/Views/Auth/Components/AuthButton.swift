//
//  AuthButton.swift
//  Food1
//
//  Custom button styles for authentication screens.
//  Primary (filled) and Secondary (outlined) variants with haptic feedback.
//

import SwiftUI

/// Primary filled button style (for Apple Sign In and main CTAs)
struct PrimaryAuthButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @State private var isPressed = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.semiBold(size: 17))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black)
                    .opacity(isEnabled ? 1 : 0.5)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    // Light haptic feedback on press
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
    }
}

/// Secondary outlined button style (for email auth)
struct SecondaryAuthButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.medium(size: 17))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ?
                            Color.white.opacity(0.3) :
                            Color.black.opacity(0.2),
                        lineWidth: 1.5
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.clear)
                    )
            }
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    // Light haptic feedback on press
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
    }
}

/// Convenience button extensions
extension Button {
    func primaryAuthStyle() -> some View {
        self.buttonStyle(PrimaryAuthButtonStyle())
    }

    func secondaryAuthStyle() -> some View {
        self.buttonStyle(SecondaryAuthButtonStyle())
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 16) {
            Button("Continue with Apple") {
                // Action
            }
            .primaryAuthStyle()

            Button("Continue with Email") {
                // Action
            }
            .secondaryAuthStyle()

            Button("Disabled Button") {
                // Action
            }
            .primaryAuthStyle()
            .disabled(true)
        }
        .padding(40)
    }
}
