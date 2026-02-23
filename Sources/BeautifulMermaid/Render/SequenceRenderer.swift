// SPDX-License-Identifier: MIT
//
//  SequenceRenderer.swift
//  BeautifulMermaid
//
//  Renders positioned sequence diagrams to CGContext
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Renderer for sequence diagrams
public class SequenceRenderer {
    /// Theme for rendering
    public var theme: DiagramTheme

    /// Label renderer for text
    private let labelRenderer: LabelRenderer

    public init(theme: DiagramTheme = .default) {
        self.theme = theme
        self.labelRenderer = LabelRenderer()
    }

    // MARK: - Main Render Method

    /// Render a positioned sequence diagram to a CGContext
    public func render(_ diagram: PositionedSequenceDiagram, in context: CGContext, bounds: CGRect) {
        context.saveGState()

        // 1. Fill background
        context.setFillColor(theme.background.cgColor)
        context.fill(bounds)

        // 2. Draw blocks (background boxes for loop/alt/opt)
        renderBlocks(diagram.blocks, in: context)

        // 3. Draw lifelines (dashed vertical lines)
        renderLifelines(diagram.lifelines, in: context)

        // 4. Draw activation boxes
        renderActivations(diagram.activations, in: context)

        // 5. Draw messages (arrows with labels)
        renderMessages(diagram.messages, in: context)

        // 6. Draw notes
        renderNotes(diagram.notes, in: context)

        // 7. Draw actor boxes (on top)
        renderActors(diagram.actors, in: context)

        context.restoreGState()
    }

    // MARK: - Block Rendering

    private func renderBlocks(_ blocks: [PositionedSequenceBlock], in context: CGContext) {
        for block in blocks {
            let bounds = block.bounds

            // Draw border only - TypeScript uses fill="none" (transparent background)
            // No background fill for blocks
            context.setStrokeColor(theme.effectiveBorder().cgColor)
            context.setLineWidth(RenderConfig.shared.strokeWidthOuterBox)
            context.stroke(bounds)

            // Draw block type label in top-left corner (sharp corners)
            // Match TypeScript: tabWidth = estimateTextWidth(labelText, edgeLabel, groupHeader) + 16
            let labelText = "\(block.type.rawValue)\(block.label.isEmpty ? "" : " [\(block.label)]")"
            let config = RenderConfig.shared
            let tabWidth = config.estimateTextWidth(labelText, fontSize: config.fontSizeEdgeLabel, fontWeight: config.fontWeightGroupHeader) + 16
            let labelBgRect = CGRect(
                x: bounds.minX,
                y: bounds.minY,
                width: tabWidth,
                height: config.sequenceTabHeight
            )

            context.setFillColor(theme.subgraphHeaderColor().cgColor)
            context.fill(labelBgRect)
            context.setStrokeColor(theme.effectiveBorder().cgColor)
            context.stroke(labelBgRect)

            // Draw label text (type + optional condition) inside the tab
            // Match TypeScript: x at block.x + 6, left-aligned
            let labelFont = config.groupHeaderFont()
            labelRenderer.drawText(
                labelText,
                at: CGPoint(x: bounds.minX + 6, y: bounds.minY + config.sequenceTabHeight / 2),
                context: context,
                color: theme.effectiveTextSecondary(),
                font: labelFont,
                alignment: .left
            )

            // Draw dividers
            for divider in block.dividers {
                // Dashed line (matches TypeScript: strokeWidth 0.75, dasharray [6, 4])
                context.saveGState()
                context.setStrokeColor(theme.effectiveLine().cgColor)
                context.setLineWidth(0.75)
                context.setLineDash(phase: 0, lengths: [6, 4])

                context.move(to: CGPoint(x: bounds.minX, y: divider.y))
                context.addLine(to: CGPoint(x: bounds.maxX, y: divider.y))
                context.strokePath()
                context.restoreGState()

                // Divider label (e.g., "else")
                // TypeScript: x at block.x + 8, y at divider.y + 14, edge label font
                if !divider.label.isEmpty {
                    let dividerFont = config.edgeLabelFont()
                    labelRenderer.drawText(
                        "[\(divider.label)]",
                        at: CGPoint(x: bounds.minX + 8, y: divider.y + 14),
                        context: context,
                        color: theme.effectiveMuted(),
                        font: dividerFont,
                        alignment: .left
                    )
                }
            }
        }
    }

