//
//  FastingHeroView.swift
//  Food1
//
//  Fasting progress card with horizontal timeline visualization.
//
//  WHY THIS ARCHITECTURE:
//  - Timeline shows the fasting JOURNEY, not just current state
//  - Position marker moves along timeline as time passes
//  - Stage zones are visually distinct with gradient fills
//  - Compact but information-dense (~120pt height)
//  - Amber/orange colors: Associated with energy/fasting
//  - Info button → sheet: Detailed explanations on demand
//  - Manual End Fast: Proper styled button, not floating text
//

import SwiftUI
import SwiftData
import Combine

struct FastingHeroView: View {
    let fast: Fast
    let demoMode: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var currentTime = Date()
    @State private var showInfoSheet = false
    @State private var showEndConfirmation = false

    // Timer fires every second for live updates
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Timeline configuration (hours)
    private let timelineMaxHours: Double = 28  // Show up to 28h for Extended stage visibility

    // MARK: - Computed Properties

    private var durationSeconds: Int {
        // IMPORTANT: Reference currentTime to force SwiftUI recomputation when timer fires
        _ = currentTime
        return fast.durationSeconds(demoMode: demoMode)
    }

    private var durationHours: Double {
        Double(durationSeconds) / 3600.0
    }

    private var currentStage: FastingStage {
        _ = currentTime
        return fast.stage(demoMode: demoMode)
    }

    private var formattedDuration: String {
        let totalSeconds = durationSeconds
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        // Progressive reveal: show units as they become relevant
        if hours >= 24 {
            // Days: "1d 2h 34m" (drop seconds for readability)
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h \(minutes)m"
        } else if hours > 0 {
            // Hours: "2h 34m 56s"
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            // Minutes: "12m 34s"
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            // Seconds only: "45s"
            return "\(seconds)s"
        }
    }

    /// Progress along the timeline (0.0 to 1.0)
    private var timelineProgress: Double {
        min(durationHours / timelineMaxHours, 1.0)
    }

    /// Whether we're in the fed state (0-4h, not truly fasting yet)
    private var isFedState: Bool {
        currentStage == .fed
    }

    /// Time until next stage (formatted)
    private var timeToNextStage: String? {
        guard let nextHour = currentStage.endHour else { return nil }
        let hoursRemaining = Double(nextHour) - durationHours
        if hoursRemaining <= 0 { return nil }

        let hours = Int(hoursRemaining)
        let minutes = Int((hoursRemaining - Double(hours)) * 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m to \(nextStageName)"
        } else {
            return "\(minutes)m to \(nextStageName)"
        }
    }

    private var nextStageName: String {
        switch currentStage {
        case .fed: return "Metabolic Shift"
        case .earlyFast: return "Fat Burning"
        case .ketosis: return "Deep Repair"
        case .extended: return "continuing"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Header: Timer + Stage Info + Info Button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Main timer
                    Text(formattedDuration)
                        .font(DesignSystem.Typography.bold(size: 32))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.1), value: formattedDuration)

