// Ported from original/src/xychart/renderer.ts
import Foundation

private enum ChartFont {
    static let titleSize: Double = 18
    static let titleWeight: Int = 600
    static let axisTitleSize: Double = 15
    static let axisTitleWeight: Int = 500
    static let labelSize: Double = 12
    static let labelWeight: Int = 400
    static let legendSize: Double = 12
    static let legendWeight: Int = 400
    static let dotRadius: Double = 5
    static let lineWidth: Double = 2.5
    static let barRadius: Double = 8
}

private enum TIP {
    static let fontSize: Double = 15
    static let fontWeight: Int = 500
    static let height: Double = 32
    static let padX: Double = 14
    static let offsetY: Double = 12
    static let rx: Double = 8
    static let minY: Double = 4
    static let pointerSize: Double = 6
}

// MARK: - Public entry point

public func renderXYChartSvg(
    _ chart: PositionedXYChart,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false,
    interactive: Bool = false
) -> String {
    var parts: [String] = []

    let maxColorIdx = max(
        0,
        chart.bars.map(\.colorIndex).max() ?? 0,
        chart.lines.map(\.colorIndex).max() ?? 0
    )
    let themeColors = original_src_theme.DiagramColors(bg: colors.bg, fg: colors.fg, line: colors.line, accent: colors.accent, muted: colors.muted, surface: colors.surface, border: colors.border)
    var svgTag = original_src_theme.svgOpenTag(chart.width, chart.height, themeColors, transparent)
    svgTag = svgTag.replacingOccurrences(of: "<svg ", with: "<svg data-xychart-colors=\"\(maxColorIdx)\" ")
    parts.append(svgTag)
    parts.append(original_src_theme.buildStyleBlock(font, false))

    let maxLinePoints = chart.lines.map(\.points.count).max() ?? 0
    let sparse = maxLinePoints > 0 && maxLinePoints <= 12

    let chartCss = _chartStyles(chart, interactive, sparse, colors.accent, colors.bg)
    parts.append(chartCss.style)

    // 1. Dot grid
    let plotArea = chart.plotArea
    let xTickPositions = chart.xAxis.ticks.map(\.x)
    let yVals = chart.horizontal
        ? chart.yAxis.ticks.map(\.y)
        : chart.gridLines.map(\.y1)
    let xBaseRaw = xTickPositions.count > 1 ? abs(xTickPositions[1] - xTickPositions[0]) : plotArea.width / 6
    let yBaseRaw = yVals.count > 1 ? abs(yVals[1] - yVals[0]) : plotArea.height / 6
    let xBase = (xBaseRaw.isFinite && abs(xBaseRaw) < 1e15) ? xBaseRaw : plotArea.width / 6
    let yBase = (yBaseRaw.isFinite && abs(yBaseRaw) < 1e15) ? yBaseRaw : plotArea.height / 6
    let xGap = xBase / Double(max(1, Int((xBase / 20).rounded())))
    let yGap = yBase / Double(max(1, Int((yBase / 20).rounded())))
    let xAnchor = xTickPositions.first ?? plotArea.x
    let yAnchor = yVals.first ?? plotArea.y
    let xStart = xAnchor - ceil((xAnchor - plotArea.x) / xGap) * xGap
    let yStart = yAnchor - ceil((yAnchor - plotArea.y) / yGap) * yGap

    var y = yStart
    while y <= plotArea.y + plotArea.height + 0.5 {
        var x = xStart
        while x <= plotArea.x + plotArea.width + 0.5 {
            parts.append("<circle cx=\"\(_r(x))\" cy=\"\(_r(y))\" r=\"1.5\" class=\"xychart-grid\"/>")
            x += xGap
        }
        y += yGap
    }

    // 2. Bars
    var barOverlay: [String] = []
    for bar in chart.bars {
        let dataAttrs = " data-value=\"\(bar.value)\"\(bar.label.map { " data-label=\"\(_escapeXml($0))\"" } ?? "")"
        let barPath = chart.horizontal
            ? _roundedRightBarPath(bar.x, bar.y, bar.width, bar.height, ChartFont.barRadius)
            : _roundedTopBarPath(bar.x, bar.y, bar.width, bar.height, ChartFont.barRadius)
        parts.append("<path d=\"\(barPath)\" class=\"xychart-bar xychart-color-\(bar.colorIndex)\"\(dataAttrs)/>")

        if interactive {
            let tipText = _formatTipValue(bar.value)
            let tipTitle = bar.label.map { "\($0): \(tipText)" } ?? tipText
            let tip = _tooltipAbove(bar.x + bar.width / 2, bar.y, tipText)
            barOverlay.append(
                "<g class=\"xychart-bar-group\">" +
                "<rect x=\"\(_r(bar.x))\" y=\"\(_r(bar.y))\" width=\"\(_r(bar.width))\" height=\"\(_r(bar.height))\" fill=\"transparent\"/>" +
                "<title>\(_escapeXml(tipTitle))</title>" +
                tip + "</g>"
            )
        }
    }

    // 3. Lines
    for line in chart.lines {
        if line.points.isEmpty { continue }
        let d = _smoothCurvePath(line.points)
        parts.append("<path d=\"\(d)\" class=\"xychart-line-shadow xychart-color-\(line.colorIndex)\" transform=\"translate(0,2)\"/>")
        parts.append("<path d=\"\(d)\" class=\"xychart-line xychart-color-\(line.colorIndex)\"/>")
    }

    // 4. Dots
    var dotOverlay: [String] = []
    if interactive || sparse {
        var columns: [String: [(x: Double, y: Double, value: Double, label: String?, seriesIndex: Int, colorIndex: Int)]] = [:]
        for line in chart.lines {
            for p in line.points {
                let key = _r(p.x)
                columns[key, default: []].append((p.x, p.y, p.value, p.label, line.seriesIndex, line.colorIndex))
            }
        }

        for entries in columns.values {
            guard let first = entries.first else { continue }

            if !interactive {
                // Sparse, not interactive: static dots
                for e in entries {
                    let dataAttrs = " data-value=\"\(e.value)\"\(e.label.map { " data-label=\"\(_escapeXml($0))\"" } ?? "")"
                    parts.append("<circle cx=\"\(_r(e.x))\" cy=\"\(_r(e.y))\" r=\"\(ChartFont.dotRadius)\" class=\"xychart-dot xychart-color-\(e.colorIndex)\"\(dataAttrs)/>")
                }
            } else if entries.count > 1 {
                let topY = entries.map(\.y).min() ?? first.y
                let botY = entries.map(\.y).max() ?? first.y
                let hitPad = ChartFont.dotRadius * 3
                let hitArea = "<rect x=\"\(_r(first.x - hitPad))\" y=\"\(_r(topY - hitPad))\" width=\"\(_r(hitPad * 2))\" height=\"\(_r(botY - topY + hitPad * 2))\" fill=\"transparent\" class=\"xychart-hit\"/>"
                let tipEntries = entries.map { e in
                    (text: _formatTipValue(e.value), legendLabel: "Line \(e.seriesIndex + 1)")
                }
                let tip = _multiTooltipAbove(first.x, topY - ChartFont.dotRadius, first.label ?? "", tipEntries)
                let valStrs = tipEntries.map(\.text)
                let titleText = first.label.map { "\($0): \(valStrs.joined(separator: " · "))" } ?? valStrs.joined(separator: " · ")

                var group = "<g class=\"xychart-dot-group\">\(hitArea)"
                for e in entries {
                    let dataAttrs = " data-value=\"\(e.value)\"\(e.label.map { " data-label=\"\(_escapeXml($0))\"" } ?? "")"
                    group += "<circle cx=\"\(_r(e.x))\" cy=\"\(_r(e.y))\" r=\"\(ChartFont.dotRadius)\" class=\"xychart-dot xychart-color-\(e.colorIndex)\"\(dataAttrs)/>"
                }
                group += "<title>\(_escapeXml(titleText))</title>\(tip)</g>"
                dotOverlay.append(group)
            } else {
                let e = first
                let dataAttrs = " data-value=\"\(e.value)\"\(e.label.map { " data-label=\"\(_escapeXml($0))\"" } ?? "")"
                let tipText = _formatTipValue(e.value)
                let tipTitle = e.label.map { "\($0): \(tipText)" } ?? tipText
                let tip = _tooltipAbove(first.x, e.y - ChartFont.dotRadius, tipText)
                let hitArea = sparse
                    ? "<circle cx=\"\(_r(first.x))\" cy=\"\(_r(e.y))\" r=\"\(ChartFont.dotRadius * 3)\" fill=\"transparent\" class=\"xychart-hit\"/>"
                    : ""
                dotOverlay.append(
                    "<g class=\"xychart-dot-group\">\(hitArea)" +
                    "<circle cx=\"\(_r(e.x))\" cy=\"\(_r(e.y))\" r=\"\(ChartFont.dotRadius)\" class=\"xychart-dot xychart-color-\(e.colorIndex)\"\(dataAttrs)/>" +
                    "<title>\(_escapeXml(tipTitle))</title>\(tip)</g>"
                )
            }
        }
    }

    // 5. Axis labels
    let TEXT_BASELINE = original_src_styles.TEXT_BASELINE_SHIFT
    for tick in chart.xAxis.ticks {
        parts.append(
            "<text x=\"\(tick.labelX)\" y=\"\(tick.labelY)\" text-anchor=\"\(tick.textAnchor)\" " +
            "font-size=\"\(ChartFont.labelSize)\" font-weight=\"\(ChartFont.labelWeight)\" " +
            "dy=\"\(TEXT_BASELINE)\" class=\"xychart-label\">\(_escapeXml(tick.label))</text>"
        )
    }
    for tick in chart.yAxis.ticks {
        parts.append(
            "<text x=\"\(tick.labelX)\" y=\"\(tick.labelY)\" text-anchor=\"\(tick.textAnchor)\" " +
            "font-size=\"\(ChartFont.labelSize)\" font-weight=\"\(ChartFont.labelWeight)\" " +
            "dy=\"\(TEXT_BASELINE)\" class=\"xychart-label\">\(_escapeXml(tick.label))</text>"
        )
    }

    // 6. Axis titles
    if let t = chart.xAxis.title {
        let transform = t.rotate.map { " transform=\"rotate(\($0),\(t.x),\(t.y))\"" } ?? ""
        parts.append(
            "<text x=\"\(t.x)\" y=\"\(t.y)\" text-anchor=\"middle\"\(transform) " +
            "font-size=\"\(ChartFont.axisTitleSize)\" font-weight=\"\(ChartFont.axisTitleWeight)\" " +
            "dy=\"\(TEXT_BASELINE)\" class=\"xychart-axis-title\">\(_escapeXml(t.text))</text>"
        )
    }
    if let t = chart.yAxis.title {
        let transform = t.rotate.map { " transform=\"rotate(\($0),\(t.x),\(t.y))\"" } ?? ""
        parts.append(
            "<text x=\"\(t.x)\" y=\"\(t.y)\" text-anchor=\"middle\"\(transform) " +
            "font-size=\"\(ChartFont.axisTitleSize)\" font-weight=\"\(ChartFont.axisTitleWeight)\" " +
            "dy=\"\(TEXT_BASELINE)\" class=\"xychart-axis-title\">\(_escapeXml(t.text))</text>"
        )
    }

    // 7. Chart title
    if let title = chart.title {
        parts.append(
            "<text x=\"\(title.x)\" y=\"\(title.y)\" text-anchor=\"middle\" " +
            "font-size=\"\(ChartFont.titleSize)\" font-weight=\"\(ChartFont.titleWeight)\" " +
            "dy=\"\(TEXT_BASELINE)\" class=\"xychart-title\">\(_escapeXml(title.text))</text>"
        )
    }

    // 8. Legend — swatches centered on item.y (matches TS)
    for item in chart.legend {
        let swatchW: Double = 12, swatchH: Double = 10, gap: Double = 5
        if item.type == .bar {
            parts.append(
                "<rect x=\"\(item.x)\" y=\"\(item.y - swatchH / 2)\" width=\"\(swatchW)\" height=\"\(swatchH)\" rx=\"2\" " +
                "class=\"xychart-bar xychart-color-\(item.colorIndex)\"/>"
            )
        } else {
            parts.append(
                "<line x1=\"\(item.x)\" y1=\"\(item.y)\" x2=\"\(item.x + swatchW)\" y2=\"\(item.y)\" " +
                "stroke-width=\"\(ChartFont.lineWidth)\" stroke-linecap=\"round\" class=\"xychart-legend-line xychart-color-\(item.colorIndex)\"/>"
            )
        }
        parts.append(
            "<text x=\"\(item.x + swatchW + gap)\" y=\"\(item.y)\" text-anchor=\"start\" " +
            "font-size=\"\(ChartFont.legendSize)\" font-weight=\"\(ChartFont.legendWeight)\" " +
            "dy=\"\(TEXT_BASELINE)\" class=\"xychart-legend-text\">\(_escapeXml(item.label))</text>"
        )
    }

    // 9. Interactive overlay
    for g in barOverlay { parts.append(g) }
    for g in dotOverlay { parts.append(g) }

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

