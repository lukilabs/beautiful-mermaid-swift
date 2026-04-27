// Ported from original/src/xychart/layout.ts
import Foundation

// MARK: - Layout constants

private enum XY {
    static let plotWidth: Double = 600
    static let plotHeight: Double = 340
    static let padding: Double = 22
    static let titleFontSize: Double = 18
    static let titleFontWeight: Int = 600
    static let titleHeight: Double = 42
    static let axisLabelFontSize: Double = 14
    static let axisLabelFontWeight: Int = 400
    static let axisTitleFontSize: Double = 15
    static let axisTitleFontWeight: Int = 500
    static let xLabelHeight: Double = 38
    static let yLabelWidth: Double = 58
    static let yLabelGap: Double = 18
    static let axisTitlePad: Double = 30
    static let tickLength: Double = 4
    static let barPadRatio: Double = 0.2
    static let barGroupGap: Double = 0
    static let maxBarWidth: Double = 40
    static let legendFontSize: Double = 12
    static let legendFontWeight: Int = 400
    static let legendHeight: Double = 24
    static let legendSwatchW: Double = 12
    static let legendSwatchH: Double = 10
    static let legendGap: Double = 5
    static let legendItemGap: Double = 14
    static let headerBottomPad: Double = 10
}

// MARK: - Public entry point

public func layoutXYChart(_ chart: XYChart, _ options: RenderOptions = RenderOptions()) -> PositionedXYChart {
    if chart.horizontal { return _layoutHorizontal(chart) }
    return _layoutVertical(chart)
}

// MARK: - Vertical layout

private func _layoutVertical(_ chart: XYChart) -> PositionedXYChart {
    let hasTitle = chart.title != nil
    let hasXTitle = chart.xAxis.title != nil
    let hasYTitle = chart.yAxis.title != nil
    let hasLegend = chart.series.count > 1

    guard let yRange = chart.yAxis.range else {
        return PositionedXYChart(width: 0, height: 0, title: nil, xAxis: PositionedXYAxis(title: nil, ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)), yAxis: PositionedXYAxis(title: nil, ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)), plotArea: XYPlotArea(x: 0, y: 0, width: 0, height: 0), bars: [], lines: [], gridLines: [], legend: [])
    }
    let yTicks = _niceTickValues(yRange.min, yRange.max)
    let maxYLabelWidth = max(
        yTicks.map({ original_src_styles.estimateTextWidth(_formatTickValue($0), XY.axisLabelFontSize, XY.axisLabelFontWeight) }).max() ?? 0,
        XY.yLabelWidth
    )

    let top = XY.padding + (hasTitle ? XY.titleHeight : 0) + (hasLegend ? XY.legendHeight : 0) + (hasTitle || hasLegend ? XY.headerBottomPad : 0)
    let bottom = XY.padding + XY.xLabelHeight + (hasXTitle ? XY.axisTitlePad : 0)
    let left = XY.padding + maxYLabelWidth + XY.yLabelGap + (hasYTitle ? XY.axisTitlePad : 0)
    let right = XY.padding

    let plotW = XY.plotWidth
    let plotH = XY.plotHeight
    let totalW = left + plotW + right
    let totalH = top + plotH + bottom

    let plotArea = XYPlotArea(x: left, y: top, width: plotW, height: plotH)

    let dataCount = _getDataCount(chart)
    let bandWidth = plotW / Double(dataCount)
    let xScale: (Int) -> Double = { i in left + (Double(i) + 0.5) * bandWidth }
    let yScale: (Double) -> Double = { v in
        let t = (v - yRange.min) / (yRange.max - yRange.min == 0 ? 1 : yRange.max - yRange.min)
        return top + plotH - t * plotH
    }

    let catLabels = _getCategoryLabels(chart, dataCount)
    let xTicks = _buildXTicks(chart, xScale, top + plotH, bandWidth)

    let yAxisTicks: [XYAxisTick] = yTicks.map { v in
        XYAxisTick(
            label: _formatTickValue(v),
            x: left, y: yScale(v),
            tx: left - XY.tickLength, ty: yScale(v),
            labelX: left - XY.yLabelGap, labelY: yScale(v),
            textAnchor: "end"
        )
    }

    let gridLines: [XYGridLine] = yTicks.map { v in
        XYGridLine(x1: left, y1: yScale(v), x2: left + plotW, y2: yScale(v))
    }

    let colorMap = chart.series.indices.map { $0 }

    let bars = _layoutBars(chart, xScale, yScale, bandWidth, yRange.min, catLabels, colorMap)
    let lines = _layoutLines(chart, xScale, yScale, catLabels, colorMap)

    let legendY = XY.padding + (hasTitle ? XY.titleHeight : 0) + XY.legendHeight / 2
    let legend = hasLegend ? _buildLegendItems(chart, totalW / 2, legendY, colorMap) : []

    let xAxisLine = AxisLine(x1: left, y1: top + plotH, x2: left + plotW, y2: top + plotH)
    let yAxisLine = AxisLine(x1: left, y1: top, x2: left, y2: top + plotH)

    let xAxisObj = PositionedXYAxis(
        title: chart.xAxis.title.map { AxisTitle(text: $0, x: left + plotW / 2, y: totalH - XY.padding) },
        ticks: xTicks, line: xAxisLine
    )
    let yAxisObj = PositionedXYAxis(
        title: chart.yAxis.title.map { AxisTitle(text: $0, x: XY.padding + 4, y: top + plotH / 2, rotate: -90) },
        ticks: yAxisTicks, line: yAxisLine
    )

    let titleObj = chart.title.map { PositionedTitle(text: $0, x: totalW / 2, y: XY.padding + XY.titleFontSize) }

    return PositionedXYChart(
        width: totalW, height: totalH, title: titleObj,
        xAxis: xAxisObj, yAxis: yAxisObj, plotArea: plotArea,
        bars: bars, lines: lines, gridLines: gridLines, legend: legend
    )
}

