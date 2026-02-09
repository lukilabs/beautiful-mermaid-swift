// SPDX-License-Identifier: MIT
//
//  ShapeRenderer.swift
//  BeautifulMermaid
//
//  Renders node shapes using CoreGraphics
//

import Foundation
import CoreGraphics

/// Renders node shapes
public class ShapeRenderer {

    public init() {}

    /// Draw a node's shape
    public func drawShape(_ node: MermaidNode, in context: CGContext, theme: DiagramTheme) {
        let bounds = node.bounds

        context.saveGState()

        // Special handling for state pseudostates - they use text color, not node colors
        if node.shape == .stateStart {
            // State start: filled circle with text color, no stroke
            // TypeScript: fill="var(--_text)" stroke="none"
            let path = shapePath(for: node.shape, in: bounds, theme: theme)
            context.setFillColor(theme.foreground.cgColor)
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
            return
        }

        if node.shape == .stateEnd {
            // State end: outer ring with text color stroke, inner filled circle
            // TypeScript: outer circle fill="none" stroke="var(--_text)" stroke-width="2"
            //            inner circle fill="var(--_text)" stroke="none"
            let cx = bounds.midX
            let cy = bounds.midY
            let outerR = min(bounds.width, bounds.height) / 2 - 2

            // Draw outer ring
            let outerRect = CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)
            context.setStrokeColor(theme.foreground.cgColor)
            context.setLineWidth(RenderConfig.shared.strokeWidthInnerBox * 2)
            context.strokeEllipse(in: outerRect)

            // Draw inner filled circle
            let innerR = outerR - 4
            let innerRect = CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2)
            context.setFillColor(theme.foreground.cgColor)
            context.fillEllipse(in: innerRect)

