// SPDX-License-Identifier: MIT
//
//  EdgeRenderer.swift
//  BeautifulMermaid
//
//  Renders edges/connections using CoreGraphics
//

import Foundation
import CoreGraphics

/// Renders edges and connections
public class EdgeRenderer {

    public init() {}

    /// Draw the edge path (line only)
    public func drawEdgePath(_ edge: MermaidEdge, in context: CGContext, theme: DiagramTheme) {
        guard edge.points.count >= 2 else { return }

        let color = theme.edgeColor(for: edge.style)
        // Use connector stroke width from RenderConfig
        let baseLineWidth = RenderConfig.shared.strokeWidthConnector
        let lineWidth = baseLineWidth * edge.style.lineStyle.widthMultiplier

        context.saveGState()

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Apply dash pattern if needed
        if let pattern = edge.style.lineStyle.dashPattern {
            context.setLineDash(phase: 0, lengths: pattern)
        }

        // Draw path
        context.move(to: edge.points[0])
        for i in 1..<edge.points.count {
            context.addLine(to: edge.points[i])
        }
        context.strokePath()

        context.restoreGState()
    }

    /// Draw arrow heads at edge endpoints
    public func drawArrowHeads(_ edge: MermaidEdge, in context: CGContext, theme: DiagramTheme) {
        guard edge.points.count >= 2 else { return }

        // Arrow heads use accent color or 50% blend (separate from edge line color)
        let arrowColor = theme.effectiveArrow()
        // Use connector stroke width from RenderConfig
        let baseLineWidth = RenderConfig.shared.strokeWidthConnector
        let lineWidth = baseLineWidth * edge.style.lineStyle.widthMultiplier

        // Draw target arrow
        if edge.style.targetArrow != .none {
            let point = edge.points.last!
            drawArrowHead(
                edge.style.targetArrow,
                at: point,
                angle: edge.targetAngle,
                lineWidth: lineWidth,
                color: arrowColor,
                in: context
            )
        }

        // Draw source arrow
        if edge.style.sourceArrow != .none {
            let point = edge.points.first!
            drawArrowHead(
                edge.style.sourceArrow,
                at: point,
                angle: edge.sourceAngle,
                lineWidth: lineWidth,
                color: arrowColor,
                in: context
            )
        }
    }

    /// Draw a single arrow head
    private func drawArrowHead(
        _ style: ArrowHead,
        at point: CGPoint,
        angle: CGFloat,
        lineWidth: CGFloat,
        color: BMColor,
        in context: CGContext
    ) {
        // Arrow head dimensions - use fixed sizes to match TypeScript SVG markers
        // TypeScript: <marker markerWidth="8" markerHeight="4.8">
        let config = RenderConfig.shared
        let arrowWidth = config.arrowHeadWidth   // 8 px
        let arrowHeight = config.arrowHeadHeight // 4.8 px

        context.saveGState()

        // Transform to arrow position and orientation
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)

        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)

        switch style {
        case .none:
            break

        case .arrow:
            // Filled triangle (width=8, height=4.8)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            path.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            path.closeSubpath()

            context.addPath(path)
            context.fillPath()

        case .open:
            // Open arrow (V shape)
            context.move(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            context.addLine(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            context.strokePath()

        case .circle:
            // Circle marker - smaller than arrow
            let circleSize = arrowHeight * 0.8
            let circleRect = CGRect(
                x: -circleSize - lineWidth,
                y: -circleSize / 2,
                width: circleSize,
                height: circleSize
            )
            context.addEllipse(in: circleRect)
            context.fillPath()

        case .cross:
            // X marker
            let crossSize = arrowHeight * 0.4
            context.move(to: CGPoint(x: -crossSize * 2 - lineWidth, y: -crossSize))
            context.addLine(to: CGPoint(x: -lineWidth, y: crossSize))
            context.move(to: CGPoint(x: -crossSize * 2 - lineWidth, y: crossSize))
            context.addLine(to: CGPoint(x: -lineWidth, y: -crossSize))
            context.strokePath()

        case .diamond:
            // Diamond marker - slightly larger than arrow
            let diamondWidth = arrowWidth * 1.2
            let diamondHeight = arrowHeight
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -diamondWidth / 2, y: -diamondHeight / 2))
            path.addLine(to: CGPoint(x: -diamondWidth, y: 0))
            path.addLine(to: CGPoint(x: -diamondWidth / 2, y: diamondHeight / 2))
            path.closeSubpath()

            context.addPath(path)
            context.fillPath()
        }

        context.restoreGState()
    }
}

// MARK: - Bezier Curve Support

extension EdgeRenderer {
    /// Draw a curved edge using Bezier curves
    public func drawCurvedEdgePath(_ edge: MermaidEdge, in context: CGContext, theme: DiagramTheme) {
        guard edge.points.count >= 4 else {
            // Fall back to straight line
            drawEdgePath(edge, in: context, theme: theme)
            return
        }

        let color = theme.edgeColor(for: edge.style)
        // Use connector stroke width from RenderConfig
        let baseLineWidth = RenderConfig.shared.strokeWidthConnector
        let lineWidth = baseLineWidth * edge.style.lineStyle.widthMultiplier

        context.saveGState()

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if let pattern = edge.style.lineStyle.dashPattern {
            context.setLineDash(phase: 0, lengths: pattern)
        }

        // Cubic bezier curve
        context.move(to: edge.points[0])
        context.addCurve(
            to: edge.points[3],
            control1: edge.points[1],
            control2: edge.points[2]
        )
        context.strokePath()

        context.restoreGState()
    }
}
