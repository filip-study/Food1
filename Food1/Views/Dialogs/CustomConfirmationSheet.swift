//
//  CustomConfirmationSheet.swift
//  Food1
//
//  Unified premium confirmation dialog.
//
//  DESIGN PHILOSOPHY:
//  - ALL dialogs look identical - unified visual language
//  - Dark glassmorphic aesthetic matching app's premium feel
//  - Destructive actions use subtle red text, not garish colored buttons
//  - Minimal decoration - content-focused, no distracting icons
//  - Consistent with Oura/Apple Health level polish
//

import SwiftUI

// MARK: - Action Type

/// Semantic action type - affects text styling only, not layout
enum ActionType {
    case normal      // Standard action (sign out, end fast, etc.)
    case destructive // Permanent deletion (delete account, delete meal)
}

// MARK: - Premium Confirmation Sheet

struct PremiumConfirmationSheet: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let actionType: ActionType
    let onConfirm: () -> Void
    var onCancel: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            Spacer().frame(height: 32)

            // Title
            Text(title)
                .font(DesignSystem.Typography.semiBold(size: 20))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 12)

            // Message
            Text(message)
                .font(DesignSystem.Typography.regular(size: 15))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 24)

            Spacer().frame(height: 32)

            // Actions
            VStack(spacing: 12) {
                // Primary action button
                Button {
                    HapticManager.medium()
                    dismiss()
                    onConfirm()
                } label: {
                    Text(confirmTitle)
                        .font(DesignSystem.Typography.semiBold(size: 16))
                        .foregroundColor(actionType == .destructive ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(actionType == .destructive
                                    ? Color.red.opacity(0.9)
                                    : Color.white)
                        )
                }
                .buttonStyle(PremiumButtonStyle())

                // Cancel button - always subtle
                Button {
                    HapticManager.light()
                    dismiss()
                    onCancel?()
                } label: {
                    Text(cancelTitle)
                        .font(DesignSystem.Typography.medium(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(sheetBackground)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }

    private var sheetBackground: some View {
        ZStack {
            // Base dark color
            Color(red: 0.08, green: 0.08, blue: 0.10)

            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Noise texture for depth
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        }
    }
}

// MARK: - Button Style

private struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - View Extension

extension View {
    /// Present a premium confirmation sheet with unified styling.
    func confirmationSheet(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        confirmStyle: ConfirmStyle, // Keep for backward compatibility
        cancelTitle: String = "Cancel",
        icon: String? = nil, // Ignored - no icons in new design
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        let actionType: ActionType = {
            switch confirmStyle {
            case .destructive:
                return .destructive
            default:
                return .normal
            }
        }()

        return self.sheet(isPresented: isPresented) {
            PremiumConfirmationSheet(
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                cancelTitle: cancelTitle,
                actionType: actionType,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        }
    }
}

// MARK: - Keep ConfirmStyle for Backward Compatibility

enum ConfirmStyle {
    case destructive
    case fasting
    case primary
    case custom(Color)

    var color: Color {
        switch self {
        case .destructive: return .red
        case .fasting: return ColorPalette.calories
        case .primary: return ColorPalette.accentPrimary
        case .custom(let color): return color
        }
    }
}

// MARK: - Previews

#Preview("End Fast") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PremiumConfirmationSheet(
                title: "End Fast",
                message: "You've been fasting for 16h 30m. End and log this fast?",
                confirmTitle: "End Fast",
                cancelTitle: "Keep Fasting",
                actionType: .normal,
                onConfirm: {}
            )
        }
}

#Preview("Cancel Fast") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PremiumConfirmationSheet(
                title: "Cancel Fast",
                message: "You've only been fasting 2h 15m. This won't be logged.",
                confirmTitle: "Cancel Fast",
                cancelTitle: "Keep Fasting",
                actionType: .normal,
                onConfirm: {}
            )
        }
}

#Preview("Sign Out") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PremiumConfirmationSheet(
                title: "Sign Out",
                message: "Are you sure you want to sign out of your account?",
                confirmTitle: "Sign Out",
                cancelTitle: "Cancel",
                actionType: .normal,
                onConfirm: {}
            )
        }
}

#Preview("Delete Account") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PremiumConfirmationSheet(
                title: "Delete Account",
                message: "This will permanently delete your account and all your data. This cannot be undone.",
                confirmTitle: "Delete Account",
                cancelTitle: "Cancel",
                actionType: .destructive,
                onConfirm: {}
            )
        }
}

#Preview("Delete Meal") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PremiumConfirmationSheet(
                title: "Delete Meal",
                message: "Are you sure you want to delete this meal?",
                confirmTitle: "Delete",
                cancelTitle: "Cancel",
                actionType: .destructive,
                onConfirm: {}
            )
        }
}
