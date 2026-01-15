//
//  MealTagPill.swift
//  Food1
//
//  Small colored pill displaying AI-assigned meal nutritional tag.
//
//  DESIGN DECISIONS:
//  - Uses existing ColorPalette colors for consistency (protein=teal, fat=blue)
//  - Compact size fits below calories in MealCard without expanding card height much
//  - SF Symbols icon + short label for quick visual recognition
//  - Subtle background color (12% opacity) matches glassmorphic app aesthetic
//

import SwiftUI

/// Nutritional tag types for meals - assigned by AI during food recognition
enum MealTag: String, CaseIterable {
    case processed = "processed"
    case protein = "protein"
    case fat = "fat"

    var displayName: String {
        switch self {
        case .processed: return "Processed"
        case .protein: return "Protein"
        case .fat: return "Fat"
        }
    }

    var iconName: String {
        switch self {
        case .processed: return "shippingbox.fill"
        case .protein: return "bolt.fill"
        case .fat: return "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .processed: return Color(hex: "#9CA3AF")  // Neutral gray
        case .protein: return ColorPalette.macroProtein  // Teal
        case .fat: return ColorPalette.macroFat  // Deep blue
        }
    }
}

struct MealTagPill: View {
    let tag: MealTag

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: tag.iconName)
                .font(.system(size: 9, weight: .semibold))

            Text(tag.displayName)
                .font(DesignSystem.Typography.semiBold(size: 10))
        }
        .foregroundColor(tag.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(tag.color.opacity(0.12))
        )
    }

    /// Convenience initializer from string (returns nil if invalid tag)
    init?(tagString: String?) {
        guard let tagString = tagString,
              let tag = MealTag(rawValue: tagString) else {
            return nil
        }
        self.tag = tag
    }

    init(tag: MealTag) {
        self.tag = tag
    }
}

// MARK: - Previews

#Preview("All Tags") {
    VStack(spacing: 12) {
        MealTagPill(tag: .processed)
        MealTagPill(tag: .protein)
        MealTagPill(tag: .fat)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("In Context - Light") {
    VStack(alignment: .leading, spacing: 6) {
        Text("Grilled Chicken Salad")
            .font(DesignSystem.Typography.semiBold(size: 17))

        HStack(spacing: 4) {
            Text("12:30 PM")
            Text("•")
            Text("520 cal")
        }
        .font(DesignSystem.Typography.medium(size: 14))
        .foregroundColor(.secondary)

        MealTagPill(tag: .protein)
    }
    .padding()
    .background(.ultraThinMaterial)
    .cornerRadius(20)
    .padding()
}

#Preview("In Context - Dark") {
    VStack(alignment: .leading, spacing: 6) {
        Text("Potato Chips")
            .font(DesignSystem.Typography.semiBold(size: 17))

        HStack(spacing: 4) {
            Text("8:15 AM")
            Text("•")
            Text("380 cal")
        }
        .font(DesignSystem.Typography.medium(size: 14))
        .foregroundColor(.secondary)

        MealTagPill(tag: .processed)
    }
    .padding()
    .background(.ultraThinMaterial)
    .cornerRadius(20)
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}
