//
//  FastingLiveActivity.swift
//  MealReminderWidget
//
//  Live Activity views for fasting progress tracking.
//  Lock screen widget and Dynamic Island presentations.
//
//  DESIGN PHILOSOPHY:
//  - "The Journey Becomes Visible" - UI evolves as fast progresses
//  - Stage-based gradients that shift from warm amber to rich achievement tones
//  - Milestone markers show the architecture of the journey
//  - Stage-appropriate symbols (flame is EARNED at Fat Burning, not given)
//  - Elapsed time is the HERO - your achievement counter
//  - End Fast is demoted to reduce temptation anchoring
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Stage Color Palettes

/// Each stage has its own gradient palette - warm color progression throughout
private func stageGradient(for stageIndex: Int) -> [Color] {
    switch stageIndex {
    case 0: // Digesting - soft, neutral
        return [Color(hex: "9CA3AF"), Color(hex: "6B7280")]
    case 1: // Metabolic Shift - warming up
        return [Color(hex: "F59E0B"), Color(hex: "D97706")]
    case 2: // Fat Burning - energetic warmth
        return [Color(hex: "F97316"), Color(hex: "EA580C")]
    default: // Deep Repair - rich golden achievement
        return [Color(hex: "D97706"), Color(hex: "B45309")]
    }
}

/// Stage symbol - earned through progression
private func stageSymbol(for stageIndex: Int) -> String {
    switch stageIndex {
    case 0: return "leaf.fill"              // Digesting - processing
    case 1: return "arrow.triangle.swap"    // Metabolic Shift - switching
    case 2: return "flame.fill"             // Fat Burning - EARNED flame
    default: return "sparkles"              // Deep Repair - cellular magic
    }
}

/// Accent color for each stage
private func stageAccent(for stageIndex: Int) -> Color {
    switch stageIndex {
    case 0: return Color(hex: "9CA3AF")     // Gray
    case 1: return Color(hex: "F59E0B")     // Amber
    case 2: return Color(hex: "F97316")     // Orange
    default: return Color(hex: "D97706")    // Deep Gold
    }
}

// MARK: - Brand Colors

private let brandGold = Color(red: 0.84, green: 0.67, blue: 0.15)  // #D6AC25

// MARK: - Widget Configuration

struct FastingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingActivityAttributes.self) { context in
            // Lock Screen / StandBy presentation
            FastingLockScreenView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 8) {
                        // Elapsed time - THE HERO
                        // iOS 18+: Auto-updating with nice format
                        if context.state.countdownDisplay != nil {
                            // Demo mode
                            Text(context.state.elapsedDisplay)
                                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                        } else {
                            Text(
                                TimeDataSource<Date>.durationOffset(to: context.attributes.startTime),
                                format: .units(
                                    allowed: [.hours, .minutes],
                                    width: .narrow,
                                    fractionalPart: .hide(rounded: .down)
                                )
                            )
                            .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        }

                        // Stage name
                        HStack(spacing: 6) {
                            Image(systemName: stageSymbol(for: context.state.stageIndex))
                                .font(.system(size: 14))
                                .foregroundStyle(stageAccent(for: context.state.stageIndex))
                                .symbolEffect(.pulse.byLayer, options: .repeating)
                            Text(context.state.stageName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(stageAccent(for: context.state.stageIndex))
                        }

                        // Progress bar with stage gradient
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Track
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.white.opacity(0.15))

                                if context.state.stageIndex == 3 {
                                    // Deep Repair: FULL bar - journey complete
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: stageGradient(for: 3),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                } else {
                                    // Normal progress for stages 0-2
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: stageGradient(for: context.state.stageIndex),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(geo.size.width * context.state.stageProgress, 6))
                                }
                            }
                        }
                        .frame(height: 6)
                        .padding(.horizontal, 20)

                        // Next milestone (if not in extended)
                        if context.state.secondsToNextStage != nil {
                            // Use countdownDisplay in demo mode, formatTime otherwise
                            let countdownText = context.state.countdownDisplay ?? formatTime(context.state.secondsToNextStage!)
                            Text("\(nextStageName(after: context.state.stageIndex)) in \(countdownText)")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                        } else {
                            // Deep Repair - show celebration text
                            Text("✨ Deep cellular repair active")
                                .font(.system(size: 12))
                                .foregroundStyle(stageAccent(for: 3).opacity(0.7))
                        }
                    }
                    .padding(.vertical, 8)
                }
                DynamicIslandExpandedRegion(.leading) { EmptyView() }
                DynamicIslandExpandedRegion(.trailing) { EmptyView() }
                DynamicIslandExpandedRegion(.bottom) { EmptyView() }
            } compactLeading: {
                // Prismae logo in brand gold
                PrismaeLogoShape()
                    .fill(brandGold)
                    .frame(width: 16, height: 16)
            } compactTrailing: {
                // Stage icon + elapsed time (auto-updating)
                HStack(spacing: 4) {
                    Image(systemName: stageSymbol(for: context.state.stageIndex))
                        .font(.system(size: 10))
                        .foregroundStyle(stageAccent(for: context.state.stageIndex))
                        .symbolEffect(.pulse.byLayer, options: .repeating)
                    if context.state.countdownDisplay != nil {
                        // Demo mode
                        Text(context.state.elapsedDisplay)
                            .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    } else {
                        // Auto-updating with constrained frame
                        // Hidden template constrains width, overlay shows actual content
                        Text("00h")
                            .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                            .hidden()
                            .overlay(alignment: .trailing) {
                                Text(
                                    TimeDataSource<Date>.durationOffset(to: context.attributes.startTime),
                                    format: .units(
                                        allowed: [.hours, .minutes],
                                        width: .narrow,
                                        maximumUnitCount: 1,
                                        fractionalPart: .hide(rounded: .down)
                                    )
                                )
                                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                            }
                    }
                }
            } minimal: {
                // Prismae logo
                PrismaeLogoShape()
                    .fill(brandGold)
                    .frame(width: 14, height: 14)
            }
            .keylineTint(brandGold)
        }
    }
}

