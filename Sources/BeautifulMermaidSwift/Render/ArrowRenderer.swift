import Foundation
import CoreGraphics

public struct ArrowRenderer {

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
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -size, y: -size / 2))
            path.addLine(to: CGPoint(x: -size, y: size / 2))
            path.closeSubpath()
        case .open:
            path.move(to: CGPoint(x: -size, y: -size / 2))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -size, y: size / 2))
        case .circle:
            let circleSize = size * 0.6
            path.addEllipse(in: CGRect(x: -circleSize, y: -circleSize / 2, width: circleSize, height: circleSize))
        case .cross:
            let crossSize = size * 0.4
            path.move(to: CGPoint(x: -crossSize * 2, y: -crossSize))
            path.addLine(to: CGPoint(x: 0, y: crossSize))
            path.move(to: CGPoint(x: -crossSize * 2, y: crossSize))
            path.addLine(to: CGPoint(x: 0, y: -crossSize))
        case .diamond:
            let diamondSize = size * 0.7
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -diamondSize, y: -diamondSize / 2))
            path.addLine(to: CGPoint(x: -diamondSize * 2, y: 0))
            path.addLine(to: CGPoint(x: -diamondSize, y: diamondSize / 2))
            path.closeSubpath()
        }

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: point.x, y: point.y)
        transform = transform.rotated(by: angle)

        return path.copy(using: &transform) ?? path
    }
}
