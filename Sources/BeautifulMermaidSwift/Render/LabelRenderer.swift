import Foundation
import CoreGraphics
import CoreText

#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum TextAlignment {
    case left
    case center
    case right
}

public enum VerticalAlignment {
    case top
    case center
    case bottom
}

public class LabelRenderer {

    public init() {}

    public func drawText(
        _ text: String,
        at point: CGPoint,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .center
    ) {
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        var x = point.x
        let y = point.y - size.height / 2

        switch alignment {
        case .left: break
        case .center: x = point.x - size.width / 2
        case .right: x = point.x - size.width
        }

        let rect = CGRect(x: x, y: y, width: size.width, height: size.height)
        drawAttributedString(attributedString, in: rect, context: context)
    }

    public func drawText(
        _ text: String,
        in rect: CGRect,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .left,
        verticalAlignment: VerticalAlignment = .center
    ) {
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        var x = rect.minX
        var y = rect.minY

        switch alignment {
        case .left: x = rect.minX
        case .center: x = rect.minX + (rect.width - size.width) / 2
        case .right: x = rect.maxX - size.width
        }

        switch verticalAlignment {
        case .top: y = rect.minY
        case .center: y = rect.minY + (rect.height - size.height) / 2
        case .bottom: y = rect.maxY - size.height
        }

        let drawRect = CGRect(x: x, y: y, width: size.width, height: size.height)
        drawAttributedString(attributedString, in: drawRect, context: context)
    }

    // MARK: - Private Drawing

    private func drawAttributedString(
        _ attributedString: NSAttributedString,
        in rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()

        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        attributedString.draw(in: rect)
        #elseif canImport(AppKit)
        let centerY = rect.midY
        context.translateBy(x: 0, y: centerY)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -centerY)

        // Ensure NSGraphicsContext is available (required for NSAttributedString.draw).
        // flipped: false because the local CTM unflip above restored y=0-at-bottom.
        let needsContext = NSGraphicsContext.current == nil
        if needsContext {
            let nsCtx = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsCtx
        }
        attributedString.draw(in: rect)
        if needsContext {
            NSGraphicsContext.current = nil
        }
        #endif

        context.restoreGState()
    }

    /// Draw multiline text (newline-separated) with each line individually positioned,
    /// matching the TS renderMultilineText vertical centering formula.
    /// Lines are centered on `rect.midY` using `lineHeight = fontSize * 1.3`.
    public func drawMultilineText(
        _ text: String,
        in rect: CGRect,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .center,
        lineSpacing: CGFloat = 4
    ) {
        guard !text.isEmpty else { return }

        let lines = text.components(separatedBy: "\n")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        // Match TS: lineHeight = fontSize * LINE_HEIGHT_RATIO (1.3)
        let fontSize = font.pointSize
        let lineHeight = fontSize * 1.3

        // Total block height and vertical start, centered on rect.midY
        let blockHeight = CGFloat(lines.count) * lineHeight
        let startY = rect.midY - blockHeight / 2

        for (i, line) in lines.enumerated() {
            guard !line.isEmpty else { continue }
            let attrStr = NSAttributedString(string: line, attributes: attributes)
            let size = attrStr.size()

            let y = startY + CGFloat(i) * lineHeight
            var x: CGFloat
            switch alignment {
            case .left:   x = rect.minX
            case .center: x = rect.midX - size.width / 2
            case .right:  x = rect.maxX - size.width
            }

            let lineRect = CGRect(x: x, y: y, width: size.width, height: size.height)
            drawAttributedString(attrStr, in: lineRect, context: context)
        }
    }

    // MARK: - Text Measurement

    public func measureText(_ text: String, font: BMFont) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return NSAttributedString(string: text, attributes: attributes).size()
    }
}
