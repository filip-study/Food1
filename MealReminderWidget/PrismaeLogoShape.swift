//
//  PrismaeLogoShape.swift
//  MealReminderWidget
//
//  Prismae logo shape for Live Activities.
//  Copied from main app for widget extension access.
//

import SwiftUI

/// The Prismae logo as a SwiftUI Shape
/// Golden double-chevron design with curved connecting arcs
struct PrismaeLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Original viewBox dimensions from SVG
        let originalWidth: CGFloat = 532.26
        let originalHeight: CGFloat = 558.3

        // Scale factor to fit the rect while maintaining aspect ratio
        let scale = min(rect.width / originalWidth, rect.height / originalHeight)

        // Center the logo in the rect
        let xOffset = (rect.width - originalWidth * scale) / 2
        let yOffset = (rect.height - originalHeight * scale) / 2

        // Helper to transform points
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scale + xOffset, y: y * scale + yOffset)
        }

        // Path 1: Right chevron with curved arc
        path.move(to: point(486.45, 238.75))
        path.addLine(to: point(486.45 - 319.55, 238.75 + 319.55))
        path.addLine(to: point(166.9 + 130.59, 558.3))
        path.addLine(to: point(297.49 + 174.86, 558.3 - 174.86))
        path.addCurve(
            to: point(472.35, 94.18),
            control1: point(552.23, 303.56),
            control2: point(552.23, 174.05)
        )
        path.addLine(to: point(378.17, 0))
        path.addLine(to: point(378.17 - 130.57, 0))
        path.addLine(to: point(247.6 + 238.85, 0 + 238.74))
        path.closeSubpath()

        // Path 2: Left chevron with curved arc
        path.move(to: point(224.75, 94.17))
        path.addLine(to: point(130.57, 0))
        path.addLine(to: point(0, 0))
        path.addLine(to: point(238.85, 238.75))
        path.addLine(to: point(59.11, 418.49))
        path.addLine(to: point(59.11 + 130.59, 418.49))
        path.addLine(to: point(189.7 + 35.05, 418.49 - 35.05))
        path.addCurve(
            to: point(224.75, 94.18),
            control1: point(304.63, 303.57),
            control2: point(304.63, 174.06)
        )
        path.closeSubpath()

        return path
    }
}
