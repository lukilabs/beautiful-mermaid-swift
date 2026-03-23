// Ported from original/src/sequence/renderer.ts
import Foundation
import ElkSwift

public func renderSequenceSvg(
    _ diagram: PositionedSequenceDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderSequenceSvgEntry(diagram, colors, font, transparent)
}

private func _renderSequenceSvgEntry(
    _ diagram: PositionedSequenceDiagram,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    var parts: [String] = []
    let themeColors = original_src_theme.DiagramColors(
        bg: colors.bg,
        fg: colors.fg,
        line: colors.line,
        accent: colors.accent,
        muted: colors.muted,
        surface: colors.surface,
        border: colors.border
    )

    parts.append(original_src_theme.svgOpenTag(diagram.width, diagram.height, themeColors, transparent))
    parts.append(original_src_theme.buildStyleBlock(font, false))
    parts.append("<defs>")
    parts.append(arrowMarkerDefs())
    parts.append("</defs>")

    for block in diagram.blocks {
        parts.append(renderBlock(block))
    }
    for lifeline in diagram.lifelines {
        parts.append(renderLifeline(lifeline))
    }
    for activation in diagram.activations {
        parts.append(renderActivation(activation))
    }
    for message in diagram.messages {
        parts.append(renderMessage(message))
    }
    for note in diagram.notes {
        parts.append(renderNote(note))
    }
    for actor in diagram.actors {
        parts.append(renderActor(actor))
    }

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

private func arrowMarkerDefs() -> String {
    let w = original_src_styles.ARROW_HEAD.width
    let h = original_src_styles.ARROW_HEAD.height
    return "  <marker id=\"seq-arrow\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"\(w)\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">"
        + "\n    <polygon points=\"0 0, \(w) \(h / 2), 0 \(h)\" fill=\"var(--_arrow)\" />"
        + "\n  </marker>"
        + "\n  <marker id=\"seq-arrow-open\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"\(w)\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">"
        + "\n    <polyline points=\"0 0, \(w) \(h / 2), 0 \(h)\" fill=\"none\" stroke=\"var(--_arrow)\" stroke-width=\"1\" />"
        + "\n  </marker>"
}

private func renderActor(_ actor: PositionedSequenceActor) -> String {
    let id = actor.id
    let x = actor.x
    let y = actor.y
    let width = actor.width
    let height = actor.height
    let label = actor.label
    let type = actor.type

    var parts: [String] = []
    parts.append(
        "<g class=\"actor\" data-id=\"\(escapeAttr(id))\" data-label=\"\(escapeAttr(label))\" data-type=\"\(type)\">"
    )

    if type == "actor" {
        let s = (height / 24) * 0.9
        let tx = x - 12 * s
        let ty = y + (height - 24 * s) / 2
        let sw = original_src_styles.STROKE_WIDTHS.outerBox / s
        let iconStroke = "var(--_line)"

        parts.append(
            "  <g transform=\"translate(\(tx),\(ty)) scale(\(s))\">"
                + "\n    <path d=\"M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z\" fill=\"none\" stroke=\"\(iconStroke)\" stroke-width=\"\(sw)\" />"
                + "\n    <path d=\"M15 10C15 11.6569 13.6569 13 12 13C10.3431 13 9 11.6569 9 10C9 8.34315 10.3431 7 12 7C13.6569 7 15 8.34315 15 10Z\" fill=\"none\" stroke=\"\(iconStroke)\" stroke-width=\"\(sw)\" />"
                + "\n    <path d=\"M5.62842 18.3563C7.08963 17.0398 9.39997 16 12 16C14.6 16 16.9104 17.0398 18.3716 18.3563\" fill=\"none\" stroke=\"\(iconStroke)\" stroke-width=\"\(sw)\" />"
                + "\n  </g>"
        )

        parts.append(
            "  " + original_src_multiline_utils.renderMultilineText(
                label,
                cx: x,
                cy: y + height + 14,
                fontSize: original_src_styles.FONT_SIZES.nodeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.nodeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.nodeLabel)\" fill=\"var(--_text)\""
            )
        )
    } else {
        let boxX = x - width / 2
        parts.append(
            "  <rect x=\"\(boxX)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" rx=\"4\" ry=\"4\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
        )
        parts.append(
            "  " + original_src_multiline_utils.renderMultilineText(
                label,
                cx: x,
                cy: y + height / 2,
                fontSize: original_src_styles.FONT_SIZES.nodeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.nodeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.nodeLabel)\" fill=\"var(--_text)\""
            )
        )
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func renderLifeline(_ lifeline: SequenceLifeline) -> String {
    "<line class=\"lifeline\" data-actor=\"\(escapeAttr(lifeline.actorId))\" x1=\"\(lifeline.x)\" y1=\"\(lifeline.topY)\" x2=\"\(lifeline.x)\" y2=\"\(lifeline.bottomY)\" stroke=\"var(--_line)\" stroke-width=\"0.75\" stroke-dasharray=\"6 4\" />"
}

private func renderActivation(_ activation: SequenceActivation) -> String {
    "<rect class=\"activation\" data-actor=\"\(escapeAttr(activation.actorId))\" x=\"\(activation.x)\" y=\"\(activation.topY)\" width=\"\(activation.width)\" height=\"\(activation.bottomY - activation.topY)\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />"
}

private func renderMessage(_ msg: PositionedSequenceMessage) -> String {
    var parts: [String] = []
    let dashArray = msg.lineStyle == "dashed" ? " stroke-dasharray=\"6 4\"" : ""
    let markerId = msg.arrowHead == "filled" ? "seq-arrow" : "seq-arrow-open"

    parts.append(
        "<g class=\"message\" data-from=\"\(escapeAttr(msg.from))\" data-to=\"\(escapeAttr(msg.to))\" data-label=\"\(escapeAttr(msg.label))\" data-line-style=\"\(msg.lineStyle)\" data-arrow-head=\"\(msg.arrowHead)\" data-self=\"\(msg.isSelf)\">"
    )

    if msg.isSelf {
        let loopW = 30.0
        let loopH = 20.0
        let labelPadding = 8.0
        parts.append(
            "  <polyline points=\"\(msg.x1),\(msg.y) \(msg.x1 + loopW),\(msg.y) \(msg.x1 + loopW),\(msg.y + loopH) \(msg.x2),\(msg.y + loopH)\" fill=\"none\" stroke=\"var(--_line)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.connector)\"\(dashArray) marker-end=\"url(#\(markerId))\" />"
        )
        parts.append(
            "  " + original_src_multiline_utils.renderMultilineText(
                msg.label,
                cx: msg.x1 + loopW + labelPadding,
                cy: msg.y + loopH / 2,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"start\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
            )
        )
    } else {
        parts.append(
            "  <line x1=\"\(msg.x1)\" y1=\"\(msg.y)\" x2=\"\(msg.x2)\" y2=\"\(msg.y)\" stroke=\"var(--_line)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.connector)\"\(dashArray) marker-end=\"url(#\(markerId))\" />"
        )
        let midX = (msg.x1 + msg.x2) / 2
        parts.append(
            "  " + original_src_multiline_utils.renderMultilineText(
                msg.label,
                cx: midX,
                cy: msg.y - 6,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
            )
        )
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func renderBlock(_ block: PositionedSequenceBlock) -> String {
    var parts: [String] = []
    let labelAttr = block.label.isEmpty ? "" : " data-label=\"\(escapeAttr(block.label))\""

    parts.append("<g class=\"block\" data-type=\"\(escapeAttr(block.type))\"\(labelAttr)>")
    parts.append(
        "  <rect x=\"\(block.x)\" y=\"\(block.y)\" width=\"\(block.width)\" height=\"\(block.height)\" rx=\"0\" ry=\"0\" fill=\"none\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
    )

    let labelText = block.label.isEmpty ? block.type : "\(block.type) [\(block.label)]"
    let firstLine = labelText.components(separatedBy: "\n").first ?? labelText
    let tabWidth = original_src_styles.estimateTextWidth(
        firstLine,
        original_src_styles.FONT_SIZES.edgeLabel,
        original_src_styles.FONT_WEIGHTS.groupHeader
    ) + 16
    let tabHeight = 18.0

    parts.append(
        "  <rect x=\"\(block.x)\" y=\"\(block.y)\" width=\"\(tabWidth)\" height=\"\(tabHeight)\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
    )

    parts.append(
        "  " + original_src_multiline_utils.renderMultilineText(
            labelText,
            cx: block.x + 6,
            cy: block.y + tabHeight / 2,
            fontSize: original_src_styles.FONT_SIZES.edgeLabel,
            attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.groupHeader)\" fill=\"var(--_text-sec)\""
        )
    )

    for divider in block.dividers {
        parts.append(
            "  <line x1=\"\(block.x)\" y1=\"\(divider.y)\" x2=\"\(block.x + block.width)\" y2=\"\(divider.y)\" stroke=\"var(--_line)\" stroke-width=\"0.75\" stroke-dasharray=\"6 4\" />"
        )
        if !divider.label.isEmpty {
            parts.append(
                "  " + original_src_multiline_utils.renderMultilineText(
                    "[\(divider.label)]",
                    cx: block.x + 8,
                    cy: divider.y + 14,
                    fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                    attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"start\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
                )
            )
        }
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func renderNote(_ note: PositionedSequenceNote) -> String {
    let foldSize = 6.0
    let actorsAttr = note.actors.isEmpty ? "" : " data-actors=\"\(note.actors.map(escapeAttr).joined(separator: ","))\""
    let positionAttr = note.position.isEmpty ? "" : " data-position=\"\(escapeAttr(note.position))\""

    let noteTextAttrs =
        "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" "
        + "text-anchor=\"middle\" "
        + "font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" "
        + "fill=\"var(--_text-muted)\""
    let noteText = original_src_multiline_utils.renderMultilineText(
        note.text,
        cx: note.x + note.width / 2,
        cy: note.y + note.height / 2,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        attrs: noteTextAttrs
    )

    return "<g class=\"note\"\(positionAttr)\(actorsAttr)>"
        + "\n  <rect x=\"\(note.x)\" y=\"\(note.y)\" width=\"\(note.width)\" height=\"\(note.height)\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />"
        + "\n  <polygon points=\"\(note.x + note.width - foldSize),\(note.y) \(note.x + note.width),\(note.y + foldSize) \(note.x + note.width - foldSize),\(note.y + foldSize)\" fill=\"var(--_inner-stroke)\" />"
        + "\n  \(noteText)"
        + "\n</g>"
}

private func escapeXml(_ value: String) -> String {
    original_src_multiline_utils.escapeXml(value)
}

private func escapeAttr(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

open class original_src_sequence_renderer {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    public static func renderSequenceSvg(
        _ diagram: PositionedSequenceDiagram,
        _ colors: DiagramColors,
        _ font: String = "Inter",
        _ transparent: Bool = false
    ) throws -> String {
        try _renderSequenceSvgEntry(diagram, colors, font, transparent)
    }
}
