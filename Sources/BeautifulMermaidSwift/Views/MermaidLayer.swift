import Foundation
import CoreGraphics
import QuartzCore

#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A prepared diagram ready for direct CGContext rendering
public struct PreparedDiagram {
    /// The bounds of the diagram content
    public let bounds: CGRect
    /// Renders the diagram into the given context. The context should already be
    /// set up with the correct coordinate system (y=0 at top).
    public let render: (CGContext, CGRect) -> Void
}

/// A CALayer subclass that manages the Mermaid diagram rendering pipeline:
/// parse -> layout -> draw.
public class MermaidLayer: CALayer {

    // MARK: - Public Properties

    public var source: String = "" {
        didSet {
            if source != oldValue { prepareDiagram() }
        }
    }

    public var theme: DiagramTheme = .default {
        didSet { prepareDiagram() }
    }

    public var layoutConfig: LayoutConfig = LayoutConfig() {
        didSet { prepareDiagram() }
    }

    public private(set) var parseError: Error?
    public private(set) var diagramBounds: CGRect = .zero
    public private(set) var preparedDiagram: PreparedDiagram?

    /// Called after the diagram is prepared (parsed + laid out).
    public var onPrepareComplete: (() -> Void)?

    // MARK: - Initialization

    public override init() {
        super.init()
        commonInit()
    }

    public override init(layer: Any) {
        if let other = layer as? MermaidLayer {
            super.init(layer: layer)
            self.source = other.source
            self.theme = other.theme
            self.layoutConfig = other.layoutConfig
            self.parseError = other.parseError
            self.diagramBounds = other.diagramBounds
            self.preparedDiagram = other.preparedDiagram
        } else {
            super.init(layer: layer)
        }
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        needsDisplayOnBoundsChange = true
        #if os(visionOS)
        contentsScale = 2.0
        #elseif targetEnvironment(macCatalyst) || canImport(UIKit)
        contentsScale = UIScreen.main.scale
        #elseif canImport(AppKit)
        contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        #endif
    }

    // MARK: - Bitmap Rendering

    public func renderImage(scale: CGFloat = 2.0) -> BMImage? {
        guard let prepared = preparedDiagram else { return nil }
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return nil }

        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        let size = CGSize(width: diagBounds.width * scale, height: diagBounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let uiRenderer = UIGraphicsImageRenderer(size: size, format: format)
        return uiRenderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            if !theme.transparent {
                ctx.setFillColor(theme.background.cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
            prepared.render(ctx, diagBounds)
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: diagBounds.width * scale, height: diagBounds.height * scale)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        // Flip for AppKit (lockFocus context has y=0 at bottom)
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)

        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)

        prepared.render(ctx, diagBounds)

        image.unlockFocus()
        return image
        #endif
    }

    // MARK: - Private Methods

    private func prepareDiagram() {
        parseError = nil
        preparedDiagram = nil
        diagramBounds = .zero

        guard !source.isEmpty else {
            setNeedsDisplay()
            onPrepareComplete?()
            return
        }

        do {
            let graph = try MermaidParser.parse(source)
            let layout = GraphLayout(config: layoutConfig)
            let positioned = try layout.layout(graph)
            let renderer = DiagramRenderer(theme: theme)

            let bounds = CGRect(x: 0, y: 0, width: max(1, positioned.width), height: max(1, positioned.height))
            preparedDiagram = PreparedDiagram(bounds: bounds) { context, renderBounds in
                renderer.render(positioned, in: context, bounds: renderBounds)
            }
            diagramBounds = bounds
        } catch {
            parseError = error
        }

        setNeedsDisplay()
        onPrepareComplete?()
    }
}
