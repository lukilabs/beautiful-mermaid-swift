// SPDX-License-Identifier: MIT
//
//  ShapeBounds.swift
//  BeautifulMermaid
//
//  Shape boundary calculations for node shapes
//

import Foundation
import CoreGraphics

/// Calculates boundary points for different node shapes
public struct ShapeBounds {

    /// Calculate the intersection point of a line from the center to an external point
    /// with the shape boundary
    public static func intersectionPoint(
        shape: NodeShape,
        bounds: CGRect,
        from center: CGPoint,
        to external: CGPoint
    ) -> CGPoint {
        switch shape {
        case .circle, .stateStart, .stateEnd, .stateChoice:
            return circleIntersection(bounds: bounds, from: center, to: external)

        case .diamond, .rhombus:
            return diamondIntersection(bounds: bounds, from: center, to: external)

        case .hexagon:
            return hexagonIntersection(bounds: bounds, from: center, to: external)

        case .stadium:
            return stadiumIntersection(bounds: bounds, from: center, to: external)

        case .rounded, .cylinder:
            return roundedRectIntersection(bounds: bounds, cornerRadius: 8, from: center, to: external)

        case .parallelogram, .parallelogramAlt:
            return parallelogramIntersection(bounds: bounds, from: center, to: external)

        case .trapezoid, .trapezoidAlt:
            return trapezoidIntersection(bounds: bounds, from: center, to: external)

        case .asymmetric:
            return asymmetricIntersection(bounds: bounds, from: center, to: external)

        case .stateFork:
            return rectIntersection(bounds: bounds, from: center, to: external)

        default:
            return rectIntersection(bounds: bounds, from: center, to: external)
        }
    }

    // MARK: - Shape-specific Intersection Calculations

    private static func rectIntersection(bounds: CGRect, from center: CGPoint, to external: CGPoint) -> CGPoint {
        let direction = external - center
        guard direction.magnitude > 0 else { return center }

        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2

        // Calculate intersection with each edge and return the closest
        var tMin: CGFloat = .infinity

        // Right edge
        if direction.x > 0 {
            let t = halfWidth / direction.x
            if t < tMin { tMin = t }
        }
        // Left edge
        if direction.x < 0 {
            let t = -halfWidth / direction.x
            if t < tMin { tMin = t }
        }
        // Bottom edge
        if direction.y > 0 {
            let t = halfHeight / direction.y
            if t < tMin { tMin = t }
        }
        // Top edge
        if direction.y < 0 {
            let t = -halfHeight / direction.y
            if t < tMin { tMin = t }
        }

        return center + direction * tMin
    }

    private static func circleIntersection(bounds: CGRect, from center: CGPoint, to external: CGPoint) -> CGPoint {
        let radius = min(bounds.width, bounds.height) / 2
        let direction = (external - center).normalized
        return center + direction * radius
    }

    private static func diamondIntersection(bounds: CGRect, from center: CGPoint, to external: CGPoint) -> CGPoint {
        let direction = external - center
        guard direction.magnitude > 0 else { return center }

        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2

        // Diamond has 4 edges forming an X pattern
        // Using parametric line intersection
        let absX = abs(direction.x)
        let absY = abs(direction.y)

        // Normalize by diamond dimensions
        let scaledX = absX / halfWidth
        let scaledY = absY / halfHeight
        let sum = scaledX + scaledY

        guard sum > 0 else { return center }

        let t = 1.0 / sum
        return center + direction * t
    }

    private static func hexagonIntersection(bounds: CGRect, from center: CGPoint, to external: CGPoint) -> CGPoint {
        let direction = external - center
        guard direction.magnitude > 0 else { return center }

        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        let sideInset = bounds.width * 0.25 // Hexagon inset

        // For simplicity, use rect approximation with slightly reduced width
        let effectiveBounds = CGRect(
            x: bounds.minX + sideInset/2,
            y: bounds.minY,
            width: bounds.width - sideInset,
            height: bounds.height
        )

        // More accurate would involve checking 6 edge segments
        return rectIntersection(bounds: bounds, from: center, to: external)
    }

    private static func stadiumIntersection(bounds: CGRect, from center: CGPoint, to external: CGPoint) -> CGPoint {
        let cornerRadius = bounds.height / 2
        return roundedRectIntersection(bounds: bounds, cornerRadius: cornerRadius, from: center, to: external)
    }

    private static func roundedRectIntersection(bounds: CGRect, cornerRadius: CGFloat, from center: CGPoint, to external: CGPoint) -> CGPoint {
        // Simplified: use rect intersection with slight inset
        let direction = external - center
        guard direction.magnitude > 0 else { return center }

        // First get rect intersection
        let rectPoint = rectIntersection(bounds: bounds, from: center, to: external)

        // Check if intersection is in corner region and adjust
        let insetBounds = bounds.insetBy(dx: cornerRadius, dy: cornerRadius)

        let inCorner = (rectPoint.x < insetBounds.minX || rectPoint.x > insetBounds.maxX) &&
                       (rectPoint.y < insetBounds.minY || rectPoint.y > insetBounds.maxY)

        if inCorner {
            // Find nearest corner center and intersect with arc
            var cornerCenter = CGPoint.zero
            if rectPoint.x < center.x {
                cornerCenter.x = insetBounds.minX
            } else {
                cornerCenter.x = insetBounds.maxX
            }
            if rectPoint.y < center.y {
                cornerCenter.y = insetBounds.minY
            } else {
                cornerCenter.y = insetBounds.maxY
            }

            let cornerBounds = CGRect(center: cornerCenter, size: CGSize(width: cornerRadius * 2, height: cornerRadius * 2))
            return circleIntersection(bounds: cornerBounds, from: center, to: external)
        }

        return rectPoint
    }

