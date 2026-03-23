import Foundation
import CoreGraphics

extension DiagramRenderer {

    func _drawClass(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard
            let classes = positioned.classNodes,
            let relationships = positioned.classRelationships,
            !classes.isEmpty
        else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            let ch = max(1, positioned.height)

            let config = self.config

            // Relationships (lines)
            for rel in relationships {
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                guard pts.count >= 2 else { continue }
                ctx.saveGState()
                ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                ctx.setLineWidth(config.strokeWidthConnector)
                let isDashed = rel.type == RenderRelType.dependency.rawValue ||
                               rel.type == RenderRelType.realization.rawValue
                if isDashed { ctx.setLineDash(phase: 0, lengths: [6, 4]) }
                ctx.move(to: pts[0])
                for i in 1..<pts.count { ctx.addLine(to: pts[i]) }
                ctx.strokePath()
                ctx.restoreGState()

                // Marker
                self._drawClassMarker(rel, pts: pts, in: ctx)
            }

            // Class boxes
            for cls in classes {
                let box = CGRect(x: cls.x, y: cls.y, width: cls.width, height: cls.height)
                ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                ctx.fill(box)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(config.strokeWidthOuterBox)
                ctx.stroke(box)

                // Header
                let headerRect = CGRect(x: cls.x, y: cls.y, width: cls.width, height: cls.headerHeight)
                ctx.setFillColor(self.theme.subgraphHeaderColor().cgColor)
                ctx.fill(headerRect)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.stroke(headerRect)

                // Annotation (<<interface>>, <<abstract>>, etc.)
                var nameY = cls.y + cls.headerHeight / 2
                if let annotation = cls.annotation, !annotation.isEmpty {
                    let annotY = cls.y + 12
                    let annotFont = self._italicSystemFont(size: 10, weight: 0.23)
                    self._drawTextInFlipped(
                        "<<\(annotation)>>",
                        at: CGPoint(x: cls.x + cls.width / 2, y: annotY),
                        context: ctx, contentHeight: ch,
                        color: self.theme.effectiveMuted(),
                        font: annotFont,
                        alignment: .center
                    )
                    nameY = cls.y + cls.headerHeight / 2 + 6
                }

                // Class name
                let nameFont = BMFont.systemFont(ofSize: config.fontSizeNodeLabel, weight: .bold)
                self._drawTextInFlipped(
                    cls.label,
                    at: CGPoint(x: cls.x + cls.width / 2, y: nameY),
                    context: ctx, contentHeight: ch,
                    color: self.theme.foreground,
                    font: nameFont,
                    alignment: .center
                )

                // Divider
                let attrTop = cls.y + cls.headerHeight
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(config.strokeWidthInnerBox)
                ctx.move(to: CGPoint(x: cls.x, y: attrTop))
                ctx.addLine(to: CGPoint(x: cls.x + cls.width, y: attrTop))
                ctx.strokePath()

                // Attributes
                for i in 0..<cls.attributes.count {
                    let member = cls.attributes[i]
                    let memberY = attrTop + 4 + CGFloat(i) * config.classMemberRowHeight + config.classMemberRowHeight / 2
                    self._drawClassMemberHighlighted(member, at: CGPoint(x: cls.x + config.classBoxPadX, y: memberY), context: ctx, contentHeight: ch, config: config)
                }

                // Method divider
                let methodTop = attrTop + cls.attrHeight
                ctx.move(to: CGPoint(x: cls.x, y: methodTop))
                ctx.addLine(to: CGPoint(x: cls.x + cls.width, y: methodTop))
                ctx.strokePath()

                // Methods
                for i in 0..<cls.methods.count {
                    let method = cls.methods[i]
                    let memberY = methodTop + 4 + CGFloat(i) * config.classMemberRowHeight + config.classMemberRowHeight / 2
                    self._drawClassMemberHighlighted(method, at: CGPoint(x: cls.x + config.classBoxPadX, y: memberY), context: ctx, contentHeight: ch, config: config)
                }
            }

            // Relationship labels + cardinality
            for rel in relationships {
                guard rel.label != nil || rel.fromCardinality != nil || rel.toCardinality != nil else { continue }
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                guard pts.count >= 2 else { continue }
                let labelFont = config.edgeLabelFont()

                if let label = rel.label, !label.isEmpty {
                    let pos = rel.labelPosition.map { CGPoint(x: $0.x, y: $0.y) } ?? pts[pts.count / 2]
                    self._drawTextInFlipped(label, at: CGPoint(x: pos.x, y: pos.y - 8), context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: labelFont, alignment: .center)
                }

                // From cardinality (near start)
                if let fromCard = rel.fromCardinality, !fromCard.isEmpty {
                    let p = pts[0], next = pts[1]
                    let offset = self._cardinalityOffset(from: p, to: next)
                    self._drawTextInFlipped(fromCard, at: CGPoint(x: p.x + offset.x, y: p.y + offset.y), context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: labelFont, alignment: .center)
                }

                // To cardinality (near end)
                if let toCard = rel.toCardinality, !toCard.isEmpty {
                    let p = pts[pts.count - 1], prev = pts[pts.count - 2]
                    let offset = self._cardinalityOffset(from: p, to: prev)
                    self._drawTextInFlipped(toCard, at: CGPoint(x: p.x + offset.x, y: p.y + offset.y), context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: labelFont, alignment: .center)
                }
            }
        }
    }

    private func _drawClassMarker(_ rel: PositionedClassRelationship, pts: [CGPoint], in context: CGContext) {
        guard pts.count >= 2 else { return }
        let endpoint: CGPoint
        let prevPoint: CGPoint
        if rel.markerAt == "from" {
            endpoint = pts[0]; prevPoint = pts[1]
        } else {
            endpoint = pts[pts.count - 1]; prevPoint = pts[pts.count - 2]
        }
        let angle = atan2(endpoint.y - prevPoint.y, endpoint.x - prevPoint.x)

        context.saveGState()
        context.translateBy(x: endpoint.x, y: endpoint.y)
        context.rotate(by: angle)

        switch rel.type {
        case RenderRelType.inheritance.rawValue,
             RenderRelType.realization.rawValue:
            let path = CGMutablePath()
            path.move(to: .zero); path.addLine(to: CGPoint(x: -12, y: -5)); path.addLine(to: CGPoint(x: -12, y: 5)); path.closeSubpath()
            context.addPath(path)
            context.setFillColor(theme.background.cgColor)
            context.setStrokeColor(theme.effectiveArrow().cgColor)
            context.setLineWidth(1.5)
            context.drawPath(using: .fillStroke)
        case RenderRelType.composition.rawValue:
            let path = CGMutablePath()
            path.move(to: .zero); path.addLine(to: CGPoint(x: -6, y: -5)); path.addLine(to: CGPoint(x: -12, y: 0)); path.addLine(to: CGPoint(x: -6, y: 5)); path.closeSubpath()
            context.addPath(path)
            context.setFillColor(theme.effectiveArrow().cgColor)
            context.drawPath(using: .fillStroke)
        case RenderRelType.aggregation.rawValue:
            let path = CGMutablePath()
            path.move(to: .zero); path.addLine(to: CGPoint(x: -6, y: -5)); path.addLine(to: CGPoint(x: -12, y: 0)); path.addLine(to: CGPoint(x: -6, y: 5)); path.closeSubpath()
            context.addPath(path)
            context.setFillColor(theme.background.cgColor)
            context.setStrokeColor(theme.effectiveArrow().cgColor)
            context.setLineWidth(1.5)
            context.drawPath(using: .fillStroke)
        default:
            // Open arrow for association/dependency
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -8, y: -3)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: -8, y: 3))
            context.addPath(path)
            context.setStrokeColor(theme.effectiveArrow().cgColor)
            context.setLineWidth(1.5)
            context.strokePath()
        }
        context.restoreGState()
    }

    private func _classMemberText(_ member: ClassMember) -> String {
        var text = ""
        if !member.visibility.isEmpty { text += member.visibility + " " }
        text += member.name
        if let params = member.params, !params.isEmpty { text += "(\(params))" }
        if let type = member.type, !type.isEmpty { text += ": \(type)" }
        return text
    }

    /// Draw a class member with syntax highlighting (visibility/name/type in separate colors)
    /// and italic for abstract, underline for static.
    private func _drawClassMemberHighlighted(
        _ member: ClassMember,
        at point: CGPoint,
        context ctx: CGContext,
        contentHeight ch: CGFloat,
        config: RenderConfig
    ) {
        let memberFont = member.isAbstract
            ? _italicMonoFont(size: config.classMemberFontSize)
            : _monoFont(size: config.classMemberFontSize)
        var currentX = point.x

        // Visibility symbol
        if !member.visibility.isEmpty {
            let visText = member.visibility + " "
            _drawTextInFlipped(visText, at: CGPoint(x: currentX, y: point.y), context: ctx, contentHeight: ch, color: theme.effectiveTextFaint(), font: memberFont, alignment: .left)
            currentX += config.estimateMonoTextWidth(visText, fontSize: config.classMemberFontSize)
        }

        // Member name (methods include parentheses and params)
        let displayName = member.isMethod ? "\(member.name)(\(member.params ?? ""))" : member.name
        _drawTextInFlipped(displayName, at: CGPoint(x: currentX, y: point.y), context: ctx, contentHeight: ch, color: theme.effectiveTextSecondary(), font: memberFont, alignment: .left)

        // Underline for static members
        if member.isStatic {
            let nameWidth = config.estimateMonoTextWidth(displayName, fontSize: config.classMemberFontSize)
            let underlineY = point.y + 6
            ctx.saveGState()
            ctx.setStrokeColor(theme.effectiveTextSecondary().cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: currentX, y: underlineY))
            ctx.addLine(to: CGPoint(x: currentX + nameWidth, y: underlineY))
            ctx.strokePath()
            ctx.restoreGState()
        }

        currentX += config.estimateMonoTextWidth(displayName, fontSize: config.classMemberFontSize)

        // Type annotation
        if let type = member.type, !type.isEmpty {
            let colonText = ": "
            _drawTextInFlipped(colonText, at: CGPoint(x: currentX, y: point.y), context: ctx, contentHeight: ch, color: theme.effectiveTextFaint(), font: memberFont, alignment: .left)
            currentX += config.estimateMonoTextWidth(colonText, fontSize: config.classMemberFontSize)
            _drawTextInFlipped(type, at: CGPoint(x: currentX, y: point.y), context: ctx, contentHeight: ch, color: theme.effectiveMuted(), font: memberFont, alignment: .left)
        }
    }

    /// Calculate offset for cardinality label perpendicular to edge direction
    func _cardinalityOffset(from: CGPoint, to: CGPoint) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        if abs(dx) > abs(dy) {
            return CGPoint(x: dx > 0 ? 14 : -14, y: -10)
        }
        return CGPoint(x: -14, y: dy > 0 ? 14 : -14)
    }
}
