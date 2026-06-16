// SVG renderer for pie charts.
import Foundation

private enum PieSvgFont {
    static let titleSize: Double = 18
    static let titleWeight: Int = 600
    static let labelSize: Double = 12
    static let labelWeight: Int = 600
    static let legendSize: Double = 13
    static let legendWeight: Int = 400
}

public func renderPieChartSvg(
    _ chart: PositionedPieChart,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) -> String {
    let themeColors = original_src_theme.DiagramColors(
        bg: colors.bg,
        fg: colors.fg,
        line: colors.line,
        accent: colors.accent,
        muted: colors.muted,
        surface: colors.surface,
        border: colors.border
    )
    let accent = colors.accent ?? CHART_ACCENT_FALLBACK
    var svgTag = original_src_theme.svgOpenTag(chart.width, chart.height, themeColors, transparent)
    svgTag = svgTag.replacingOccurrences(of: "<svg ", with: "<svg data-piechart-slices=\"\(chart.slices.count)\" ")

    var parts: [String] = [
        svgTag,
        original_src_theme.buildStyleBlock(font, false),
        """
        <style>
          .piechart-slice { stroke: var(--bg); stroke-width: 2; }
          .piechart-title { fill: var(--_text); }
          .piechart-label { font-size: \(PieSvgFont.labelSize)px; font-weight: \(PieSvgFont.labelWeight); }
          .piechart-legend-text { fill: var(--_text-muted); }
        </style>
        """
    ]

    for slice in chart.slices {
        let color = getSeriesColor(slice.colorIndex, accent, colors.bg)
        let dataAttrs = "data-label=\"\(_pieEscapeXml(slice.label))\" data-value=\"\(slice.value)\" data-percent=\"\(_formatPiePercent(slice.percentage))\""
        if slice.percentage >= 0.9999 {
            parts.append(
                "<circle class=\"piechart-slice\" \(dataAttrs) cx=\"\(_pieR(chart.centerX))\" cy=\"\(_pieR(chart.centerY))\" r=\"\(_pieR(chart.radius))\" fill=\"\(color)\"/>"
            )
        } else {
            parts.append(
                "<path class=\"piechart-slice\" \(dataAttrs) d=\"\(_pieSlicePath(chart, slice))\" fill=\"\(color)\"/>"
            )
        }
    }

    for slice in chart.slices where slice.percentage >= 0.045 {
        let color = getSeriesColor(slice.colorIndex, accent, colors.bg)
        let labelColor = isDarkBackground(color) ? "#ffffff" : "#000000"
        parts.append(
            "<text x=\"\(_pieR(slice.labelX))\" y=\"\(_pieR(slice.labelY))\" text-anchor=\"middle\" " +
            "dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" class=\"piechart-label\" fill=\"\(labelColor)\">\(_formatPiePercent(slice.percentage))</text>"
        )
    }

    if let title = chart.title {
        parts.append(
            "<text x=\"\(_pieR(title.x))\" y=\"\(_pieR(title.y))\" text-anchor=\"middle\" " +
            "font-size=\"\(PieSvgFont.titleSize)\" font-weight=\"\(PieSvgFont.titleWeight)\" " +
            "dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" class=\"piechart-title\">\(_pieEscapeXml(title.text))</text>"
        )
    }

    for item in chart.legend {
        let color = getSeriesColor(item.colorIndex, accent, colors.bg)
        let text = chart.showData ? "\(item.label) \(_formatPieValue(item.value))" : item.label
        parts.append(
            "<rect x=\"\(_pieR(item.x))\" y=\"\(_pieR(item.y - 6))\" width=\"12\" height=\"12\" rx=\"2\" fill=\"\(color)\"/>"
        )
        parts.append(
            "<text x=\"\(_pieR(item.x + 20))\" y=\"\(_pieR(item.y))\" text-anchor=\"start\" " +
            "font-size=\"\(PieSvgFont.legendSize)\" font-weight=\"\(PieSvgFont.legendWeight)\" " +
            "dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" class=\"piechart-legend-text\">\(_pieEscapeXml(text))</text>"
        )
    }

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

private func _pieSlicePath(_ chart: PositionedPieChart, _ slice: PositionedPieSlice) -> String {
    let sx = chart.centerX + cos(slice.startAngle) * chart.radius
    let sy = chart.centerY + sin(slice.startAngle) * chart.radius
    let ex = chart.centerX + cos(slice.endAngle) * chart.radius
    let ey = chart.centerY + sin(slice.endAngle) * chart.radius
    let largeArc = (slice.endAngle - slice.startAngle) > Double.pi ? 1 : 0
    return [
        "M\(_pieR(chart.centerX)),\(_pieR(chart.centerY))",
        "L\(_pieR(sx)),\(_pieR(sy))",
        "A\(_pieR(chart.radius)),\(_pieR(chart.radius)) 0 \(largeArc),1 \(_pieR(ex)),\(_pieR(ey))",
        "Z",
    ].joined(separator: " ")
}

private func _pieR(_ n: Double) -> String {
    let rounded = (n * 10).rounded() / 10
    if rounded.isFinite && abs(rounded) < 1e15 && rounded == rounded.rounded() {
        return String(Int(rounded))
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}

private func _pieEscapeXml(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
