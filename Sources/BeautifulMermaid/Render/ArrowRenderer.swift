// SPDX-License-Identifier: MIT
//
//  ArrowRenderer.swift
//  BeautifulMermaid
//
//  Specialized arrow head rendering
//

import Foundation
import CoreGraphics

/// Creates arrow head paths for different arrow styles
public struct ArrowRenderer {

    /// Create a path for an arrow head
    public static func createArrowPath(
        style: ArrowHead,
        at point: CGPoint,
        angle: CGFloat,
        size: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()

        switch style {
        case .none:
            return path

        case .arrow:
            // Filled triangle pointing right (will be rotated)
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -size, y: -size / 2))
            path.addLine(to: CGPoint(x: -size, y: size / 2))
            path.closeSubpath()

        case .open:
            // V-shaped open arrow
            path.move(to: CGPoint(x: -size, y: -size / 2))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -size, y: size / 2))

        case .circle:
            // Circle marker
            let circleSize = size * 0.6
            path.addEllipse(in: CGRect(
                x: -circleSize,
                y: -circleSize / 2,
                width: circleSize,
                height: circleSize
            ))

        case .cross:
            // X marker
            let crossSize = size * 0.4
            path.move(to: CGPoint(x: -crossSize * 2, y: -crossSize))
            path.addLine(to: CGPoint(x: 0, y: crossSize))
            path.move(to: CGPoint(x: -crossSize * 2, y: crossSize))
            path.addLine(to: CGPoint(x: 0, y: -crossSize))

        case .diamond:
            // Diamond/rhombus marker
            let diamondSize = size * 0.7
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -diamondSize, y: -diamondSize / 2))
            path.addLine(to: CGPoint(x: -diamondSize * 2, y: 0))
            path.addLine(to: CGPoint(x: -diamondSize, y: diamondSize / 2))
            path.closeSubpath()
        }

        // Transform to position and angle
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: point.x, y: point.y)
        transform = transform.rotated(by: angle)

        return path.copy(using: &transform) ?? path
    }

    /// Calculate the offset to apply to edge endpoint to account for arrow head
    public static func arrowHeadOffset(style: ArrowHead, lineWidth: CGFloat) -> CGFloat {
        guard style != .none else { return 0 }

        let size = lineWidth * style.sizeMultiplier

        switch style {
        case .none:
            return 0
        case .arrow, .diamond:
            return size
        case .open:
            return size * 0.5
        case .circle:
            return size * 0.6
        case .cross:
            return size * 0.4
        }
    }

    /// Get the bounding box of an arrow head
    public static func arrowHeadBounds(
        style: ArrowHead,
        at point: CGPoint,
        angle: CGFloat,
        lineWidth: CGFloat
    ) -> CGRect {
        guard style != .none else {
            return CGRect(origin: point, size: .zero)
        }

        let size = lineWidth * style.sizeMultiplier
        let path = createArrowPath(style: style, at: point, angle: angle, size: size)

        return path.boundingBox
    }
}
