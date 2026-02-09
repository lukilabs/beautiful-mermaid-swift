// SPDX-License-Identifier: MIT
//
//  DiagramRenderer.swift
//  BeautifulMermaid
//
//  Main rendering coordinator for diagrams
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Main renderer for positioned diagrams
public class DiagramRenderer {
    /// Theme for rendering
    public var theme: DiagramTheme

    /// Shape renderer
    private let shapeRenderer: ShapeRenderer

    /// Edge renderer
    private let edgeRenderer: EdgeRenderer

    /// Label renderer
    private let labelRenderer: LabelRenderer

    public init(theme: DiagramTheme = .default) {
        self.theme = theme
        self.shapeRenderer = ShapeRenderer()
        self.edgeRenderer = EdgeRenderer()
        self.labelRenderer = LabelRenderer()
    }

    /// Render a positioned graph to a CGContext
    public func render(_ graph: PositionedGraph, in context: CGContext, bounds: CGRect) {
        // Apply coordinate transform if needed
        context.saveGState()

        // 1. Fill background
        context.setFillColor(theme.background.cgColor)
        context.fill(bounds)

        // 2. Draw subgraph backgrounds (recursively for nested subgraphs)
        for subgraph in graph.subgraphs {
            drawSubgraphBackgroundRecursive(subgraph, in: context)
        }

        // 3. Draw edges (lines only, no arrows yet)
        for edge in graph.edges {
            edgeRenderer.drawEdgePath(edge, in: context, theme: theme)
        }

        // 4. Draw arrow heads
        for edge in graph.edges {
            edgeRenderer.drawArrowHeads(edge, in: context, theme: theme)
        }

        // 5. Draw edge labels
        for edge in graph.edges {
            if edge.label != nil {
                drawEdgeLabel(edge, in: context)
            }
        }

        // 6. Draw node shapes
        for node in graph.nodes {
            shapeRenderer.drawShape(node, in: context, theme: theme)
        }

        // 7. Draw node labels
        for node in graph.nodes {
            drawNodeLabel(node, in: context)
        }

        // 8. Draw subgraph labels (recursively for nested subgraphs)
        for subgraph in graph.subgraphs {
            drawSubgraphLabelRecursive(subgraph, in: context)
        }

        context.restoreGState()
    }

    // MARK: - Subgraph Rendering

    /// Recursively draw subgraph backgrounds (outer first, then nested children)
    private func drawSubgraphBackgroundRecursive(_ subgraph: Subgraph, in context: CGContext) {
        // Draw this subgraph's background first (so children draw on top)
        drawSubgraphBackground(subgraph, in: context)

        // Then draw nested children
        for child in subgraph.children {
            drawSubgraphBackgroundRecursive(child, in: context)
        }
    }

    /// Recursively draw subgraph labels
    private func drawSubgraphLabelRecursive(_ subgraph: Subgraph, in context: CGContext) {
        drawSubgraphLabel(subgraph, in: context)

        for child in subgraph.children {
            drawSubgraphLabelRecursive(child, in: context)
        }
    }

    private func drawSubgraphBackground(_ subgraph: Subgraph, in context: CGContext) {
        let bounds = subgraph.bounds

        // Skip subgraphs with invalid or zero bounds
        guard bounds.width > 1 && bounds.height > 1 else { return }

        // TypeScript uses sharp corners (rx="0" ry="0") for subgraphs
        let path = BMBezierPath(rect: bounds)

        // Fill entire subgraph area with pure background color (matching TypeScript --_group-fill: var(--bg))
        let contentColor = theme.subgraphBackgroundColor()
        context.setFillColor(contentColor.cgColor)
        context.addPath(path.bm_cgPath)
        context.fillPath()

        // Draw header band on top with sharp corners
        let headerBounds = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: subgraph.headerHeight
        )

        let headerColor = theme.subgraphHeaderColor()
        context.setFillColor(headerColor.cgColor)

        // Use sharp corners for header (matching TypeScript)
        context.fill(headerBounds)