// MARK: - Lock Screen View

struct FastingLockScreenView: View {
    let context: ActivityViewContext<FastingActivityAttributes>

    var body: some View {
        ZStack {
            // Background: Large transparent Prismae logo as watermark
            HStack {
                Spacer()
                PrismaeLogoShape()
                    .fill(brandGold.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .offset(x: 10, y: 0)
            }

            // Content
            HStack(spacing: 16) {
                // Left: Progress ring (fixed position)
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 5)

                    if context.state.stageIndex == 3 {
                        // Deep Repair: Multi-layered ring system for "alive" feeling
                        // Layer 1: Outer soft glow (widest, most subtle)
                        Circle()
                            .stroke(
                                stageAccent(for: 3).opacity(0.12),
                                lineWidth: 12
                            )

                        // Layer 2: Mid glow ring (adds depth)
                        Circle()
                            .stroke(
                                stageAccent(for: 3).opacity(0.25),
                                lineWidth: 7
                            )

                        // Layer 3: Main ring with rich gradient
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: stageGradient(for: 3),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 5
                            )

                        // Layer 4: Inner highlight (bright accent)
                        Circle()
                            .stroke(
                                Color.white.opacity(0.15),
                                lineWidth: 2
                            )
                            .padding(2)
                    } else {
                        // Normal progress ring for stages 0-2
                        Circle()
                            .trim(from: 0, to: context.state.stageProgress)
                            .stroke(
                                LinearGradient(
                                    colors: stageGradient(for: context.state.stageIndex),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }

                    // Center: Stage symbol (earned through progression)
                    if context.state.stageIndex == 3 {
                        // Deep Repair: Larger, more prominent sparkles
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [stageAccent(for: 3), Color.orange.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .symbolEffect(.pulse.byLayer, options: .repeating)
                    } else {
                        Image(systemName: stageSymbol(for: context.state.stageIndex))
                            .font(.system(size: 20))
                            .foregroundStyle(stageAccent(for: context.state.stageIndex))
                            .symbolEffect(.pulse.byLayer, options: .repeating)
                    }
                }
                .frame(width: 56, height: 56)

                // Right: Info hierarchy (fills remaining space)
                VStack(alignment: .leading, spacing: 6) {
                    // HERO: Elapsed time - your achievement counter
                    // iOS 18+: TimeDataSource.durationOffset with custom format auto-updates!
                    if context.state.countdownDisplay != nil {
                        // Demo mode: use pre-formatted (native timer uses real time)
                        Text(context.state.elapsedDisplay)
                            .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    } else {
                        // Normal mode: auto-updating with nice "2h 34m" format
                        Text(
                            TimeDataSource<Date>.durationOffset(to: context.attributes.startTime),
                            format: .units(
                                allowed: [.hours, .minutes],
                                width: .narrow,
                                fractionalPart: .hide(rounded: .down)
                            )
                        )
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                    }

                    // Stage name
                    Text(context.state.stageName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(stageAccent(for: context.state.stageIndex))

                // Next milestone with live countdown
                if let secondsToNext = context.state.secondsToNextStage {
                    HStack(spacing: 4) {
                        Text(nextStageName(after: context.state.stageIndex))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(stageAccent(for: context.state.stageIndex + 1).opacity(0.8))
                        Text("in")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                        // Use pre-formatted countdown in demo mode, native timer otherwise
                        if let countdown = context.state.countdownDisplay {
                            Text(countdown)
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.6))
                        } else {
                            Text(Date().addingTimeInterval(TimeInterval(secondsToNext)), style: .timer)
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                } else {
                    // Extended stage - celebration mode
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("Deep cellular repair active")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(stageAccent(for: 3).opacity(0.8))
                }
                }

                // Spacer keeps ring in fixed position regardless of text width
                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }
}

// MARK: - Helper Functions

private func nextStageName(after stageIndex: Int) -> String {
    switch stageIndex {
    case 0: return "Metabolic Shift"
    case 1: return "Fat Burning"
    case 2: return "Deep Repair"
    default: return ""
    }
}

private func formatTime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Previews

#Preview("Lock Screen - Digesting", as: .content, using: FastingActivityAttributes(
    fastId: UUID(),
    startTime: Date().addingTimeInterval(-2 * 3600)
)) {
    FastingLiveActivity()
} contentStates: {
    FastingActivityAttributes.ContentState(
        stageName: "Digesting",
        stageIndex: 0,
        secondsToNextStage: 2 * 3600,
        elapsedDisplay: "2h",
        stageProgress: 0.5
    )
}

#Preview("Lock Screen - Metabolic Shift", as: .content, using: FastingActivityAttributes(
    fastId: UUID(),
    startTime: Date().addingTimeInterval(-8 * 3600)
)) {
    FastingLiveActivity()
} contentStates: {
    FastingActivityAttributes.ContentState(
        stageName: "Metabolic Shift",
        stageIndex: 1,
        secondsToNextStage: 4 * 3600,
        elapsedDisplay: "8h",
        stageProgress: 0.5
    )
}