// MARK: - Horizontal layout

private func _layoutHorizontal(_ chart: XYChart) -> PositionedXYChart {
    let hasTitle = chart.title != nil
    let hasXTitle = chart.xAxis.title != nil
    let hasYTitle = chart.yAxis.title != nil
    let hasLegend = chart.series.count > 1

    guard let yRange = chart.yAxis.range else {
        return PositionedXYChart(width: 0, height: 0, title: nil, xAxis: PositionedXYAxis(title: nil, ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)), yAxis: PositionedXYAxis(title: nil, ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)), plotArea: XYPlotArea(x: 0, y: 0, width: 0, height: 0), bars: [], lines: [], gridLines: [], legend: [])
    }
    let valueTicks = _niceTickValues(yRange.min, yRange.max)

    let dataCount = _getDataCount(chart)
    let catLabels = _getCategoryLabels(chart, dataCount)
    let maxCatLabelWidth = max(
        catLabels.map({ original_src_styles.estimateTextWidth($0, XY.axisLabelFontSize, XY.axisLabelFontWeight) }).max() ?? 0,
        40
    )

    let top = XY.padding + (hasTitle ? XY.titleHeight : 0) + (hasLegend ? XY.legendHeight : 0) + (hasTitle || hasLegend ? XY.headerBottomPad : 0)
    let bottom = XY.padding + XY.xLabelHeight + (hasYTitle ? XY.axisTitlePad : 0)
    let left = XY.padding + maxCatLabelWidth + XY.yLabelGap + (hasXTitle ? XY.axisTitlePad : 0)
    let right = XY.padding

    let plotW = XY.plotWidth
    let plotH = XY.plotHeight
    let totalW = left + plotW + right
    let totalH = top + plotH + bottom

    let plotArea = XYPlotArea(x: left, y: top, width: plotW, height: plotH)

    let valueScale: (Double) -> Double = { v in
        let t = (v - yRange.min) / (yRange.max - yRange.min == 0 ? 1 : yRange.max - yRange.min)
        return left + t * plotW
    }
    let bandHeight = plotH / Double(dataCount)
    let catScale: (Int) -> Double = { i in top + (Double(i) + 0.5) * bandHeight }

    let xTicks: [XYAxisTick] = valueTicks.map { v in
        XYAxisTick(
            label: _formatTickValue(v), x: valueScale(v), y: top + plotH,
            tx: valueScale(v), ty: top + plotH + XY.tickLength,
            labelX: valueScale(v), labelY: top + plotH + 18,
            textAnchor: "middle"
        )
    }

    let yTicks: [XYAxisTick] = catLabels.enumerated().map { i, label in
        XYAxisTick(
            label: label, x: left, y: catScale(i),
            tx: left - XY.tickLength, ty: catScale(i),
            labelX: left - XY.yLabelGap, labelY: catScale(i),
            textAnchor: "end"
        )
    }

    let gridLines: [XYGridLine] = valueTicks.map { v in
        XYGridLine(x1: valueScale(v), y1: top, x2: valueScale(v), y2: top + plotH)
    }

    let colorMap = chart.series.indices.map { $0 }

    // Bars (horizontal)
    let barSeries = chart.series.enumerated().filter { $0.element.type == .bar }
    let barCount = barSeries.count
    var bars: [PositionedBar] = []
    if barCount > 0 {
        let usable = bandHeight * (1 - XY.barPadRatio)
        let rawBarH = barCount > 1 ? (usable - Double(barCount - 1) * XY.barGroupGap) / Double(barCount) : usable
        let singleBarH = min(rawBarH, XY.maxBarWidth)
        let groupH = barCount > 1 ? singleBarH * Double(barCount) + XY.barGroupGap * Double(barCount - 1) : singleBarH

        var bIdx = 0
        for (seriesArrayIdx, s) in chart.series.enumerated() {
            guard s.type == .bar else { continue }
            for i in 0..<min(s.data.count, catLabels.count) {
                let cy = catScale(i)
                let groupTop = cy - groupH / 2
                let by = groupTop + Double(bIdx) * (singleBarH + XY.barGroupGap)
                let valX = valueScale(max(s.data[i], yRange.min))
                let baseX = valueScale(max(0, yRange.min))
                bars.append(PositionedBar(
                    x: min(baseX, valX), y: by,
                    width: abs(valX - baseX), height: singleBarH,
                    value: s.data[i], label: catLabels[i],
                    seriesIndex: bIdx, colorIndex: colorMap[seriesArrayIdx]
                ))
            }
            bIdx += 1
        }
    }

    // Lines (horizontal)
    var lines: [PositionedLine] = []
    var lineIdx = 0
    for (seriesIdx, s) in chart.series.enumerated() {
        guard s.type == .line else { continue }
        let points = (0..<min(s.data.count, catLabels.count)).map { i -> LinePoint in
            let v = s.data[i]
            return LinePoint(x: valueScale(v), y: catScale(i), value: v, label: catLabels[i])
        }
        lines.append(PositionedLine(points: points, seriesIndex: lineIdx, colorIndex: colorMap[seriesIdx]))
        lineIdx += 1
    }

    let xAxisLine = AxisLine(x1: left, y1: top + plotH, x2: left + plotW, y2: top + plotH)
    let yAxisLine = AxisLine(x1: left, y1: top, x2: left, y2: top + plotH)

    let xAxisObj = PositionedXYAxis(
        title: chart.yAxis.title.map { AxisTitle(text: $0, x: left + plotW / 2, y: totalH - XY.padding) },
        ticks: xTicks, line: xAxisLine
    )
    let yAxisObj = PositionedXYAxis(
        title: chart.xAxis.title.map { AxisTitle(text: $0, x: XY.padding + 4, y: top + plotH / 2, rotate: -90) },
        ticks: yTicks, line: yAxisLine
    )

    let titleObj = chart.title.map { PositionedTitle(text: $0, x: totalW / 2, y: XY.padding + XY.titleFontSize) }

    let legendY = XY.padding + (hasTitle ? XY.titleHeight : 0) + XY.legendHeight / 2
    let legend = hasLegend ? _buildLegendItems(chart, totalW / 2, legendY, colorMap) : []

    return PositionedXYChart(
        width: totalW, height: totalH, horizontal: true, title: titleObj,
        xAxis: xAxisObj, yAxis: yAxisObj, plotArea: plotArea,
        bars: bars, lines: lines, gridLines: gridLines, legend: legend
    )
}