    private static func parallelogramIntersection(bounds: CGRect, from center: CGPoint, to external: CGPoint) -> CGPoint {
        // Parallelogram is skewed rectangle
        // For simplicity, use rect approximation
        return rectIntersection(bounds: bounds, from: center, to: external)
    }

    private static func trapezoidIntersection(bounds: CGRect, from center: CGPoint, to external: CGPoint) -> CGPoint {
        // Trapezoid has angled top or bottom
        // For simplicity, use rect approximation
        return rectIntersection(bounds: bounds, from: center, to: external)
    }

    private static func asymmetricIntersection(bounds: CGRect, from center: CGPoint, to external: CGPoint) -> CGPoint {
        // Asymmetric (flag) shape
        // For simplicity, use rect approximation
        return rectIntersection(bounds: bounds, from: center, to: external)
    }
}

// MARK: - Size Calculation

/// Constants matching the original beautiful-mermaid TypeScript implementation
private enum NodePadding {
    /// Horizontal padding inside rectangles/rounded/stadium
    static let horizontal: CGFloat = 16
    /// Vertical padding inside rectangles/rounded/stadium
    static let vertical: CGFloat = 10
    /// Extra padding for diamond shapes (they need more space due to rotation)
    static let diamondExtra: CGFloat = 24
}

/// Font sizes matching original
private enum FontSizes {
    static let nodeLabel: CGFloat = 13
}

extension ShapeBounds {
    /// Calculate the required size for a node given its label and shape
    /// Ported from beautiful-mermaid TypeScript estimateNodeSize()
    public static func calculateSize(
        for shape: NodeShape,
        label: String,
        font: BMFont,
        padding: CGSize? = nil
    ) -> CGSize {
        let minimumSize = shape.minimumSize

        // Use provided padding or fall back to defaults
        let horizontalPadding = padding?.width ?? NodePadding.horizontal
        let verticalPadding = padding?.height ?? NodePadding.vertical
        let fontSize = font.pointSize

        // Calculate text width using the font size from config
        let textWidth = estimateTextWidth(label, fontSize: fontSize, fontWeight: 500)

        var width = textWidth + horizontalPadding * 2
        var height = fontSize + verticalPadding * 2

        // Apply shape-specific adjustments (matching original TypeScript)
        switch shape {
        case .diamond, .rhombus:
            // Diamonds need extra space because text is inside a rotated square
            // Original: const side = Math.max(width, height) + NODE_PADDING.diamondExtra
            let side = max(width, height) + NodePadding.diamondExtra
            width = side
            height = side  // MUST be square!

        case .circle, .doublecircle:
            // Circles: bounding box must be square, diameter must fit text rect
            // For a rect (w x h) inscribed in a circle: diameter >= sqrt(w^2 + h^2)
            let diameter = ceil(sqrt(width * width + height * height)) + 8
            width = shape == .doublecircle ? diameter + 12 : diameter
            height = width

        case .hexagon:
            // Hexagons need extra horizontal padding for the angled sides
            width += NodePadding.horizontal

        case .trapezoid, .trapezoidAlt:
            // Trapezoids need extra horizontal padding for angled edges
            width += NodePadding.horizontal

        case .asymmetric:
            // Asymmetric flag shape needs left padding for the pointed end
            width += 12

        case .cylinder:
            // Cylinder needs extra vertical space for the ellipse cap
            height += 14

        case .stateStart, .stateEnd:
            // State diagram pseudostates — small fixed-size circles
            width = 28
            height = 28

        case .stateChoice:
            // State choice diamond - small fixed size
            width = 24
            height = 24

        case .stateFork:
            // Fork is a bar shape
            width = max(width, 60)
            height = 8

        default:
            break
        }

        // Minimum sizes for aesthetics (matching TypeScript)
        // State pseudostates (stateStart, stateEnd) get minimum sizes applied AFTER setting 28x28
        // Only skip for stateChoice and stateFork which have truly fixed sizes
        let fixedSizeShapes: Set<NodeShape> = [.stateChoice, .stateFork]
        if !fixedSizeShapes.contains(shape) {
            width = max(width, 60)
            height = max(height, 36)

            // Also ensure shape-specific minimums
            width = max(width, minimumSize.width)
            height = max(height, minimumSize.height)
        }

        return CGSize(width: width, height: height)
    }

    /// Estimate text width using character-based approximation
    /// Matching original TypeScript: estimateTextWidth()
    private static func estimateTextWidth(_ text: String, fontSize: CGFloat, fontWeight: Int) -> CGFloat {
        // Inter average character widths as fraction of fontSize, per weight.
        // Heavier weights are slightly wider.
        let widthRatio: CGFloat
        if fontWeight >= 600 {
            widthRatio = 0.58
        } else if fontWeight >= 500 {
            widthRatio = 0.55
        } else {
            widthRatio = 0.52
        }
        return CGFloat(text.count) * fontSize * widthRatio
    }

    /// Measure text size (fallback for precise measurement)
    private static func measureText(_ text: String, font: BMFont) -> CGSize {
        guard !text.isEmpty else {
            return CGSize(width: 0, height: font.pointSize)
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return size
    }
}
