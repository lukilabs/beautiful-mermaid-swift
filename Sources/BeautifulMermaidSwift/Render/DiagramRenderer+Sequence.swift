import Foundation
import CoreGraphics

extension DiagramRenderer {

    func _drawSequence(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard
            let actors = positioned.sequenceActors,
            let messages = positioned.sequenceMessages,
            !actors.isEmpty
        else { return }

        let blocks = positioned.sequenceBlocks ?? []
        let lifelines = positioned.seqLifelines
        let activations = positioned.seqActivations
        let notes = positioned.seqNotes

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            let ch = max(1, positioned.height)

            let config = self.config

            // 1. Block regions (loop/alt/opt/par/critical)
            for block in blocks {
                let blockRect = CGRect(x: block.x, y: block.y, width: block.width, height: block.height)
                // Border only (transparent background, matching OSS)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(config.strokeWidthOuterBox)
                ctx.stroke(blockRect)

                // Tab label
                let labelText = "\(block.type)\(block.label.isEmpty ? "" : " [\(block.label)]")"
                let tabWidth = config.estimateTextWidth(labelText, fontSize: config.fontSizeEdgeLabel, fontWeight: config.fontWeightGroupHeader) + 16
                let tabHeight = config.sequenceTabHeight
                let tabRect = CGRect(x: block.x, y: block.y, width: tabWidth, height: tabHeight)
                ctx.setFillColor(self.theme.subgraphHeaderColor().cgColor)
                ctx.fill(tabRect)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.stroke(tabRect)

                self._drawTextInFlipped(
                    labelText,
                    at: CGPoint(x: block.x + 6, y: block.y + tabHeight / 2),
                    context: ctx, contentHeight: ch,
                    color: self.theme.effectiveTextSecondary(),
                    font: config.groupHeaderFont(),
                    alignment: .left
                )

                // Dividers
                for divider in block.dividers {
                    ctx.saveGState()
                    ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                    ctx.setLineWidth(0.75)
                    ctx.setLineDash(phase: 0, lengths: [6, 4])
                    ctx.move(to: CGPoint(x: block.x, y: divider.y))
                    ctx.addLine(to: CGPoint(x: block.x + block.width, y: divider.y))
                    ctx.strokePath()
                    ctx.restoreGState()

                    if !divider.label.isEmpty {
                        self._drawTextInFlipped(
                            "[\(divider.label)]",
                            at: CGPoint(x: block.x + 8, y: divider.y + 14),
                            context: ctx, contentHeight: ch,
                            color: self.theme.effectiveMuted(),
                            font: config.edgeLabelFont(),
                            alignment: .left
                        )
                    }
                }
            }

            // 2. Lifelines (dashed vertical lines)
            ctx.saveGState()
            ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
            ctx.setLineWidth(0.75)
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            if lifelines.isEmpty {
                // Fallback: compute from actors
                let maxY = messages.map(\.y).max() ?? 300
                for actor in actors {
                    ctx.move(to: CGPoint(x: actor.x, y: actor.y + actor.height))
                    ctx.addLine(to: CGPoint(x: actor.x, y: maxY + 60))
                    ctx.strokePath()
                }
            } else {
                for ll in lifelines {
                    ctx.move(to: CGPoint(x: ll.x, y: ll.topY))
                    ctx.addLine(to: CGPoint(x: ll.x, y: ll.bottomY))
                    ctx.strokePath()
                }
            }
            ctx.restoreGState()

            // 3. Activation bars
            for act in activations {
                let actRect = CGRect(x: act.x - act.width / 2, y: act.topY, width: act.width, height: act.bottomY - act.topY)
                ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                ctx.fill(actRect)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(config.strokeWidthInnerBox)
                ctx.stroke(actRect)
            }

            // 4. Messages (arrows with labels)
            for msg in messages {
                ctx.saveGState()
                ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                ctx.setLineWidth(config.strokeWidthConnector)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)

                if msg.lineStyle == "dashed" {
                    ctx.setLineDash(phase: 0, lengths: [6, 4])
                }

                if msg.isSelf {
                    let loopW: CGFloat = 28, loopH: CGFloat = 20
                    let pts = [
                        CGPoint(x: msg.x1, y: msg.y),
                        CGPoint(x: msg.x1 + loopW, y: msg.y),
                        CGPoint(x: msg.x1 + loopW, y: msg.y + loopH),
                        CGPoint(x: msg.x2, y: msg.y + loopH),
                    ]
                    ctx.move(to: pts[0])
                    for p in pts.dropFirst() { ctx.addLine(to: p) }
                    ctx.strokePath()
                    ctx.restoreGState()

                    guard let lastPt = pts.last else { return }
                    self._drawSequenceArrowHead(at: lastPt, from: pts[pts.count - 2], style: msg.arrowHead, in: ctx)
                    self._drawTextInFlipped(
                        msg.label,
                        at: CGPoint(x: msg.x1 + loopW + 4, y: msg.y + loopH / 2),
                        context: ctx, contentHeight: ch,
                        color: self.theme.effectiveMuted(),
                        font: config.edgeLabelFont(),
                        alignment: .left
                    )
                } else {
                    ctx.move(to: CGPoint(x: msg.x1, y: msg.y))
                    ctx.addLine(to: CGPoint(x: msg.x2, y: msg.y))
                    ctx.strokePath()
                    ctx.restoreGState()

                    self._drawSequenceArrowHead(at: CGPoint(x: msg.x2, y: msg.y), from: CGPoint(x: msg.x1, y: msg.y), style: msg.arrowHead, in: ctx)
                    self._drawTextInFlipped(
                        msg.label,
                        at: CGPoint(x: (msg.x1 + msg.x2) / 2, y: msg.y - 8),
                        context: ctx, contentHeight: ch,
                        color: self.theme.effectiveMuted(),
                        font: config.edgeLabelFont(),
                        alignment: .center
                    )
                }
            }