// MARK: - Chart-specific CSS

private func _chartStyles(
    _ chart: PositionedXYChart, _ interactive: Bool, _ sparse: Bool,
    _ themeAccent: String?, _ bgColor: String?
) -> (style: String, defs: String) {
    let accentHex = themeAccent ?? CHART_ACCENT_FALLBACK

    var colorIndices = Set<Int>()
    for b in chart.bars { colorIndices.insert(b.colorIndex) }
    for l in chart.lines { colorIndices.insert(l.colorIndex) }

    var colorVarDefs: [String] = []
    for idx in colorIndices.sorted() {
        let value = idx == 0
            ? "var(--accent, \(CHART_ACCENT_FALLBACK))"
            : getSeriesColor(idx, accentHex, bgColor)
        colorVarDefs.append("    --xychart-color-\(idx): \(value);")
        colorVarDefs.append("    --xychart-bar-fill-\(idx): color-mix(in srgb, var(--bg) 75%, var(--xychart-color-\(idx)) 25%);")
    }

    var seriesRules: [String] = []
    for idx in colorIndices.sorted() {
        let color = "var(--xychart-color-\(idx))"
        seriesRules.append("  .xychart-bar.xychart-color-\(idx) { stroke: \(color); fill: var(--xychart-bar-fill-\(idx)); }")
        seriesRules.append("  path.xychart-color-\(idx), line.xychart-color-\(idx) { stroke: \(color); }")
        seriesRules.append("  circle.xychart-color-\(idx) { fill: \(color); }")
    }

    let tipRules = interactive ? """

      .xychart-tip { opacity: 0; pointer-events: none; }
      .xychart-tip-bg { fill: var(--_text); filter: drop-shadow(0 1px 3px color-mix(in srgb, var(--fg) 20%, transparent)); }
      .xychart-tip-text { fill: var(--bg); font-size: \(TIP.fontSize)px; font-weight: \(TIP.fontWeight); }
      .xychart-tip-ptr { fill: var(--_text); }
      .xychart-bar-group:hover .xychart-tip,
      .xychart-dot-group:hover .xychart-tip { opacity: 1; }
    """ : ""

    let colorVarsBlock = colorVarDefs.isEmpty ? "" : "\n  svg {\n\(colorVarDefs.joined(separator: "\n"))\n  }"

    let style = """
    <style>
      .xychart-grid { fill: var(--_inner-stroke); stroke: none; opacity: 0.65; }
      .xychart-bar { stroke-width: 1.5; }
      .xychart-line { fill: none; stroke-width: \(ChartFont.lineWidth); stroke-linecap: round; stroke-linejoin: round; }
      .xychart-line-shadow { fill: none; stroke-width: 5; stroke-linecap: round; stroke-linejoin: round; opacity: 0.12; }
      .xychart-dot { stroke: var(--bg); stroke-width: 2; }
      .xychart-label { fill: var(--_text-muted); }
      .xychart-legend-text { fill: var(--_text-muted); }
      .xychart-axis-title { fill: var(--_text-sec); }
      .xychart-title { fill: var(--_text); }\(colorVarsBlock)
    \(seriesRules.joined(separator: "\n"))\(tipRules)
    </style>
    """

    return (style, "")
}

