// SPDX-License-Identifier: MIT
//
//  ERDiagramRenderer.swift
//  BeautifulMermaid
//
//  Renders positioned ER diagrams to CGContext
//  Port of: original/src/er/renderer.ts
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Renderer for ER diagrams
public class ERDiagramRenderer {
    /// Theme for rendering
    public var theme: DiagramTheme

    /// Label renderer for text
    private let labelRenderer: LabelRenderer

    /// Font sizes specific to ER diagrams (matches TypeScript ER_FONT)
    private struct ERFont {
        static let attrSize: CGFloat = 11
        static let attrWeight: Int = 400
        static let keySize: CGFloat = 9
        static let keyWeight: Int = 600
    }

    public init(theme: DiagramTheme = .default) {
        self.theme = theme
        self.labelRenderer = LabelRenderer()
    }

    // MARK: - Main Render Method

    /// Render a positioned ER diagram to a CGContext
    public func render(_ diagram: PositionedErDiagram, in context: CGContext, bounds: CGRect) {
        context.saveGState()

        // 1. Fill background
        context.setFillColor(theme.background.cgColor)
        context.fill(bounds)

        // 2. Render relationship lines (behind boxes)
        for rel in diagram.relationships {
            renderRelationshipLine(rel, in: context)
        }

        // 3. Render entity boxes
        for entity in diagram.entities {
            renderEntityBox(entity, in: context)
        }

        // 4. Render cardinality markers at relationship endpoints
        for rel in diagram.relationships {
            renderCardinality(rel, in: context)
        }

        // 5. Render relationship labels
        for rel in diagram.relationships {
            renderRelationshipLabel(rel, in: context)
        }

        context.restoreGState()
    }

    /// Render to an image
    public func renderToImage(_ diagram: PositionedErDiagram, scale: CGFloat = 2.0) -> BMImage? {
        let bounds = CGRect(x: 0, y: 0, width: diagram.width, height: diagram.height)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        guard size.width > 0, size.height > 0 else { return nil }

        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.scaleBy(x: scale, y: scale)
            render(diagram, in: context, bounds: bounds)
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

        render(diagram, in: context, bounds: bounds)

        image.unlockFocus()
        return image
        #endif
    }

    // MARK: - Entity Box Rendering

    /// Render an entity box with header and attribute rows
    private func renderEntityBox(_ entity: PositionedErEntity, in context: CGContext) {
        let x = entity.x
        let y = entity.y
        let width = entity.width
        let height = entity.height

        // Outer rectangle - TypeScript uses rx="0" (sharp corners)
        let boxRect = CGRect(x: x, y: y, width: width, height: height)
        context.setFillColor(theme.effectiveSurface().cgColor)
        context.fill(boxRect)
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(RenderConfig.shared.strokeWidthOuterBox)
        context.stroke(boxRect)

        // Header background - TypeScript uses rx="0" (sharp corners)
        let headerRect = CGRect(x: x, y: y, width: width, height: entity.headerHeight)
        context.setFillColor(theme.subgraphHeaderColor().cgColor)
        context.fill(headerRect)
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.stroke(headerRect)

        // Entity name (bold, centered)
        let nameFont = BMFont.systemFont(ofSize: RenderConfig.shared.fontSizeNodeLabel, weight: .bold)
        labelRenderer.drawText(
            entity.label,
            at: CGPoint(x: x + width / 2, y: y + entity.headerHeight / 2),
            context: context,
            color: theme.foreground,
            font: nameFont,
            alignment: .center
        )

        // Divider line between header and attributes
        let attrTop = y + entity.headerHeight
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(RenderConfig.shared.strokeWidthInnerBox)
        context.move(to: CGPoint(x: x, y: attrTop))
        context.addLine(to: CGPoint(x: x + width, y: attrTop))
        context.strokePath()

        // Render attributes
        if entity.attributes.isEmpty {
            // Empty row placeholder
            let emptyFont = italicFont(ofSize: ERFont.attrSize)
            labelRenderer.drawText(
                "(no attributes)",
                at: CGPoint(x: x + width / 2, y: attrTop + entity.rowHeight / 2),
                context: context,
                color: theme.effectiveTextFaint(),
                font: emptyFont,
                alignment: .center
            )
        } else {
            for i in 0..<entity.attributes.count {
                let attr = entity.attributes[i]
                let rowY = attrTop + CGFloat(i) * entity.rowHeight + entity.rowHeight / 2
                renderAttribute(attr, boxX: x, y: rowY, boxWidth: width, in: context)
            }
        }
    }

