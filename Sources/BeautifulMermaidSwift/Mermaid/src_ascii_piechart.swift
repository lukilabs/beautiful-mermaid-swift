// ASCII renderer for pie charts.
import Foundation

public func renderPieChartAscii(
    _ text: String,
    _ config: AsciiConfig,
    _ colorMode: ColorMode,
    _ theme: AsciiTheme
) -> String {
    _ = colorMode
    _ = theme
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    return renderPieChartAscii(parsePieChart(lines), config, colorMode, theme)
}

public func renderPieChartAscii(
    _ chart: PieChart,
    _ config: AsciiConfig,
    _ colorMode: ColorMode,
    _ theme: AsciiTheme
) -> String {
    _ = colorMode
    _ = theme

    let slices = chart.slices.filter { $0.value > 0 && $0.value.isFinite }
    guard !slices.isEmpty else { return "" }

    let total = slices.reduce(0) { $0 + $1.value }
    guard total > 0 else { return "" }

    let barChar = config.useAscii ? "#" : "█"
    let emptyChar = config.useAscii ? "." : "░"
    let barWidth = 28
    let labelWidth = min(24, max(4, slices.map { $0.label.count }.max() ?? 4))

    var rows: [String] = []
    if let title = chart.title {
        rows.append(title)
    }

    for slice in slices {
        let pct = slice.value / total
        let filled = max(1, min(barWidth, Int((pct * Double(barWidth)).rounded())))
        let empty = max(0, barWidth - filled)
        let label = _padPieAsciiLabel(slice.label, width: labelWidth)
        let value = chart.showData ? " \(_formatPieValue(slice.value))" : ""
        rows.append("\(label) \(String(repeating: barChar, count: filled))\(String(repeating: emptyChar, count: empty)) \(_formatPiePercent(pct))\(value)")
    }

    return rows.joined(separator: "\n")
}

private func _padPieAsciiLabel(_ label: String, width: Int) -> String {
    let clipped = label.count > width ? String(label.prefix(max(0, width - 1))) + "~" : label
    if clipped.count >= width {
        return clipped
    }
    return clipped + String(repeating: " ", count: width - clipped.count)
}
