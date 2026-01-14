//
//  PackagingPromptView.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//

import SwiftUI

/// Bottom sheet that prompts user to scan nutrition label when packaged food is detected
/// Shown immediately after photo capture and recognition, before predictions list
struct PackagingPromptView: View {
    @Environment(\.dismiss) var dismiss

    let capturedImage: UIImage
    let onScanLabel: () -> Void
    let onSkipToAI: () -> Void

    @State private var iconScale: CGFloat = 0.8
    @State private var iconOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Playful animated food packaging emoji
                Text("🥡")
                    .font(.system(size: 64))
                    .scaleEffect(iconScale)
                    .offset(y: iconOffset)
                    .onAppear {
                        // Gentle bounce animation
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true)) {
                            iconScale = 1.1
                            iconOffset = -8
                        }
                    }

                // Friendly messaging
                VStack(spacing: 12) {
                    Text("Found packaged food!")
                        .font(DesignSystem.Typography.semiBold(size: 24))

                    Text("I can scan the nutrition label\nfor more accurate data")
                        .font(DesignSystem.Typography.regular(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Clear action buttons
                VStack(spacing: 12) {
                    // Primary action - Scan label
                    Button(action: {
                        HapticManager.medium()
                        dismiss()
                        onScanLabel()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                            Text("Scan Nutrition Label")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    // Secondary action - Skip
                    Button(action: {
                        HapticManager.light()
                        dismiss()
                        onSkipToAI()
                    }) {
                        Text("Skip for now")
                            .font(DesignSystem.Typography.regular(size: 16))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onAppear {
            HapticManager.light()
        }
    }
}

#Preview {
    PackagingPromptView(
        capturedImage: UIImage(systemName: "photo")!,
        onScanLabel: {},
        onSkipToAI: {}
    )
}
