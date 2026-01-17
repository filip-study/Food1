//
//  ParticleFormationView.swift
//  Food1
//
//  Premium particle formation animation for the welcome screen.
//  Thousands of particles swirl and coalesce into the Prismae logo.
//
//  TIMELINE (optimized for snappier feel):
//  0.0s - 1.0s: Particles swirl chaotically, quickly moving toward center
//  1.0s - 2.0s: Particles find their target positions, form logo shape
//  2.0s - 2.5s: Logo solidifies, white-to-gold transition completes
//  2.5s - 2.8s: Hold for completion callback
//
//  SMOOTH TRANSITION (v2):
//  - Logo starts fading in at 50% progress (behind particles)
//  - Particles fade out starting at 60% progress
//  - Cross-dissolve creates seamless blend from particles to solid logo
//  - No jarring "pop" when switching from dots to filled shape
//
//  ACCESSIBILITY:
//  - Reduced motion: Shows static logo immediately
//  - VoiceOver: Announces "Prismae logo"
//

import SwiftUI

// MARK: - Particle Formation View

struct ParticleFormationView: View {

    // MARK: - Properties

    /// Size of the logo
    var logoSize: CGFloat = 160

    /// Number of particles (more = denser, slower)
    var particleCount: Int = 800

    /// Callback when animation completes
    var onComplete: (() -> Void)?

    // MARK: - State

    @State private var particleSystem = LogoParticleSystem()
    @State private var isAnimating = false
    @State private var showStaticLogo = false
    @State private var logoOpacity: Double = 0
    @State private var glowIntensity: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Prismae golden brand color
    private let goldColor = Color(hex: "D6AC25")

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )

            ZStack {
                if reduceMotion || showStaticLogo {
                    // Static logo for reduced motion or after animation
                    staticLogoView
                        .opacity(logoOpacity)
                        .position(center)
                } else {
                    // Particle animation
                    particleAnimationView(center: center, size: geometry.size)
                }
            }
            .onAppear {
                startAnimation(center: center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prismae logo")
    }

    // MARK: - Static Logo View

    private var staticLogoView: some View {
        ZStack {
            // Glow behind logo
            PrismaeLogoShape()
                .fill(goldColor.opacity(glowIntensity * 0.4))
                .blur(radius: 30)
                .frame(width: logoSize, height: logoSize)

            // Main logo
            PrismaeLogo(size: logoSize, animated: false)
        }
    }

    // MARK: - Particle Animation View

    private func particleAnimationView(center: CGPoint, size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, canvasSize in
                let progress = particleSystem.formationProgress

                // Calculate logo opacity - starts fading in at 50%, fully opaque by 90%
                let logoFadeStart: Double = 0.5
                let logoFadeEnd: Double = 0.9
                let logoOpacity = progress <= logoFadeStart ? 0 :
                    min(1, (progress - logoFadeStart) / (logoFadeEnd - logoFadeStart))

                // Calculate particle opacity - starts fading out at 60%, nearly gone by 95%
                let particleFadeStart: Double = 0.6
                let particleFadeEnd: Double = 0.95
                let particleOpacity = progress >= particleFadeEnd ? 0.1 :
                    progress <= particleFadeStart ? 1 :
                    1 - ((progress - particleFadeStart) / (particleFadeEnd - particleFadeStart)) * 0.9

                // Draw logo underneath particles (builds up as particles settle)
                if logoOpacity > 0 {
                    let logoRect = CGRect(
                        x: center.x - logoSize / 2,
                        y: center.y - logoSize / 2,
                        width: logoSize,
                        height: logoSize
                    )

                    // Glow behind logo
                    context.drawLayer { ctx in
                        ctx.opacity = logoOpacity * 0.4
                        ctx.fill(
                            PrismaeLogoShape().path(in: logoRect),
                            with: .color(goldColor)
                        )
                        ctx.addFilter(.blur(radius: 25))
                    }

                    // Solid logo with gradient
                    context.drawLayer { ctx in
                        ctx.opacity = logoOpacity
                        ctx.fill(
                            PrismaeLogoShape().path(in: logoRect),
                            with: .color(goldColor)
                        )
                    }
                }

                // Draw particles on top with fading opacity
                var mutableContext = context
                particleSystem.draw(in: &mutableContext, goldColor: goldColor, globalOpacity: particleOpacity)
            }
            .onChange(of: timeline.date) { _, _ in
                updateAnimation()
            }
        }
    }

    // MARK: - Animation Control

    private func startAnimation(center: CGPoint) {
        if reduceMotion {
            // Skip animation for reduced motion
            logoOpacity = 1
            glowIntensity = 0.5
            showStaticLogo = true

            // Still call completion after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete?()
            }
            return
        }

        // Sample points from logo
        let sampler = LogoPathSampler(
            targetSize: CGSize(width: logoSize, height: logoSize),
            pointCount: particleCount
        )
        let targetPoints = sampler.samplePoints()

        // Initialize particle system
        particleSystem.initialize(
            targetPoints: targetPoints,
            center: center,
            logoSize: CGSize(width: logoSize, height: logoSize)
        )

        isAnimating = true

        // Schedule completion - reduced from 4.0s to 2.8s for snappier feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            completeAnimation()
        }
    }

    private func updateAnimation() {
        guard isAnimating else { return }

        // Update physics
        particleSystem.update(deltaTime: 1/60)

        // Check for early completion
        if particleSystem.isComplete && !showStaticLogo {
            completeAnimation()
        }
    }

    private func completeAnimation() {
        guard !showStaticLogo else { return }

        isAnimating = false

        // Fade in static logo
        withAnimation(.easeOut(duration: 0.5)) {
            showStaticLogo = true
            logoOpacity = 1
            glowIntensity = 0.6
        }

        // Haptic feedback
        HapticManager.success()

        // Glow settles
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            glowIntensity = 0.4
        }

        // Call completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete?()
        }
    }
}

// MARK: - Preview

#Preview("Particle Formation") {
    ZStack {
        BrandGradientBackground()

        ParticleFormationView(logoSize: 180, particleCount: 600) {
            print("Animation complete!")
        }
    }
}

#Preview("Particle Formation - Dark") {
    ZStack {
        Color.black

        ParticleFormationView(logoSize: 200, particleCount: 800) {
            print("Complete")
        }
    }
}

// Note: Reduced motion preview requires running on device with accessibility settings enabled