// MARK: - Shared helpers (also used by ASCII renderer)

func _getDataCount(_ chart: XYChart) -> Int {
    if let cats = chart.xAxis.categories { return cats.count }
    for s in chart.series {
        if !s.data.isEmpty { return s.data.count }
    }
    return 1
}

func _getCategoryLabels(_ chart: XYChart, _ count: Int) -> [String] {
    if let cats = chart.xAxis.categories { return cats }
    if let range = chart.xAxis.range {
        let step = count > 1 ? (range.max - range.min) / Double(count - 1) : 0
        return (0..<count).map { _formatTickValue(range.min + step * Double($0)) }
    }
    return (0..<count).map { String($0 + 1) }
}

func _niceTickValues(_ min: Double, _ max: Double) -> [Double] {
    let range = max - min
    if range <= 0 { return [min] }

    let rawInterval = range / 6.0
    let magnitude = pow(10, floor(log10(rawInterval)))
    let residual = rawInterval / magnitude
    let niceInterval: Double
    if residual <= 1.5 { niceInterval = magnitude }
    else if residual <= 3 { niceInterval = 2 * magnitude }
    else if residual <= 7 { niceInterval = 5 * magnitude }
    else { niceInterval = 10 * magnitude }

    let start = ceil(min / niceInterval) * niceInterval
    var ticks: [Double] = []
    var v = start
    while v <= max + niceInterval * 0.001 {
        ticks.append((v * 1e10).rounded() / 1e10)
        v += niceInterval
    }
    return ticks
}

