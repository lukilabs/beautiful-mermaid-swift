// SPDX-License-Identifier: MIT
//
//  MermaidView.swift
//  BeautifulMermaid
//
//  Native view for rendering Mermaid diagrams
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit

/// A UIView subclass that renders Mermaid diagrams
public class MermaidView: UIView {

    // MARK: - Public Properties

    /// The Mermaid diagram source
    public var source: String = "" {
        didSet {
            if source != oldValue {
                renderDiagram()
            }
        }
    }

    /// Theme for rendering
    public var theme: DiagramTheme = .default {
        didSet {
            imageRenderer.theme = theme
            backgroundColor = theme.background
            renderDiagram()
        }
    }

    /// Layout configuration
    public var layoutConfig: LayoutConfig = LayoutConfig() {
        didSet {
            imageRenderer.layoutConfig = layoutConfig
            renderDiagram()
        }
    }

    /// Parsing error (if any)
    public private(set) var parseError: Error?

    /// The rendered bounds of the diagram
    public private(set) var diagramBounds: CGRect = .zero

    // MARK: - Private Properties

    private let imageRenderer: MermaidImageRenderer
    private var renderedImage: UIImage?

    // MARK: - Initialization

    public override init(frame: CGRect) {
        self.imageRenderer = MermaidImageRenderer()
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.imageRenderer = MermaidImageRenderer()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = theme.background
        contentMode = .redraw
        imageRenderer.theme = theme
        imageRenderer.scale = UIScreen.main.scale
    }

    // MARK: - Drawing

    public override func draw(_ rect: CGRect) {
        guard let image = renderedImage else {
            // Draw background even if no diagram
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.setFillColor(theme.background.cgColor)
            context.fill(rect)
            return
        }

        // Calculate scale to fit (don't scale up)
        let scale = calculateScale(for: diagramBounds, in: rect)

        // Center the image
        let scaledWidth = diagramBounds.width * scale
        let scaledHeight = diagramBounds.height * scale
        let offsetX = (rect.width - scaledWidth) / 2
        let offsetY = (rect.height - scaledHeight) / 2

        let drawRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
        image.draw(in: drawRect)
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    // MARK: - Sizing

    public override var intrinsicContentSize: CGSize {
        diagramBounds.size
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard diagramBounds.width > 0, diagramBounds.height > 0 else {
            return super.sizeThatFits(size)
        }

        let scale = calculateScale(for: diagramBounds, in: CGRect(origin: .zero, size: size))
        return CGSize(
            width: diagramBounds.width * scale,
            height: diagramBounds.height * scale
        )
    }

    // MARK: - Private Methods

    private func renderDiagram() {
        parseError = nil
        renderedImage = nil
        diagramBounds = .zero

        guard !source.isEmpty else {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
            return
        }

        do {
            // Render the diagram to an image
            if let image = try imageRenderer.renderImage(from: source) {
                renderedImage = image
                // Derive bounds from image size (origin is always 0,0)
                diagramBounds = CGRect(origin: .zero, size: image.size)
            }
        } catch {
            parseError = error
        }

        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    private func calculateScale(for diagramBounds: CGRect, in viewBounds: CGRect) -> CGFloat {
        guard diagramBounds.width > 0 && diagramBounds.height > 0 else {
            return 1.0
        }

        let scaleX = viewBounds.width / diagramBounds.width
        let scaleY = viewBounds.height / diagramBounds.height

        return min(scaleX, scaleY, 1.0) // Don't scale up
    }
}

#elseif canImport(AppKit)
import AppKit

/// An NSView subclass that renders Mermaid diagrams
public class MermaidView: NSView {

    // MARK: - Public Properties

    /// The Mermaid diagram source
    public var source: String = "" {
        didSet {
            if source != oldValue {
                renderDiagram()
            }
        }
    }

    /// Theme for rendering
    public var theme: DiagramTheme = .default {
        didSet {
            imageRenderer.theme = theme
            layer?.backgroundColor = theme.background.cgColor
            renderDiagram()
        }
    }

    /// Layout configuration
    public var layoutConfig: LayoutConfig = LayoutConfig() {
        didSet {
            imageRenderer.layoutConfig = layoutConfig
            renderDiagram()
        }
    }

    /// Parsing error (if any)
    public private(set) var parseError: Error?

    /// The rendered bounds of the diagram
    public private(set) var diagramBounds: CGRect = .zero

    // MARK: - Private Properties

    private let imageRenderer: MermaidImageRenderer
    private var renderedImage: NSImage?

    // MARK: - Initialization

    public override init(frame frameRect: NSRect) {
        self.imageRenderer = MermaidImageRenderer()
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.imageRenderer = MermaidImageRenderer()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = theme.background.cgColor
        imageRenderer.theme = theme
        imageRenderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let image = renderedImage else {
            // Draw background only
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.setFillColor(theme.background.cgColor)
            context.fill(dirtyRect)
            return
        }

        let rect = bounds

        // Calculate scale to fit (don't scale up)
        let scale = calculateScale(for: diagramBounds, in: rect)

        // Center the image
        let scaledWidth = diagramBounds.width * scale
        let scaledHeight = diagramBounds.height * scale
        let offsetX = (rect.width - scaledWidth) / 2
        let offsetY = (rect.height - scaledHeight) / 2

        let drawRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
        image.draw(in: drawRect)
    }

    // MARK: - Sizing

    public override var intrinsicContentSize: NSSize {
        NSSize(width: diagramBounds.width, height: diagramBounds.height)
    }

    // MARK: - Private Methods

    private func renderDiagram() {
        parseError = nil
        renderedImage = nil
        diagramBounds = .zero

        guard !source.isEmpty else {
            invalidateIntrinsicContentSize()
            needsDisplay = true
            return
        }

        do {
            // Render the diagram to an image
            if let image = try imageRenderer.renderImage(from: source) {
                renderedImage = image
                // Derive bounds from image size (origin is always 0,0)
                diagramBounds = CGRect(origin: .zero, size: image.size)
            }
        } catch {
            parseError = error
        }

        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    private func calculateScale(for diagramBounds: CGRect, in viewBounds: CGRect) -> CGFloat {
        guard diagramBounds.width > 0 && diagramBounds.height > 0 else {
            return 1.0
        }

        let scaleX = viewBounds.width / diagramBounds.width
        let scaleY = viewBounds.height / diagramBounds.height

        return min(scaleX, scaleY, 1.0)
    }
}

#endif