    // MARK: - Lifeline Rendering

    private func renderLifelines(_ lifelines: [SequenceLifeline], in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(0.75)
        context.setLineDash(phase: 0, lengths: [6, 4])

        for lifeline in lifelines {
            context.move(to: CGPoint(x: lifeline.x, y: lifeline.startY))
            context.addLine(to: CGPoint(x: lifeline.x, y: lifeline.endY))
            context.strokePath()
        }

        context.restoreGState()
    }

    // MARK: - Activation Rendering

    private func renderActivations(_ activations: [SequenceActivation], in context: CGContext) {
        for activation in activations {
            let bounds = activation.bounds

            // Fill
            context.setFillColor(theme.effectiveSurface().cgColor)
            context.fill(bounds)

            // Stroke
            context.setStrokeColor(theme.effectiveBorder().cgColor)
            context.setLineWidth(RenderConfig.shared.strokeWidthInnerBox)
            context.stroke(bounds)
        }
    }

    // MARK: - Message Rendering

    private func renderMessages(_ messages: [PositionedSequenceMessage], in context: CGContext) {
        for message in messages {
            guard message.points.count >= 2 else { continue }

            // Draw message line
            context.saveGState()

            let lineColor = theme.effectiveLine()
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(RenderConfig.shared.strokeWidthConnector)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            // Apply dash pattern for dashed lines (matches TypeScript [6, 4])
            if message.lineStyle == .dashed {
                context.setLineDash(phase: 0, lengths: [6, 4])
            }

            // Draw the path
            context.move(to: message.points[0])
            for i in 1..<message.points.count {
                context.addLine(to: message.points[i])
            }
            context.strokePath()

            context.restoreGState()

            // Draw arrow head
            let arrowPoint = message.points.last!
            drawArrowHead(
                message.arrowHead,
                at: arrowPoint,
                angle: message.arrowAngle,
                in: context
            )

            // Draw label - TypeScript uses var(--_text-muted) for message labels
            // Self-messages use left alignment, normal messages use center
            if !message.label.isEmpty {
                let labelFont = RenderConfig.shared.edgeLabelFont()
                labelRenderer.drawText(
                    message.label,
                    at: message.labelPosition,
                    context: context,
                    color: theme.effectiveMuted(),
                    font: labelFont,
                    alignment: message.isSelfMessage ? .left : .center
                )
            }
        }
    }

    private func drawArrowHead(
        _ style: SequenceArrowHead,
        at point: CGPoint,
        angle: CGFloat,
        in context: CGContext
    ) {
        // Arrow dimensions scaled by stroke width to match SVG markerUnits="strokeWidth" behavior
        let config = RenderConfig.shared
        let lineWidth = config.strokeWidthConnector
        let arrowWidth = config.arrowHeadWidth * lineWidth
        let arrowHeight = config.arrowHeadHeight * lineWidth

        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)

        let arrowColor = theme.effectiveArrow()
        context.setFillColor(arrowColor.cgColor)
        context.setStrokeColor(arrowColor.cgColor)
        context.setLineWidth(config.strokeWidthConnector)