                    // Stage name + short description
                    HStack(spacing: 6) {
                        // Flame icon (animated glow for active fasting)
                        Image(systemName: isFedState ? "circle" : "flame.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(isFedState ? .secondary : stageColor)

                        Text(currentStage.title)
                            .font(DesignSystem.Typography.semiBold(size: 15))
                            .foregroundStyle(isFedState ? .secondary : .primary)

                        if let countdown = timeToNextStage {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text(countdown)
                                .font(DesignSystem.Typography.regular(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Info button
                Button {
                    HapticManager.light()
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Fasting stage information")
            }

            // Timeline visualization
            FastingTimeline(
                progress: timelineProgress,
                currentStage: currentStage,
                durationHours: durationHours,
                isFedState: isFedState
            )

            // End/Cancel Fast button
            // Fed state (<4h) = Cancel (delete), otherwise = End (log)
            Button {
                HapticManager.medium()
                showEndConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isFedState ? "xmark.circle" : "stop.circle")
                        .font(.system(size: 14))
                    Text(isFedState ? "Cancel Fast" : "End Fast")
                        .font(DesignSystem.Typography.medium(size: 14))
                }
                .foregroundColor(isFedState ? .secondary : stageColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill((isFedState ? Color.secondary : stageColor).opacity(0.12))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(cardBackground)
        .padding(.horizontal)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .sheet(isPresented: $showInfoSheet) {
            FastingInfoSheet(
                currentStage: currentStage,
                durationSeconds: durationSeconds
            )
        }
        .confirmationSheet(
            isPresented: $showEndConfirmation,
            title: isFedState ? "Cancel Fast" : "End Fast",
            message: isFedState
                ? "You've only been fasting \(formattedDuration). This won't be logged."
                : "You've been fasting for \(formattedDuration). End and log this fast?",
            confirmTitle: isFedState ? "Cancel Fast" : "End Fast",
            confirmStyle: .fasting,
            cancelTitle: "Keep Fasting",
            icon: isFedState ? "xmark.circle" : "flame.fill"
        ) {
            if isFedState {
                cancelFast()
            } else {
                endFast()
            }
        }
    }

    // MARK: - Stage Color

    private var stageColor: Color {
        switch currentStage {
        case .fed: return .secondary
        case .earlyFast: return ColorPalette.calories.opacity(0.8)
        case .ketosis: return ColorPalette.calories
        case .extended: return Color.orange
        }
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.thinMaterial.opacity(0.97))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        stageColor.opacity(colorScheme == .dark ? 0.2 : 0.15),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.08),
                radius: 16, x: 0, y: 6
            )
    }

    // MARK: - Actions

    /// End fast and log it (for fasts 4h+)
    private func endFast() {
        fast.end()

        // End Live Activity
        Task {
            await FastingActivityManager.shared.endActivity()
        }

        HapticManager.success()
    }

    /// Cancel fast and delete it (for fasts <4h, not logged)
    private func cancelFast() {
        // End Live Activity first
        Task {
            await FastingActivityManager.shared.endActivity()
        }

        modelContext.delete(fast)
        HapticManager.light()
    }
}

// MARK: - Fasting Timeline

/// Horizontal timeline showing fasting journey with dynamic stage expansion
/// Current stage is expanded (60%) to show detailed progress, completed stages compress (8%),
/// and future stages share remaining space. This creates engaging "level up" moments.
private struct FastingTimeline: View {
    let progress: Double
    let currentStage: FastingStage
    let durationHours: Double
    let isFedState: Bool

    @Environment(\.colorScheme) var colorScheme

    // Stage boundaries (in hours)
    private let stage1End: Double = 4    // Fed → Metabolic Shift
    private let stage2End: Double = 12   // Metabolic Shift → Fat Burning
    private let stage3End: Double = 24   // Fat Burning → Deep Repair

    // Dynamic width distribution
    private let expandedWidth: Double = 0.55    // Current stage gets 55%
    private let completedWidth: Double = 0.08   // Completed stages get 8% each

    // MARK: - Dynamic Width Calculation

    /// Returns width fractions for each stage based on current progress
    private var stageWidths: (fed: Double, metabolic: Double, fatBurn: Double, deep: Double) {
        let stageIndex = currentStageIndex

        switch stageIndex {
        case 0: // In Fed state (0-4h)
            let remaining = 1.0 - expandedWidth
            let futureShare = remaining / 3.0
            return (expandedWidth, futureShare, futureShare, futureShare)

        case 1: // In Metabolic Shift (4-12h)
            let remaining = 1.0 - expandedWidth - completedWidth
            let futureShare = remaining / 2.0
            return (completedWidth, expandedWidth, futureShare, futureShare)

        case 2: // In Fat Burning (12-24h)
            let remaining = 1.0 - expandedWidth - (completedWidth * 2)
            return (completedWidth, completedWidth, expandedWidth, remaining)

        default: // In Deep Repair (24h+)
            let remaining = 1.0 - (completedWidth * 3)
            return (completedWidth, completedWidth, completedWidth, remaining)
        }
    }

    /// Current stage as index (0=fed, 1=earlyFast, 2=ketosis, 3=extended)
    private var currentStageIndex: Int {
        switch currentStage {
        case .fed: return 0
        case .earlyFast: return 1
        case .ketosis: return 2
        case .extended: return 3
        }
    }