            // 5. Notes (sticky-note polygons with fold corner)
            for note in notes {
                let noteRect = CGRect(x: note.x, y: note.y, width: note.width, height: note.height)
                let foldSize: CGFloat = 6

                let notePath = CGMutablePath()
                notePath.move(to: CGPoint(x: noteRect.minX, y: noteRect.minY))
                notePath.addLine(to: CGPoint(x: noteRect.maxX - foldSize, y: noteRect.minY))
                notePath.addLine(to: CGPoint(x: noteRect.maxX, y: noteRect.minY + foldSize))
                notePath.addLine(to: CGPoint(x: noteRect.maxX, y: noteRect.maxY))
                notePath.addLine(to: CGPoint(x: noteRect.minX, y: noteRect.maxY))
                notePath.closeSubpath()

                ctx.setFillColor(self.theme.subgraphHeaderColor().cgColor)
                ctx.addPath(notePath)
                ctx.fillPath()
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(config.strokeWidthInnerBox)
                ctx.addPath(notePath)
                ctx.strokePath()

                // Fold triangle
                let foldPath = CGMutablePath()
                foldPath.move(to: CGPoint(x: noteRect.maxX - foldSize, y: noteRect.minY))
                foldPath.addLine(to: CGPoint(x: noteRect.maxX - foldSize, y: noteRect.minY + foldSize))
                foldPath.addLine(to: CGPoint(x: noteRect.maxX, y: noteRect.minY + foldSize))
                foldPath.closeSubpath()
                ctx.setFillColor(self.theme.effectiveBorder().cgColor)
                ctx.addPath(foldPath)
                ctx.fillPath()

                if !note.text.isEmpty {
                    let inset = noteRect.insetBy(dx: 6, dy: 4)
                    self.labelRenderer.drawMultilineText(
                        note.text,
                        in: inset,
                        context: ctx,
                        color: self.theme.effectiveMuted(),
                        font: config.edgeLabelFont(),
                        alignment: .center
                    )
                }
            }

