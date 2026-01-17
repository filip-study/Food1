//
//  LogoPathSampler.swift
//  Food1
//
//  Extracts evenly-spaced sample points from the Prismae logo bezier paths.
//  These points become targets for the particle formation animation.
//
//  ALGORITHM:
//  1. Get the logo path from PrismaeLogoShape
//  2. Walk along the path, sampling points at regular intervals
//  3. Return array of CGPoints that define the logo silhouette
//
//  NOTE: Path sampling in SwiftUI is non-trivial because Path doesn't expose
//  arc-length parameterization. We approximate by subdividing bezier curves.
//

import SwiftUI

// MARK: - Logo Path Sampler

/// Samples evenly-spaced points from the Prismae logo path
struct LogoPathSampler {

    /// Target size for the logo (points will be scaled to this)
    let targetSize: CGSize

    /// Number of points to sample from the logo
    let pointCount: Int

    /// Initialize with target size and desired point count
    /// - Parameters:
    ///   - targetSize: Size to fit the logo into
    ///   - pointCount: Number of points to sample (default 1000)
    init(targetSize: CGSize, pointCount: Int = 1000) {
        self.targetSize = targetSize
        self.pointCount = pointCount
    }

    /// Sample points from the logo path
    /// - Returns: Array of CGPoints representing the logo silhouette
    func samplePoints() -> [CGPoint] {
        // Get the logo path at target size
        let rect = CGRect(origin: .zero, size: targetSize)
        let logoPath = PrismaeLogoShape().path(in: rect)

        // Sample points along the path
        return samplePointsFromPath(logoPath, count: pointCount)
    }

    /// Sample points evenly distributed along a path
    private func samplePointsFromPath(_ path: Path, count: Int) -> [CGPoint] {
        // First, collect all the path elements
        var elements: [PathElement] = []
        path.forEach { element in
            elements.append(element)
        }

        // Flatten bezier curves into line segments for easier sampling
        let segments = flattenPathElements(elements)

        // Calculate total path length
        let totalLength = calculateTotalLength(segments)

        guard totalLength > 0 else { return [] }

        // Sample points at regular intervals
        let interval = totalLength / Double(count)
        var points: [CGPoint] = []
        var currentLength: Double = 0
        var targetLength: Double = 0

        for i in 0..<count {
            targetLength = Double(i) * interval

            // Find the point at this length along the path
            if let point = pointAtLength(targetLength, segments: segments) {
                points.append(point)
            }
        }

        return points
    }

    /// Flatten path elements into simple line segments
    private func flattenPathElements(_ elements: [PathElement]) -> [LineSegment] {
        var segments: [LineSegment] = []
        var currentPoint: CGPoint = .zero

        for element in elements {
            switch element {
            case .move(to: let point):
                currentPoint = point

            case .line(to: let point):
                segments.append(LineSegment(start: currentPoint, end: point))
                currentPoint = point

            case .quadCurve(to: let end, control: let control):
                // Subdivide quadratic bezier into line segments
                let subdivisions = 10
                for i in 0..<subdivisions {
                    let t0 = Double(i) / Double(subdivisions)
                    let t1 = Double(i + 1) / Double(subdivisions)
                    let p0 = quadraticBezierPoint(t: t0, start: currentPoint, control: control, end: end)
                    let p1 = quadraticBezierPoint(t: t1, start: currentPoint, control: control, end: end)
                    segments.append(LineSegment(start: p0, end: p1))
                }
                currentPoint = end

            case .curve(to: let end, control1: let c1, control2: let c2):
                // Subdivide cubic bezier into line segments
                let subdivisions = 15
                for i in 0..<subdivisions {
                    let t0 = Double(i) / Double(subdivisions)
                    let t1 = Double(i + 1) / Double(subdivisions)
                    let p0 = cubicBezierPoint(t: t0, start: currentPoint, control1: c1, control2: c2, end: end)
                    let p1 = cubicBezierPoint(t: t1, start: currentPoint, control1: c1, control2: c2, end: end)
                    segments.append(LineSegment(start: p0, end: p1))
                }
                currentPoint = end

            case .closeSubpath:
                // Close path handled by returning to first point
                break
            }
        }

        return segments
    }

