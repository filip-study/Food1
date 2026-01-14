//
//  SmartCropView.swift
//  Food1
//
//  Photo crop interface for gallery photos with multiple food items
//  Allows user to zoom/pan to focus on specific food before AI analysis
//
//  REDESIGNED: Native SwiftUI gestures, simplified state, iOS-native patterns
//

import SwiftUI

struct SmartCropView: View {
    let originalImage: UIImage
    let onCropComplete: (UIImage) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // Single source of truth for zoom/pan
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    // Gesture state (auto-resets when gesture ends)
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureOffset: CGSize = .zero

    // Interaction feedback
    @State private var isInteracting: Bool = false
    @State private var showZoomLevel: Bool = false

    // Geometry tracking for accurate crop calculations
    @State private var viewSize: CGSize = .zero
    @State private var cropFrameSize: CGFloat = 0

    var body: some View {
        ZStack {
            // Soft dark background
            Color(white: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer()

                // Main crop area
                cropArea

                Spacer()

                // Instructions
                instructionText

                // Action button
                analyzeButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }

            // Zoom level indicator
            if showZoomLevel {
                zoomLevelBadge
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - View Components

    private var topBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }

            Spacer()

            // Reset button (appears when zoomed/panned)
            if scale > 1.01 || offset != .zero {
                Button(action: resetTransform) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: offset)
    }

    private var cropArea: some View {
        GeometryReader { geometry in
            let frameSize = min(geometry.size.width, geometry.size.height) * 0.85
            let totalScale = scale * gestureScale
            let totalOffset = CGSize(
                width: offset.width + gestureOffset.width,
                height: offset.height + gestureOffset.height
            )

            ZStack {
                // Full-screen interactive image with zoom/pan
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(totalScale)
                    .offset(totalOffset)
                    .gesture(
                        magnificationGesture
                            .simultaneously(with: dragGesture)
                    )
                    .gesture(doubleTapGesture) // Separate gesture for double-tap

                // Dark overlay showing excluded area
                DimmedOverlay(frameSize: frameSize, isInteracting: isInteracting)

                // Crop frame with dynamic grid
                CropFrame(frameSize: frameSize, isInteracting: isInteracting)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear {
                viewSize = geometry.size
                cropFrameSize = frameSize
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
                cropFrameSize = min(newSize.width, newSize.height) * 0.85
            }
        }
        .padding(.horizontal, 16)
    }

    private var instructionText: some View {
        Group {
            if scale <= 1.01 && offset == .zero {
                Text("Pinch to zoom • Drag to pan • Double-tap to zoom")
                    .font(DesignSystem.Typography.medium(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
            } else {
                Text("Position the specific food in the frame")
                    .font(DesignSystem.Typography.medium(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
            }
        }
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.2), value: scale)
        .animation(.easeInOut(duration: 0.2), value: offset)
    }

    private var analyzeButton: some View {
        Button(action: analyzeCroppedImage) {
            HStack(spacing: 12) {
                Text("Use This Area")
                    .font(DesignSystem.Typography.semiBold(size: 17))

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [.white, .white.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10)
        }
    }

    private var zoomLevelBadge: some View {
        VStack {
            Text(String(format: "%.1f×", scale))
                .font(DesignSystem.Typography.bold(size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 8)
                )
                .padding(.top, 80)

            Spacer()
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onChanged { _ in
                if !isInteracting {
                    withAnimation(.easeOut(duration: 0.1)) {
                        isInteracting = true
                        showZoomLevel = true
                    }
                }
            }
            .onEnded { value in
                let newScale = scale * value

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    // Clamp scale between 1.0 and 5.0
                    if newScale < 1.0 {
                        scale = 1.0
                        offset = .zero // Reset offset when zooming out fully

                        // Haptic feedback for snap back
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } else {
                        scale = min(5.0, newScale)
                    }

                    isInteracting = false
                }

                // Hide zoom level after delay
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    withAnimation(.easeOut(duration: 0.2)) {
                        showZoomLevel = false
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                if !isInteracting {
                    withAnimation(.easeOut(duration: 0.1)) {
                        isInteracting = true
                    }
                }
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    offset.width += value.translation.width
                    offset.height += value.translation.height

                    // Apply bounds to prevent panning too far
                    offset = constrainOffset(offset, scale: scale)

                    isInteracting = false
                }
            }
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    if scale > 1.5 {
                        // Zoom out to 1.0
                        scale = 1.0
                        offset = .zero
                    } else {
                        // Zoom in to 2.0
                        scale = 2.0
                    }
                }
            }
    }

    // MARK: - Actions

    private func resetTransform() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            scale = 1.0
            offset = .zero
        }
    }

    private func constrainOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        // Don't constrain at 1.0 scale
        guard scale > 1.0 else { return .zero }

        // Simple bounds - prevent excessive panning
        // This creates a "rubber band" effect at edges
        let maxOffset = viewSize.width * 0.3 * scale

        return CGSize(
            width: min(maxOffset, max(-maxOffset, offset.width)),
            height: min(maxOffset, max(-maxOffset, offset.height))
        )
    }

