//
//  LogoParticleSystem.swift
//  Food1
//
//  Particle physics system for the logo formation animation.
//  Uses spring-damper physics to animate particles to their target positions.
//
//  PHYSICS MODEL:
//  - Each particle has: position, velocity, target position
//  - Spring force: F = k * (target - position)
//  - Damping: velocity *= damping each frame
//  - Result: Smooth, organic motion that settles precisely on target
//
//  RENDERING:
//  - Uses Canvas for GPU-efficient drawing at 60fps
//  - Each particle is a small gold circle with gradient
//  - Glow effect builds as particles converge
//

import SwiftUI

// MARK: - Particle

/// Single particle in the formation animation
struct Particle: Identifiable {
    let id: Int

    /// Current position
    var position: CGPoint

    /// Target position (on logo)
    let targetPosition: CGPoint

    /// Current velocity
    var velocity: CGVector

    /// Random delay before particle starts moving (0-0.5s)
    let startDelay: Double

    /// Particle size (2-4pt)
    let size: CGFloat

    /// Whether particle has started moving toward target
    var hasStarted: Bool = false

    /// Color hue offset for subtle variation (gold range)
    let hueOffset: Double
}

// MARK: - Particle System

/// Manages particle physics and state
@Observable
final class LogoParticleSystem {

    // MARK: - Configuration

    /// Spring constant (stiffness) - higher = snappier pull toward target
    let springConstant: CGFloat = 4.0   // Increased from 2.5 for snappier feel

    /// Damping factor (0-1, higher = more damping, lower = bouncier)
    let damping: CGFloat = 0.72         // Decreased from 0.88 for more bounce/energy

    /// Minimum velocity before particle is considered "settled"
    let settleThreshold: CGFloat = 0.3  // Decreased from 0.5 for faster perceived settle

    // MARK: - State

    /// All particles in the system
    var particles: [Particle] = []

    /// Whether the animation has completed
    var isComplete: Bool = false

    /// Animation start time
    private var startTime: Date = .now

    /// Center point for initial particle positions
    private var center: CGPoint = .zero

    /// Target size for the logo
    private var logoSize: CGSize = .zero

    // MARK: - Initialization

    /// Initialize with target points
    /// - Parameters:
    ///   - targetPoints: Points on the logo where particles will converge
    ///   - center: Center point of the view
    ///   - logoSize: Size of the logo
    func initialize(targetPoints: [CGPoint], center: CGPoint, logoSize: CGSize) {
        self.center = center
        self.logoSize = logoSize

        // Calculate offset to center the logo points
        let logoOffset = CGPoint(
            x: center.x - logoSize.width / 2,
            y: center.y - logoSize.height / 2
        )

        // Create particles for each target point
        particles = targetPoints.enumerated().map { index, targetPoint in
            // Offset target point to center
            let offsetTarget = CGPoint(
                x: targetPoint.x + logoOffset.x,
                y: targetPoint.y + logoOffset.y
            )

            // Start particles in a scattered pattern
            let startPosition = randomStartPosition(around: center, radius: 400)

            return Particle(
                id: index,
                position: startPosition,
                targetPosition: offsetTarget,
                velocity: CGVector(dx: 0, dy: 0),
                startDelay: Double.random(in: 0...0.5),
                size: CGFloat.random(in: 2...4),
                hueOffset: Double.random(in: -0.05...0.05)
            )
        }

        startTime = .now
        isComplete = false
    }

    /// Generate a random starting position around a center point
    private func randomStartPosition(around center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = Double(CGFloat.random(in: radius * 0.5...radius))

        return CGPoint(
            x: Double(center.x) + cos(angle) * distance,
            y: Double(center.y) + sin(angle) * distance
        )
    }

    // MARK: - Physics Update

    /// Update all particles for the current frame
    /// - Parameter deltaTime: Time since last update (seconds)
    func update(deltaTime: Double) {
        let elapsed = Date.now.timeIntervalSince(startTime)
        var allSettled = true

        for i in particles.indices {
            var particle = particles[i]

            // Check if particle should start moving
            if !particle.hasStarted {
                if elapsed >= particle.startDelay {
                    particle.hasStarted = true
                } else {
                    particles[i] = particle
                    allSettled = false
                    continue
                }
            }

            // Calculate spring force
            let dx = particle.targetPosition.x - particle.position.x
            let dy = particle.targetPosition.y - particle.position.y

            // Apply spring force to velocity
            particle.velocity.dx += dx * springConstant * deltaTime
            particle.velocity.dy += dy * springConstant * deltaTime

            // Apply damping
            particle.velocity.dx *= damping
            particle.velocity.dy *= damping

            // Update position
            particle.position.x += particle.velocity.dx
            particle.position.y += particle.velocity.dy

            // Check if settled
            let speed = sqrt(
                particle.velocity.dx * particle.velocity.dx +
                particle.velocity.dy * particle.velocity.dy
            )
            if speed > settleThreshold {
                allSettled = false
            }

            particles[i] = particle
        }

        // Mark complete when all particles have settled
        if allSettled && !particles.isEmpty {
            // Snap all particles to exact target positions
            for i in particles.indices {
                particles[i].position = particles[i].targetPosition
            }
            isComplete = true
        }
    }