func _formatTickValue(_ v: Double) -> String {
    if v == v.rounded() && abs(v) < 1e15 { return String(Int(v)) }
    return abs(v) < 10 ? String(format: "%.1f", v) : String(format: "%.0f", v)
}

// MARK: - Private helpers

private func _buildXTicks(_ chart: XYChart, _ xScale: (Int) -> Double, _ axisY: Double, _ bandWidth: Double) -> [XYAxisTick] {
    let count = _getDataCount(chart)
    let labels = _getCategoryLabels(chart, count)
    return labels.enumerated().map { i, label in
        XYAxisTick(
            label: label, x: xScale(i), y: axisY,
            tx: xScale(i), ty: axisY + XY.tickLength,
            labelX: xScale(i), labelY: axisY + 18,
            textAnchor: "middle"
        )
    }
}

private func _layoutBars(
    _ chart: XYChart, _ xScale: (Int) -> Double, _ yScale: (Double) -> Double,
    _ bandWidth: Double, _ yMin: Double, _ catLabels: [String], _ colorMap: [Int]
) -> [PositionedBar] {
    let barSeries = chart.series.filter { $0.type == .bar }
    let barCount = barSeries.count
    if barCount == 0 { return [] }

    let usable = bandWidth * (1 - XY.barPadRatio)
    let rawBarW = barCount > 1 ? (usable - Double(barCount - 1) * XY.barGroupGap) / Double(barCount) : usable
    let singleBarW = min(rawBarW, XY.maxBarWidth)
    let groupW = barCount > 1 ? singleBarW * Double(barCount) + XY.barGroupGap * Double(barCount - 1) : singleBarW

    var bars: [PositionedBar] = []
    var bIdx = 0
    for (seriesArrayIdx, s) in chart.series.enumerated() {
        guard s.type == .bar else { continue }
        for i in 0..<min(s.data.count, catLabels.count) {
            let cx = xScale(i)
            let groupLeft = cx - groupW / 2
            let bx = groupLeft + Double(bIdx) * (singleBarW + XY.barGroupGap)
            let valY = yScale(s.data[i])
            let baseY = yScale(max(0, yMin))
            bars.append(PositionedBar(
                x: bx, y: min(valY, baseY),
                width: singleBarW, height: abs(baseY - valY),
                value: s.data[i], label: catLabels[i],
                seriesIndex: bIdx, colorIndex: colorMap[seriesArrayIdx]
            ))
        }
        bIdx += 1
    }
    return bars
}

private func _layoutLines(
    _ chart: XYChart, _ xScale: (Int) -> Double, _ yScale: (Double) -> Double,
    _ catLabels: [String], _ colorMap: [Int]
) -> [PositionedLine] {
    var lines: [PositionedLine] = []
    var lineIdx = 0
    for (seriesArrayIdx, s) in chart.series.enumerated() {
        guard s.type == .line else { continue }
        let points = (0..<min(s.data.count, catLabels.count)).map { i -> LinePoint in
            let v = s.data[i]
            return LinePoint(x: xScale(i), y: yScale(v), value: v, label: catLabels[i])
        }
        lines.append(PositionedLine(points: points, seriesIndex: lineIdx, colorIndex: colorMap[seriesArrayIdx]))
        lineIdx += 1
    }
    return lines
}

private func _buildLegendItems(_ chart: XYChart, _ centerX: Double, _ y: Double, _ colorMap: [Int]) -> [XYLegendItem] {
    var items: [XYLegendItem] = []
    var barIdx = 0, lineIdx = 0
    for si in 0..<chart.series.count {
        let s = chart.series[si]
        let label = s.type == .bar ? "Bar \(barIdx + 1)" : "Line \(lineIdx + 1)"
        items.append(XYLegendItem(label: label, x: 0, y: y, type: s.type, seriesIndex: s.type == .bar ? barIdx : lineIdx, colorIndex: colorMap[si]))
        if s.type == .bar { barIdx += 1 }
        else { lineIdx += 1 }
    }

    let itemWidths = items.map { item in
        original_src_styles.estimateTextWidth(item.label, XY.legendFontSize, XY.legendFontWeight) + XY.legendSwatchW + XY.legendGap
    }
    let totalWidth = itemWidths.reduce(0, +) + Double(items.count - 1) * XY.legendItemGap
    var x = centerX - totalWidth / 2

    for i in 0..<items.count {
        items[i].x = x
        x += itemWidths[i] + XY.legendItemGap
    }

    return items
}