// MARK: - Bar paths

private func _roundedTopBarPath(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ radius: Double) -> String {
    let rr = min(radius, w / 2, h / 2)
    if rr <= 0 {
        return "M\(_r(x)),\(_r(y)) h\(_r(w)) v\(_r(h)) h\(_r(-w)) Z"
    }
    return [
        "M\(_r(x)),\(_r(y + rr))",
        "Q\(_r(x)),\(_r(y)) \(_r(x + rr)),\(_r(y))",
        "L\(_r(x + w - rr)),\(_r(y))",
        "Q\(_r(x + w)),\(_r(y)) \(_r(x + w)),\(_r(y + rr))",
        "L\(_r(x + w)),\(_r(y + h - rr))",
        "Q\(_r(x + w)),\(_r(y + h)) \(_r(x + w - rr)),\(_r(y + h))",
        "L\(_r(x + rr)),\(_r(y + h))",
        "Q\(_r(x)),\(_r(y + h)) \(_r(x)),\(_r(y + h - rr))",
        "Z",
    ].joined(separator: " ")
}

private func _roundedRightBarPath(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ radius: Double) -> String {
    let rr = min(radius, w / 2, h / 2)
    if rr <= 0 {
        return "M\(_r(x)),\(_r(y)) h\(_r(w)) v\(_r(h)) h\(_r(-w)) Z"
    }
    return [
        "M\(_r(x + rr)),\(_r(y))",
        "L\(_r(x + w - rr)),\(_r(y))",
        "Q\(_r(x + w)),\(_r(y)) \(_r(x + w)),\(_r(y + rr))",
        "L\(_r(x + w)),\(_r(y + h - rr))",
        "Q\(_r(x + w)),\(_r(y + h)) \(_r(x + w - rr)),\(_r(y + h))",
        "L\(_r(x + rr)),\(_r(y + h))",
        "Q\(_r(x)),\(_r(y + h)) \(_r(x)),\(_r(y + h - rr))",
        "L\(_r(x)),\(_r(y + rr))",
        "Q\(_r(x)),\(_r(y)) \(_r(x + rr)),\(_r(y))",
        "Z",
    ].joined(separator: " ")
}

