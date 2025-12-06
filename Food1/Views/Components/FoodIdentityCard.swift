//
//  FoodIdentityCard.swift
//  Food1
//
//  Hero card component displaying AI-detected food identity with editable meal name.
//  Shows EITHER emoji (text input) OR photo (camera input), never both.
//
//  WHY THIS ARCHITECTURE:
//  - Mutually exclusive display: Text input uses emoji, camera uses photo
//  - Confidence indicator provides trust signal for AI predictions
//  - Inline editable name eliminates duplicate fields
//  - Tap-to-edit pattern follows iOS Contacts/Notes conventions
//  - Compact horizontal layout maximizes screen real estate
//  - Graceful degradation when optional data (description, photo) is missing
//

import SwiftUI

struct FoodIdentityCard: View {
    @Binding var mealName: String  // Editable user name
    let emoji: String?
    let photo: UIImage?
    let foodName: String  // AI prediction (for reference)
    let description: String?
    let confidence: Double

    @State private var isEditingName = false
    @FocusState private var isNameFocused: Bool

    // Confidence level for display
    private var confidencePercentage: Int {
        Int(confidence * 100)
    }

    // Confidence dots visualization (6 dots)
    private var confidenceDots: String {
        let filled = Int(confidence * 6)
        return String(repeating: "●", count: filled) + String(repeating: "○", count: 6 - filled)
    }

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 16) {
                // Left side: Emoji OR Photo (mutually exclusive)
                if let image = photo {
                    // Camera input: Show photo thumbnail
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(.systemGray5), lineWidth: 1)
                        )
                } else if let emojiText = emoji {
                    // Text input: Show large emoji
                    Text(emojiText)
                        .font(.system(size: 56))
                        .frame(width: 64, height: 64)
                }

                // Right side: Food details
                VStack(alignment: .leading, spacing: 8) {
                    // Editable food name with confidence badge
                    HStack(alignment: .top, spacing: 8) {
                        // Name - tap to edit inline
                        HStack(spacing: 4) {
                            if isEditingName {
                                TextField("Meal name", text: $mealName)
                                    .font(.system(size: 19, weight: .semibold))
                                    .textFieldStyle(.plain)
                                    .focused($isNameFocused)
                                    .onSubmit {
                                        isEditingName = false
                                        HapticManager.light()
                                    }
                            } else {
                                Text(mealName.isEmpty ? foodName : mealName)
                                    .font(.system(size: 19, weight: .semibold))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .onTapGesture {
                                        isEditingName = true
                                        isNameFocused = true
                                        HapticManager.light()
                                    }

                                if !isEditingName {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.blue.opacity(0.6))
                                }
                            }
                        }

                        Spacer(minLength: 4)

                        // Confidence badge
                        VStack(spacing: 2) {
                            Text("\(confidencePercentage)%")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                            Text(confidenceDots)
                                .font(.system(size: 8))
                                .foregroundColor(.blue.opacity(0.6))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }

                    // Description if available
                    if let desc = description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview("With Photo") {
    Form {
        FoodIdentityCard(
            mealName: .constant("Grilled Chicken Salad"),
            emoji: nil,
            photo: nil,
            foodName: "Grilled Chicken Salad",
            description: "Fresh salad with grilled chicken breast, mixed greens, and vinaigrette",
            confidence: 0.95
        )
    }
}

#Preview("With Emoji") {
    Form {
        FoodIdentityCard(
            mealName: .constant("Caesar Salad"),
            emoji: "🥗",
            photo: nil,
            foodName: "Caesar Salad",
            description: "Classic caesar with romaine lettuce and parmesan",
            confidence: 0.87
        )
    }
}

#Preview("No Description") {
    Form {
        FoodIdentityCard(
            mealName: .constant("Pizza Margherita"),
            emoji: "🍕",
            photo: nil,
            foodName: "Pizza Margherita",
            description: nil,
            confidence: 0.92
        )
    }
}

#Preview("Low Confidence") {
    Form {
        FoodIdentityCard(
            mealName: .constant("Mixed Dish"),
            emoji: "🍽️",
            photo: nil,
            foodName: "Mixed Dish",
            description: "Various ingredients detected",
            confidence: 0.65
        )
    }
}
