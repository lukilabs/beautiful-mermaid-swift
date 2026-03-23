// Ported from original/src/renderer.ts
import Foundation
import ElkSwift

private struct _SvgPoint {
    var x: Double
    var y: Double
}

private struct _SvgNode {
    var id: String
    var label: String
    var shape: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var inlineStyle: [String: String]
}

private struct _SvgEdge {
    var source: String
    var target: String
    var label: String?
    var style: String
    var hasArrowStart: Bool
    var hasArrowEnd: Bool
    var points: [_SvgPoint]
    var labelPosition: _SvgPoint?
    var inlineStyle: [String: String]?
}

private struct _SvgGroup {
    var id: String
    var label: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var children: [_SvgGroup]
}

private struct _SvgGraphModel {
    var width: Double
    var height: Double
    var nodes: [_SvgNode]
    var edges: [_SvgEdge]
    var groups: [_SvgGroup]
}

public func renderSvg(
    _ graph: PositionedGraph,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderSvgEntry(graph, colors, font, transparent)
}

private func _renderSvgEntry(
    _ graph: PositionedGraph,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    let model = _extractSvgGraphModel(graph)
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

    parts.append(original_src_theme.svgOpenTag(model.width, model.height, themeColors, transparent))
    parts.append(original_src_theme.buildStyleBlock(font, false))
    parts.append("<defs>")
    parts.append(_arrowMarkerDefs())
    // Per-color arrow markers for edges with custom stroke via linkStyle
    var customStrokeColors = Set<String>()
    for edge in model.edges {
        if let stroke = edge.inlineStyle?["stroke"] {
            customStrokeColors.insert(stroke)
        }
    }
    for color in customStrokeColors {
        parts.append(_arrowMarkerDefsForColor(color))
    }
    parts.append("</defs>")

    for group in model.groups {
        parts.append(_renderGroup(group, font))
    }

    for edge in model.edges {
        parts.append(_renderEdge(edge))
    }

    for edge in model.edges where edge.label != nil {
        parts.append(_renderEdgeLabel(edge, font))
    }

    for node in model.nodes {
        parts.append(_renderNode(node, font))
    }

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

private func _arrowMarkerDefs() -> String {
    let w = original_src_styles.ARROW_HEAD.width
    let h = original_src_styles.ARROW_HEAD.height
    let arrowStyle = "fill=\"var(--_arrow)\" stroke=\"var(--_arrow)\" stroke-width=\"0.75\" stroke-linejoin=\"round\""
    let refX = w - 1
    return "  <marker id=\"arrowhead\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"\(refX)\" refY=\"\(h / 2)\" orient=\"auto\">\n" +
        "    <polygon points=\"0 0, \(w) \(h / 2), 0 \(h)\" \(arrowStyle) />\n" +
        "  </marker>\n" +
        "  <marker id=\"arrowhead-start\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"1\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">\n" +
        "    <polygon points=\"\(w) 0, 0 \(h / 2), \(w) \(h)\" \(arrowStyle) />\n" +
        "  </marker>"
}

private func _arrowMarkerDefsForColor(_ color: String) -> String {
    let w = original_src_styles.ARROW_HEAD.width
    let h = original_src_styles.ARROW_HEAD.height
    let escaped = _escapeAttr(color)
    let arrowStyle = "fill=\"\(escaped)\" stroke=\"\(escaped)\" stroke-width=\"0.75\" stroke-linejoin=\"round\""
    let refX = w - 1
    let suffix = _markerSuffix(color)
    return "  <marker id=\"arrowhead-\(suffix)\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"\(refX)\" refY=\"\(h / 2)\" orient=\"auto\">\n" +
        "    <polygon points=\"0 0, \(w) \(h / 2), 0 \(h)\" \(arrowStyle) />\n" +
        "  </marker>\n" +
        "  <marker id=\"arrowhead-start-\(suffix)\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"1\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">\n" +
        "    <polygon points=\"\(w) 0, 0 \(h / 2), \(w) \(h)\" \(arrowStyle) />\n" +
        "  </marker>"
}

private func _markerSuffix(_ color: String) -> String {
    color.unicodeScalars.map { scalar in
        let ch = Character(scalar)
        if ch.isLetter || ch.isNumber { return String(ch) }
        return String(scalar.value, radix: 16)
    }.joined()
}

private func _renderGroup(_ group: _SvgGroup, _ font: String) -> String {
    _ = font
    let headerHeight = original_src_styles.FONT_SIZES.groupHeader + 16
    var parts: [String] = []

    parts.append("<g class=\"subgraph\" data-id=\"\(_escapeAttr(group.id))\" data-label=\"\(_escapeAttr(group.label))\">")
    parts.append(
        "  <rect x=\"\(group.x)\" y=\"\(group.y)\" width=\"\(group.width)\" height=\"\(group.height)\" " +
            "rx=\"0\" ry=\"0\" fill=\"var(--_group-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
    )
    parts.append(
        "  <rect x=\"\(group.x)\" y=\"\(group.y)\" width=\"\(group.width)\" height=\"\(headerHeight)\" " +
            "rx=\"0\" ry=\"0\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
    )

    let header = original_src_multiline_utils.renderMultilineText(
        group.label,
        cx: group.x + 12,
        cy: group.y + headerHeight / 2,
        fontSize: original_src_styles.FONT_SIZES.groupHeader,
        attrs: "font-size=\"\(original_src_styles.FONT_SIZES.groupHeader)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.groupHeader)\" fill=\"var(--_text-sec)\""
    )
    parts.append("  \(header)")

    for child in group.children {
        parts.append(_renderGroup(child, font))
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func _renderEdge(_ edge: _SvgEdge) -> String {
    if edge.points.count < 2 {
        return ""
    }

    let pathData = _pointsToPolylinePath(edge.points)
    let dashArray = edge.style == "dotted" ? " stroke-dasharray=\"4 4\"" : ""
    let baseStrokeWidth = edge.style == "thick"
        ? original_src_styles.STROKE_WIDTHS.connector * 2
        : original_src_styles.STROKE_WIDTHS.connector
    let strokeColor = _escapeAttr(edge.inlineStyle?["stroke"] ?? "var(--_line)")
    let strokeWidth = _escapeAttr(edge.inlineStyle?["stroke-width"] ?? "\(baseStrokeWidth)")

    // Use color-specific markers when edge has a custom stroke from linkStyle
    let suffix: String
    if let strokeColor = edge.inlineStyle?["stroke"] {
        suffix = "-\(_markerSuffix(strokeColor))"
    } else {
        suffix = ""
    }
    var markers = ""
    if edge.hasArrowEnd {
        markers += " marker-end=\"url(#arrowhead\(suffix))\""
    }
    if edge.hasArrowStart {
        markers += " marker-start=\"url(#arrowhead-start\(suffix))\""
    }

    var dataAttrs: [String] = [
        "class=\"edge\"",
        "data-from=\"\(_escapeAttr(edge.source))\"",
        "data-to=\"\(_escapeAttr(edge.target))\"",
        "data-style=\"\(_escapeAttr(edge.style))\"",
        "data-arrow-start=\"\(edge.hasArrowStart)\"",
        "data-arrow-end=\"\(edge.hasArrowEnd)\"",
    ]
    if let label = edge.label {
        dataAttrs.append("data-label=\"\(_escapeAttr(label))\"")
    }

    return "<polyline \(dataAttrs.joined(separator: " ")) points=\"\(pathData)\" fill=\"none\" stroke=\"\(strokeColor)\" " +
        "stroke-width=\"\(strokeWidth)\"\(dashArray)\(markers) />"
}

private func _pointsToPolylinePath(_ points: [_SvgPoint]) -> String {
    points.map { "\($0.x),\($0.y)" }.joined(separator: " ")
}

private func _renderEdgeLabel(_ edge: _SvgEdge, _ font: String) -> String {
    _ = font
    let mid = edge.labelPosition ?? _edgeMidpoint(edge.points)
    let label = edge.label ?? ""
    let padding = 8.0
    let metrics = original_src_text_metrics.measureMultilineText(
        label,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
    )

    let content = original_src_multiline_utils.renderMultilineTextWithBackground(
        label,
        cx: mid.x,
        cy: mid.y,
        textWidth: metrics.width,
        textHeight: metrics.height,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        padding: padding,
        textAttrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-sec)\"",
        bgAttrs: "rx=\"2\" ry=\"2\" fill=\"var(--bg)\" stroke=\"var(--_inner-stroke)\" stroke-width=\"1\""
    )

    return "<g class=\"edge-label\" data-from=\"\(_escapeAttr(edge.source))\" data-to=\"\(_escapeAttr(edge.target))\" data-label=\"\(_escapeAttr(label))\">\n" +
        "  \(content.replacingOccurrences(of: "\n", with: "\n  "))\n" +
        "</g>"
}

private func _edgeMidpoint(_ points: [_SvgPoint]) -> _SvgPoint {
    if points.isEmpty {
        return _SvgPoint(x: 0, y: 0)
    }
    if points.count == 1 {
        return points[0]
    }

    var totalLength = 0.0
    for i in 1 ..< points.count {
        totalLength += _dist(points[i - 1], points[i])
    }

    var remaining = totalLength / 2
    for i in 1 ..< points.count {
        let segLen = _dist(points[i - 1], points[i])
        if remaining <= segLen {
            let t = segLen == 0 ? 0 : (remaining / segLen)
            return _SvgPoint(
                x: points[i - 1].x + t * (points[i].x - points[i - 1].x),
                y: points[i - 1].y + t * (points[i].y - points[i - 1].y)
            )
        }
        remaining -= segLen
    }

    return points[points.count - 1]
}

private func _dist(_ a: _SvgPoint, _ b: _SvgPoint) -> Double {
    let dx = b.x - a.x
    let dy = b.y - a.y
    return (dx * dx + dy * dy).squareRoot()
}

private func _renderNode(_ node: _SvgNode, _ font: String) -> String {
    let shape = _renderNodeShape(node)
    let label = _renderNodeLabel(node, font)

    var parts: [String] = []
    parts.append("<g class=\"node\" data-id=\"\(_escapeAttr(node.id))\" data-label=\"\(_escapeAttr(node.label))\" data-shape=\"\(_escapeAttr(node.shape))\">")
    parts.append("  \(shape.replacingOccurrences(of: "\n", with: "\n  "))")
    if !label.isEmpty {
        parts.append("  \(label.replacingOccurrences(of: "\n", with: "\n  "))")
    }
    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func _renderNodeShape(_ node: _SvgNode) -> String {
    let x = node.x
    let y = node.y
    let width = node.width
    let height = node.height
    let shape = node.shape
    let inlineStyle = node.inlineStyle

    let fill = _escapeAttr(inlineStyle["fill"] ?? "var(--_node-fill)")
    let stroke = _escapeAttr(inlineStyle["stroke"] ?? "var(--_node-stroke)")
    let sw = _escapeAttr(inlineStyle["stroke-width"] ?? "\(original_src_styles.STROKE_WIDTHS.innerBox)")

    switch shape {
    case "diamond":
        return _renderDiamond(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "rounded":
        return _renderRoundedRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "stadium":
        return _renderStadium(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "circle":
        return _renderCircle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "subroutine":
        return _renderSubroutine(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "doublecircle":
        return _renderDoubleCircle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "hexagon":
        return _renderHexagon(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "cylinder":
        return _renderCylinder(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "asymmetric":
        return _renderAsymmetric(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "trapezoid":
        return _renderTrapezoid(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "trapezoid-alt":
        return _renderTrapezoidAlt(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "state-start":
        return _renderStateStart(x: x, y: y, w: width, h: height)
    case "state-end":
        return _renderStateEnd(x: x, y: y, w: width, h: height)
    default:
        return _renderRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    }
}

private func _renderRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderRoundedRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"6\" ry=\"6\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderStadium(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let r = h / 2
    return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"\(r)\" ry=\"\(r)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderCircle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let r = min(w, h) / 2
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderDiamond(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let hw = w / 2
    let hh = h / 2
    let points = [
        "\(cx),\(cy - hh)",
        "\(cx + hw),\(cy)",
        "\(cx),\(cy + hh)",
        "\(cx - hw),\(cy)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderSubroutine(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = 8.0
    return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(x + inset)\" y1=\"\(y)\" x2=\"\(x + inset)\" y2=\"\(y + h)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(x + w - inset)\" y1=\"\(y)\" x2=\"\(x + w - inset)\" y2=\"\(y + h)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderDoubleCircle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let outerR = min(w, h) / 2
    let innerR = outerR - 5
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(outerR)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(innerR)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderHexagon(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = h / 4
    let points = [
        "\(x + inset),\(y)",
        "\(x + w - inset),\(y)",
        "\(x + w),\(y + h / 2)",
        "\(x + w - inset),\(y + h)",
        "\(x + inset),\(y + h)",
        "\(x),\(y + h / 2)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderCylinder(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let ry = 7.0
    let cx = x + w / 2
    let bodyTop = y + ry
    let bodyH = h - 2 * ry
    return "<rect x=\"\(x)\" y=\"\(bodyTop)\" width=\"\(w)\" height=\"\(bodyH)\" fill=\"\(fill)\" stroke=\"none\" />\n" +
        "<line x1=\"\(x)\" y1=\"\(bodyTop)\" x2=\"\(x)\" y2=\"\(bodyTop + bodyH)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(x + w)\" y1=\"\(bodyTop)\" x2=\"\(x + w)\" y2=\"\(bodyTop + bodyH)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<ellipse cx=\"\(cx)\" cy=\"\(y + h - ry)\" rx=\"\(w / 2)\" ry=\"\(ry)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<ellipse cx=\"\(cx)\" cy=\"\(bodyTop)\" rx=\"\(w / 2)\" ry=\"\(ry)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderAsymmetric(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let indent = 12.0
    let points = [
        "\(x + indent),\(y)",
        "\(x + w),\(y)",
        "\(x + w),\(y + h)",
        "\(x + indent),\(y + h)",
        "\(x),\(y + h / 2)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderTrapezoid(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = w * 0.15
    let points = [
        "\(x + inset),\(y)",
        "\(x + w - inset),\(y)",
        "\(x + w),\(y + h)",
        "\(x),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderTrapezoidAlt(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = w * 0.15
    let points = [
        "\(x),\(y)",
        "\(x + w),\(y)",
        "\(x + w - inset),\(y + h)",
        "\(x + inset),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderStateStart(x: Double, y: Double, w: Double, h: Double) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let r = min(w, h) / 2 - 2
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"var(--_text)\" stroke=\"none\" />"
}

private func _renderStateEnd(x: Double, y: Double, w: Double, h: Double) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let outerR = min(w, h) / 2 - 2
    let innerR = outerR - 4
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(outerR)\" fill=\"none\" stroke=\"var(--_text)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox * 2)\" />\n" +
        "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(innerR)\" fill=\"var(--_text)\" stroke=\"none\" />"
}

private func _renderNodeLabel(_ node: _SvgNode, _ font: String) -> String {
    _ = font
    if (node.shape == "state-start" || node.shape == "state-end"), node.label.isEmpty {
        return ""
    }

    let cx = node.x + node.width / 2
    let cy = node.y + node.height / 2
    let textColor = _escapeAttr(node.inlineStyle["color"] ?? "var(--_text)")

    return original_src_multiline_utils.renderMultilineText(
        node.label,
        cx: cx,
        cy: cy,
        fontSize: original_src_styles.FONT_SIZES.nodeLabel,
        attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.nodeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.nodeLabel)\" fill=\"\(textColor)\""
    )
}

private func _escapeAttr(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

private func _extractSvgGraphModel(_ graph: PositionedGraph) -> _SvgGraphModel {
    _SvgGraphModel(
        width: graph.width,
        height: graph.height,
        nodes: (graph.flowchartNodes ?? []).map { $0 as Any }.map(_extractNode),
        edges: (graph.flowchartEdges ?? []).map { $0 as Any }.map(_extractEdge),
        groups: (graph.flowchartGroups ?? []).map { $0 as Any }.map(_extractGroup)
    )
}

private func _extractNode(_ any: Any) -> _SvgNode {
    _SvgNode(
        id: _readString(any, label: "id") ?? "",
        label: _readString(any, label: "label") ?? "",
        shape: _readString(any, label: "shape") ?? "rectangle",
        x: _readDouble(any, label: "x") ?? 0,
        y: _readDouble(any, label: "y") ?? 0,
        width: _readDouble(any, label: "width") ?? 0,
        height: _readDouble(any, label: "height") ?? 0,
        inlineStyle: _readStringMap(any, label: "inlineStyle") ?? [:]
    )
}

private func _extractEdge(_ any: Any) -> _SvgEdge {
    _SvgEdge(
        source: _readString(any, label: "source") ?? "",
        target: _readString(any, label: "target") ?? "",
        label: _readOptionalString(any, label: "label"),
        style: _readString(any, label: "style") ?? "solid",
        hasArrowStart: _readBool(any, label: "hasArrowStart") ?? false,
        hasArrowEnd: _readBool(any, label: "hasArrowEnd") ?? true,
        points: _readArray(any, label: "points").map(_extractPoint),
        labelPosition: _readAny(any, label: "labelPosition").map(_extractPoint),
        inlineStyle: _readStringMap(any, label: "inlineStyle")
    )
}

private func _extractGroup(_ any: Any) -> _SvgGroup {
    _SvgGroup(
        id: _readString(any, label: "id") ?? "",
        label: _readString(any, label: "label") ?? "",
        x: _readDouble(any, label: "x") ?? 0,
        y: _readDouble(any, label: "y") ?? 0,
        width: _readDouble(any, label: "width") ?? 0,
        height: _readDouble(any, label: "height") ?? 0,
        children: _readArray(any, label: "children").map(_extractGroup)
    )
}

private func _extractPoint(_ any: Any) -> _SvgPoint {
    _SvgPoint(
        x: _readDouble(any, label: "x") ?? 0,
        y: _readDouble(any, label: "y") ?? 0
    )
}

private func _unboxOptional(_ any: Any) -> Any? {
    let mirror = Mirror(reflecting: any)
    guard mirror.displayStyle == .optional else {
        return any
    }
    return mirror.children.first?.value
}

private func _readAny(_ any: Any, label: String) -> Any? {
    for child in Mirror(reflecting: any).children where child.label == label {
        return _unboxOptional(child.value)
    }
    return nil
}

private func _readArray(_ any: Any, label: String) -> [Any] {
    guard let value = _readAny(any, label: label) else {
        return []
    }
    return value as? [Any] ?? []
}

private func _readString(_ any: Any, label: String) -> String? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    if let text = value as? String {
        return text
    }
    return String(describing: value)
}

private func _readOptionalString(_ any: Any, label: String) -> String? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    return value as? String
}

private func _readDouble(_ any: Any, label: String) -> Double? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    if let number = value as? Double {
        return number
    }
    if let number = value as? Int {
        return Double(number)
    }
    if let number = value as? Float {
        return Double(number)
    }
    if let number = value as? NSNumber {
        return number.doubleValue
    }
    return nil
}

private func _readBool(_ any: Any, label: String) -> Bool? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    if let b = value as? Bool {
        return b
    }
    if let n = value as? NSNumber {
        return n.boolValue
    }
    return nil
}

private func _readStringMap(_ any: Any, label: String) -> [String: String]? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    return value as? [String: String]
}

open class original_src_renderer {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export function renderSvg
    public static func renderSvg(
        _ graph: PositionedGraph,
        _ colors: DiagramColors,
        _ font: String = "Inter",
        _ transparent: Bool = false
    ) throws -> String {
        try _renderSvgEntry(graph, colors, font, transparent)
    }
}