// MARK: - Smooth curve (natural cubic spline)

private func _smoothCurvePath(_ points: [LinePoint]) -> String {
    if points.isEmpty { return "" }
    if points.count == 1 { return "M\(_r(points[0].x)),\(_r(points[0].y))" }
    if points.count == 2 {
        return "M\(_r(points[0].x)),\(_r(points[0].y)) L\(_r(points[1].x)),\(_r(points[1].y))"
    }

    let n = points.count

    var h: [Double] = []
    var delta: [Double] = []
    for i in 0..<(n - 1) {
        let hi = points[i + 1].x - points[i].x
        h.append(hi)
        delta.append(hi == 0 ? 0 : (points[i + 1].y - points[i].y) / hi)
    }

    var c = [Double](repeating: 0, count: n)
    if n > 2 {
        var cp = [Double](repeating: 0, count: n)
        var dp = [Double](repeating: 0, count: n)
        for i in 1..<(n - 1) {
            let diag = 2 * (h[i - 1] + h[i])
            let rhs = 3 * (delta[i] - delta[i - 1])
            if i == 1 {
                cp[i] = h[i] / diag
                dp[i] = rhs / diag
            } else {
                let w = diag - h[i - 1] * cp[i - 1]
                cp[i] = h[i] / w
                dp[i] = (rhs - h[i - 1] * dp[i - 1]) / w
            }
        }
        for i in stride(from: n - 2, through: 1, by: -1) {
            c[i] = dp[i] - cp[i] * c[i + 1]
        }
    }

    var slopes = [Double](repeating: 0, count: n)
    for i in 0..<(n - 1) {
        slopes[i] = delta[i] - h[i] * (2 * c[i] + c[i + 1]) / 3
    }
    slopes[n - 1] = delta[n - 2] + h[n - 2] * c[n - 2] / 3

    var path = "M\(_r(points[0].x)),\(_r(points[0].y))"
    for i in 0..<(n - 1) {
        let seg = h[i] / 3
        let cp1x = points[i].x + seg
        let cp1y = points[i].y + slopes[i] * seg
        let cp2x = points[i + 1].x - seg
        let cp2y = points[i + 1].y - slopes[i + 1] * seg
        path += " C\(_r(cp1x)),\(_r(cp1y)) \(_r(cp2x)),\(_r(cp2y)) \(_r(points[i + 1].x)),\(_r(points[i + 1].y))"
    }

    return path
}