        // Draw border around the header (creates bottom border line like TypeScript)
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(RenderConfig.shared.strokeWidthOuterBox)
        context.stroke(headerBounds)

        // Draw border around the entire subgraph
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(RenderConfig.shared.strokeWidthOuterBox)
        context.addPath(path.bm_cgPath)
        context.strokePath()
    }

    private func createTopRoundedRect(_ rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let r = cornerRadius

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                         control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                         control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }

    private func drawSubgraphLabel(_ subgraph: Subgraph, in context: CGContext) {
        // Use small padding for label bounds (TypeScript uses 8px padding)
        let labelPadding: CGFloat = 8
        let labelBounds = CGRect(
            x: subgraph.bounds.minX + labelPadding,
            y: subgraph.bounds.minY,
            width: subgraph.bounds.width - labelPadding * 2,
            height: subgraph.headerHeight
        )

        // Use group header font from RenderConfig
        let groupFont = RenderConfig.shared.groupHeaderFont()
        labelRenderer.drawText(
            subgraph.label,
            in: labelBounds,
            context: context,
            color: theme.effectiveTextSecondary(),
            font: groupFont,
            alignment: .left,
            verticalAlignment: .center
        )
    }

    // MARK: - Label Rendering

    private func drawEdgeLabel(_ edge: MermaidEdge, in context: CGContext) {
        guard let label = edge.label, !label.isEmpty else { return }

        // Calculate label size using edge label font from RenderConfig
        let config = RenderConfig.shared
        let edgeFont = config.edgeLabelFont()
        let attributes: [NSAttributedString.Key: Any] = [.font: edgeFont]
        let size = (label as NSString).size(withAttributes: attributes)

        // Draw background pill (using edge label settings from RenderConfig)
        let padding = config.edgeLabelPadding
        let pillRect = CGRect(
            x: edge.labelPosition.x - size.width / 2 - padding,
            y: edge.labelPosition.y - size.height / 2 - padding / 2,
            width: size.width + padding * 2,
            height: size.height + padding
        )

        let pillPath = BMBezierPath(roundedRect: pillRect, cornerRadius: config.edgeLabelCornerRadius)

        context.setFillColor(theme.background.cgColor)
        context.addPath(pillPath.bm_cgPath)
        context.fillPath()

        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(config.edgeLabelBorderWidth)
        context.addPath(pillPath.bm_cgPath)
        context.strokePath()

        // Draw label text (using edge label font from RenderConfig)
        labelRenderer.drawText(
            label,
            at: edge.labelPosition,
            context: context,
            color: theme.effectiveMuted(),
            font: edgeFont,
            alignment: .center
        )
    }

    private func drawNodeLabel(_ node: MermaidNode, in context: CGContext) {
        guard !node.label.isEmpty else { return }

        let textColor = theme.nodeTextColor(for: node)
        let nodeFont = RenderConfig.shared.nodeLabelFont()

        labelRenderer.drawText(
            node.label,
            at: node.position,
            context: context,
            color: textColor,
            font: nodeFont,
            alignment: .center
        )
    }
}

// MARK: - Convenience Rendering

extension DiagramRenderer {
    /// Render to a UIImage/NSImage
    public func renderToImage(_ graph: PositionedGraph, scale: CGFloat = 2.0) -> BMImage? {
        let bounds = graph.bounds
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext

            // Scale up
            context.scaleBy(x: scale, y: scale)

            // Translate to account for bounds origin
            context.translateBy(x: -bounds.minX, y: -bounds.minY)

            // Render
            render(graph, in: context, bounds: bounds)
        }
        #elseif canImport(AppKit)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        // Flip for AppKit (AppKit has y=0 at bottom, layout uses y=0 at top)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        // Scale up
        context.scaleBy(x: scale, y: scale)

        // Translate to account for bounds origin
        context.translateBy(x: -bounds.minX, y: -bounds.minY)

        // Render
        render(graph, in: context, bounds: bounds)

        image.unlockFocus()
        return image
        #endif
    }
}
