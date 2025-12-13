//
//  MealImageView.swift
//  Food1
//
//  Reusable meal image component with 3-layer fallback hierarchy.
//
//  WHY THIS ARCHITECTURE:
//  - Layer 1: Local photoData (highest priority - already on device, fastest)
//  - Layer 2: Cloud photoThumbnailUrl (fetched via AsyncImage when syncing from another device)
//  - Layer 3: Emoji fallback (always available)
//
//  This solves the sync issue where photo thumbnails were lost when restoring
//  meals on a new device - the cloud URL existed but was never displayed.
//

import SwiftUI

struct MealImageView: View {
    let photoData: Data?
    let photoThumbnailUrl: String?
    let emoji: String
    let size: CGFloat
    let cornerRadius: CGFloat

    init(meal: Meal, size: CGFloat = 80, cornerRadius: CGFloat = 14) {
        self.photoData = meal.photoData
        self.photoThumbnailUrl = meal.photoThumbnailUrl
        self.emoji = meal.emoji
        self.size = size
        self.cornerRadius = cornerRadius
    }

    init(photoData: Data?, photoThumbnailUrl: String?, emoji: String, size: CGFloat = 80, cornerRadius: CGFloat = 14) {
        self.photoData = photoData
        self.photoThumbnailUrl = photoThumbnailUrl
        self.emoji = emoji
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            // Layer 1: Local photo data (highest priority - fastest)
            if let imageData = photoData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            }
            // Layer 2: Cloud thumbnail URL (for synced meals from other devices)
            else if let urlString = photoThumbnailUrl,
                    let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // Loading state - show emoji with spinner
                        ZStack {
                            emojiView
                            ProgressView()
                                .scaleEffect(0.6)
                                .offset(x: size * 0.3, y: size * 0.3)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                    case .failure:
                        // Failed to load - fallback to emoji
                        emojiView
                    @unknown default:
                        emojiView
                    }
                }
            }
            // Layer 3: Emoji fallback (always available)
            else {
                emojiView
            }
        }
    }

    private var emojiView: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemGray6).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}

#Preview("With Photo Data") {
    MealImageView(
        photoData: nil,
        photoThumbnailUrl: nil,
        emoji: "🥗",
        size: 80
    )
}

#Preview("With Emoji Fallback") {
    VStack(spacing: 20) {
        MealImageView(
            photoData: nil,
            photoThumbnailUrl: nil,
            emoji: "🍕",
            size: 80
        )

        MealImageView(
            photoData: nil,
            photoThumbnailUrl: nil,
            emoji: "🥗",
            size: 120,
            cornerRadius: 20
        )
    }
}