            context.restoreGState()
            return
        }

        // Normal shape rendering
        let fillColor = theme.nodeFillColor(for: node)
        let strokeColor = theme.nodeStrokeColor(for: node)

        // Get path for shape
        let path = shapePath(for: node.shape, in: bounds, theme: theme)

        // Fill
        context.setFillColor(fillColor.cgColor)
        context.addPath(path)
        context.fillPath()

        // Stroke (using inner box stroke width from RenderConfig)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(RenderConfig.shared.strokeWidthInnerBox)
        context.addPath(path)
        context.strokePath()

        // Draw additional shape details
        drawShapeDetails(node.shape, in: bounds, context: context, theme: theme)

        context.restoreGState()
    }

    /// Create a CGPath for a shape
    public func shapePath(for shape: NodeShape, in bounds: CGRect, theme: DiagramTheme) -> CGPath {
        switch shape {
        case .rectangle, .entity, .invisible:
            return rectanglePath(bounds)

        case .rounded, .stateNote:
            // TypeScript uses fixed rx=6 for rounded rectangles
            return roundedRectPath(bounds, cornerRadius: 6)

        case .stadium:
            return stadiumPath(bounds)

        case .circle, .doublecircle, .stateChoice:
            return circlePath(bounds)

        case .stateStart, .stateEnd:
            // State start/end are true circles (not ellipses) - TypeScript uses Math.min(w, h)
            return trueCirclePath(bounds)

        case .diamond, .rhombus:
            return diamondPath(bounds)

        case .hexagon:
            return hexagonPath(bounds)

        case .parallelogram:
            return parallelogramPath(bounds)

        case .parallelogramAlt:
            return parallelogramAltPath(bounds)

        case .trapezoid:
            return trapezoidPath(bounds)

        case .trapezoidAlt:
            return trapezoidAltPath(bounds)

        case .cylinder:
            // Cylinder is handled as a special case with multiple components
            // Return the body rectangle path; ellipses drawn in drawShapeDetails
            let ry = RenderConfig.shared.cylinderEllipseRadius
            let bodyTop = bounds.minY + ry
            let bodyHeight = bounds.height - 2 * ry
            let bodyRect = CGRect(x: bounds.minX, y: bodyTop, width: bounds.width, height: bodyHeight)
            return CGPath(rect: bodyRect, transform: nil)

        case .subroutine:
            return rectanglePath(bounds) // Base shape; details drawn separately

        case .asymmetric:
            return asymmetricPath(bounds)

        case .stateFork:
            return rectanglePath(bounds)

        case .classBox:
            return roundedRectPath(bounds, cornerRadius: 4)
        }
    }

    // MARK: - Shape Paths

    private func rectanglePath(_ bounds: CGRect) -> CGPath {
        CGPath(rect: bounds, transform: nil)
    }

    private func roundedRectPath(_ bounds: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addRoundedRect(in: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        return path
    }

    private func stadiumPath(_ bounds: CGRect) -> CGPath {
        let radius = bounds.height / 2
        return roundedRectPath(bounds, cornerRadius: radius)
    }

    private func circlePath(_ bounds: CGRect) -> CGPath {
        CGPath(ellipseIn: bounds, transform: nil)
    }

    /// True circle path (not ellipse) - uses min(width, height) for diameter
    /// TypeScript uses: r = Math.min(w, h) / 2 - 2
    private func trueCirclePath(_ bounds: CGRect) -> CGPath {
        let cx = bounds.midX
        let cy = bounds.midY
        let r = min(bounds.width, bounds.height) / 2 - 2
        let circleRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        return CGPath(ellipseIn: circleRect, transform: nil)
    }

    private func diamondPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let center = bounds.center

        path.move(to: CGPoint(x: center.x, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: center.y))
        path.closeSubpath()

        return path
    }

    private func hexagonPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        // Original TypeScript uses: inset = height / 4
        let inset = bounds.height / 4
        let center = bounds.center

        // Six points of hexagon
        path.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: center.y))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: center.y))
        path.closeSubpath()

        return path
    }

    private func parallelogramPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let skew = bounds.width * 0.2

        path.move(to: CGPoint(x: bounds.minX + skew, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - skew, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()

        return path
    }

    private func parallelogramAltPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let skew = bounds.width * 0.2

        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - skew, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + skew, y: bounds.maxY))
        path.closeSubpath()

        return path
    }

    private func trapezoidPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.width * 0.15

        path.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()

        return path
    }

    private func trapezoidAltPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.width * 0.15

        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + inset, y: bounds.maxY))
        path.closeSubpath()

        return path
    }

    private func asymmetricPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        // Original TypeScript uses: indent = 12 (fixed pixels)
        // The flag shape has a pointed left edge that sticks OUT to the left
        let indent = RenderConfig.shared.asymmetricIndent
        let center = bounds.center

        // TypeScript order (point sticks OUT to left):
        // 1. top-left (indented from left edge)
        // 2. top-right
        // 3. bottom-right
        // 4. bottom-left (indented from left edge)
        // 5. left point (at actual left edge, at vertical center)
        path.move(to: CGPoint(x: bounds.minX + indent, y: bounds.minY))   // top-left indented
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))         // top-right
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))         // bottom-right
        path.addLine(to: CGPoint(x: bounds.minX + indent, y: bounds.maxY)) // bottom-left indented
        path.addLine(to: CGPoint(x: bounds.minX, y: center.y))            // left point (sticks out)
        path.closeSubpath()

        return path
    }

    // MARK: - Shape Details

    private func drawShapeDetails(_ shape: NodeShape, in bounds: CGRect, context: CGContext, theme: DiagramTheme) {
        let config = RenderConfig.shared

        switch shape {
        case .subroutine:
            // Draw double vertical lines (using subroutine inset from RenderConfig)
            let inset = config.subroutineInset
            context.setStrokeColor(theme.nodeStrokeColor(for: MermaidNode(id: "", label: "", shape: shape)).cgColor)
            context.setLineWidth(config.strokeWidthInnerBox)

            // Left line
            context.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.minX + inset, y: bounds.maxY))
            context.strokePath()

            // Right line
            context.move(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
            context.strokePath()

        case .doublecircle:
            // Draw inner circle with 5px gap (original: innerR = outerR - 5)
            let gap = config.doubleCircleGap
            let innerBounds = bounds.insetBy(dx: gap, dy: gap)
            let innerPath = circlePath(innerBounds)

            context.setStrokeColor(theme.nodeStrokeColor(for: MermaidNode(id: "", label: "", shape: shape)).cgColor)
            context.setLineWidth(config.strokeWidthInnerBox)
            context.addPath(innerPath)
            context.strokePath()

        case .cylinder:
            // Cylinder rendered as multiple components (matching TypeScript):
            // 1. Body rectangle (already drawn as the main shape)
            // 2. Left and right side border lines
            // 3. Bottom ellipse (half visible)
            // 4. Top ellipse (full, on top)
            let ry = config.cylinderEllipseRadius
            let ellipseHeight = ry * 2
            let bodyTop = bounds.minY + ry
            let bodyBottom = bounds.maxY - ry

            let strokeColor = theme.nodeStrokeColor(for: MermaidNode(id: "", label: "", shape: shape))
            let fillColor = theme.nodeFillColor(for: MermaidNode(id: "", label: "", shape: shape))

            // Draw left and right body border lines
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(config.strokeWidthInnerBox)

            context.move(to: CGPoint(x: bounds.minX, y: bodyTop))
            context.addLine(to: CGPoint(x: bounds.minX, y: bodyBottom))
            context.strokePath()

            context.move(to: CGPoint(x: bounds.maxX, y: bodyTop))
            context.addLine(to: CGPoint(x: bounds.maxX, y: bodyBottom))
            context.strokePath()

            // Bottom ellipse (full ellipse, but only front half visible since body covers back)
            let bottomEllipse = CGRect(x: bounds.minX, y: bounds.maxY - ellipseHeight, width: bounds.width, height: ellipseHeight)
            let bottomPath = CGPath(ellipseIn: bottomEllipse, transform: nil)

            context.setFillColor(fillColor.cgColor)
            context.addPath(bottomPath)
            context.fillPath()

            context.setStrokeColor(strokeColor.cgColor)
            context.addPath(bottomPath)
            context.strokePath()

            // Top ellipse (full, drawn on top of everything)
            let topEllipse = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: ellipseHeight)
            let topPath = CGPath(ellipseIn: topEllipse, transform: nil)

            context.setFillColor(fillColor.cgColor)
            context.addPath(topPath)
            context.fillPath()

            context.setStrokeColor(strokeColor.cgColor)
            context.addPath(topPath)
            context.strokePath()

        default:
            break
        }
    }
}