    /// Calculate marker position in the dynamic layout
    private func markerPosition(totalWidth: CGFloat) -> CGFloat {
        let widths = stageWidths
        let cumulativeWidths = [
            0.0,
            widths.fed,
            widths.fed + widths.metabolic,
            widths.fed + widths.metabolic + widths.fatBurn,
            1.0
        ]

        // Progress within current stage (0-1)
        let stageStart: Double
        let stageEnd: Double
        switch currentStageIndex {
        case 0:
            stageStart = 0
            stageEnd = stage1End
        case 1:
            stageStart = stage1End
            stageEnd = stage2End
        case 2:
            stageStart = stage2End
            stageEnd = stage3End
        default:
            stageStart = stage3End
            stageEnd = stage3End + 28 // Extended stage has no real end
        }

        let progressInStage = min(1.0, max(0, (durationHours - stageStart) / (stageEnd - stageStart)))

        // Position = start of current stage + progress within it
        let stageStartPosition = cumulativeWidths[currentStageIndex]
        let stageWidth = cumulativeWidths[currentStageIndex + 1] - stageStartPosition
        let position = stageStartPosition + (progressInStage * stageWidth)

        return totalWidth * position
    }

    /// Calculate boundary positions in dynamic layout
    private func boundaryPositions(totalWidth: CGFloat) -> [CGFloat] {
        let widths = stageWidths
        return [
            totalWidth * widths.fed,
            totalWidth * (widths.fed + widths.metabolic),
            totalWidth * (widths.fed + widths.metabolic + widths.fatBurn)
        ]
    }

    var body: some View {
        VStack(spacing: 8) {
            // Timeline bar with position marker
            GeometryReader { geometry in
                let width = geometry.size.width
                let widths = stageWidths
                let markerPos = markerPosition(totalWidth: width)
                let boundaries = boundaryPositions(totalWidth: width)
                let isDeepRepair = currentStageIndex == 3

                ZStack(alignment: .leading) {
                    // Background track with dynamic stage zones
                    HStack(spacing: 0) {
                        // Fed zone - gray (completed or current)
                        stageZone(
                            color: currentStageIndex > 0 ? .secondary.opacity(0.15) : .secondary.opacity(0.2),
                            widthFraction: widths.fed,
                            width: width
                        )

                        // Metabolic Shift zone - light amber
                        stageZone(
                            color: currentStageIndex > 1
                                ? ColorPalette.calories.opacity(0.15)
                                : ColorPalette.calories.opacity(0.25),
                            widthFraction: widths.metabolic,
                            width: width
                        )

                        // Fat Burning zone - amber
                        stageZone(
                            color: currentStageIndex > 2
                                ? ColorPalette.calories.opacity(0.25)
                                : ColorPalette.calories.opacity(0.4),
                            widthFraction: widths.fatBurn,
                            width: width
                        )

                        // Deep Repair zone - orange
                        stageZone(
                            color: Color.orange.opacity(0.4),
                            widthFraction: widths.deep,
                            width: width
                        )
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())

                    // Progress fill - FULL for Deep Repair, marker position otherwise
                    if isDeepRepair {
                        // Deep Repair: Full progress bar with animated shimmer
                        DeepRepairProgressBar(width: width)
                    } else {
                        Capsule()
                            .fill(progressGradient)
                            .frame(width: markerPos, height: 8)
                    }

                    if isDeepRepair {
                        // Deep Repair: Marker at end with pulsing glow
                        DeepRepairMarker()
                            .offset(x: width - 16)
                    } else {
                        // Position marker (glowing dot) for stages 0-2
                        Circle()
                            .fill(markerColor)
                            .frame(width: 16, height: 16)
                            .shadow(color: markerColor.opacity(0.5), radius: 6, x: 0, y: 0)
                            .offset(x: markerPos - 8)
                    }

                    // Stage boundary markers (at dynamic positions)
                    ForEach(Array(boundaries.enumerated()), id: \.offset) { index, position in
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: 1, height: 12)
                            .offset(x: position, y: -2)
                    }
                }
            }
            .frame(height: 16)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStageIndex)