    /// Calculate total length of all segments
    private func calculateTotalLength(_ segments: [LineSegment]) -> Double {
        segments.reduce(0) { $0 + $1.length }
    }

    /// Find point at a specific length along the path
    private func pointAtLength(_ targetLength: Double, segments: [LineSegment]) -> CGPoint? {
        var accumulatedLength: Double = 0

        for segment in segments {
            let segmentLength = segment.length

            if accumulatedLength + segmentLength >= targetLength {
                // Point is within this segment
                let remainingLength = targetLength - accumulatedLength
                let t = segmentLength > 0 ? remainingLength / segmentLength : 0
                return segment.pointAt(t: t)
            }

            accumulatedLength += segmentLength
        }

        // Return last point if we've gone past the end
        return segments.last?.end
    }

    // MARK: - Bezier Helpers

    /// Evaluate quadratic bezier at parameter t
    private func quadraticBezierPoint(t: Double, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
        let mt = 1 - t
        let x = mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x
        let y = mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }

    /// Evaluate cubic bezier at parameter t
    private func cubicBezierPoint(t: Double, start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t

        let x = mt3 * start.x + 3 * mt2 * t * control1.x + 3 * mt * t2 * control2.x + t3 * end.x
        let y = mt3 * start.y + 3 * mt2 * t * control1.y + 3 * mt * t2 * control2.y + t3 * end.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Path Element

/// Represents a single element of a SwiftUI Path
enum PathElement {
    case move(to: CGPoint)
    case line(to: CGPoint)
    case quadCurve(to: CGPoint, control: CGPoint)
    case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
    case closeSubpath
}

// MARK: - Path Extension for Element Extraction

extension Path {
    /// Iterate over path elements
    func forEach(_ body: (PathElement) -> Void) {
        // Use CGPath's apply method
        let cgPath = self.cgPath

        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee

            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                body(.move(to: point))

            case .addLineToPoint:
                let point = element.points[0]
                body(.line(to: point))

            case .addQuadCurveToPoint:
                let control = element.points[0]
                let end = element.points[1]
                body(.quadCurve(to: end, control: control))

            case .addCurveToPoint:
                let c1 = element.points[0]
                let c2 = element.points[1]
                let end = element.points[2]
                body(.curve(to: end, control1: c1, control2: c2))

            case .closeSubpath:
                body(.closeSubpath)

            @unknown default:
                break
            }
        }
    }
}

// MARK: - Line Segment

/// Simple line segment for path calculations
struct LineSegment {
    let start: CGPoint
    let end: CGPoint

    var length: Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }

    func pointAt(t: Double) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t
        )
    }
}

// MARK: - Preview Helper

#Preview("Sampled Points Visualization") {
    GeometryReader { geometry in
        let size = min(geometry.size.width, geometry.size.height) * 0.8
        let sampler = LogoPathSampler(
            targetSize: CGSize(width: size, height: size),
            pointCount: 500
        )
        let points = sampler.samplePoints()

        ZStack {
            Color.black

            // Draw sampled points
            Canvas { context, canvasSize in
                let offsetX = (canvasSize.width - size) / 2
                let offsetY = (canvasSize.height - size) / 2

                for (index, point) in points.enumerated() {
                    let hue = Double(index) / Double(points.count)
                    let color = Color(hue: hue, saturation: 1, brightness: 1)

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: point.x + offsetX - 1.5,
                            y: point.y + offsetY - 1.5,
                            width: 3,
                            height: 3
                        )),
                        with: .color(color)
                    )
                }
            }

            Text("\(points.count) points sampled")
                .foregroundStyle(.white)
                .font(.caption)
                .padding()
                .background(.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding()
        }
    }
}
