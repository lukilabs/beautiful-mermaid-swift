// Ported from original/src/er/renderer.ts
import Foundation
import ElkSwift

private enum ERFont {
    static let attrSize: Double = 11
    static let attrWeight: Int = 400
    static let keySize: Double = 9
    static let keyWeight: Int = 600
}

public func renderErSvg(
    _ diagram: PositionedErDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderErSvgEntry(diagram, colors, font, transparent)
}

private func _renderErSvgEntry(
    _ diagram: PositionedErDiagram,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    var parts: [String] = []
    let themeColors = _toThemeColors(colors)

    parts.append(original_src_theme.svgOpenTag(diagram.width, diagram.height, themeColors, transparent))
    parts.append(original_src_theme.buildStyleBlock(font, true))
    parts.append("<defs>")
    parts.append("</defs>")

    for rel in diagram.relationships {
        parts.append(_renderRelationshipLine(rel))
    }

    for entity in diagram.entities {
        parts.append(_renderEntityBox(entity))
    }

    for rel in diagram.relationships {
        parts.append(_renderCardinality(rel))
    }

    for rel in diagram.relationships {
        parts.append(_renderRelationshipLabel(rel))
    }

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

private func _toThemeColors(_ colors: DiagramColors) -> original_src_theme.DiagramColors {
    original_src_theme.DiagramColors(
        bg: colors.bg,
        fg: colors.fg,
        line: colors.line,
        accent: colors.accent,
        muted: colors.muted,
        surface: colors.surface,
        border: colors.border
    )
}

private func _renderEntityBox(_ entity: PositionedErEntity) -> String {
    let x = entity.x
    let y = entity.y
    let width = entity.width
    let height = entity.height
    let headerHeight = entity.headerHeight
    let rowHeight = entity.rowHeight
    let label = entity.label
    let attrs = entity.attributes

    var parts: [String] = []
    parts.append("<g class=\"entity\" data-id=\"\(_escapeAttr(entity.id))\" data-label=\"\(_escapeAttr(label))\">")

    parts.append(
        "  <rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" " +
            "rx=\"0\" ry=\"0\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" " +
            "stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
    )

    parts.append(
        "  <rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(headerHeight)\" " +
            "rx=\"0\" ry=\"0\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" " +
            "stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
    )

    parts.append(
        "  " + original_src_multiline_utils.renderMultilineText(
            label,
            cx: x + width / 2,
            cy: y + headerHeight / 2,
            fontSize: original_src_styles.FONT_SIZES.nodeLabel,
            attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.nodeLabel)\" " +
                "font-weight=\"700\" fill=\"var(--_text)\""
        )
    )

    let attrTop = y + headerHeight
    parts.append(
        "  <line x1=\"\(x)\" y1=\"\(attrTop)\" x2=\"\(x + width)\" y2=\"\(attrTop)\" " +
            "stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />"
    )

    for (idx, attr) in attrs.enumerated() {
        let rowY = attrTop + Double(idx) * rowHeight + rowHeight / 2
        let rendered = _renderAttribute(attr, boxX: x, y: rowY, boxWidth: width)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "  " + $0 }
            .joined(separator: "\n")
        parts.append(rendered)
    }

    if attrs.isEmpty {
        parts.append(
            "  <text x=\"\(x + width / 2)\" y=\"\(attrTop + rowHeight / 2)\" text-anchor=\"middle\" " +
                "dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" font-size=\"\(ERFont.attrSize)\" " +
                "fill=\"var(--_text-faint)\" font-style=\"italic\">(no attributes)</text>"
        )
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func _renderAttribute(
    _ attr: ErAttribute,
    boxX: Double,
    y: Double,
    boxWidth: Double
) -> String {
    var parts: [String] = []
    let hasComment = (attr.comment?.isEmpty == false)
    if hasComment {
        let tooltipText = (attr.comment ?? "").replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        parts.append("<g><title>\(original_src_multiline_utils.escapeXml(tooltipText))</title>")
    }

    var keyWidth = 0.0
    if !attr.keys.isEmpty {
        let keyText = attr.keys.joined(separator: ",")
        keyWidth = original_src_styles.estimateTextWidth(keyText, ERFont.keySize, ERFont.keyWeight) + 8
        parts.append(
            "<rect x=\"\(boxX + 6)\" y=\"\(y - 7)\" width=\"\(keyWidth)\" height=\"14\" rx=\"2\" ry=\"2\" " +
                "fill=\"var(--_key-badge)\" />"
        )
        parts.append(
            "<text x=\"\(boxX + 6 + keyWidth / 2)\" y=\"\(y)\" text-anchor=\"middle\" " +
                "dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" font-size=\"\(ERFont.keySize)\" " +
                "font-weight=\"\(ERFont.keyWeight)\" fill=\"var(--_text-sec)\">\(attr.keys.joined(separator: ","))</text>"
        )
    }

    let typeX = boxX + 8 + (keyWidth > 0 ? keyWidth + 6 : 0)
    parts.append(
        "<text x=\"\(typeX)\" y=\"\(y)\" class=\"mono\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
            "font-size=\"\(ERFont.attrSize)\" font-weight=\"\(ERFont.attrWeight)\">" +
            "<tspan fill=\"var(--_text-muted)\">\(original_src_multiline_utils.escapeXml(attr.type))</tspan></text>"
    )

    let nameX = boxX + boxWidth - 8
    parts.append(
        "<text x=\"\(nameX)\" y=\"\(y)\" class=\"mono\" text-anchor=\"end\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
            "font-size=\"\(ERFont.attrSize)\" font-weight=\"\(ERFont.attrWeight)\">" +
            "<tspan fill=\"var(--_text-sec)\">\(original_src_multiline_utils.escapeXml(attr.name))</tspan></text>"
    )

    if hasComment {
        parts.append("</g>")
    }
    return parts.joined(separator: "\n")
}

private func _renderRelationshipLine(_ rel: PositionedErRelationship) -> String {
    guard rel.points.count >= 2 else {
        return ""
    }
    let pathData = rel.points.map { "\($0.x),\($0.y)" }.joined(separator: " ")
    let dashArray = rel.identifying ? "" : " stroke-dasharray=\"6 4\""
    let labelAttr = rel.label.isEmpty ? "" : " data-label=\"\(_escapeAttr(rel.label))\""
    let attrs = [
        "class=\"er-relationship\"",
        "data-entity1=\"\(_escapeAttr(rel.entity1))\"",
        "data-entity2=\"\(_escapeAttr(rel.entity2))\"",
        "data-cardinality1=\"\(rel.cardinality1)\"",
        "data-cardinality2=\"\(rel.cardinality2)\"",
        "data-identifying=\"\(rel.identifying)\"",
    ].joined(separator: " ")

    return "<polyline \(attrs)\(labelAttr) points=\"\(pathData)\" fill=\"none\" stroke=\"var(--_line)\" " +
        "stroke-width=\"\(original_src_styles.STROKE_WIDTHS.connector)\"\(dashArray) />"
}

private func _renderRelationshipLabel(_ rel: PositionedErRelationship) -> String {
    guard !rel.label.isEmpty, rel.points.count >= 2 else {
        return ""
    }

    let mid = _midpoint(rel.points)
    let metrics = original_src_text_metrics.measureMultilineText(
        rel.label,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
    )
    let bgW = metrics.width + 8
    let bgH = metrics.height + 6

    return "<rect x=\"\(mid.x - bgW / 2)\" y=\"\(mid.y - bgH / 2)\" width=\"\(bgW)\" height=\"\(bgH)\" rx=\"2\" ry=\"2\" " +
        "fill=\"var(--bg)\" stroke=\"var(--_inner-stroke)\" stroke-width=\"0.5\" />\n" +
        original_src_multiline_utils.renderMultilineText(
            rel.label,
            cx: mid.x,
            cy: mid.y,
            fontSize: original_src_styles.FONT_SIZES.edgeLabel,
            attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" " +
                "font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
        )
}

private func _renderCardinality(_ rel: PositionedErRelationship) -> String {
    guard rel.points.count >= 2 else {
        return ""
    }
    var out: [String] = []

    let p1 = rel.points[0]
    let p2 = rel.points[1]
    out.append(_renderCrowsFoot(point: p1, toward: p2, cardinality: rel.cardinality1))

    let pN = rel.points[rel.points.count - 1]
    let pN1 = rel.points[rel.points.count - 2]
    out.append(_renderCrowsFoot(point: pN, toward: pN1, cardinality: rel.cardinality2))

    return out.filter { !$0.isEmpty }.joined(separator: "\n")
}

private func _renderCrowsFoot(point: ErPoint, toward: ErPoint, cardinality: Cardinality) -> String {
    let sw = original_src_styles.STROKE_WIDTHS.connector + 0.25
    let dx = point.x - toward.x
    let dy = point.y - toward.y
    let len = sqrt(dx * dx + dy * dy)
    if len == 0 {
        return ""
    }
    let ux = dx / len
    let uy = dy / len
    let px = -uy
    let py = ux

    let tipX = point.x - ux * 4
    let tipY = point.y - uy * 4
    let backX = point.x - ux * 16
    let backY = point.y - uy * 16

    let hasOneLine = cardinality == "one" || cardinality == "zero-one"
    let hasCrowsFoot = cardinality == "many" || cardinality == "zero-many"
    let hasCircle = cardinality == "zero-one" || cardinality == "zero-many"

    var parts: [String] = []

    if hasOneLine {
        let halfW = 6.0
        parts.append(
            "<line x1=\"\(tipX + px * halfW)\" y1=\"\(tipY + py * halfW)\" x2=\"\(tipX - px * halfW)\" y2=\"\(tipY - py * halfW)\" " +
                "stroke=\"var(--_line)\" stroke-width=\"\(sw)\" />"
        )
        let line2X = tipX - ux * 4
        let line2Y = tipY - uy * 4
        parts.append(
            "<line x1=\"\(line2X + px * halfW)\" y1=\"\(line2Y + py * halfW)\" x2=\"\(line2X - px * halfW)\" y2=\"\(line2Y - py * halfW)\" " +
                "stroke=\"var(--_line)\" stroke-width=\"\(sw)\" />"
        )
    }

    if hasCrowsFoot {
        let fanW = 7.0
        let cfTipX = tipX
        let cfTipY = tipY
        parts.append(
            "<line x1=\"\(cfTipX + px * fanW)\" y1=\"\(cfTipY + py * fanW)\" x2=\"\(backX)\" y2=\"\(backY)\" " +
                "stroke=\"var(--_line)\" stroke-width=\"\(sw)\" />"
        )
        parts.append(
            "<line x1=\"\(cfTipX)\" y1=\"\(cfTipY)\" x2=\"\(backX)\" y2=\"\(backY)\" " +
                "stroke=\"var(--_line)\" stroke-width=\"\(sw)\" />"
        )
        parts.append(
            "<line x1=\"\(cfTipX - px * fanW)\" y1=\"\(cfTipY - py * fanW)\" x2=\"\(backX)\" y2=\"\(backY)\" " +
                "stroke=\"var(--_line)\" stroke-width=\"\(sw)\" />"
        )
    }

    if hasCircle {
        let circleOffset = hasCrowsFoot ? 20.0 : 12.0
        let circleX = point.x - ux * circleOffset
        let circleY = point.y - uy * circleOffset
        parts.append(
            "<circle cx=\"\(circleX)\" cy=\"\(circleY)\" r=\"4\" fill=\"var(--bg)\" stroke=\"var(--_line)\" stroke-width=\"\(sw)\" />"
        )
    }

    return parts.joined(separator: "\n")
}

private func _midpoint(_ points: [ErPoint]) -> ErPoint {
    if points.isEmpty {
        return ErPoint(x: 0, y: 0)
    }
    if points.count == 1 {
        return points[0]
    }

    var totalLen = 0.0
    for i in 1 ..< points.count {
        let dx = points[i].x - points[i - 1].x
        let dy = points[i].y - points[i - 1].y
        totalLen += sqrt(dx * dx + dy * dy)
    }
    if totalLen == 0 {
        return points[0]
    }

    let halfLen = totalLen / 2
    var walked = 0.0
    for i in 1 ..< points.count {
        let dx = points[i].x - points[i - 1].x
        let dy = points[i].y - points[i - 1].y
        let segLen = sqrt(dx * dx + dy * dy)
        if walked + segLen >= halfLen {
            let t = segLen > 0 ? (halfLen - walked) / segLen : 0
            return ErPoint(
                x: points[i - 1].x + dx * t,
                y: points[i - 1].y + dy * t
            )
        }
        walked += segLen
    }

    return points[points.count - 1]
}

private func _escapeAttr(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

open class original_src_er_renderer {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export function renderErSvg
    public static func renderErSvg(
        _ diagram: PositionedErDiagram,
        _ colors: DiagramColors,
        _ font: String = "Inter",
        _ transparent: Bool = false
    ) throws -> String {
        try _renderErSvgEntry(diagram, colors, font, transparent)
    }
}
