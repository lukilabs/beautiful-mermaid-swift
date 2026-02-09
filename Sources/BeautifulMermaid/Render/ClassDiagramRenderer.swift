// SPDX-License-Identifier: MIT
//
//  ClassDiagramRenderer.swift
//  BeautifulMermaid
//
//  Renders positioned class diagrams to CGContext
//  Port of: original/src/class/renderer.ts
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Renderer for class diagrams
public class ClassDiagramRenderer {
    /// Theme for rendering
    public var theme: DiagramTheme

    /// Label renderer for text
    private let labelRenderer: LabelRenderer

    /// Font sizes specific to class diagrams (matches TypeScript CLS_FONT)
    private struct ClassFont {
        static let memberSize: CGFloat = 11
        static let memberWeight: Int = 400
        static let annotationSize: CGFloat = 10
        static let annotationWeight: Int = 500
    }

    /// Box padding constants (matches TypeScript CLS in layout.ts)
    private struct BoxPadding {
        static let padX: CGFloat = 8
        static let memberRowHeight: CGFloat = 20
    }

    public init(theme: DiagramTheme = .default) {
        self.theme = theme
        self.labelRenderer = LabelRenderer()
    }

    // MARK: - Main Render Method

    /// Render a positioned class diagram to a CGContext
    public func render(_ diagram: PositionedClassDiagram, in context: CGContext, bounds: CGRect) {
        context.saveGState()

        // 1. Fill background
        context.setFillColor(theme.background.cgColor)
        context.fill(bounds)

        // 2. Render relationship lines (behind boxes)
        for rel in diagram.relationships {
            renderRelationship(rel, in: context)
        }

        // 3. Render class boxes
        for cls in diagram.classes {
            renderClassBox(cls, in: context)
        }

        // 4. Render relationship labels and cardinality
        for rel in diagram.relationships {
            renderRelationshipLabels(rel, in: context)
        }

        context.restoreGState()
    }

    /// Render to an image
    public func renderToImage(_ diagram: PositionedClassDiagram, scale: CGFloat = 2.0) -> BMImage? {
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

    // MARK: - Class Box Rendering

    /// Render a class box with 3 compartments: header, attributes, methods
    private func renderClassBox(_ cls: PositionedClassNode, in context: CGContext) {
        let x = cls.x
        let y = cls.y
        let width = cls.width
        let height = cls.height

        // Outer rectangle (full box)
        let boxRect = CGRect(x: x, y: y, width: width, height: height)
        context.setFillColor(theme.effectiveSurface().cgColor)
        context.fill(boxRect)
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(RenderConfig.shared.strokeWidthOuterBox)
        context.stroke(boxRect)

        // Header background
        let headerRect = CGRect(x: x, y: y, width: width, height: cls.headerHeight)
        context.setFillColor(theme.subgraphHeaderColor().cgColor)
        context.fill(headerRect)
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.stroke(headerRect)

        // Annotation (<<interface>>, <<abstract>>, etc.)
        var nameY = y + cls.headerHeight / 2
        if let annotation = cls.annotation, !annotation.isEmpty {
            let annotY = y + 12
            let annotFont = italicFont(ofSize: ClassFont.annotationSize, weight: .medium)
            labelRenderer.drawText(
                "<<\(annotation)>>",
                at: CGPoint(x: x + width / 2, y: annotY),
                context: context,
                color: theme.effectiveMuted(),
                font: annotFont,
                alignment: .center
            )
            nameY = y + cls.headerHeight / 2 + 6
        }

        // Class name (bold)
        let nameFont = BMFont.systemFont(ofSize: RenderConfig.shared.fontSizeNodeLabel, weight: .bold)
        labelRenderer.drawText(
            cls.label,
            at: CGPoint(x: x + width / 2, y: nameY),
            context: context,
            color: theme.foreground,
            font: nameFont,
            alignment: .center
        )

        // Divider line between header and attributes
        let attrTop = y + cls.headerHeight
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(RenderConfig.shared.strokeWidthInnerBox)
        context.move(to: CGPoint(x: x, y: attrTop))
        context.addLine(to: CGPoint(x: x + width, y: attrTop))
        context.strokePath()

        // Attributes
        for i in 0..<cls.attributes.count {
            let member = cls.attributes[i]
            let memberY = attrTop + 4 + CGFloat(i) * BoxPadding.memberRowHeight + BoxPadding.memberRowHeight / 2
            renderMember(member, x: x + BoxPadding.padX, y: memberY, in: context)
        }

        // Divider line between attributes and methods
        let methodTop = attrTop + cls.attrHeight
        context.move(to: CGPoint(x: x, y: methodTop))
        context.addLine(to: CGPoint(x: x + width, y: methodTop))
        context.strokePath()

        // Methods
        for i in 0..<cls.methods.count {
            let member = cls.methods[i]
            let memberY = methodTop + 4 + CGFloat(i) * BoxPadding.memberRowHeight + BoxPadding.memberRowHeight / 2
            renderMember(member, x: x + BoxPadding.padX, y: memberY, in: context)
        }
    }

    /// Render a single class member with syntax highlighting
    private func renderMember(_ member: ClassDiagramMember, x: CGFloat, y: CGFloat, in context: CGContext) {
        var currentX = x
        // Get font with italic style if abstract
        let memberFont = member.isAbstract
            ? italicMonoFont(size: ClassFont.memberSize, weight: ClassFont.memberWeight)
            : monoFont(size: ClassFont.memberSize, weight: ClassFont.memberWeight)

        // Visibility symbol
        if !member.visibility.isEmpty {
            let visText = member.visibility + " "
            drawMemberText(
                visText,
                at: CGPoint(x: currentX, y: y),
                context: context,
                color: theme.effectiveTextFaint(),
                font: memberFont,
                underline: member.isStatic
            )
            // Use monospace width estimation since class diagrams use Menlo font
            currentX += RenderConfig.shared.estimateMonoTextWidth(visText, fontSize: ClassFont.memberSize)
        }

        // Member name
        drawMemberText(
            member.name,
            at: CGPoint(x: currentX, y: y),
            context: context,
            color: theme.effectiveTextSecondary(),
            font: memberFont,
            underline: member.isStatic
        )
        // Use monospace width estimation since class diagrams use Menlo font
        currentX += RenderConfig.shared.estimateMonoTextWidth(member.name, fontSize: ClassFont.memberSize)

        // Type annotation
        if let type = member.type, !type.isEmpty {
            let colonText = ": "
            drawMemberText(
                colonText,
                at: CGPoint(x: currentX, y: y),
                context: context,
                color: theme.effectiveTextFaint(),
                font: memberFont,
                underline: member.isStatic
            )
            // Use monospace width estimation since class diagrams use Menlo font
            currentX += RenderConfig.shared.estimateMonoTextWidth(colonText, fontSize: ClassFont.memberSize)

            drawMemberText(
                type,
                at: CGPoint(x: currentX, y: y),
                context: context,
                color: theme.effectiveMuted(),
                font: memberFont,
                underline: member.isStatic
            )
        }
    }

    /// Helper to draw member text with optional underline (for static members)
    private func drawMemberText(
        _ text: String,
        at point: CGPoint,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        underline: Bool
    ) {
        labelRenderer.drawText(
            text,
            at: point,
            context: context,
            color: color,
            font: font,
            alignment: .left
        )

        // Draw underline for static members
        if underline {
            let size = labelRenderer.measureText(text, font: font)
            context.saveGState()
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1)
            let underlineY = point.y + size.height / 2 - 1
            context.move(to: CGPoint(x: point.x, y: underlineY))
            context.addLine(to: CGPoint(x: point.x + size.width, y: underlineY))
            context.strokePath()
            context.restoreGState()
        }
    }

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