        switch style {
        case .filled:
            // Filled triangle
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            path.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()

        case .open:
            // Open V shape
            context.move(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            context.addLine(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            context.strokePath()

        case .cross:
            // X mark
            let crossSize = arrowHeight * 0.5
            context.move(to: CGPoint(x: -crossSize * 2, y: -crossSize))
            context.addLine(to: CGPoint(x: 0, y: crossSize))
            context.move(to: CGPoint(x: -crossSize * 2, y: crossSize))
            context.addLine(to: CGPoint(x: 0, y: -crossSize))
            context.strokePath()

        case .none:
            break
        }

        context.restoreGState()
    }

    // MARK: - Note Rendering

    private func renderNotes(_ notes: [PositionedSequenceNote], in context: CGContext) {
        for note in notes {
            let bounds = note.bounds

            // Draw note background with folded corner
            let foldSize: CGFloat = RenderConfig.shared.sequenceFoldSize

            let path = CGMutablePath()
            path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.maxX - foldSize, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + foldSize))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
            path.closeSubpath()

            // Fill - TypeScript uses var(--_group-hdr) which is subgraphHeaderColor()
            context.setFillColor(theme.subgraphHeaderColor().cgColor)
            context.addPath(path)
            context.fillPath()

            // Stroke
            context.setStrokeColor(theme.effectiveBorder().cgColor)
            context.setLineWidth(RenderConfig.shared.strokeWidthInnerBox)
            context.addPath(path)
            context.strokePath()

            // Draw fold triangle (filled polygon matching TypeScript)
            let foldPath = CGMutablePath()
            foldPath.move(to: CGPoint(x: bounds.maxX - foldSize, y: bounds.minY))
            foldPath.addLine(to: CGPoint(x: bounds.maxX - foldSize, y: bounds.minY + foldSize))
            foldPath.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + foldSize))
            foldPath.closeSubpath()
            context.setFillColor(theme.effectiveBorder().cgColor)
            context.addPath(foldPath)
            context.fillPath()

            // Draw text - TypeScript uses var(--_text-muted) and edge label font
            if !note.text.isEmpty {
                let textRect = bounds.insetBy(dx: SequenceConstants.notePadding, dy: SequenceConstants.notePadding)
                let noteFont = RenderConfig.shared.edgeLabelFont()
                labelRenderer.drawMultilineText(
                    note.text,
                    in: textRect,
                    context: context,
                    color: theme.effectiveMuted(),
                    font: noteFont,
                    alignment: .left
                )
            }
        }
    }

    // MARK: - Actor Rendering

    private func renderActors(_ actors: [PositionedActor], in context: CGContext) {
        for actor in actors {
            switch actor.type {
            case .participant:
                renderParticipantBox(actor, in: context)
            case .actor:
                renderActorFigure(actor, in: context)
            }
        }
    }

    private func renderParticipantBox(_ actor: PositionedActor, in context: CGContext) {
        let bounds = actor.bounds

        // Draw rounded rectangle - TypeScript uses rx="4" (4px corner radius)
        let path = BMBezierPath(roundedRect: bounds, cornerRadius: 4)

        // Fill
        context.setFillColor(theme.effectiveSurface().cgColor)
        context.addPath(path.bm_cgPath)
        context.fillPath()

        // Stroke (TypeScript uses strokeWidth 1.0 for participants)
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(1.0)
        context.addPath(path.bm_cgPath)
        context.strokePath()

        // Label
        let labelFont = RenderConfig.shared.nodeLabelFont()
        labelRenderer.drawText(
            actor.label,
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            context: context,
            color: theme.foreground,
            font: labelFont,
            alignment: .center
        )
    }

    private func renderActorFigure(_ actor: PositionedActor, in context: CGContext) {
        let bounds = actor.bounds
        let centerX = bounds.midX

        // Circle-person icon matching TypeScript SVG paths
        // SVG coordinate space is 24x24, centered at (12, 12)
        // Scale to fit the actor box height
        let iconHeight = bounds.height - 16 // Leave room for label
        let scale = iconHeight / 24.0
        let iconCenterY = bounds.minY + iconHeight / 2

        context.saveGState()

        // Transform to position and scale the icon
        // Move origin to icon center, scale, then offset for SVG center (12, 12)
        context.translateBy(x: centerX, y: iconCenterY)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -12, y: -12)

        // Stroke settings - use thin stroke matching TypeScript
        // Use effectiveLine() color (30% foreground mix) to match TypeScript var(--_line)
        let baseStrokeWidth: CGFloat = 1.0
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(baseStrokeWidth / scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setFillColor(CGColor(gray: 0, alpha: 0)) // No fill

        // Outer circle: M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z
        context.move(to: CGPoint(x: 21, y: 12))
        context.addCurve(to: CGPoint(x: 12, y: 21), control1: CGPoint(x: 21, y: 16.9706), control2: CGPoint(x: 16.9706, y: 21))
        context.addCurve(to: CGPoint(x: 3, y: 12), control1: CGPoint(x: 7.02944, y: 21), control2: CGPoint(x: 3, y: 16.9706))
        context.addCurve(to: CGPoint(x: 12, y: 3), control1: CGPoint(x: 3, y: 7.02944), control2: CGPoint(x: 7.02944, y: 3))
        context.addCurve(to: CGPoint(x: 21, y: 12), control1: CGPoint(x: 16.9706, y: 3), control2: CGPoint(x: 21, y: 7.02944))
        context.closePath()
        context.strokePath()

        // Head circle: M15 10C15 11.6569 13.6569 13 12 13C10.3431 13 9 11.6569 9 10C9 8.34315 10.3431 7 12 7C13.6569 7 15 8.34315 15 10Z
        context.move(to: CGPoint(x: 15, y: 10))
        context.addCurve(to: CGPoint(x: 12, y: 13), control1: CGPoint(x: 15, y: 11.6569), control2: CGPoint(x: 13.6569, y: 13))
        context.addCurve(to: CGPoint(x: 9, y: 10), control1: CGPoint(x: 10.3431, y: 13), control2: CGPoint(x: 9, y: 11.6569))
        context.addCurve(to: CGPoint(x: 12, y: 7), control1: CGPoint(x: 9, y: 8.34315), control2: CGPoint(x: 10.3431, y: 7))
        context.addCurve(to: CGPoint(x: 15, y: 10), control1: CGPoint(x: 13.6569, y: 7), control2: CGPoint(x: 15, y: 8.34315))
        context.closePath()
        context.strokePath()

        // Shoulders arc: M5.62842 18.3563C7.08963 17.0398 9.39997 16 12 16C14.6 16 16.9104 17.0398 18.3716 18.3563
        context.move(to: CGPoint(x: 5.62842, y: 18.3563))
        context.addCurve(to: CGPoint(x: 12, y: 16), control1: CGPoint(x: 7.08963, y: 17.0398), control2: CGPoint(x: 9.39997, y: 16))
        context.addCurve(to: CGPoint(x: 18.3716, y: 18.3563), control1: CGPoint(x: 14.6, y: 16), control2: CGPoint(x: 16.9104, y: 17.0398))
        context.strokePath()

        context.restoreGState()

        // Label below figure
        let labelFont = RenderConfig.shared.nodeLabelFont()
        labelRenderer.drawText(
            actor.label,
            at: CGPoint(x: centerX, y: bounds.maxY - 8),
            context: context,
            color: theme.foreground,
            font: labelFont,
            alignment: .center
        )
    }
}

// MARK: - Convenience Rendering

extension SequenceRenderer {
    /// Render to a BMImage
    public func renderToImage(_ diagram: PositionedSequenceDiagram, scale: CGFloat = 2.0) -> BMImage? {
        let bounds = diagram.bounds
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            render(diagram, in: context, bounds: bounds)
        }
        #elseif canImport(AppKit)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        // Flip for AppKit
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)

        render(diagram, in: context, bounds: bounds)

        image.unlockFocus()
        return image
        #endif
    }
}
