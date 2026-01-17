//
//  CelebrationParticles.swift
//  Food1
//
//  Celebratory particle effects for milestone moments.
//
//  WHY THIS ARCHITECTURE:
//  - Tasteful alternative to generic confetti
//  - Multiple styles: sparkle (subtle), burst (dramatic), cascade (elegant)
//  - Auto-triggers on appear, can be manually triggered
//  - Respects accessibility (reduce motion)
//  - GPU-efficient using Canvas and TimelineView
//

import SwiftUI

// MARK: - Celebration Style

/// Visual styles for celebration particles
enum CelebrationStyle {
    /// Subtle twinkling stars - for quiet achievements
    case sparkle

    /// Dramatic burst from center - for major milestones
    case burst

    /// Elegant falling particles - for completion screens
    case cascade

    /// Rising golden particles - for success/victory
    case rising
}

// MARK: - Celebration Particles

/// Animated celebration particles for milestone moments.
///
/// Example:
/// ```swift
/// ZStack {
///     // Your content
///     CelebrationParticles(style: .burst, trigger: $celebrate)
/// }
/// .onAppear { celebrate = true }
/// ```
struct CelebrationParticles: View {
    var style: CelebrationStyle = .sparkle
    @Binding var trigger: Bool
    var duration: Double = 3.0
    var particleCount: Int = 30

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [CelebrationParticle] = []
    @State private var animationStart: Date = .now

    var body: some View {
        if reduceMotion {
            // Static glow for accessibility
            if trigger {
                staticCelebration
            }
        } else {
            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                Canvas { context, size in
                    guard trigger else { return }

                    let elapsed = timeline.date.timeIntervalSince(animationStart)
                    guard elapsed < duration else { return }

                    let progress = elapsed / duration

                    for particle in particles {
                        drawParticle(
                            context: context,
                            size: size,
                            particle: particle,
                            progress: progress
                        )
                    }
                }
            }
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    animationStart = .now
                    generateParticles()

                    // Auto-reset after duration
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        trigger = false
                    }
                }
            }
        }
    }

    // MARK: - Static Celebration (Accessibility)

    private var staticCelebration: some View {
        ZStack {
            // Golden glow
            RadialGradient(
                colors: [
                    Color(hex: "#F59E0B").opacity(0.3),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 200
            )

            // Checkmark
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color(hex: "#F59E0B"))
        }
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Particle Drawing

    private func drawParticle(
        context: GraphicsContext,
        size: CGSize,
        particle: CelebrationParticle,
        progress: Double
    ) {
        let particleProgress = min(1.0, (progress - particle.delay) / (1.0 - particle.delay))
        guard particleProgress > 0 else { return }

        // Calculate position based on style
        let position = calculatePosition(
            particle: particle,
            size: size,
            progress: particleProgress
        )

        // Calculate opacity (fade out near end)
        let fadeProgress = particleProgress > 0.7 ? (1.0 - particleProgress) / 0.3 : 1.0
        let opacity = particle.baseOpacity * fadeProgress

        // Calculate size (shrink near end for some styles)
        let sizeMultiplier = style == .burst ? (1.0 - particleProgress * 0.5) : 1.0
        let particleSize = particle.size * sizeMultiplier

        // Draw particle
        let rect = CGRect(
            x: position.x - particleSize / 2,
            y: position.y - particleSize / 2,
            width: particleSize,
            height: particleSize
        )

        // Draw with glow effect
        context.fill(
            Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
            with: .color(particle.color.opacity(opacity * 0.3))
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .color(particle.color.opacity(opacity))
        )
    }

    private func calculatePosition(
        particle: CelebrationParticle,
        size: CGSize,
        progress: Double
    ) -> CGPoint {
        let centerX = size.width / 2
        let centerY = size.height / 2

        switch style {
        case .sparkle:
            // Random twinkling positions
            let drift = sin(progress * .pi * 2) * 10
            return CGPoint(
                x: particle.startX * size.width + drift,
                y: particle.startY * size.height
            )

        case .burst:
            // Explode from center
            let distance = progress * particle.velocity * 150
            let x = centerX + cos(particle.angle) * distance
            let y = centerY + sin(particle.angle) * distance
            return CGPoint(x: x, y: y)

        case .cascade:
            // Fall from top with horizontal drift
            let drift = sin(progress * .pi * particle.velocity) * 50
            return CGPoint(
                x: particle.startX * size.width + drift,
                y: -20 + progress * (size.height + 40)
            )

        case .rising:
            // Rise from bottom with gentle curve
            let drift = sin(progress * .pi * 2) * 30
            return CGPoint(
                x: particle.startX * size.width + drift,
                y: size.height + 20 - progress * (size.height + 40)
            )
        }
    }

    // MARK: - Particle Generation

    private func generateParticles() {
        particles = (0..<particleCount).map { i in
            CelebrationParticle(
                id: i,
                startX: Double.random(in: 0...1),
                startY: Double.random(in: 0...1),
                angle: Double.random(in: 0...(.pi * 2)),
                velocity: Double.random(in: 0.5...1.5),
                size: Double.random(in: 4...10),
                baseOpacity: Double.random(in: 0.6...1.0),
                delay: Double.random(in: 0...0.3),
                color: celebrationColor
            )
        }
    }

    private var celebrationColor: Color {
        let colors: [Color] = [
            Color(hex: "#F59E0B"), // Amber
            Color(hex: "#FCD34D"), // Gold
            Color(hex: "#FBBF24"), // Yellow
            .white
        ]
        return colors.randomElement() ?? .white
    }
}

// MARK: - Particle Model

private struct CelebrationParticle: Identifiable {
    let id: Int
    let startX: Double
    let startY: Double
    let angle: Double
    let velocity: Double
    let size: Double
    let baseOpacity: Double
    let delay: Double
    let color: Color
}

// MARK: - Simple Trigger Variant

/// Auto-triggering celebration that starts on appear
struct AutoCelebrationParticles: View {
    var style: CelebrationStyle = .sparkle
    var duration: Double = 3.0
    var particleCount: Int = 30

    @State private var trigger = false

    var body: some View {
        CelebrationParticles(
            style: style,
            trigger: $trigger,
            duration: duration,
            particleCount: particleCount
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                trigger = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Sparkle") {
    ZStack {
        Color.black.ignoresSafeArea()
        AutoCelebrationParticles(style: .sparkle, duration: 5)
    }
}

#Preview("Burst") {
    ZStack {
        Color.black.ignoresSafeArea()
        AutoCelebrationParticles(style: .burst, duration: 3, particleCount: 50)
    }
}

#Preview("Cascade") {
    ZStack {
        Color.black.ignoresSafeArea()
        AutoCelebrationParticles(style: .cascade, duration: 4)
    }
}

#Preview("Rising") {
    ZStack {
        Color.black.ignoresSafeArea()
        AutoCelebrationParticles(style: .rising, duration: 4, particleCount: 40)
    }
}
