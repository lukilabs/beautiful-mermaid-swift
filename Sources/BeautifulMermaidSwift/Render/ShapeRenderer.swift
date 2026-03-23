import Foundation
import CoreGraphics

public class NodeShapeRenderer {

    let config: RenderConfig

    public init(config: RenderConfig = RenderConfig.shared) {
        self.config = config
    }

    public func drawShape(_ shape: String, bounds: CGRect, inlineStyles: [String: String], in context: CGContext, theme: DiagramTheme) {
        context.saveGState()

        if shape == "state-start" {
            let path = trueCirclePath(bounds)
            context.setFillColor(theme.foreground.cgColor)
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
            return
        }

        if shape == "state-end" {
            let cx = bounds.midX, cy = bounds.midY
            let outerR = min(bounds.width, bounds.height) / 2 - 2
            let outerRect = CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)
            context.setStrokeColor(theme.foreground.cgColor)
            context.setLineWidth(config.strokeWidthInnerBox * 2)
            context.strokeEllipse(in: outerRect)
            let innerR = outerR - 4
            let innerRect = CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2)
            context.setFillColor(theme.foreground.cgColor)
            context.fillEllipse(in: innerRect)
            context.restoreGState()
            return
        }

        let fillColor = theme.nodeFillColor(for: inlineStyles)
        let strokeColor = theme.nodeStrokeColor(for: inlineStyles)
        let path = shapePath(for: shape, in: bounds)

        context.setFillColor(fillColor.cgColor)
        context.addPath(path)
        context.fillPath()

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(config.strokeWidthInnerBox)
        context.addPath(path)
        context.strokePath()

        drawShapeDetails(shape, in: bounds, context: context, theme: theme, inlineStyles: inlineStyles)

        context.restoreGState()
    }

    public func shapePath(for shape: String, in bounds: CGRect) -> CGPath {
        switch shape {
        case "rectangle", "entity", "invisible":
            return CGPath(rect: bounds, transform: nil)
        case "rounded", "state-note":
            return roundedRectPath(bounds, cornerRadius: 6)
        case "stadium":
            return roundedRectPath(bounds, cornerRadius: bounds.height / 2)
        case "circle", "doublecircle", "state-choice":
            return CGPath(ellipseIn: bounds, transform: nil)
        case "state-start", "state-end":
            return trueCirclePath(bounds)
        case "diamond", "rhombus":
            return diamondPath(bounds)
        case "hexagon":
            return hexagonPath(bounds)
        case "parallelogram":
            return parallelogramPath(bounds)
        case "parallelogram-alt":
            return parallelogramAltPath(bounds)
        case "trapezoid":
            return trapezoidPath(bounds)
        case "trapezoid-alt":
            return trapezoidAltPath(bounds)
        case "cylinder":
            let ry = config.cylinderEllipseRadius
            let bodyRect = CGRect(x: bounds.minX, y: bounds.minY + ry, width: bounds.width, height: bounds.height - 2 * ry)
            return CGPath(rect: bodyRect, transform: nil)
        case "subroutine":
            return CGPath(rect: bounds, transform: nil)
        case "asymmetric":
            return asymmetricPath(bounds)
        case "state-fork":
            return CGPath(rect: bounds, transform: nil)
        case "class-box":
            return roundedRectPath(bounds, cornerRadius: 4)
        default:
            return CGPath(rect: bounds, transform: nil)
        }
    }

    // MARK: - Shape Paths

    private func roundedRectPath(_ bounds: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addRoundedRect(in: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        return path
    }

    private func trueCirclePath(_ bounds: CGRect) -> CGPath {
        let cx = bounds.midX, cy = bounds.midY
        let r = min(bounds.width, bounds.height) / 2 - 2
        return CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2), transform: nil)
    }

    private func diamondPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let c = bounds.center
        path.move(to: CGPoint(x: c.x, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: c.y))
        path.addLine(to: CGPoint(x: c.x, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: c.y))
        path.closeSubpath()
        return path
    }

    private func hexagonPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.height / 4
        let c = bounds.center
        path.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: c.y))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: c.y))
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
        let indent = config.asymmetricIndent
        let c = bounds.center
        path.move(to: CGPoint(x: bounds.minX + indent, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + indent, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: c.y))
        path.closeSubpath()
        return path
    }

    // MARK: - Shape Details

    private func drawShapeDetails(_ shape: String, in bounds: CGRect, context: CGContext, theme: DiagramTheme, inlineStyles: [String: String]) {
        let config = config

        switch shape {
        case "subroutine":
            let inset = config.subroutineInset
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(config.strokeWidthInnerBox)
            context.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.minX + inset, y: bounds.maxY))
            context.strokePath()
            context.move(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
            context.strokePath()

        case "doublecircle":
            let innerBounds = bounds.insetBy(dx: config.doubleCircleGap, dy: config.doubleCircleGap)
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(config.strokeWidthInnerBox)
            context.addPath(CGPath(ellipseIn: innerBounds, transform: nil))
            context.strokePath()

        case "cylinder":
            let ry = config.cylinderEllipseRadius
            let ellipseHeight = ry * 2
            let bodyTop = bounds.minY + ry
            let bodyBottom = bounds.maxY - ry

            let strokeColor = theme.nodeStrokeColor(for: inlineStyles)
            let fillColor = theme.nodeFillColor(for: inlineStyles)

            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(config.strokeWidthInnerBox)
            context.move(to: CGPoint(x: bounds.minX, y: bodyTop))
            context.addLine(to: CGPoint(x: bounds.minX, y: bodyBottom))
            context.strokePath()
            context.move(to: CGPoint(x: bounds.maxX, y: bodyTop))
            context.addLine(to: CGPoint(x: bounds.maxX, y: bodyBottom))
            context.strokePath()

            let bottomEllipse = CGRect(x: bounds.minX, y: bounds.maxY - ellipseHeight, width: bounds.width, height: ellipseHeight)
            let bottomPath = CGPath(ellipseIn: bottomEllipse, transform: nil)
            context.setFillColor(fillColor.cgColor)
            context.addPath(bottomPath)
            context.fillPath()
            context.setStrokeColor(strokeColor.cgColor)
            context.addPath(bottomPath)
            context.strokePath()

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