#Preview("Lock Screen - Fat Burning", as: .content, using: FastingActivityAttributes(
    fastId: UUID(),
    startTime: Date().addingTimeInterval(-18 * 3600)
)) {
    FastingLiveActivity()
} contentStates: {
    FastingActivityAttributes.ContentState(
        stageName: "Fat Burning",
        stageIndex: 2,
        secondsToNextStage: 6 * 3600,
        elapsedDisplay: "18h",
        stageProgress: 0.5
    )
}

#Preview("Lock Screen - Deep Repair", as: .content, using: FastingActivityAttributes(
    fastId: UUID(),
    startTime: Date().addingTimeInterval(-28 * 3600)
)) {
    FastingLiveActivity()
} contentStates: {
    FastingActivityAttributes.ContentState(
        stageName: "Deep Repair",
        stageIndex: 3,
        secondsToNextStage: nil,
        elapsedDisplay: "1d 4h",
        stageProgress: 0.17
    )
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: FastingActivityAttributes(
    fastId: UUID(),
    startTime: Date().addingTimeInterval(-14 * 3600)
)) {
    FastingLiveActivity()
} contentStates: {
    FastingActivityAttributes.ContentState(
        stageName: "Fat Burning",
        stageIndex: 2,
        secondsToNextStage: 10 * 3600,
        elapsedDisplay: "14h",
        stageProgress: 0.17
    )
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: FastingActivityAttributes(
    fastId: UUID(),
    startTime: Date().addingTimeInterval(-14 * 3600)
)) {
    FastingLiveActivity()
} contentStates: {
    FastingActivityAttributes.ContentState(
        stageName: "Fat Burning",
        stageIndex: 2,
        secondsToNextStage: 10 * 3600,
        elapsedDisplay: "14h",
        stageProgress: 0.17
    )
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: FastingActivityAttributes(
    fastId: UUID(),
    startTime: Date().addingTimeInterval(-8 * 3600)
)) {
    FastingLiveActivity()
} contentStates: {
    FastingActivityAttributes.ContentState(
        stageName: "Metabolic Shift",
        stageIndex: 1,
        secondsToNextStage: 4 * 3600,
        elapsedDisplay: "8h",
        stageProgress: 0.5
    )
}
