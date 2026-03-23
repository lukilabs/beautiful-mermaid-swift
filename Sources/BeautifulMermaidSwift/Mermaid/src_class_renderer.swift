// Ported from original/src/class/renderer.ts
import Foundation
import ElkSwift

private enum _ClassFont {
    static let memberSize: Double = 11
    static let memberWeight: Int = 400
    static let annotationSize: Double = 10
    static let annotationWeight: Int = 500
}

public func renderClassSvg(
    _ diagram: PositionedClassDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderClassSvgEntry(diagram, colors, font, transparent)
}

private func _renderClassSvgEntry(
    _ diagram: PositionedClassDiagram,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    var parts: [String] = []

    let themedColors = original_src_theme.DiagramColors(
        bg: colors.bg,
        fg: colors.fg,
        line: colors.line,
        accent: colors.accent,
        muted: colors.muted,
        surface: colors.surface,
        border: colors.border
    )

    parts.append(original_src_theme.svgOpenTag(diagram.width, diagram.height, themedColors, transparent))
    parts.append(original_src_theme.buildStyleBlock(font, true))
    parts.append("<defs>")
    parts.append(_relationshipMarkerDefs())
    parts.append("</defs>")

    for rel in diagram.relationships {
        let rendered = _renderRelationship(rel)
        if !rendered.isEmpty {
            parts.append(rendered)
        }
    }

    for cls in diagram.classes {
        parts.append(_renderClassBox(cls))
    }

    for rel in diagram.relationships {
        let rendered = _renderRelationshipLabels(rel)
        if !rendered.isEmpty {
            parts.append(rendered)
        }
    }

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

private func _relationshipMarkerDefs() -> String {
    "  <marker id=\"cls-inherit\" markerWidth=\"12\" markerHeight=\"10\" refX=\"12\" refY=\"5\" orient=\"auto-start-reverse\">\n" +
        "    <polygon points=\"0 0, 12 5, 0 10\" fill=\"var(--bg)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />\n" +
        "  </marker>\n" +
        "  <marker id=\"cls-composition\" markerWidth=\"12\" markerHeight=\"10\" refX=\"0\" refY=\"5\" orient=\"auto-start-reverse\">\n" +
        "    <polygon points=\"6 0, 12 5, 6 10, 0 5\" fill=\"var(--_arrow)\" stroke=\"var(--_arrow)\" stroke-width=\"1\" />\n" +
        "  </marker>\n" +
        "  <marker id=\"cls-aggregation\" markerWidth=\"12\" markerHeight=\"10\" refX=\"0\" refY=\"5\" orient=\"auto-start-reverse\">\n" +
        "    <polygon points=\"6 0, 12 5, 6 10, 0 5\" fill=\"var(--bg)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />\n" +
        "  </marker>\n" +
        "  <marker id=\"cls-arrow\" markerWidth=\"8\" markerHeight=\"6\" refX=\"8\" refY=\"3\" orient=\"auto-start-reverse\">\n" +
        "    <polyline points=\"0 0, 8 3, 0 6\" fill=\"none\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />\n" +
        "  </marker>"
}

private func _renderClassBox(_ cls: PositionedClassNode) -> String {
    let x = cls.x
    let y = cls.y
    let width = cls.width
    let height = cls.height
    let headerHeight = cls.headerHeight
    let attrHeight = cls.attrHeight

    var parts: [String] = []
    let annotationAttr = cls.annotation.map { " data-annotation=\"\(_escapeAttr($0))\"" } ?? ""
    parts.append(
        "<g class=\"class-node\" data-id=\"\(_escapeAttr(cls.id))\" data-label=\"\(_escapeAttr(cls.label))\"\(annotationAttr)>"
    )

    parts.append(
        "  <rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" " +
            "rx=\"0\" ry=\"0\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
    )

    parts.append(
        "  <rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(headerHeight)\" " +
            "rx=\"0\" ry=\"0\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
    )

    var nameY = y + headerHeight / 2
    if let annotation = cls.annotation {
        let annotY = y + 12
        parts.append(
            "  <text x=\"\(x + width / 2)\" y=\"\(annotY)\" text-anchor=\"middle\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
                "font-size=\"\(_ClassFont.annotationSize)\" font-weight=\"\(_ClassFont.annotationWeight)\" " +
                "font-style=\"italic\" fill=\"var(--_text-muted)\">&lt;&lt;\(original_src_multiline_utils.escapeXml(annotation))&gt;&gt;</text>"
        )
        nameY = y + headerHeight / 2 + 6
    }

    parts.append(
        "  " + original_src_multiline_utils.renderMultilineText(
            cls.label,
            cx: x + width / 2,
            cy: nameY,
            fontSize: original_src_styles.FONT_SIZES.nodeLabel,
            attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.nodeLabel)\" font-weight=\"700\" fill=\"var(--_text)\""
        )
    )

    let attrTop = y + headerHeight
    parts.append(
        "  <line x1=\"\(x)\" y1=\"\(attrTop)\" x2=\"\(x + width)\" y2=\"\(attrTop)\" " +
            "stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />"
    )

    let memberRowH = 20.0
    for (i, member) in cls.attributes.enumerated() {
        let memberY = attrTop + 4 + Double(i) * memberRowH + memberRowH / 2
        parts.append("  " + _renderMember(member, x + CLS.boxPadX, memberY))
    }

    let methodTop = attrTop + attrHeight
    parts.append(
        "  <line x1=\"\(x)\" y1=\"\(methodTop)\" x2=\"\(x + width)\" y2=\"\(methodTop)\" " +
            "stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />"
    )

    for (i, member) in cls.methods.enumerated() {
        let memberY = methodTop + 4 + Double(i) * memberRowH + memberRowH / 2
        parts.append("  " + _renderMember(member, x + CLS.boxPadX, memberY))
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func _renderMember(_ member: ClassMember, _ x: Double, _ y: Double) -> String {
    let fontStyle = member.isAbstract ? " font-style=\"italic\"" : ""
    let decoration = member.isStatic ? " text-decoration=\"underline\"" : ""

    var spans: [String] = []
    if !member.visibility.isEmpty {
        spans.append("<tspan fill=\"var(--_text-faint)\">\(original_src_multiline_utils.escapeXml(member.visibility)) </tspan>")
    }

    let displayName = member.isMethod
        ? "\(member.name)(\(member.params ?? ""))"
        : member.name
    spans.append("<tspan fill=\"var(--_text-sec)\">\(original_src_multiline_utils.escapeXml(displayName))</tspan>")

    if let type = member.type, !type.isEmpty {
        spans.append("<tspan fill=\"var(--_text-faint)\">: </tspan>")
        spans.append("<tspan fill=\"var(--_text-muted)\">\(original_src_multiline_utils.escapeXml(type))</tspan>")
    }

    return "<text x=\"\(x)\" y=\"\(y)\" class=\"mono\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
        "font-size=\"\(_ClassFont.memberSize)\" font-weight=\"\(_ClassFont.memberWeight)\"\(fontStyle)\(decoration)>\(spans.joined())</text>"
}

private func _renderRelationship(_ rel: PositionedClassRelationship) -> String {
    if rel.points.count < 2 {
        return ""
    }

    let pathData = rel.points.map { "\($0.x),\($0.y)" }.joined(separator: " ")
    let type = rel.type.lowercased()
    let isDashed = type == "dependency" || type == "realization"
    let dashArray = isDashed ? " stroke-dasharray=\"6 4\"" : ""

    let markerAt = rel.markerAt.lowercased() == "from" ? "from" : "to"
    let markers = _getRelationshipMarkers(type, markerAt)

    var dataAttrs: [String] = [
        "class=\"class-relationship\"",
        "data-from=\"\(_escapeAttr(rel.from))\"",
        "data-to=\"\(_escapeAttr(rel.to))\"",
        "data-type=\"\(_escapeAttr(rel.type))\"",
        "data-marker-at=\"\(_escapeAttr(markerAt))\"",
    ]
    if let label = rel.label, !label.isEmpty {
        dataAttrs.append("data-label=\"\(_escapeAttr(label))\"")
    }
    if let fromCardinality = rel.fromCardinality, !fromCardinality.isEmpty {
        dataAttrs.append("data-from-cardinality=\"\(_escapeAttr(fromCardinality))\"")
    }
    if let toCardinality = rel.toCardinality, !toCardinality.isEmpty {
        dataAttrs.append("data-to-cardinality=\"\(_escapeAttr(toCardinality))\"")
    }

    return "<polyline \(dataAttrs.joined(separator: " ")) points=\"\(pathData)\" fill=\"none\" stroke=\"var(--_line)\" " +
        "stroke-width=\"\(original_src_styles.STROKE_WIDTHS.connector)\"\(dashArray)\(markers) />"
}

private func _getRelationshipMarkers(_ type: String, _ markerAt: String) -> String {
    guard let markerId = _getMarkerDefId(type) else {
        return ""
    }

    if markerAt == "from" {
        return " marker-start=\"url(#\(markerId))\""
    }
    return " marker-end=\"url(#\(markerId))\""
}

private func _getMarkerDefId(_ type: String) -> String? {
    switch type {
    case "inheritance", "realization":
        return "cls-inherit"
    case "composition":
        return "cls-composition"
    case "aggregation":
        return "cls-aggregation"
    case "association", "dependency":
        return "cls-arrow"
    default:
        return nil
    }
}

private func _renderRelationshipLabels(_ rel: PositionedClassRelationship) -> String {
    let hasLabel = rel.label.map { !$0.isEmpty } ?? false
    let hasFrom = rel.fromCardinality.map { !$0.isEmpty } ?? false
    let hasTo = rel.toCardinality.map { !$0.isEmpty } ?? false
    if !(hasLabel || hasFrom || hasTo) || rel.points.count < 2 {
        return ""
    }

    var parts: [String] = []

    if let label = rel.label, !label.isEmpty {
        let pos = rel.labelPosition ?? _midpoint(rel.points)
        parts.append(
            original_src_multiline_utils.renderMultilineText(
                label,
                cx: pos.x,
                cy: pos.y - 8,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
            )
        )
    }

    if let fromCardinality = rel.fromCardinality, !fromCardinality.isEmpty {
        let p = rel.points[0]
        let next = rel.points[1]
        let offset = _cardinalityOffset(from: p, to: next)
        parts.append(
            original_src_multiline_utils.renderMultilineText(
                fromCardinality,
                cx: p.x + offset.x,
                cy: p.y + offset.y,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
            )
        )
    }

    if let toCardinality = rel.toCardinality, !toCardinality.isEmpty {
        let p = rel.points[rel.points.count - 1]
        let prev = rel.points[rel.points.count - 2]
        let offset = _cardinalityOffset(from: p, to: prev)
        parts.append(
            original_src_multiline_utils.renderMultilineText(
                toCardinality,
                cx: p.x + offset.x,
                cy: p.y + offset.y,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
            )
        )
    }

    return parts.joined(separator: "\n")
}

private func _midpoint(_ points: [ClassPoint]) -> ClassPoint {
    if points.isEmpty {
        return ClassPoint(x: 0, y: 0)
    }
    let mid = points.count / 2
    return points[mid]
}

private func _cardinalityOffset(from: ClassPoint, to: ClassPoint) -> ClassPoint {
    let dx = to.x - from.x
    let dy = to.y - from.y
    if abs(dx) > abs(dy) {
        return ClassPoint(x: dx > 0 ? 14 : -14, y: -10)
    }
    return ClassPoint(x: -14, y: dy > 0 ? 14 : -14)
}

private func _escapeAttr(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

open class original_src_class_renderer {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export function renderClassSvg
    public static func renderClassSvg(
        _ diagram: PositionedClassDiagram,
        _ colors: DiagramColors,
        _ font: String = "Inter",
        _ transparent: Bool = false
    ) throws -> String {
        try _renderClassSvgEntry(diagram, colors, font, transparent)
    }
}