// MARK: - Tooltips

private func _tooltipAbove(_ cx: Double, _ topY: Double, _ text: String) -> String {
    let textW = original_src_styles.estimateTextWidth(text, TIP.fontSize, TIP.fontWeight)
    let bgW = textW + TIP.padX * 2
    let bgH = TIP.height
    let tipY = max(TIP.minY, topY - TIP.offsetY - bgH - TIP.pointerSize)
    let bgX = cx - bgW / 2
    let textX = cx
    let textY = tipY + bgH / 2
    let ptrY = tipY + bgH
    let ps = TIP.pointerSize
    let pointer = "<polygon points=\"\(_r(cx - ps)),\(_r(ptrY)) \(_r(cx + ps)),\(_r(ptrY)) \(_r(cx)),\(_r(ptrY + ps))\" class=\"xychart-tip xychart-tip-ptr\"/>"

    return "<rect x=\"\(_r(bgX))\" y=\"\(_r(tipY))\" width=\"\(_r(bgW))\" height=\"\(bgH)\" rx=\"\(TIP.rx)\" class=\"xychart-tip xychart-tip-bg\"/>" +
        pointer +
        "<text x=\"\(_r(textX))\" y=\"\(_r(textY))\" text-anchor=\"middle\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" class=\"xychart-tip xychart-tip-text\">\(_escapeXml(text))</text>"
}

