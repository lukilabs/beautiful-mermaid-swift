import Foundation
import CoreGraphics

public class EdgeRenderer {

    let config: RenderConfig

    public init(config: RenderConfig = RenderConfig.shared) {
        self.config = config
    }

    public func drawEdgePath(
        points: [CGPoint],
        style: EdgeStyle,
        in context: CGContext,
        theme: DiagramTheme
    ) {
        guard points.count >= 2 else { return }

        let color = theme.edgeColor(for: style)
        let baseLineWidth = config.strokeWidthConnector
        let lineWidth = style.strokeWidth ?? (baseLineWidth * style.lineStyle.widthMultiplier)

        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if let pattern = style.lineStyle.dashPattern {
            context.setLineDash(phase: 0, lengths: pattern)
        }

        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        context.strokePath()
        context.restoreGState()
    }

    public func drawArrowHeads(
        points: [CGPoint],
        style: EdgeStyle,
        in context: CGContext,
        theme: DiagramTheme
    ) {
        guard points.count >= 2 else { return }

        let arrowColor = style.color != nil ? theme.edgeColor(for: style) : theme.effectiveArrow()
        let baseLineWidth = config.strokeWidthConnector
        let lineWidth = style.strokeWidth ?? (baseLineWidth * style.lineStyle.widthMultiplier)

        if style.targetArrow != .none {
            let p0 = points[points.count - 2]
            let p1 = points[points.count - 1]
            let angle = atan2(p1.y - p0.y, p1.x - p0.x)
            drawArrowHead(style.targetArrow, at: p1, angle: angle, lineWidth: lineWidth, color: arrowColor, in: context)
        }

        if style.sourceArrow != .none {
            let p0 = points[1]
            let p1 = points[0]
            let angle = atan2(p1.y - p0.y, p1.x - p0.x)
            drawArrowHead(style.sourceArrow, at: p1, angle: angle, lineWidth: lineWidth, color: arrowColor, in: context)
        }
    }

    private func drawArrowHead(
        _ style: ArrowHead,
        at point: CGPoint,
        angle: CGFloat,
        lineWidth: CGFloat,
        color: BMColor,
        in context: CGContext
    ) {
        let config = config
        let arrowWidth = config.arrowHeadWidth
        let arrowHeight = config.arrowHeadHeight

        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)

        switch style {
        case .none:
            break

        case .arrow:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            path.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            path.closeSubpath()
            context.setLineJoin(.round)
            context.setLineWidth(0.75)
            context.addPath(path)
            context.drawPath(using: .fillStroke)

        case .open:
            context.move(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            context.addLine(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            context.strokePath()

        case .circle:
            let circleSize = arrowHeight * 0.8
            context.addEllipse(in: CGRect(x: -circleSize - lineWidth, y: -circleSize / 2, width: circleSize, height: circleSize))
            context.fillPath()

        case .cross:
            let crossSize = arrowHeight * 0.4
            context.move(to: CGPoint(x: -crossSize * 2 - lineWidth, y: -crossSize))
            context.addLine(to: CGPoint(x: -lineWidth, y: crossSize))
            context.move(to: CGPoint(x: -crossSize * 2 - lineWidth, y: crossSize))
            context.addLine(to: CGPoint(x: -lineWidth, y: -crossSize))
            context.strokePath()

        case .diamond:
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

// MARK: - LineStyle Extensions

extension LineStyle {
    public var dashPattern: [CGFloat]? {
        switch self {
        case .solid, .thick: return nil
        case .dotted: return [2, 4]
        case .dashed: return [8, 4]
        }
    }

    public var widthMultiplier: CGFloat {
        self == .thick ? 2.0 : 1.0
    }
}
