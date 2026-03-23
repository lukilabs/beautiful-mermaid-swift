import Foundation
import CoreGraphics
import QuartzCore

#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit

/// A UIView subclass that renders Mermaid diagrams
public class MermaidView: UIView {

    public let mermaidLayer: MermaidLayer

    public var source: String {
        get { mermaidLayer.source }
        set { mermaidLayer.source = newValue }
    }

    public var theme: DiagramTheme {
        get { mermaidLayer.theme }
        set {
            mermaidLayer.theme = newValue
            backgroundColor = newValue.background
        }
    }

    public var layoutConfig: LayoutConfig {
        get { mermaidLayer.layoutConfig }
        set { mermaidLayer.layoutConfig = newValue }
    }

    public var parseError: Error? { mermaidLayer.parseError }
    public var diagramBounds: CGRect { mermaidLayer.diagramBounds }

    public override init(frame: CGRect) {
        self.mermaidLayer = MermaidLayer()
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.mermaidLayer = MermaidLayer()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = mermaidLayer.theme.background
        contentMode = .redraw
        mermaidLayer.onPrepareComplete = { [weak self] in
            self?.invalidateIntrinsicContentSize()
            self?.setNeedsDisplay()
        }
    }

    public override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let viewBounds = bounds

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(viewBounds)
        }

        guard let prepared = mermaidLayer.preparedDiagram else { return }
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return }
        guard viewBounds.width > 0, viewBounds.height > 0 else { return }

        let scaleX = viewBounds.width / diagBounds.width
        let scaleY = viewBounds.height / diagBounds.height
        let fitScale = min(scaleX, scaleY)

        let scaledWidth = diagBounds.width * fitScale
        let scaledHeight = diagBounds.height * fitScale
        let offsetX = (viewBounds.width - scaledWidth) / 2
        let offsetY = (viewBounds.height - scaledHeight) / 2

        ctx.saveGState()
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: fitScale, y: fitScale)
        ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
        prepared.render(ctx, diagBounds)
        ctx.restoreGState()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    public override var intrinsicContentSize: CGSize {
        diagramBounds.size
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let db = diagramBounds
        guard db.width > 0, db.height > 0 else {
            return super.sizeThatFits(size)
        }
        let fitScale = min(size.width / db.width, size.height / db.height)
        return CGSize(width: db.width * fitScale, height: db.height * fitScale)
    }
}

#elseif canImport(AppKit)
import AppKit

/// An NSView subclass that renders Mermaid diagrams
public class MermaidView: NSView {

    public let mermaidLayer: MermaidLayer

    public var source: String {
        get { mermaidLayer.source }
        set { mermaidLayer.source = newValue }
    }

    public var theme: DiagramTheme {
        get { mermaidLayer.theme }
        set {
            mermaidLayer.theme = newValue
            layer?.backgroundColor = newValue.background.cgColor
        }
    }

    public var layoutConfig: LayoutConfig {
        get { mermaidLayer.layoutConfig }
        set { mermaidLayer.layoutConfig = newValue }
    }

    public var parseError: Error? { mermaidLayer.parseError }
    public var diagramBounds: CGRect { mermaidLayer.diagramBounds }

    public override init(frame frameRect: NSRect) {
        self.mermaidLayer = MermaidLayer()
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.mermaidLayer = MermaidLayer()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = mermaidLayer.theme.background.cgColor
        mermaidLayer.onPrepareComplete = { [weak self] in
            self?.invalidateIntrinsicContentSize()
            self?.needsDisplay = true
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(rect)
        }

        guard let prepared = mermaidLayer.preparedDiagram else { return }
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return }
        guard rect.width > 0, rect.height > 0 else { return }

        let scaleX = rect.width / diagBounds.width
        let scaleY = rect.height / diagBounds.height
        let fitScale = min(scaleX, scaleY)

        let scaledWidth = diagBounds.width * fitScale
        let scaledHeight = diagBounds.height * fitScale
        let offsetX = (rect.width - scaledWidth) / 2
        let offsetY = (rect.height - scaledHeight) / 2

        ctx.saveGState()
        // Flip for AppKit (y=0 at bottom -> y=0 at top)
        ctx.translateBy(x: 0, y: rect.height)
        ctx.scaleBy(x: 1, y: -1)
        // Apply centering and scale
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: fitScale, y: fitScale)
        ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
        prepared.render(ctx, diagBounds)
        ctx.restoreGState()
    }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: diagramBounds.width, height: diagramBounds.height)
    }
}

#endif