    /// Render a single attribute row with key badges and monospace text
    private func renderAttribute(_ attr: ErAttribute, boxX: CGFloat, y: CGFloat, boxWidth: CGFloat, in context: CGContext) {
        var keyWidth: CGFloat = 0

        // Key badges on the left (PK, FK, UK)
        if !attr.keys.isEmpty {
            let keyText = attr.keys.joined(separator: ",")
            keyWidth = RenderConfig.shared.estimateTextWidth(keyText, fontSize: ERFont.keySize, fontWeight: ERFont.keyWeight) + 8

            // Badge background
            let badgeRect = CGRect(x: boxX + 6, y: y - 7, width: keyWidth, height: 14)
            let badgePath = BMBezierPath(roundedRect: badgeRect, cornerRadius: 2)
            context.setFillColor(theme.keyBadgeColor().cgColor)
            context.addPath(badgePath.bm_cgPath)
            context.fillPath()

            // Badge text
            let keyFont = BMFont.systemFont(ofSize: ERFont.keySize, weight: .semibold)
            labelRenderer.drawText(
                keyText,
                at: CGPoint(x: boxX + 6 + keyWidth / 2, y: y),
                context: context,
                color: theme.effectiveTextSecondary(),
                font: keyFont,
                alignment: .center
            )
        }

        // Type (left-aligned after keys, monospace)
        let typeX = boxX + 8 + (keyWidth > 0 ? keyWidth + 6 : 0)
        let typeFont = monoFont(size: ERFont.attrSize, weight: ERFont.attrWeight)
        labelRenderer.drawText(
            attr.type,
            at: CGPoint(x: typeX, y: y),
            context: context,
            color: theme.effectiveMuted(),
            font: typeFont,
            alignment: .left
        )

        // Name (right-aligned, monospace)
        let nameX = boxX + boxWidth - 8
        labelRenderer.drawText(
            attr.name,
            at: CGPoint(x: nameX, y: y),
            context: context,
            color: theme.effectiveTextSecondary(),
            font: typeFont,
            alignment: .right
        )
    }

    // MARK: - Relationship Rendering

    /// Render a relationship line
    private func renderRelationshipLine(_ rel: PositionedErRelationship, in context: CGContext) {
        guard rel.points.count >= 2 else { return }

        context.saveGState()
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(RenderConfig.shared.strokeWidthConnector)

        // Dashed for non-identifying relationships
        if !rel.identifying {
            context.setLineDash(phase: 0, lengths: [6, 4])
        }

        // Draw the polyline
        context.move(to: rel.points[0])
        for i in 1..<rel.points.count {
            context.addLine(to: rel.points[i])
        }
        context.strokePath()

        context.restoreGState()
    }

    /// Render a relationship label at the midpoint
    private func renderRelationshipLabel(_ rel: PositionedErRelationship, in context: CGContext) {
        guard !rel.label.isEmpty, rel.points.count >= 2 else { return }

        let mid = arcLengthMidpoint(rel.points)
        let labelFont = RenderConfig.shared.edgeLabelFont()
        let textWidth = RenderConfig.shared.estimateTextWidth(rel.label, fontSize: RenderConfig.shared.fontSizeEdgeLabel, fontWeight: 400)

        // Background pill for readability
        let bgW = textWidth + 8
        let bgH = RenderConfig.shared.fontSizeEdgeLabel + 6
        let bgRect = CGRect(x: mid.x - bgW / 2, y: mid.y - bgH / 2, width: bgW, height: bgH)
        let bgPath = BMBezierPath(roundedRect: bgRect, cornerRadius: 2)

        context.setFillColor(theme.background.cgColor)
        context.addPath(bgPath.bm_cgPath)
        context.fillPath()

        context.setStrokeColor(theme.effectiveInnerStroke().cgColor)
        context.setLineWidth(0.5)
        context.addPath(bgPath.bm_cgPath)
        context.strokePath()

        // Label text
        labelRenderer.drawText(
            rel.label,
            at: mid,
            context: context,
            color: theme.effectiveMuted(),
            font: labelFont,
            alignment: .center
        )
    }

    /// Render crow's foot cardinality markers at both endpoints
    private func renderCardinality(_ rel: PositionedErRelationship, in context: CGContext) {
        guard rel.points.count >= 2 else { return }

        // Entity1 side (first point, direction toward second point)
        let p1 = rel.points[0]
        let p2 = rel.points[1]
        renderCrowsFoot(point: p1, toward: p2, cardinality: rel.cardinality1, in: context)

        // Entity2 side (last point, direction toward second-to-last point)
        let pN = rel.points[rel.points.count - 1]
        let pN1 = rel.points[rel.points.count - 2]
        renderCrowsFoot(point: pN, toward: pN1, cardinality: rel.cardinality2, in: context)
    }

    /// Render a crow's foot marker at a given endpoint
    private func renderCrowsFoot(point: CGPoint, toward: CGPoint, cardinality: String, in context: CGContext) {
        let sw = RenderConfig.shared.strokeWidthConnector + 0.25

        // Calculate direction from toward → point (unit vector)
        let dx = point.x - toward.x
        let dy = point.y - toward.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return }
        let ux = dx / len
        let uy = dy / len