    private func analyzeCroppedImage() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Calculate crop based on current zoom/pan with actual geometry
        if let croppedImage = performCrop(viewSize: viewSize, cropFrameSize: cropFrameSize) {
            onCropComplete(croppedImage)
        } else {
            // Fallback to original if crop fails
            onCropComplete(originalImage)
        }
    }

    // MARK: - Cropping Logic

    private func performCrop(viewSize: CGSize, cropFrameSize: CGFloat) -> UIImage? {
        // If no zoom/pan, return original
        if scale == 1.0 && offset == .zero {
            return originalImage
        }

        // Get image dimensions
        let imageSize = originalImage.size
        let imageAspect = imageSize.width / imageSize.height

        // Calculate displayed image size (scaledToFit within viewSize)
        let viewAspect = viewSize.width / viewSize.height
        var displayedSize: CGSize

        if imageAspect > viewAspect {
            // Image is wider - constrained by width
            displayedSize = CGSize(
                width: viewSize.width,
                height: viewSize.width / imageAspect
            )
        } else {
            // Image is taller - constrained by height
            displayedSize = CGSize(
                width: viewSize.height * imageAspect,
                height: viewSize.height
            )
        }

        // Apply current scale to displayed size
        let scaledDisplaySize = CGSize(
            width: displayedSize.width * scale,
            height: displayedSize.height * scale
        )

        // Calculate the position of the scaled image in the view
        // (centered, then offset by user pan)
        let imagePositionInView = CGPoint(
            x: (viewSize.width - scaledDisplaySize.width) / 2 + offset.width,
            y: (viewSize.height - scaledDisplaySize.height) / 2 + offset.height
        )

        // Crop frame is centered in the view
        let cropFrameOrigin = CGPoint(
            x: (viewSize.width - cropFrameSize) / 2,
            y: (viewSize.height - cropFrameSize) / 2
        )

        // Calculate crop frame position relative to the displayed image
        let cropInImageView = CGRect(
            x: cropFrameOrigin.x - imagePositionInView.x,
            y: cropFrameOrigin.y - imagePositionInView.y,
            width: cropFrameSize,
            height: cropFrameSize
        )

        // Convert to original image coordinates
        let scaleToOriginal = imageSize.width / scaledDisplaySize.width
        let cropRect = CGRect(
            x: cropInImageView.origin.x * scaleToOriginal,
            y: cropInImageView.origin.y * scaleToOriginal,
            width: cropInImageView.width * scaleToOriginal,
            height: cropInImageView.height * scaleToOriginal
        )

        // Clamp to image bounds
        let clampedRect = CGRect(
            x: max(0, cropRect.origin.x),
            y: max(0, cropRect.origin.y),
            width: min(cropRect.width, imageSize.width - max(0, cropRect.origin.x)),
            height: min(cropRect.height, imageSize.height - max(0, cropRect.origin.y))
        )

        // Handle image orientation for cropping
        guard let orientedImage = originalImage.fixOrientation(),
              let cgImage = orientedImage.cgImage?.cropping(to: clampedRect) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: .up)
    }
}

// MARK: - Visual Feedback Components

/// Semi-transparent overlay that darkens everything outside the crop frame
struct DimmedOverlay: View {
    let frameSize: CGFloat
    let isInteracting: Bool

    var body: some View {
        ZStack {
            // Full screen dark overlay
            Rectangle()
                .fill(Color.black.opacity(isInteracting ? 0.6 : 0.5))
                .animation(.easeInOut(duration: 0.2), value: isInteracting)

            // Punch out the crop area to show image clearly
            RoundedRectangle(cornerRadius: 20)
                .frame(width: frameSize, height: frameSize)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

/// Crop frame with dynamic grid (appears during interaction)
struct CropFrame: View {
    let frameSize: CGFloat
    let isInteracting: Bool

    var body: some View {
        ZStack {
            // Main border
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white, lineWidth: 2.5)
                .frame(width: frameSize, height: frameSize)
                .shadow(color: .white.opacity(0.3), radius: 4)

            // Dynamic grid (rule of thirds)
            if isInteracting {
                GridOverlay(frameSize: frameSize)
                    .transition(.opacity)
            }

            // Corner indicators
            ForEach(0..<4) { corner in
                CornerIndicator(rotation: cornerRotation(corner: corner))
                    .frame(width: 24, height: 24)
                    .offset(cornerOffset(corner: corner, size: frameSize))
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.2), value: isInteracting)
    }

    private func cornerOffset(corner: Int, size: CGFloat) -> CGSize {
        let half = size / 2
        let inset: CGFloat = 12
        switch corner {
        case 0: return CGSize(width: -half + inset, height: -half + inset) // Top-left
        case 1: return CGSize(width: half - inset, height: -half + inset)  // Top-right
        case 2: return CGSize(width: -half + inset, height: half - inset)  // Bottom-left
        case 3: return CGSize(width: half - inset, height: half - inset)   // Bottom-right
        default: return .zero
        }
    }

    private func cornerRotation(corner: Int) -> Angle {
        switch corner {
        case 0: return .degrees(0)     // Top-left
        case 1: return .degrees(90)    // Top-right
        case 2: return .degrees(-90)   // Bottom-left
        case 3: return .degrees(180)   // Bottom-right
        default: return .degrees(0)
        }
    }
}

/// Rule of thirds grid overlay (appears during interaction)
struct GridOverlay: View {
    let frameSize: CGFloat

    var body: some View {
        ZStack {
            // Vertical lines
            ForEach(1..<3) { i in
                Path { path in
                    let x = frameSize * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: frameSize))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
            }

            // Horizontal lines
            ForEach(1..<3) { i in
                Path { path in
                    let y = frameSize * CGFloat(i) / 3
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: frameSize, y: y))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
            }
        }
        .frame(width: frameSize, height: frameSize)
    }
}

/// L-shaped corner indicator showing crop boundaries
struct CornerIndicator: View {
    let rotation: Angle

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 6))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 6, y: 0))
        }
        .stroke(Color.white, lineWidth: 2.5)
        .rotationEffect(rotation)
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Normalizes image orientation by redrawing with correct orientation
    /// Required for proper cropping of images with EXIF orientation data
    func fixOrientation() -> UIImage? {
        // Already correct orientation
        if imageOrientation == .up {
            return self
        }

        // Redraw image with correct orientation
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage
    }
}