            // 6. Actor boxes (on top)
            for actor in actors {
                if actor.type == "actor" {
                    self._drawActorFigure(actor, in: ctx, contentHeight: ch)
                } else {
                    let box = CGRect(x: actor.x - actor.width / 2, y: actor.y, width: actor.width, height: actor.height)
                    let path = BMBezierPath(roundedRect: box, cornerRadius: 4)
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                    ctx.addPath(path.bm_cgPath)
                    ctx.fillPath()
                    ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                    ctx.setLineWidth(1.0)
                    ctx.addPath(path.bm_cgPath)
                    ctx.strokePath()

                    self._drawTextInFlipped(
                        actor.label,
                        at: CGPoint(x: box.midX, y: box.midY),
                        context: ctx, contentHeight: ch,
                        color: self.theme.foreground,
                        font: config.nodeLabelFont(),
                        alignment: .center
                    )
                }
            }
        }
    }

    private func _drawSequenceArrowHead(at point: CGPoint, from prev: CGPoint, style: String = "filled", in context: CGContext) {
        let config = self.config
        let arrowColor = theme.effectiveArrow()
        let lineWidth = config.strokeWidthConnector
        let arrowWidth = config.arrowHeadWidth * lineWidth
        let arrowHeight = config.arrowHeadHeight * lineWidth
        let angle = atan2(point.y - prev.y, point.x - prev.x)

        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)
        context.setStrokeColor(arrowColor.cgColor)
        context.setFillColor(arrowColor.cgColor)
        context.setLineWidth(config.strokeWidthConnector)

        switch style {
        case "open":
            // Open V shape (not filled)
            context.move(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            context.addLine(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            context.strokePath()
        case "cross":
            // X mark
            let crossSize = arrowHeight * 0.5
            context.move(to: CGPoint(x: -crossSize * 2, y: -crossSize))
            context.addLine(to: CGPoint(x: 0, y: crossSize))
            context.move(to: CGPoint(x: -crossSize * 2, y: crossSize))
            context.addLine(to: CGPoint(x: 0, y: -crossSize))
            context.strokePath()
        default:
            // Filled triangle
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            path.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
        context.restoreGState()
    }

    private func _drawActorFigure(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let config = self.config
        let cx = actor.x
        let boxTop = actor.y
        let figH = actor.height - 16 // leave room for label below
        let scale = figH / 24.0 // SVG viewBox is 24x24
        let originX = cx - 12 * scale
        let originY = boxTop

        context.saveGState()
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Outer circle (24x24 space: circle at center 12,12 radius 11)
        let outerR = 11.0 * scale
        context.strokeEllipse(in: CGRect(
            x: originX + 12 * scale - outerR,
            y: originY + 12 * scale - outerR,
            width: outerR * 2, height: outerR * 2
        ))

        // Head circle (center at 12, 10, radius ~3)
        let headR = 3.0 * scale
        context.strokeEllipse(in: CGRect(
            x: originX + 12 * scale - headR,
            y: originY + 10 * scale - headR,
            width: headR * 2, height: headR * 2
        ))

        // Shoulders arc: bezier from (5.6, 18.4) through (12, 16) to (18.4, 18.4)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: originX + 5.6 * scale, y: originY + 18.4 * scale))
        path.addQuadCurve(
            to: CGPoint(x: originX + 18.4 * scale, y: originY + 18.4 * scale),
            control: CGPoint(x: originX + 12 * scale, y: originY + 16 * scale)
        )
        context.addPath(path)
        context.strokePath()
        context.restoreGState()

        // Label below the figure
        let labelY = boxTop + figH + 8
        _drawTextInFlipped(
            actor.label,
            at: CGPoint(x: cx, y: labelY),
            context: context, contentHeight: contentHeight,
            color: theme.foreground,
            font: config.nodeLabelFont(),
            alignment: .center
        )
    }
}
