//
//  FastEntryView.swift
//  Food1
//
//  Timeline entry showing a confirmed fast period.
//
//  WHY THIS ARCHITECTURE:
//  - Subtle outlined style (not material card) to differentiate from meal cards
//  - Vertical timeline line on left connects visually to adjacent items
//  - Line extends beyond bounds using clipShape: false to bridge gaps between items
//  - Swipe-to-delete via .onDelete in parent List/ForEach
//  - Shows duration + timestamp in minimal format
//

import SwiftUI

struct FastEntryView: View {
    let fast: Fast
    let showTopConnector: Bool    // Line extends up to connect to item above
    let showBottomConnector: Bool // Line extends down to connect to item below

    @Environment(\.colorScheme) var colorScheme

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: fast.confirmedAt)
    }

    /// Line color - subtle gray
    private var lineColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.12)
    }

    /// Extension distance to connect to adjacent items
    private let lineExtension: CGFloat = 20

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Spacer for line position
            Color.clear
                .frame(width: 2)

            // Fast info - more prominent
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(fast.formattedDuration)
                        .font(DesignSystem.Typography.medium(size: 17))
                        .foregroundStyle(.secondary)

                    Text("fast")
                        .font(DesignSystem.Typography.regular(size: 17))
                        .foregroundStyle(.tertiary)
                }

                Text(timeString)
                    .font(DesignSystem.Typography.regular(size: 14))
                    .foregroundStyle(.quaternary)
            }

            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.leading, 28)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                // Timeline line positioned at left edge, extending beyond bounds
                TimelineLine(
                    height: geo.size.height,
                    topExtension: showTopConnector ? lineExtension : 0,
                    bottomExtension: showBottomConnector ? lineExtension : 0,
                    color: lineColor
                )
                .position(x: 29, y: geo.size.height / 2)
            }
            .zIndex(-1) // Render line behind adjacent items
        )
        .zIndex(-1) // Ensure the whole fast entry sits behind meal cards
        .contentShape(Rectangle())
    }
}

// MARK: - Timeline Line

/// Vertical line that can extend beyond its frame to connect adjacent items.
/// Rendered as a Path shape to allow drawing outside normal bounds.
/// Fades to transparent at ends where there's no connector (open ends).
private struct TimelineLine: View {
    let height: CGFloat
    let topExtension: CGFloat
    let bottomExtension: CGFloat
    let color: Color

    /// Fade distance at open ends (no connector)
    private let fadeDistance: CGFloat = 16

    var body: some View {
        // Total height including extensions
        let totalHeight = height + topExtension + bottomExtension

        ZStack {
            // Vertical line with gradient fade at open ends
            Rectangle()
                .fill(lineGradient(totalHeight: totalHeight))
                .frame(width: 1.5, height: totalHeight)

            // Center dot marker
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
        .frame(width: 10, height: totalHeight)
        // Offset to account for top extension
        .offset(y: (bottomExtension - topExtension) / 2)
    }

    /// Creates a gradient that fades at open ends (where there's no connector)
    private func lineGradient(totalHeight: CGFloat) -> LinearGradient {
        let hasTopConnector = topExtension > 0
        let hasBottomConnector = bottomExtension > 0

        // Calculate fade positions as fractions of total height
        let topFadeEnd = hasTopConnector ? 0 : min(fadeDistance / totalHeight, 0.3)
        let bottomFadeStart = hasBottomConnector ? 1 : max(1 - (fadeDistance / totalHeight), 0.7)

        var stops: [Gradient.Stop] = []

        if hasTopConnector {
            // Solid from top
            stops.append(.init(color: color, location: 0))
        } else {
            // Fade in from top
            stops.append(.init(color: color.opacity(0), location: 0))
            stops.append(.init(color: color, location: topFadeEnd))
        }

        if hasBottomConnector {
            // Solid to bottom
            stops.append(.init(color: color, location: 1))
        } else {
            // Fade out at bottom
            stops.append(.init(color: color, location: bottomFadeStart))
            stops.append(.init(color: color.opacity(0), location: 1))
        }

        return LinearGradient(
            stops: stops,
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        // Fast with connectors
        FastEntryView(
            fast: Fast(
                startTime: Date().addingTimeInterval(-16 * 3600),
                confirmedAt: Date()
            ),
            showTopConnector: false,
            showBottomConnector: true
        )

        // Fast in the middle
        FastEntryView(
            fast: Fast(
                startTime: Date().addingTimeInterval(-20 * 3600),
                confirmedAt: Date().addingTimeInterval(-3600)
            ),
            showTopConnector: true,
            showBottomConnector: false
        )
    }
    .padding(.vertical, 20)
    .background(Color(.systemGroupedBackground))
}
