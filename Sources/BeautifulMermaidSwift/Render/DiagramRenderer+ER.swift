import Foundation
import CoreGraphics

extension DiagramRenderer {

    func _drawEr(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard
            let entities = positioned.erEntities,
            let relationships = positioned.erRelationships,
            !entities.isEmpty
        else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            let ch = max(1, positioned.height)

            let config = self.config

            // Relationship lines
            for rel in relationships {
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                guard pts.count >= 2 else { continue }
                ctx.saveGState()
                ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                ctx.setLineWidth(config.strokeWidthConnector)
                if !rel.identifying { ctx.setLineDash(phase: 0, lengths: [6, 4]) }
                ctx.move(to: pts[0])
                for i in 1..<pts.count { ctx.addLine(to: pts[i]) }
                ctx.strokePath()
                ctx.restoreGState()
            }

            // Entity boxes
            for entity in entities {
                let box = CGRect(x: entity.x, y: entity.y, width: entity.width, height: entity.height)
                ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                ctx.fill(box)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(config.strokeWidthOuterBox)
                ctx.stroke(box)

                let headerRect = CGRect(x: entity.x, y: entity.y, width: entity.width, height: entity.headerHeight)
                ctx.setFillColor(self.theme.subgraphHeaderColor().cgColor)
                ctx.fill(headerRect)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.stroke(headerRect)

                let nameFont = BMFont.systemFont(ofSize: config.fontSizeNodeLabel, weight: .bold)
                self._drawTextInFlipped(
                    entity.label,
                    at: CGPoint(x: entity.x + entity.width / 2, y: entity.y + entity.headerHeight / 2),
                    context: ctx, contentHeight: ch,
                    color: self.theme.foreground,
                    font: nameFont,
                    alignment: .center
                )

                let attrTop = entity.y + entity.headerHeight
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(config.strokeWidthInnerBox)
                ctx.move(to: CGPoint(x: entity.x, y: attrTop))
                ctx.addLine(to: CGPoint(x: entity.x + entity.width, y: attrTop))
                ctx.strokePath()

                let monoFont = self._monoFont(size: config.erAttrFontSize)
                if entity.attributes.isEmpty {
                    // Empty attribute placeholder
                    let italicFont = self._italicSystemFont(size: config.erAttrFontSize, weight: 0.0)
                    self._drawTextInFlipped(
                        "(no attributes)",
                        at: CGPoint(x: entity.x + entity.width / 2, y: attrTop + entity.rowHeight / 2),
                        context: ctx, contentHeight: ch,
                        color: self.theme.effectiveTextFaint(),
                        font: italicFont,
                        alignment: .center
                    )
                }
                for i in 0..<entity.attributes.count {
                    let attr = entity.attributes[i]
                    let rowY = attrTop + CGFloat(i) * entity.rowHeight + entity.rowHeight / 2

                    // Key badges
                    if !attr.keys.isEmpty {
                        let keyText = attr.keys.joined(separator: ",")
                        let keyWidth = config.estimateTextWidth(keyText, fontSize: 9, fontWeight: 600) + 8
                        let badgeRect = CGRect(x: entity.x + 6, y: rowY - 7, width: keyWidth, height: 14)
                        let badgePath = BMBezierPath(roundedRect: badgeRect, cornerRadius: 2)
                        ctx.setFillColor(self.theme.keyBadgeColor().cgColor)
                        ctx.addPath(badgePath.bm_cgPath)
                        ctx.fillPath()

                        let keyFont = BMFont.systemFont(ofSize: 9, weight: .semibold)
                        self._drawTextInFlipped(keyText, at: CGPoint(x: entity.x + 6 + keyWidth / 2, y: rowY), context: ctx, contentHeight: ch, color: self.theme.effectiveTextSecondary(), font: keyFont, alignment: .center)
                    }

                    // Type (left)
                    let typeX = entity.x + 8 + (attr.keys.isEmpty ? 0 : config.estimateTextWidth(attr.keys.joined(separator: ","), fontSize: 9, fontWeight: 600) + 14)
                    self._drawTextInFlipped(attr.type, at: CGPoint(x: typeX, y: rowY), context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: monoFont, alignment: .left)

                    // Name (right)
                    self._drawTextInFlipped(attr.name, at: CGPoint(x: entity.x + entity.width - 8, y: rowY), context: ctx, contentHeight: ch, color: self.theme.effectiveTextSecondary(), font: monoFont, alignment: .right)
                }
            }

            // Cardinality markers
            for rel in relationships {
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                guard pts.count >= 2 else { continue }
                self._drawCrowsFoot(point: pts[0], toward: pts[1], cardinality: rel.cardinality1, in: ctx)
                self._drawCrowsFoot(point: pts[pts.count - 1], toward: pts[pts.count - 2], cardinality: rel.cardinality2, in: ctx)
            }

            // Relationship labels with background + border
            for rel in relationships {
                guard !rel.label.isEmpty else { continue }
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                let mid = self._arcLengthMidpoint(pts)
                let labelFont = config.edgeLabelFont()
                let textW = config.estimateTextWidth(rel.label, fontSize: config.fontSizeEdgeLabel, fontWeight: 400) + 8
                let textH = config.fontSizeEdgeLabel + 6
                let bgRect = CGRect(x: mid.x - textW / 2, y: mid.y - textH / 2, width: textW, height: textH)
                let bgPath = BMBezierPath(roundedRect: bgRect, cornerRadius: 2)
                ctx.setFillColor(self.theme.background.cgColor)
                ctx.addPath(bgPath.bm_cgPath)
                ctx.fillPath()
                ctx.setStrokeColor(self.theme.effectiveInnerStroke().cgColor)
                ctx.setLineWidth(0.5)
                ctx.addPath(bgPath.bm_cgPath)
                ctx.strokePath()
                self._drawTextInFlipped(rel.label, at: mid, context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: labelFont, alignment: .center)
            }
        }
    }

    private func _drawCrowsFoot(point: CGPoint, toward: CGPoint, cardinality: String, in context: CGContext) {
        let sw = self.config.strokeWidthConnector + 0.25
        let dx = point.x - toward.x, dy = point.y - toward.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return }
        let ux = dx / len, uy = dy / len
        let px = -uy, py = ux

        let tipX = point.x - ux * 4, tipY = point.y - uy * 4

        let hasOneLine = cardinality == "one" || cardinality == "zero-one"
        let hasCrowsFoot = cardinality == "many" || cardinality == "zero-many"
        let hasCircle = cardinality == "zero-one" || cardinality == "zero-many"

        context.saveGState()
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(sw)

        if hasOneLine {
            let halfW: CGFloat = 6
            context.move(to: CGPoint(x: tipX + px * halfW, y: tipY + py * halfW))
            context.addLine(to: CGPoint(x: tipX - px * halfW, y: tipY - py * halfW))
            context.strokePath()
            let line2X = tipX - ux * 4, line2Y = tipY - uy * 4
            context.move(to: CGPoint(x: line2X + px * halfW, y: line2Y + py * halfW))
            context.addLine(to: CGPoint(x: line2X - px * halfW, y: line2Y - py * halfW))
            context.strokePath()
        }

        if hasCrowsFoot {
            let fanW: CGFloat = 7
            let backX = point.x - ux * 16, backY = point.y - uy * 16
            context.move(to: CGPoint(x: tipX + px * fanW, y: tipY + py * fanW))
            context.addLine(to: CGPoint(x: backX, y: backY))
            context.strokePath()
            context.move(to: CGPoint(x: tipX, y: tipY))
            context.addLine(to: CGPoint(x: backX, y: backY))
            context.strokePath()
            context.move(to: CGPoint(x: tipX - px * fanW, y: tipY - py * fanW))
            context.addLine(to: CGPoint(x: backX, y: backY))
            context.strokePath()
        }

        if hasCircle {
            let circleOffset: CGFloat = hasCrowsFoot ? 20 : 12
            let cx = point.x - ux * circleOffset, cy = point.y - uy * circleOffset
            let circleRect = CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8)
            context.setFillColor(theme.background.cgColor)
            context.fillEllipse(in: circleRect)
            context.strokeEllipse(in: circleRect)
        }

        context.restoreGState()
    }

    func _arcLengthMidpoint(_ points: [CGPoint]) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        var totalLen: CGFloat = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x, dy = points[i].y - points[i - 1].y
            totalLen += sqrt(dx * dx + dy * dy)
        }
        guard totalLen > 0 else { return points[0] }
        let halfLen = totalLen / 2
        var walked: CGFloat = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x, dy = points[i].y - points[i - 1].y
            let segLen = sqrt(dx * dx + dy * dy)
            if walked + segLen >= halfLen {
                let t = segLen > 0 ? (halfLen - walked) / segLen : 0
                return CGPoint(x: points[i - 1].x + dx * t, y: points[i - 1].y + dy * t)
            }
            walked += segLen
        }
        guard let last = points.last else { return points[0] }
        return last
    }
}