private func _multiTooltipAbove(_ cx: Double, _ topY: Double, _ label: String, _ entries: [(text: String, legendLabel: String)]) -> String {
    let lineH: Double = 20
    let padY: Double = 6
    let labelGap: Double = 10
    let headingW = original_src_styles.estimateTextWidth(label, TIP.fontSize, 600)
    let maxRowW = entries.map { e in
        original_src_styles.estimateTextWidth(e.legendLabel, TIP.fontSize, TIP.fontWeight) + labelGap +
        original_src_styles.estimateTextWidth(e.text, TIP.fontSize, TIP.fontWeight)
    }.max() ?? 0
    let bgW = max(headingW, maxRowW) + TIP.padX * 2
    let bgH = padY + lineH + Double(entries.count) * lineH + padY

    let tipY = max(TIP.minY, topY - TIP.offsetY - bgH - TIP.pointerSize)
    let bgX = cx - bgW / 2
    let ptrY = tipY + bgH
    let ps = TIP.pointerSize
    let pointer = "<polygon points=\"\(_r(cx - ps)),\(_r(ptrY)) \(_r(cx + ps)),\(_r(ptrY)) \(_r(cx)),\(_r(ptrY + ps))\" class=\"xychart-tip xychart-tip-ptr\"/>"

    var svg = "<rect x=\"\(_r(bgX))\" y=\"\(_r(tipY))\" width=\"\(_r(bgW))\" height=\"\(bgH)\" rx=\"\(TIP.rx)\" class=\"xychart-tip xychart-tip-bg\"/>"
    svg += pointer

    var textY = tipY + padY + lineH / 2
    svg += "<text x=\"\(_r(cx))\" y=\"\(_r(textY))\" text-anchor=\"middle\" font-weight=\"600\" font-size=\"\(TIP.fontSize)\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" class=\"xychart-tip xychart-tip-text\">\(_escapeXml(label))</text>"

    let rowLeft = bgX + TIP.padX
    let rowRight = bgX + bgW - TIP.padX
    for entry in entries {
        textY += lineH
        svg += "<text x=\"\(_r(rowLeft))\" y=\"\(_r(textY))\" text-anchor=\"start\" font-size=\"\(TIP.fontSize)\" font-weight=\"\(TIP.fontWeight)\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" class=\"xychart-tip xychart-tip-text\">\(_escapeXml(entry.legendLabel))</text>"
        svg += "<text x=\"\(_r(rowRight))\" y=\"\(_r(textY))\" text-anchor=\"end\" font-size=\"\(TIP.fontSize)\" font-weight=\"\(TIP.fontWeight)\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" class=\"xychart-tip xychart-tip-text\">\(_escapeXml(entry.text))</text>"
    }

    return svg
}

// MARK: - Utilities

private func _formatTipValue(_ v: Double) -> String {
    if v == v.rounded() && abs(v) < 1e15 {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: v)) ?? String(Int(v))
    }
    return abs(v) < 10 ? String(format: "%.1f", v) : String(format: "%.0f", v)
}

private func _r(_ n: Double) -> String {
    let rounded = (n * 10).rounded() / 10
    if rounded.isFinite && abs(rounded) < 1e15 && rounded == rounded.rounded() {
        return String(Int(rounded))
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}

private func _escapeXml(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