            // Stage labels (at dynamic positions)
            GeometryReader { labelGeometry in
                let labelWidth = labelGeometry.size.width
                let boundaries = boundaryPositions(totalWidth: labelWidth)

                ZStack(alignment: .leading) {
                    // 0h at start
                    Text("0h")
                        .font(DesignSystem.Typography.regular(size: 10))
                        .foregroundStyle(.tertiary)

                    // 4h label
                    Text("4h")
                        .font(DesignSystem.Typography.regular(size: 10))
                        .foregroundStyle(durationHours >= 4 ? .secondary : .tertiary)
                        .position(x: boundaries[0], y: 7)

                    // 12h label
                    Text("12h")
                        .font(DesignSystem.Typography.regular(size: 10))
                        .foregroundStyle(durationHours >= 12 ? .secondary : .tertiary)
                        .position(x: boundaries[1], y: 7)

                    // 24h label
                    Text("24h")
                        .font(DesignSystem.Typography.regular(size: 10))
                        .foregroundStyle(durationHours >= 24 ? .secondary : .tertiary)
                        .position(x: boundaries[2], y: 7)
                }
            }
            .frame(height: 14)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStageIndex)
        }
    }

    @ViewBuilder
    private func stageZone(color: Color, widthFraction: Double, width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width * widthFraction)
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [
                ColorPalette.calories.opacity(0.6),
                currentStage == .extended ? Color.orange : ColorPalette.calories
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var markerColor: Color {
        switch currentStage {
        case .fed: return .secondary
        case .earlyFast: return ColorPalette.calories.opacity(0.9)
        case .ketosis: return ColorPalette.calories
        case .extended: return Color.orange
        }
    }
}

// MARK: - Deep Repair Animation Components

/// Animated progress bar for Deep Repair stage with continuous shimmer effect
/// Creates the feeling of ongoing cellular repair benefits accumulating
private struct DeepRepairProgressBar: View {
    let width: CGFloat

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Gradient for the base progress fill
    private var baseGradient: LinearGradient {
        LinearGradient(
            colors: [
                ColorPalette.calories.opacity(0.6),
                Color.orange
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            // Base progress bar (full width)
            Capsule()
                .fill(baseGradient)
                .frame(width: width, height: 8)

            // Animated shimmer overlay (only if motion is allowed)
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 0.016, paused: false)) { timeline in
                    let phase = shimmerPhase(for: timeline.date)

                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: max(0, phase - 0.3)),
                                    .init(color: Color.white.opacity(0.4), location: phase),
                                    .init(color: .clear, location: min(1, phase + 0.3))
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width, height: 8)
                }
            }
        }
    }

    /// Calculate shimmer position (0 to 1) based on time
    /// Wave travels across the bar every 2 seconds
    private func shimmerPhase(for date: Date) -> Double {
        let interval = date.timeIntervalSinceReferenceDate
        // Complete cycle every 2 seconds, offset to start from -0.3 so wave enters from left
        return (interval.truncatingRemainder(dividingBy: 2.0) / 2.0) * 1.6 - 0.3
    }
}

/// Animated marker for Deep Repair stage with pulsing glow effect
private struct DeepRepairMarker: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var glowIntensity: Double = 0.6

    var body: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 16, height: 16)
            .shadow(color: Color.orange.opacity(glowIntensity), radius: 8, x: 0, y: 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 1.0
                }
            }
    }
}

// MARK: - Preview

#Preview("Active Fast - 2h (Digesting)") {
    let fast = Fast(
        startTime: Date().addingTimeInterval(-2 * 3600),
        confirmedAt: Date().addingTimeInterval(-2 * 3600),
        isActive: true
    )
    return ScrollView {
        FastingHeroView(fast: fast, demoMode: false)
            .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Active Fast - 8h (Metabolic Shift)") {
    let fast = Fast(
        startTime: Date().addingTimeInterval(-8 * 3600),
        confirmedAt: Date().addingTimeInterval(-8 * 3600),
        isActive: true
    )
    return ScrollView {
        FastingHeroView(fast: fast, demoMode: false)
            .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Active Fast - 16h (Fat Burning)") {
    let fast = Fast(
        startTime: Date().addingTimeInterval(-16 * 3600),
        confirmedAt: Date().addingTimeInterval(-16 * 3600),
        isActive: true
    )
    return ScrollView {
        FastingHeroView(fast: fast, demoMode: false)
            .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Active Fast - 30h (Deep Repair)") {
    let fast = Fast(
        startTime: Date().addingTimeInterval(-30 * 3600),
        confirmedAt: Date().addingTimeInterval(-30 * 3600),
        isActive: true
    )
    return ScrollView {
        FastingHeroView(fast: fast, demoMode: false)
            .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark Mode") {
    let fast = Fast(
        startTime: Date().addingTimeInterval(-14 * 3600),
        confirmedAt: Date().addingTimeInterval(-14 * 3600),
        isActive: true
    )
    return ScrollView {
        FastingHeroView(fast: fast, demoMode: false)
            .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}
