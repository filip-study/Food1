//
//  FlippableImageView.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//
//  Interactive image view that flips between real photo and cartoon icon
//  Auto-flips once on appearance, then manual flip on tap
//

import SwiftUI

/// Interactive view that flips between real photo and AI-generated cartoon
struct FlippableImageView: View {

    // MARK: - Properties

    let realPhoto: UIImage?
    let cartoonIcon: UIImage?
    let size: CGFloat

    @State private var showingCartoon = true  // Start with cartoon
    @State private var flipRotation: Double = 0
    @State private var hasAutoFlipped = false
    @State private var showHint = true

    @AppStorage("autoFlipInDetails") private var autoFlipInDetails: Bool = true
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Computed Properties

    /// Current image to display based on flip state
    private var currentImage: UIImage? {
        showingCartoon ? cartoonIcon : realPhoto
    }

    /// Badge text and icon
    private var badgeInfo: (text: String, icon: String) {
        showingCartoon ? ("AI", "sparkles") : ("Photo", "camera.fill")
    }

    /// Whether both images exist (enables flip interaction)
    private var canFlip: Bool {
        realPhoto != nil && cartoonIcon != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Flippable image with badge
            ZStack {
                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .rotation3DEffect(
                            .degrees(flipRotation),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                } else {
                    // Fallback to placeholder
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                        .frame(width: size, height: size)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: size * 0.3))
                                .foregroundColor(.secondary)
                        )
                }

                // Badge overlay (bottom-right corner)
                if canFlip {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: badgeInfo.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                Text(badgeInfo.text)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: showingCartoon ? [.blue, .cyan] : [.blue, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(.systemBackground).opacity(0.95))
                                    .shadow(color: .black.opacity(0.1), radius: 4)
                            )
                            .padding(8)
                        }
                    }
                    .frame(width: size, height: size)
                }
            }
            .onTapGesture {
                if canFlip {
                    performFlip()
                }
            }

            // Hint text (fades after 2 seconds)
            if canFlip && showHint {
                Text(showingCartoon ? "Tap to see real photo" : "Tap to see AI version")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
                    .onAppear {
                        // Fade out hint after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showHint = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            // Auto-flip once on appear (after 2 second delay) if setting enabled
            if canFlip && !hasAutoFlipped && autoFlipInDetails {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    performAutoFlip()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(canFlip ? "Double-tap to flip between cartoon and photo" : "")
    }

    // MARK: - Private Methods

    /// Performs the flip animation
    private func performFlip() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if reduceMotion {
            // Crossfade instead of flip for reduced motion
            withAnimation(.easeInOut(duration: 0.3)) {
                showingCartoon.toggle()
            }
        } else {
            // 3D flip animation
            withAnimation(.easeInOut(duration: 0.3)) {
                flipRotation += 90
            }

            // Switch image at midpoint of flip
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showingCartoon.toggle()

                withAnimation(.easeInOut(duration: 0.3)) {
                    flipRotation += 90
                }
            }
        }
    }

    /// Performs auto-flip sequence: cartoon → photo → cartoon
    private func performAutoFlip() {
        hasAutoFlipped = true

        // Flip to photo
        performFlip()

        // Wait 1.5 seconds, then flip back
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            performFlip()
        }
    }

    /// Accessibility description
    private var accessibilityDescription: String {
        if showingCartoon {
            return "AI-generated cartoon image. \(canFlip ? "Tap to see real photo." : "")"
        } else {
            return "Real food photo. \(canFlip ? "Tap to see AI cartoon." : "")"
        }
    }
}

// MARK: - Preview

#Preview("With Both Images") {
    FlippableImageView(
        realPhoto: UIImage(systemName: "photo.fill"),
        cartoonIcon: UIImage(systemName: "sparkles"),
        size: 120
    )
}

#Preview("Cartoon Only") {
    FlippableImageView(
        realPhoto: nil,
        cartoonIcon: UIImage(systemName: "sparkles"),
        size: 120
    )
}

#Preview("Photo Only") {
    FlippableImageView(
        realPhoto: UIImage(systemName: "photo.fill"),
        cartoonIcon: nil,
        size: 120
    )
}