        // Perpendicular direction
        let px = -uy
        let py = ux

        // Marker sits 4px from the endpoint, extending 12px back along the edge
        let tipX = point.x - ux * 4
        let tipY = point.y - uy * 4
        let backX = point.x - ux * 16
        let backY = point.y - uy * 16

        let hasOneLine = cardinality == "one" || cardinality == "zero-one"
        let hasCrowsFoot = cardinality == "many" || cardinality == "zero-many"
        let hasCircle = cardinality == "zero-one" || cardinality == "zero-many"

        context.saveGState()
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(sw)

        // Single vertical line (perpendicular to edge) at the tip
        if hasOneLine {
            let halfW: CGFloat = 6
            context.move(to: CGPoint(x: tipX + px * halfW, y: tipY + py * halfW))
            context.addLine(to: CGPoint(x: tipX - px * halfW, y: tipY - py * halfW))
            context.strokePath()

            // Second line slightly back for "exactly one" emphasis
            let line2X = tipX - ux * 4
            let line2Y = tipY - uy * 4
            context.move(to: CGPoint(x: line2X + px * halfW, y: line2Y + py * halfW))
            context.addLine(to: CGPoint(x: line2X - px * halfW, y: line2Y - py * halfW))
            context.strokePath()
        }

        // Crow's foot (three lines fanning out from tip)
        if hasCrowsFoot {
            let fanW: CGFloat = 7

            // Top fan line
            context.move(to: CGPoint(x: tipX + px * fanW, y: tipY + py * fanW))
            context.addLine(to: CGPoint(x: backX, y: backY))
            context.strokePath()

            // Center line
            context.move(to: CGPoint(x: tipX, y: tipY))
            context.addLine(to: CGPoint(x: backX, y: backY))
            context.strokePath()

            // Bottom fan line
            context.move(to: CGPoint(x: tipX - px * fanW, y: tipY - py * fanW))
            context.addLine(to: CGPoint(x: backX, y: backY))
            context.strokePath()
        }

        // Circle (for zero variants)
        if hasCircle {
            let circleOffset: CGFloat = hasCrowsFoot ? 20 : 12
            let circleX = point.x - ux * circleOffset
            let circleY = point.y - uy * circleOffset
            let circleRect = CGRect(x: circleX - 4, y: circleY - 4, width: 8, height: 8)

            context.setFillColor(theme.background.cgColor)
            context.fillEllipse(in: circleRect)
            context.strokeEllipse(in: circleRect)
        }

        context.restoreGState()
    }

    // MARK: - Utilities

    /// Get a monospace font
    private func monoFont(size: CGFloat, weight: Int) -> BMFont {
        #if canImport(UIKit)
        if let font = UIFont(name: "Menlo", size: size) {
            return font
        }
        return UIFont.monospacedSystemFont(ofSize: size, weight: fontWeight(from: weight))
        #elseif canImport(AppKit)
        if let font = NSFont(name: "Menlo", size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: fontWeight(from: weight))
        #endif
    }

    /// Get an italic font
    private func italicFont(ofSize size: CGFloat) -> BMFont {
        #if canImport(UIKit)
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withSymbolicTraits(.traitItalic) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        return UIFont(descriptor: descriptor, size: size)
        #elseif canImport(AppKit)
        let manager = NSFontManager.shared
        let font = NSFont.systemFont(ofSize: size)
        return manager.convert(font, toHaveTrait: .italicFontMask)
        #endif
    }

    private func fontWeight(from weight: Int) -> BMFont.Weight {
        switch weight {
        case 100: return .ultraLight
        case 200: return .thin
        case 300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        case 900: return .black
        default: return .regular
        }
    }

    /// Compute the arc-length midpoint of a polyline path
    /// Walks along each segment, finds the point at exactly 50% of total path length
    private func arcLengthMidpoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        guard points.count > 1 else { return points[0] }

        // Compute total path length
        var totalLen: CGFloat = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x
            let dy = points[i].y - points[i - 1].y
            totalLen += sqrt(dx * dx + dy * dy)
        }

        guard totalLen > 0 else { return points[0] }

        // Walk to 50% of total length
        let halfLen = totalLen / 2
        var walked: CGFloat = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x
            let dy = points[i].y - points[i - 1].y
            let segLen = sqrt(dx * dx + dy * dy)
            if walked + segLen >= halfLen {
                let t = segLen > 0 ? (halfLen - walked) / segLen : 0
                return CGPoint(
                    x: points[i - 1].x + dx * t,
                    y: points[i - 1].y + dy * t
                )
            }
            walked += segLen
        }

        return points[points.count - 1]
    }
}
