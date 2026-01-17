//
//  ShimmerView.swift
//  Food1
//
//  Animated shimmer effect for loading states.
//
//  WHY THIS ARCHITECTURE:
//  - Skeleton loading: Shows content structure before data loads
//  - Reduces perceived latency: Users see "something" immediately
//  - Premium feel: Used by Apple, Instagram, Facebook
//  - GPU-efficient: Uses gradient animation, not redrawing
//  - Accessibility-aware: Respects reduce motion preference
//

import SwiftUI

// MARK: - Shimmer View

/// Animated shimmer placeholder for loading states.
///
/// Example:
/// ```swift
/// if isLoading {
///     ShimmerView()
///         .frame(height: 20)
///         .clipShape(RoundedRectangle(cornerRadius: 4))
/// } else {
///     Text(content)
/// }
/// ```
struct ShimmerView: View {
    var baseColor: Color = Color(.systemGray5)
    var highlightColor: Color = Color(.systemGray4)

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            if reduceMotion {
                // Static placeholder for accessibility
                Rectangle()
                    .fill(adaptiveBaseColor)
            } else {
                Rectangle()
                    .fill(adaptiveBaseColor)
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: adaptiveHighlightColor, location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: phase * (geometry.size.width * 1.6))
                    )
                    .clipped()
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1.2)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 1.0
                        }
                    }
            }
        }
    }

    private var adaptiveBaseColor: Color {
        colorScheme == .dark
            ? Color(.systemGray6)
            : baseColor
    }

    private var adaptiveHighlightColor: Color {
        colorScheme == .dark
            ? Color(.systemGray5)
            : highlightColor
    }
}

// MARK: - Shimmer Modifier

/// Modifier to apply shimmer effect to any view
struct ShimmerModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        if isLoading {
            content
                .hidden()
                .overlay(
                    ShimmerView()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                )
        } else {
            content
        }
    }
}

extension View {
    /// Apply shimmer loading effect when loading
    func shimmer(when isLoading: Bool) -> some View {
        modifier(ShimmerModifier(isLoading: isLoading))
    }
}

// MARK: - Skeleton Shapes

/// Pre-built skeleton shapes for common UI patterns
enum SkeletonShape {
    /// Text line placeholder
    struct TextLine: View {
        var width: CGFloat? = nil

        var body: some View {
            ShimmerView()
                .frame(width: width, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    /// Circular avatar placeholder
    struct Avatar: View {
        var size: CGFloat = 44

        var body: some View {
            ShimmerView()
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
    }

    /// Rectangular card placeholder
    struct Card: View {
        var height: CGFloat = 120

        var body: some View {
            ShimmerView()
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        }
    }

    /// Image placeholder
    struct ImagePlaceholder: View {
        var aspectRatio: CGFloat = 1.0

        var body: some View {
            ShimmerView()
                .aspectRatio(aspectRatio, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

// MARK: - Meal Card Skeleton

/// Skeleton loader matching MealCard layout
struct MealCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Image placeholder
            ShimmerView()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                // Title
                SkeletonShape.TextLine(width: 120)

                // Subtitle
                SkeletonShape.TextLine(width: 80)
                    .opacity(0.7)

                // Calories
                SkeletonShape.TextLine(width: 60)
                    .opacity(0.5)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
}

// MARK: - Stats Card Skeleton

/// Skeleton loader for stats/metrics cards
struct StatsCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            SkeletonShape.TextLine(width: 100)

            // Large value
            ShimmerView()
                .frame(width: 80, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Subtitle
            SkeletonShape.TextLine(width: 140)
                .opacity(0.6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
}

// MARK: - Previews

#Preview("Basic Shimmer") {
    VStack(spacing: 16) {
        ShimmerView()
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))

        ShimmerView()
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(width: 200)

        ShimmerView()
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("Skeleton Shapes") {
    VStack(spacing: 16) {
        HStack {
            SkeletonShape.Avatar()
            VStack(alignment: .leading, spacing: 8) {
                SkeletonShape.TextLine(width: 120)
                SkeletonShape.TextLine(width: 80)
            }
        }

        SkeletonShape.Card()

        SkeletonShape.ImagePlaceholder(aspectRatio: 16/9)
            .frame(height: 200)
    }
    .padding()
}

#Preview("Meal Card Skeleton") {
    VStack {
        MealCardSkeleton()
        MealCardSkeleton()
        MealCardSkeleton()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Stats Card Skeleton") {
    HStack {
        StatsCardSkeleton()
        StatsCardSkeleton()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark Mode") {
    VStack(spacing: 16) {
        MealCardSkeleton()
        StatsCardSkeleton()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}
