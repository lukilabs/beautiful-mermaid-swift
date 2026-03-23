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

public final class DiagramRenderer {
    public var theme: DiagramTheme
    let config: RenderConfig

    let shapeRenderer: NodeShapeRenderer
    let edgeRenderer: EdgeRenderer
    let labelRenderer: LabelRenderer

    public init(theme: DiagramTheme = .default, config: RenderConfig = RenderConfig.shared) {
        self.theme = theme
        self.config = config
        self.shapeRenderer = NodeShapeRenderer(config: config)
        self.edgeRenderer = EdgeRenderer(config: config)
        self.labelRenderer = LabelRenderer()
    }

    public func render(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        _ = _ElkBridge.version
        context.saveGState()
        defer { context.restoreGState() }

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        switch positioned.diagram.type {
        case .classDiagram:
            _drawClass(positioned, in: context, bounds: bounds)
        case .erDiagram:
            _drawEr(positioned, in: context, bounds: bounds)
        case .sequenceDiagram:
            _drawSequence(positioned, in: context, bounds: bounds)
        case .stateDiagram, .flowchart:
            _drawFlowOrState(positioned, in: context, bounds: bounds)
        case .xyChart:
            _drawXYChart(positioned, in: context, bounds: bounds)
        }
    }

    // MARK: - Utility

    func _monoFont(size: CGFloat) -> BMFont {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return UIFont(name: "Menlo", size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #elseif canImport(AppKit)
        return NSFont(name: "Menlo", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #endif
    }

    func _italicSystemFont(size: CGFloat, weight: CGFloat) -> BMFont {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        let baseFont = BMFont.systemFont(ofSize: size, weight: UIFont.Weight(weight))
        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
            return BMFont(descriptor: descriptor, size: size)
        }
        return baseFont
        #elseif canImport(AppKit)
        let baseFont = BMFont.systemFont(ofSize: size, weight: NSFont.Weight(weight))
        let manager = NSFontManager.shared
        return manager.convert(baseFont, toHaveTrait: .italicFontMask)
        #endif
    }

    func _italicMonoFont(size: CGFloat) -> BMFont {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return UIFont(name: "Menlo-Italic", size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #elseif canImport(AppKit)
        return NSFont(name: "Menlo-Italic", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #endif
    }

    /// Draw text at a point. The `contentHeight` parameter is retained for call-site compatibility
    /// but is no longer used (the context is already y=0 at top).
    func _drawTextInFlipped(
        _ text: String,
        at point: CGPoint,
        context: CGContext,
        contentHeight: CGFloat,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .center
    ) {
        guard !text.isEmpty else { return }
        if text.contains("\n") {
            // Use a wide rect centered on the point; drawMultilineText will vertically center the text block.
            let rect = CGRect(x: point.x - 500, y: point.y - 500, width: 1000, height: 1000)
            labelRenderer.drawMultilineText(text, in: rect, context: context, color: color, font: font, alignment: .center)
        } else {
            labelRenderer.drawText(text, at: point, context: context, color: color, font: font, alignment: alignment)
        }
    }

    func _withFittedContext(
        _ context: CGContext,
        bounds: CGRect,
        contentWidth: Double,
        contentHeight: Double,
        draw: (CGContext) -> Void
    ) {
        let cw = max(1.0, contentWidth)
        let ch = max(1.0, contentHeight)
        let scale = min(bounds.width / cw, bounds.height / ch)
        let fittedWidth = cw * scale
        let fittedHeight = ch * scale
        let offsetX = bounds.minX + (bounds.width - fittedWidth) / 2
        let offsetY = bounds.minY + (bounds.height - fittedHeight) / 2

        context.saveGState()
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)
        draw(context)
        context.restoreGState()
    }
}