    /// Get an italic monospace font (for abstract members)
    private func italicMonoFont(size: CGFloat, weight: Int) -> BMFont {
        #if canImport(UIKit)
        if let font = UIFont(name: "Menlo-Italic", size: size) {
            return font
        }
        // Fallback to regular mono if italic not available
        return monoFont(size: size, weight: weight)
        #elseif canImport(AppKit)
        if let font = NSFont(name: "Menlo-Italic", size: size) {
            return font
        }
        // Fallback to regular mono if italic not available
        return monoFont(size: size, weight: weight)
        #endif
    }

    /// Get an italic font for annotations
    private func italicFont(ofSize size: CGFloat, weight: BMFont.Weight) -> BMFont {
        #if canImport(UIKit)
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withSymbolicTraits(.traitItalic) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        return UIFont(descriptor: descriptor, size: size)
        #elseif canImport(AppKit)
        let manager = NSFontManager.shared
        let font = NSFont.systemFont(ofSize: size, weight: weight)
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

    // MARK: - Relationship Rendering

    /// Render a relationship line with appropriate markers
    private func renderRelationship(_ rel: PositionedClassRelationship, in context: CGContext) {
        guard rel.points.count >= 2 else { return }

        context.saveGState()

        // Set line style
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(RenderConfig.shared.strokeWidthConnector)

        // Dashed for dependency and realization
        let isDashed = rel.type == ClassRelationshipType.dependency.rawValue ||
                       rel.type == ClassRelationshipType.realization.rawValue
        if isDashed {
            context.setLineDash(phase: 0, lengths: [6, 4])
        }

        // Draw the polyline
        context.move(to: rel.points[0])
        for i in 1..<rel.points.count {
            context.addLine(to: rel.points[i])
        }
        context.strokePath()

        context.restoreGState()

        // Draw the marker
        drawRelationshipMarker(rel, in: context)
    }

    /// Draw the UML marker at the appropriate end
    private func drawRelationshipMarker(_ rel: PositionedClassRelationship, in context: CGContext) {
        guard rel.points.count >= 2 else { return }

        let markerAt = rel.markerAt

        // Get the endpoint and direction for the marker
        let endpoint: CGPoint
        let prevPoint: CGPoint

        if markerAt == "from" {
            endpoint = rel.points[0]
            prevPoint = rel.points[1]
        } else {
            endpoint = rel.points[rel.points.count - 1]
            prevPoint = rel.points[rel.points.count - 2]
        }

        // Calculate angle
        let dx = endpoint.x - prevPoint.x
        let dy = endpoint.y - prevPoint.y
        let angle = atan2(dy, dx)

        context.saveGState()
        context.translateBy(x: endpoint.x, y: endpoint.y)
        context.rotate(by: angle)

        // Draw marker based on type
        switch rel.type {
        case ClassRelationshipType.inheritance.rawValue,
             ClassRelationshipType.realization.rawValue:
            drawHollowTriangle(in: context)

        case ClassRelationshipType.composition.rawValue:
            drawFilledDiamond(in: context)

        case ClassRelationshipType.aggregation.rawValue:
            drawHollowDiamond(in: context)

        case ClassRelationshipType.association.rawValue,
             ClassRelationshipType.dependency.rawValue:
            drawOpenArrow(in: context)

        default:
            break
        }

        context.restoreGState()
    }

    /// Draw hollow triangle (inheritance, realization)
    private func drawHollowTriangle(in context: CGContext) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -12, y: -5))
        path.addLine(to: CGPoint(x: -12, y: 5))
        path.closeSubpath()

        context.addPath(path)
        context.setFillColor(theme.background.cgColor)
        context.setStrokeColor(theme.effectiveArrow().cgColor)
        context.setLineWidth(1.5)
        context.drawPath(using: .fillStroke)
    }

    /// Draw filled diamond (composition)
    private func drawFilledDiamond(in context: CGContext) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -6, y: -5))
        path.addLine(to: CGPoint(x: -12, y: 0))
        path.addLine(to: CGPoint(x: -6, y: 5))
        path.closeSubpath()

        context.addPath(path)
        context.setFillColor(theme.effectiveArrow().cgColor)
        context.setStrokeColor(theme.effectiveArrow().cgColor)
        context.setLineWidth(1)
        context.drawPath(using: .fillStroke)
    }

    /// Draw hollow diamond (aggregation)
    private func drawHollowDiamond(in context: CGContext) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -6, y: -5))
        path.addLine(to: CGPoint(x: -12, y: 0))
        path.addLine(to: CGPoint(x: -6, y: 5))
        path.closeSubpath()

        context.addPath(path)
        context.setFillColor(theme.background.cgColor)
        context.setStrokeColor(theme.effectiveArrow().cgColor)
        context.setLineWidth(1.5)
        context.drawPath(using: .fillStroke)
    }

    /// Draw open arrow (association, dependency)
    private func drawOpenArrow(in context: CGContext) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -8, y: -3))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -8, y: 3))

        context.addPath(path)
        context.setStrokeColor(theme.effectiveArrow().cgColor)
        context.setLineWidth(1.5)
        context.strokePath()
    }

    // MARK: - Relationship Labels

    /// Render relationship labels and cardinality text
    private func renderRelationshipLabels(_ rel: PositionedClassRelationship, in context: CGContext) {
        guard rel.label != nil || rel.fromCardinality != nil || rel.toCardinality != nil else { return }
        guard rel.points.count >= 2 else { return }

        let labelFont = RenderConfig.shared.edgeLabelFont()

        // Label at center (prefer labelPosition if available)
        if let label = rel.label, !label.isEmpty {
            let pos = rel.labelPosition ?? midpoint(rel.points)
            labelRenderer.drawText(
                label,
                at: CGPoint(x: pos.x, y: pos.y - 8),
                context: context,
                color: theme.effectiveMuted(),
                font: labelFont,
                alignment: .center
            )
        }

        // From cardinality (near start)
        if let fromCard = rel.fromCardinality, !fromCard.isEmpty {
            let p = rel.points[0]
            let next = rel.points[1]
            let offset = cardinalityOffset(from: p, to: next)
            labelRenderer.drawText(
                fromCard,
                at: CGPoint(x: p.x + offset.x, y: p.y + offset.y),
                context: context,
                color: theme.effectiveMuted(),
                font: labelFont,
                alignment: .center
            )
        }

        // To cardinality (near end)
        if let toCard = rel.toCardinality, !toCard.isEmpty {
            let p = rel.points[rel.points.count - 1]
            let prev = rel.points[rel.points.count - 2]
            let offset = cardinalityOffset(from: p, to: prev)
            labelRenderer.drawText(
                toCard,
                at: CGPoint(x: p.x + offset.x, y: p.y + offset.y),
                context: context,
                color: theme.effectiveMuted(),
                font: labelFont,
                alignment: .center
            )
        }
    }

    /// Get the midpoint of a point array
    private func midpoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let mid = points.count / 2
        return points[mid]
    }

    /// Calculate offset for cardinality label perpendicular to edge direction
    private func cardinalityOffset(from: CGPoint, to: CGPoint) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y

        // Place label perpendicular to the edge, 14px away
        if abs(dx) > abs(dy) {
            // Mostly horizontal — offset vertically
            return CGPoint(x: dx > 0 ? 14 : -14, y: -10)
        }
        // Mostly vertical — offset horizontally
        return CGPoint(x: -14, y: dy > 0 ? 14 : -14)
    }
}
