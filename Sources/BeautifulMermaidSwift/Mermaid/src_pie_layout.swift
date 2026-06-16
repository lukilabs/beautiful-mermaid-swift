// Layout for pie charts.
import Foundation

private enum PieLayout {
    static let radius: Double = 145
    static let padding: Double = 28
    static let titleHeight: Double = 42
    static let titleFontSize: Double = 18
    static let titleFontWeight: Int = 600
    static let legendGap: Double = 46
    static let legendRowHeight: Double = 24
    static let legendFontSize: Double = 13
    static let legendFontWeight: Int = 400
    static let legendSwatch: Double = 12
    static let labelRadiusRatio: Double = 0.60
}

public func layoutPieChart(_ chart: PieChart, _ options: RenderOptions = RenderOptions()) -> PositionedPieChart {
    _ = options
    let slices = chart.slices.filter { $0.value > 0 && $0.value.isFinite }
    guard !slices.isEmpty else {
        return .empty
    }

    let total = slices.reduce(0) { $0 + $1.value }
    guard total > 0 else {
        return .empty
    }

    let hasTitle = chart.title != nil
    let top = PieLayout.padding + (hasTitle ? PieLayout.titleHeight : 0)
    let radius = PieLayout.radius
    let diameter = radius * 2
    let pieLeft = PieLayout.padding + 12
    let centerX = pieLeft + radius
    let centerY = top + radius

    let legendLabels = slices.map { _pieLegendLabel($0, total: total, showData: chart.showData) }
    let legendTextWidth = legendLabels
        .map { original_src_styles.estimateTextWidth($0, PieLayout.legendFontSize, PieLayout.legendFontWeight) }
        .max() ?? 0
    let legendWidth = PieLayout.legendSwatch + 8 + legendTextWidth
    let legendHeight = Double(slices.count) * PieLayout.legendRowHeight
    let legendX = centerX + radius + PieLayout.legendGap
    let legendTop = max(top, centerY - legendHeight / 2)

    let width = max(520, legendX + legendWidth + PieLayout.padding)
    let height = max(top + diameter + PieLayout.padding, legendTop + legendHeight + PieLayout.padding)
    let titleObj = chart.title.map {
        PositionedTitle(text: $0, x: width / 2, y: PieLayout.padding + PieLayout.titleFontSize)
    }

    var start = -Double.pi / 2
    var positionedSlices: [PositionedPieSlice] = []
    var legend: [PieLegendItem] = []

    for (index, slice) in slices.enumerated() {
        let percentage = slice.value / total
        let end = start + percentage * 2 * Double.pi
        let mid = start + (end - start) / 2
        let labelRadius = radius * PieLayout.labelRadiusRatio
        positionedSlices.append(PositionedPieSlice(
            label: slice.label,
            value: slice.value,
            percentage: percentage,
            startAngle: start,
            endAngle: end,
            midAngle: mid,
            labelX: centerX + cos(mid) * labelRadius,
            labelY: centerY + sin(mid) * labelRadius,
            colorIndex: index
        ))
        legend.append(PieLegendItem(
            label: slice.label,
            value: slice.value,
            percentage: percentage,
            x: legendX,
            y: legendTop + Double(index) * PieLayout.legendRowHeight + PieLayout.legendRowHeight / 2,
            colorIndex: index
        ))
        start = end
    }

    return PositionedPieChart(
        width: width,
        height: height,
        title: titleObj,
        showData: chart.showData,
        centerX: centerX,
        centerY: centerY,
        radius: radius,
        slices: positionedSlices,
        legend: legend
    )
}

func _pieLegendLabel(_ slice: PieChartSlice, total: Double, showData: Bool) -> String {
    guard showData else {
        return slice.label
    }
    return "\(slice.label) \(_formatPieValue(slice.value))"
}

func _formatPiePercent(_ p: Double) -> String {
    let pct = p * 100
    if pct == pct.rounded() {
        return "\(Int(pct))%"
    }
    return String(format: "%.1f%%", pct)
}

func _formatPieValue(_ v: Double) -> String {
    if v == v.rounded(), abs(v) < 1e15 {
        return String(Int(v))
    }
    return abs(v) < 10 ? String(format: "%.2f", v) : String(format: "%.1f", v)
}
