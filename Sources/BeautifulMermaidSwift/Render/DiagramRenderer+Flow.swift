import Foundation
import CoreGraphics

/// Parse a CSS length value like "2px", "1.5", "3pt" into a CGFloat.
func _parseCSSLength(_ value: String) -> CGFloat? {
    let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "px", with: "")
        .replacingOccurrences(of: "pt", with: "")
    return Double(stripped).map { CGFloat($0) }
}

extension DiagramRenderer {

    func _drawFlowOrState(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard
            let nodes = positioned.flowchartNodes,
            let edges = positioned.flowchartEdges,
            !nodes.isEmpty
        else { return }

        let groups = positioned.flowchartGroups ?? []

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            // Context already has y=0 at top (UIKit native, or AppKit flipped by MermaidView).
            // No internal flip needed — layout coordinates match the context.
            let ch = max(1, positioned.height)

            // 1. Subgraph backgrounds
            self._drawSubgraphBackgrounds(groups, in: ctx)

            // 2. Draw edges (lines only)
            for edge in edges {
                let pts = edge.points.map { CGPoint(x: $0.x, y: $0.y) }
                var style = EdgeStyleParser.parse(from: edge.style, hasArrowStart: edge.hasArrowStart, hasArrowEnd: edge.hasArrowEnd)
                style.color = edge.inlineStyle?["stroke"]
                style.strokeWidth = edge.inlineStyle?["stroke-width"].flatMap { _parseCSSLength($0) }
                self.edgeRenderer.drawEdgePath(points: pts, style: style, in: ctx, theme: self.theme)
            }

            // 3. Draw arrow heads
            for edge in edges {
                let pts = edge.points.map { CGPoint(x: $0.x, y: $0.y) }
                var style = EdgeStyleParser.parse(from: edge.style, hasArrowStart: edge.hasArrowStart, hasArrowEnd: edge.hasArrowEnd)
                style.color = edge.inlineStyle?["stroke"]
                style.strokeWidth = edge.inlineStyle?["stroke-width"].flatMap { _parseCSSLength($0) }
                self.edgeRenderer.drawArrowHeads(points: pts, style: style, in: ctx, theme: self.theme)
            }

            // 4. Draw node shapes
            for node in nodes {
                let rect = CGRect(x: node.x, y: node.y, width: node.width, height: node.height)
                self.shapeRenderer.drawShape(node.shape, bounds: rect, inlineStyles: node.inlineStyle, in: ctx, theme: self.theme)
            }

            // 5. Draw node labels
            for node in nodes {
                guard !node.label.isEmpty else { continue }
                let textColor = self.theme.nodeTextColor(for: node.inlineStyle)
                let nodeFont = self.config.nodeLabelFont()
                if node.label.contains("\n") {
                    let rect = CGRect(x: node.x, y: node.y, width: node.width, height: node.height)
                    let inset = rect.insetBy(dx: 4, dy: 2)
                    self.labelRenderer.drawMultilineText(
                        node.label,
                        in: inset,
                        context: ctx,
                        color: textColor,
                        font: nodeFont,
                        alignment: .center
                    )
                } else {
                    let center = CGPoint(x: node.x + node.width / 2, y: node.y + node.height / 2)
                    self._drawTextInFlipped(
                        node.label,
                        at: center,
                        context: ctx,
                        contentHeight: ch,
                        color: textColor,
                        font: nodeFont,
                        alignment: .center
                    )
                }
            }

            // 6. Draw edge labels (on top of nodes so they're not occluded)
            for edge in edges {
                if let label = edge.label, !label.isEmpty, let lp = edge.labelPosition {
                    self._drawEdgeLabelInFlipped(label, at: CGPoint(x: lp.x, y: lp.y), in: ctx, contentHeight: ch)
                }
            }

            // 7. Subgraph labels
            self._drawSubgraphLabelsInFlipped(groups, in: ctx, contentHeight: ch)
        }
    }

    private func _drawSubgraphBackgrounds(_ groups: [_PositionedGroupPayload], in context: CGContext) {
        for group in groups {
            let rect = CGRect(x: group.x, y: group.y, width: group.width, height: group.height)
            let path = BMBezierPath(rect: rect)

            // Fill background
            context.setFillColor(theme.subgraphBackgroundColor().cgColor)
            context.addPath(path.bm_cgPath)
            context.fillPath()

            // Fill header band at top of group box
            let headerY = group.y
            let headerRect = CGRect(x: group.x, y: headerY, width: group.width, height: group.headerHeight)
            let headerPath = BMBezierPath(roundedRect: headerRect, cornerRadius: 0)
            context.setFillColor(theme.subgraphHeaderColor().cgColor)
            context.addPath(headerPath.bm_cgPath)
            context.fillPath()

            // Stroke border
            context.setStrokeColor(theme.effectiveBorder().cgColor)
            context.setLineWidth(1.0)
            context.addPath(path.bm_cgPath)
            context.strokePath()

            // Header bottom line
            let headerBottom = headerY + group.headerHeight
            context.move(to: CGPoint(x: group.x, y: headerBottom))
            context.addLine(to: CGPoint(x: group.x + group.width, y: headerBottom))
            context.strokePath()

            // Recurse into children
            _drawSubgraphBackgrounds(group.children, in: context)
        }
    }

    private func _drawSubgraphLabels(_ groups: [_PositionedGroupPayload], in context: CGContext) {
        let headerFont = self.config.groupHeaderFont()
        for group in groups {
            if group.label.contains("\n") {
                let rect = CGRect(x: group.x + 8, y: group.y, width: group.width - 16, height: group.headerHeight)
                labelRenderer.drawMultilineText(group.label, in: rect, context: context, color: theme.effectiveTextSecondary(), font: headerFont, alignment: .center)
            } else {
                let labelPoint = CGPoint(x: group.x + 8, y: group.y + group.headerHeight / 2)
                labelRenderer.drawText(group.label, at: labelPoint, context: context, color: theme.effectiveTextSecondary(), font: headerFont, alignment: .left)
            }
            _drawSubgraphLabels(group.children, in: context)
        }
    }

    private func _drawSubgraphLabelsInFlipped(_ groups: [_PositionedGroupPayload], in context: CGContext, contentHeight ch: CGFloat) {
        let headerFont = self.config.groupHeaderFont()
        for group in groups {
            let labelPoint = CGPoint(x: group.x + 8, y: group.y + group.headerHeight / 2)
            _drawTextInFlipped(
                group.label,
                at: labelPoint,
                context: context,
                contentHeight: ch,
                color: theme.effectiveTextSecondary(),
                font: headerFont,
                alignment: .left
            )
            _drawSubgraphLabelsInFlipped(group.children, in: context, contentHeight: ch)
        }
    }

    func _drawEdgeLabelInFlipped(_ label: String, at position: CGPoint, in context: CGContext, contentHeight ch: CGFloat) {
        let config = self.config
        let edgeFont = config.edgeLabelFont()
        let attributes: [NSAttributedString.Key: Any] = [.font: edgeFont]
        let size = (label as NSString).size(withAttributes: attributes)

        let padding = config.edgeLabelPadding
        let pillRect = CGRect(
            x: position.x - size.width / 2 - padding,
            y: position.y - size.height / 2 - padding / 2,
            width: size.width + padding * 2,
            height: size.height + padding
        )

        let pillPath = BMBezierPath(roundedRect: pillRect, cornerRadius: config.edgeLabelCornerRadius)
        context.setFillColor(theme.background.cgColor)
        context.addPath(pillPath.bm_cgPath)
        context.fillPath()

        context.setStrokeColor(theme.effectiveInnerStroke().cgColor)
        context.setLineWidth(config.edgeLabelBorderWidth)
        context.addPath(pillPath.bm_cgPath)
        context.strokePath()

        _drawTextInFlipped(
            label,
            at: position,
            context: context,
            contentHeight: ch,
            color: theme.effectiveTextSecondary(),
            font: edgeFont,
            alignment: .center
        )
    }

    func _drawEdgeLabel(_ label: String, at position: CGPoint, in context: CGContext) {
        let config = self.config
        let edgeFont = config.edgeLabelFont()
        let attributes: [NSAttributedString.Key: Any] = [.font: edgeFont]
        let size = (label as NSString).size(withAttributes: attributes)

        let padding = config.edgeLabelPadding
        let pillRect = CGRect(
            x: position.x - size.width / 2 - padding,
            y: position.y - size.height / 2 - padding / 2,
            width: size.width + padding * 2,
            height: size.height + padding
        )

        let pillPath = BMBezierPath(roundedRect: pillRect, cornerRadius: config.edgeLabelCornerRadius)
        context.setFillColor(theme.background.cgColor)
        context.addPath(pillPath.bm_cgPath)
        context.fillPath()

        context.setStrokeColor(theme.effectiveInnerStroke().cgColor)
        context.setLineWidth(config.edgeLabelBorderWidth)
        context.addPath(pillPath.bm_cgPath)
        context.strokePath()

        labelRenderer.drawText(
            label,
            at: position,
            context: context,
            color: theme.effectiveTextSecondary(),
            font: edgeFont,
            alignment: .center
        )
    }
}