    // MARK: - Rendering

    /// Draw all particles to a graphics context with white-to-gold color transition.
    /// Particles start white and transition to gold as they approach their targets.
    /// - Parameters:
    ///   - context: Canvas graphics context
    ///   - goldColor: Base gold color for particles (used at end of transition)
    ///   - globalOpacity: Overall opacity multiplier for particles (used for fade-out)
    func draw(in context: inout GraphicsContext, goldColor: Color, globalOpacity: Double = 1.0) {
        let goldHue: Double = 0.12  // Gold hue
        let goldTransitionStart: Double = 0.7  // When particles start turning gold

        for particle in particles where particle.hasStarted {
            // Calculate particle progress toward target (0 = far, 1 = arrived)
            let dx = particle.targetPosition.x - particle.position.x
            let dy = particle.targetPosition.y - particle.position.y
            let distance = sqrt(dx * dx + dy * dy)
            let maxDistance: CGFloat = 400
            let progress = 1 - min(distance / maxDistance, 1)

            // Calculate color transition: white -> gold as particles settle
            // Before goldTransitionStart: pure white
            // After goldTransitionStart: interpolate to gold
            let colorProgress = max(0, (progress - goldTransitionStart) / (1 - goldTransitionStart))

            let color: Color
            if colorProgress <= 0 {
                // Pure white with slight brightness variation
                let brightness = 0.9 + progress * 0.1
                color = Color(hue: 0, saturation: 0, brightness: brightness)
            } else {
                // Interpolate white -> gold
                // As colorProgress goes 0->1, saturation increases and hue shifts to gold
                let hue = goldHue + particle.hueOffset
                let saturation = 0.7 * colorProgress  // Start at 0 (white), end at 0.7 (gold)
                let brightness = 0.95 + colorProgress * 0.05
                color = Color(hue: hue, saturation: saturation, brightness: brightness)
            }

            // Draw particle
            let rect = CGRect(
                x: particle.position.x - particle.size / 2,
                y: particle.position.y - particle.size / 2,
                width: particle.size,
                height: particle.size
            )

            // Glow effect (larger, more transparent circle) - kicks in as particles converge
            if progress > 0.5 {
                let glowSize = particle.size * 2.5  // Larger glow
                let glowRect = CGRect(
                    x: particle.position.x - glowSize / 2,
                    y: particle.position.y - glowSize / 2,
                    width: glowSize,
                    height: glowSize
                )
                // Glow transitions from white to gold too
                let glowColor = colorProgress > 0
                    ? Color(hue: goldHue, saturation: 0.5 * colorProgress, brightness: 1.0)
                    : Color.white
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(glowColor.opacity(0.35 * progress * globalOpacity))
                )
            }

            // Main particle
            context.fill(
                Path(ellipseIn: rect),
                with: .color(color.opacity(globalOpacity))
            )
        }
    }

    /// Calculate overall formation progress (0-1)
    var formationProgress: Double {
        guard !particles.isEmpty else { return 0 }

        let startedParticles = particles.filter { $0.hasStarted }
        guard !startedParticles.isEmpty else { return 0 }

        var totalProgress: Double = 0

        for particle in startedParticles {
            let dx = particle.targetPosition.x - particle.position.x
            let dy = particle.targetPosition.y - particle.position.y
            let distance = sqrt(dx * dx + dy * dy)
            let maxDistance: CGFloat = 400
            let progress = 1 - min(Double(distance) / Double(maxDistance), 1)
            totalProgress += progress
        }

        return totalProgress / Double(startedParticles.count)
    }
}

// MARK: - Preview

#Preview("Particle System Test") {
    struct ParticleSystemPreview: View {
        @State private var system = LogoParticleSystem()
        @State private var isRunning = false

        var body: some View {
            ZStack {
                Color.black

                TimelineView(.animation(minimumInterval: 1/60)) { timeline in
                    Canvas { context, size in
                        system.draw(in: &context, goldColor: Color(hex: "D6AC25"))
                    }
                    .onChange(of: timeline.date) { _, _ in
                        if isRunning {
                            system.update(deltaTime: 1/60)
                        }
                    }
                }

                VStack {
                    Text("Progress: \(Int(system.formationProgress * 100))%")
                        .foregroundStyle(.white)

                    if system.isComplete {
                        Text("Complete!")
                            .foregroundStyle(.green)
                    }

                    Button(isRunning ? "Reset" : "Start") {
                        if isRunning {
                            isRunning = false
                        } else {
                            let sampler = LogoPathSampler(
                                targetSize: CGSize(width: 200, height: 200),
                                pointCount: 500
                            )
                            let points = sampler.samplePoints()
                            system.initialize(
                                targetPoints: points,
                                center: CGPoint(x: 200, y: 400),
                                logoSize: CGSize(width: 200, height: 200)
                            )
                            isRunning = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    return ParticleSystemPreview()
}
