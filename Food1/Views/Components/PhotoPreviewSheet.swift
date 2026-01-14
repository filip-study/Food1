//
//  PhotoPreviewSheet.swift
//  Food1
//
//  Lightweight photo preview for gallery selections
//  Optimizes for 90% use case: submit whole photo immediately
//  Provides optional access to cropping for 10% use case: focus on specific food
//

import SwiftUI

struct PhotoPreviewSheet: View {
    let image: UIImage
    let onAnalyze: (UIImage) -> Void
    let onRequestCrop: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Soft dark background
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with close
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                // Full photo preview (no crop frame)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.3), radius: 20)

                Spacer()

                // Action area
                VStack(spacing: 16) {
                    // Helpful context
                    Text("Ready to analyze your meal")
                        .font(DesignSystem.Typography.medium(size: 15))
                        .foregroundColor(.white.opacity(0.8))

                    // Primary action - full width, prominent
                    Button(action: {
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onAnalyze(image)
                    }) {
                        HStack(spacing: 12) {
                            Text("Analyze Photo")
                                .font(DesignSystem.Typography.semiBold(size: 17))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                    }

                    // Secondary action - subtle, discoverable
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        onRequestCrop()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "crop")
                                .font(.system(size: 14, weight: .medium))
                            Text("Focus on specific food")
                                .font(DesignSystem.Typography.medium(size: 15))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
}
