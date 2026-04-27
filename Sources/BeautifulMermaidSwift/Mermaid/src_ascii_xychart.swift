// Ported from original/src/ascii/xychart.ts
import Foundation

// MARK: - Constants

private let PLOT_WIDTH = 60
private let PLOT_HEIGHT = 20

private struct ChartChars {
    let hLine: Character
    let vLine: Character
    let origin: Character
    let yTick: Character
    let xTick: Character
    let bar: Character
    let grid: Character
    let cornerTL: Character
    let cornerTR: Character
    let cornerBL: Character
    let cornerBR: Character
}

private let UNI = ChartChars(
    hLine: "─", vLine: "│", origin: "┼", yTick: "┤", xTick: "┬",
    bar: "█", grid: "·", cornerTL: "╭", cornerTR: "╮", cornerBL: "╰", cornerBR: "╯"
)

private let ASC = ChartChars(
    hLine: "-", vLine: "|", origin: "+", yTick: "+", xTick: "+",
    bar: "#", grid: ".", cornerTL: "+", cornerTR: "+", cornerBL: "+", cornerBR: "+"
)

// MARK: - Per-cell hex color canvas

private typealias XYCanvas = [[Character]]
private typealias XYRoleCanvas = [[CharRole?]]
private typealias HexCanvas = [[String?]]

// MARK: - Series colors

private func _getSeriesColors(_ total: Int, _ theme: AsciiTheme) -> [String] {
    let accent = theme.accent ?? CHART_ACCENT_FALLBACK
    if total <= 1 { return [accent] }
    return (0..<total).map { getSeriesColor($0, accent, theme.bg) }
}

private func _roleToHex(_ role: CharRole, _ theme: AsciiTheme) -> String {
    switch role {
    case .text: return theme.fg
    case .border: return theme.border
    case .line: return theme.line
    case .arrow: return theme.arrow
    case .corner: return theme.corner ?? theme.line
    case .junction: return theme.junction ?? theme.border
    }
}

// MARK: - Public API

public func renderXYChartAscii(
    _ text: String,
    _ config: AsciiConfig,
    _ colorMode: ColorMode,
    _ theme: AsciiTheme
) -> String {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    let chart = parseXYChart(lines)
    let ch = config.useAscii ? ASC : UNI

    if chart.horizontal {
        return _renderHorizontal(chart, ch, colorMode, theme)
    }
    return _renderVertical(chart, ch, colorMode, theme)
}

// MARK: - Vertical chart

private func _renderVertical(
    _ chart: XYChart, _ ch: ChartChars,
    _ colorMode: ColorMode, _ theme: AsciiTheme
) -> String {
    let dataCount = _getDataCount(chart)
    if dataCount == 0 { return "" }

    guard let yRange = chart.yAxis.range else { return "" }
    let yTicks = _niceTickValues(yRange.min, yRange.max)
    let yLabels = yTicks.map { _formatTickValue($0) }
    let yGutter = (yLabels.map(\.count).max() ?? 0) + 1

    let plotW = max(PLOT_WIDTH, dataCount * 6)
    let plotH = PLOT_HEIGHT
    let bandW = plotW / dataCount
    let catLabels = _getCategoryLabels(chart, dataCount)

    let hasTitle = chart.title != nil
    let hasXTitle = chart.xAxis.title != nil
    let hasLegend = chart.series.count > 1
    let plotTop = (hasTitle ? 2 : 0) + (hasLegend ? 1 : 0)
    let plotLeft = yGutter + 1
    let totalW = plotLeft + bandW * dataCount + 2
    let xAxisRow = plotTop + plotH
    let xLabelRow = xAxisRow + 1
    let xTitleRow = hasXTitle ? xLabelRow + 1 : -1
    let totalH = xLabelRow + 1 + (hasXTitle ? 1 : 0)

    var canvas = _createCanvas(totalW, totalH)
    var roles = _createRoleCanvas(totalW, totalH)
    var hexColors = _createHexCanvas(totalW, totalH)

    let seriesColors = _getSeriesColors(chart.series.count, theme)

    let valueToRow: (Double) -> Int = { v in
        let t = (v - yRange.min) / (yRange.max - yRange.min == 0 ? 1 : yRange.max - yRange.min)
        let scaled = t * Double(plotH - 1)
        guard scaled.isFinite, abs(scaled) < 1e15 else { return 0 }
        return Int(round(scaled))
    }
    let bandCenter: (Int) -> Int = { i in plotLeft + (bandW * (2 * i + 1)) / (2) }

    // 1. Title
    if let title = chart.title {
        _writeText(&canvas, &roles, 0, max(0, totalW / 2 - title.count / 2), title, .text)
    }

    // 2. Legend
    if hasLegend {
        let legendRow = hasTitle ? 1 : 0
        _drawLegend(&canvas, &roles, &hexColors, chart, legendRow, totalW, ch, seriesColors)
    }

    // 3. Y-axis
    for row in 0..<plotH {
        let displayRow = plotTop + (plotH - 1 - row)
        _set(&canvas, &roles, displayRow, plotLeft - 1, ch.vLine, .border)
    }
    _set(&canvas, &roles, xAxisRow, plotLeft - 1, ch.origin, .border)

    for tick in yTicks {
        let row = valueToRow(tick)
        if row < 0 || row >= plotH { continue }
        let displayRow = plotTop + (plotH - 1 - row)
        let label = _formatTickValue(tick)
        _set(&canvas, &roles, displayRow, plotLeft - 1, row == 0 ? ch.origin : ch.yTick, .border)
        let labelStart = yGutter - label.count
        _writeText(&canvas, &roles, displayRow, max(0, labelStart), label, .text)
    }

    // 4. X-axis
    for c in plotLeft..<(plotLeft + bandW * dataCount) {
        _set(&canvas, &roles, xAxisRow, c, ch.hLine, .border)
    }
    for i in 0..<dataCount {
        let cx = bandCenter(i)
        _set(&canvas, &roles, xAxisRow, cx, ch.xTick, .border)
        let label = catLabels[i]
        let labelStart = cx - label.count / 2
        _writeText(&canvas, &roles, xLabelRow, max(0, labelStart), label, .text)
    }

    // 5. X-axis title
    if let title = chart.xAxis.title, xTitleRow >= 0 {
        _writeText(&canvas, &roles, xTitleRow, max(0, totalW / 2 - title.count / 2), title, .text)
    }

    // 6. Grid lines
    for tick in yTicks {
        let row = valueToRow(tick)
        if row < 0 || row >= plotH { continue }
        let displayRow = plotTop + (plotH - 1 - row)
        for c in plotLeft..<(plotLeft + bandW * dataCount) {
            if _get(canvas, displayRow, c) == " " {
                _set(&canvas, &roles, displayRow, c, ch.grid, .line)
            }
        }
    }

    // 7. Bars
    var barEntries: [(data: [Double], globalIdx: Int)] = []
    for si in 0..<chart.series.count {
        if chart.series[si].type == .bar { barEntries.append((chart.series[si].data, si)) }
    }

    if !barEntries.isEmpty {
        let barCount = barEntries.count
        let usable = max(1, bandW - 2)
        let singleBarW = max(1, min(usable / barCount, 8))
        let groupW = singleBarW * barCount + (barCount - 1)
        let baseRow = valueToRow(max(0, yRange.min))

        for bIdx in 0..<barEntries.count {
            let entry = barEntries[bIdx]
            let hexColor = seriesColors[entry.globalIdx]
            for i in 0..<entry.data.count {
                let cx = bandCenter(i)
                let groupLeft = cx - groupW / 2
                let bx = groupLeft + bIdx * (singleBarW + 1)
                let valRow = valueToRow(entry.data[i])
                let fromRow = min(baseRow, valRow)
                let toRow = max(baseRow, valRow)

                for row in fromRow...toRow {
                    let displayRow = plotTop + (plotH - 1 - row)
                    for c in bx..<(bx + singleBarW) {
                        _set(&canvas, &roles, displayRow, c, ch.bar, .arrow, &hexColors, hexColor)
                    }
                }
            }
        }
    }

    // 8. Lines
    var lineEntries: [(data: [Double], globalIdx: Int)] = []
    for si in 0..<chart.series.count {
        if chart.series[si].type == .line { lineEntries.append((chart.series[si].data, si)) }
    }

    for entry in lineEntries {
        if entry.data.isEmpty { continue }
        let hexColor = seriesColors[entry.globalIdx]
        _drawStaircaseLine(&canvas, &roles, entry.data, bandCenter, valueToRow, plotTop, plotH, plotLeft, bandW * dataCount, ch, &hexColors, hexColor)
    }

    return _canvasToString(canvas, roles, hexColors, colorMode, theme)
}

// MARK: - Horizontal chart

private func _renderHorizontal(
    _ chart: XYChart, _ ch: ChartChars,
    _ colorMode: ColorMode, _ theme: AsciiTheme
) -> String {
    let dataCount = _getDataCount(chart)
    if dataCount == 0 { return "" }

    guard let yRange = chart.yAxis.range else { return "" }
    let valueTicks = _niceTickValues(yRange.min, yRange.max)
    let catLabels = _getCategoryLabels(chart, dataCount)
    let catGutter = (catLabels.map(\.count).max() ?? 0) + 1

    let plotW = max(PLOT_WIDTH, 40)
    let bandH = max(2, PLOT_HEIGHT / dataCount)
    let plotH = bandH * dataCount

    let hasTitle = chart.title != nil
    let hasYTitle = chart.yAxis.title != nil
    let hasLegend = chart.series.count > 1
    let plotTop = (hasTitle ? 2 : 0) + (hasLegend ? 1 : 0)
    let plotLeft = catGutter + 1
    let totalW = plotLeft + plotW + 2
    let totalH = plotTop + plotH + 2 + (hasYTitle ? 1 : 0)
    let xAxisRow = plotTop + plotH

    var canvas = _createCanvas(totalW, totalH)
    var roles = _createRoleCanvas(totalW, totalH)
    var hexColors = _createHexCanvas(totalW, totalH)

    let seriesColors = _getSeriesColors(chart.series.count, theme)

    let valueToCol: (Double) -> Int = { v in
        let t = (v - yRange.min) / (yRange.max - yRange.min == 0 ? 1 : yRange.max - yRange.min)
        let scaled = t * Double(plotW - 1)
        guard scaled.isFinite, abs(scaled) < 1e15 else { return plotLeft }
        return plotLeft + Int(round(scaled))
    }
    let bandMid: (Int) -> Int = { i in plotTop + (bandH * (2 * i + 1)) / 2 }

    // Title
    if let title = chart.title {
        _writeText(&canvas, &roles, 0, max(0, totalW / 2 - title.count / 2), title, .text)
    }

    // Legend
    if hasLegend {
        let legendRow = hasTitle ? 1 : 0
        _drawLegend(&canvas, &roles, &hexColors, chart, legendRow, totalW, ch, seriesColors)
    }

    // Y-axis (category labels on left)
    for r in plotTop..<(plotTop + plotH) {
        _set(&canvas, &roles, r, plotLeft - 1, ch.vLine, .border)
    }
    _set(&canvas, &roles, xAxisRow, plotLeft - 1, ch.origin, .border)

    for i in 0..<dataCount {
        let my = bandMid(i)
        let label = catLabels[i]
        let labelStart = catGutter - label.count
        _writeText(&canvas, &roles, my, max(0, labelStart), label, .text)
    }

    // X-axis (value on bottom)
    for c in plotLeft..<(plotLeft + plotW) {
        _set(&canvas, &roles, xAxisRow, c, ch.hLine, .border)
    }
    for tick in valueTicks {
        let cx = valueToCol(tick)
        if cx < plotLeft || cx >= plotLeft + plotW { continue }
        _set(&canvas, &roles, xAxisRow, cx, ch.xTick, .border)
        let label = _formatTickValue(tick)
        _writeText(&canvas, &roles, xAxisRow + 1, cx - label.count / 2, label, .text)
    }

    // Y-axis title
    if let title = chart.yAxis.title {
        _writeText(&canvas, &roles, totalH - 1, max(0, totalW / 2 - title.count / 2), title, .text)
    }

    // Grid lines
    for tick in valueTicks {
        let cx = valueToCol(tick)
        if cx < plotLeft || cx >= plotLeft + plotW { continue }
        for r in plotTop..<(plotTop + plotH) {
            if _get(canvas, r, cx) == " " {
                _set(&canvas, &roles, r, cx, ch.grid, .line)
            }
        }
    }

    // Bars (horizontal)
    var barEntries: [(data: [Double], globalIdx: Int)] = []
    for si in 0..<chart.series.count {
        if chart.series[si].type == .bar { barEntries.append((chart.series[si].data, si)) }
    }

    if !barEntries.isEmpty {
        let barCount = barEntries.count
        let singleBarH = 1
        let groupH = singleBarH * barCount + (barCount - 1)
        let baseCol = valueToCol(max(0, yRange.min))

        for bIdx in 0..<barEntries.count {
            let entry = barEntries[bIdx]
            let hexColor = seriesColors[entry.globalIdx]
            for i in 0..<entry.data.count {
                let my = bandMid(i)
                let groupTop = my - groupH / 2
                let by = groupTop + bIdx * (singleBarH + 1)
                let valCol = valueToCol(entry.data[i])
                let fromCol = min(baseCol, valCol)
                let toCol = max(baseCol, valCol)

                for r in by..<(by + singleBarH) {
                    for c in fromCol...toCol {
                        _set(&canvas, &roles, r, c, ch.bar, .arrow, &hexColors, hexColor)
                    }
                }
            }
        }
    }

    // Lines (horizontal staircase)
    var lineEntries: [(data: [Double], globalIdx: Int)] = []
    for si in 0..<chart.series.count {
        if chart.series[si].type == .line { lineEntries.append((chart.series[si].data, si)) }
    }

    for entry in lineEntries {
        if entry.data.isEmpty { continue }
        let hexColor = seriesColors[entry.globalIdx]
        _drawHorizontalStaircaseLine(&canvas, &roles, entry.data, bandMid, valueToCol, plotTop, plotH, plotLeft, plotW, ch, &hexColors, hexColor)
    }

    return _canvasToString(canvas, roles, hexColors, colorMode, theme)
}

// MARK: - Staircase line drawing (vertical)

private func _drawStaircaseLine(
    _ canvas: inout XYCanvas, _ roles: inout XYRoleCanvas,
    _ data: [Double],
    _ bandCenter: (Int) -> Int, _ valueToRow: (Double) -> Int,
    _ plotTop: Int, _ plotH: Int, _ plotLeft: Int, _ plotTotalW: Int,
    _ ch: ChartChars,
    _ hexCanvas: inout HexCanvas, _ hexColor: String
) {
    if data.isEmpty { return }

    let points = data.enumerated().map { i, v in (col: bandCenter(i), row: valueToRow(v)) }

    func drawAt(_ col: Int, _ row: Int, _ char: Character) {
        let displayRow = plotTop + (plotH - 1 - row)
        if displayRow >= 0 && col >= plotLeft && col < plotLeft + plotTotalW {
            _set(&canvas, &roles, displayRow, col, char, .arrow, &hexCanvas, hexColor)
        }
    }

    if points.count == 1 {
        drawAt(points[0].col, points[0].row, ch.hLine)
        return
    }

    for i in 0..<(points.count - 1) {
        let p1 = points[i]
        let p2 = points[i + 1]

        if p1.row == p2.row {
            for c in p1.col...p2.col { drawAt(c, p1.row, ch.hLine) }
            continue
        }

        let midCol = (p1.col + p2.col + 1) / 2
        let goingUp = p2.row > p1.row

        for c in p1.col..<midCol { drawAt(c, p1.row, ch.hLine) }

        drawAt(midCol, p1.row, goingUp ? ch.cornerBR : ch.cornerTR)

        let minRow = min(p1.row, p2.row)
        let maxRow = max(p1.row, p2.row)
        for row in (minRow + 1)..<maxRow { drawAt(midCol, row, ch.vLine) }

        drawAt(midCol, p2.row, goingUp ? ch.cornerTL : ch.cornerBL)

        for c in (midCol + 1)...p2.col { drawAt(c, p2.row, ch.hLine) }

        if i == 0 {
            let leadStart = max(plotLeft, p1.col - (p2.col - p1.col) / 4)
            for c in leadStart..<p1.col { drawAt(c, p1.row, ch.hLine) }
        }

        if i == points.count - 2 {
            let trailEnd = min(plotLeft + plotTotalW - 1, p2.col + (p2.col - p1.col) / 4)
            for c in (p2.col + 1)...trailEnd { drawAt(c, p2.row, ch.hLine) }
        }
    }
}

// MARK: - Staircase line drawing (horizontal)

private func _drawHorizontalStaircaseLine(
    _ canvas: inout XYCanvas, _ roles: inout XYRoleCanvas,
    _ data: [Double],
    _ bandMid: (Int) -> Int, _ valueToCol: (Double) -> Int,
    _ plotTop: Int, _ plotH: Int, _ plotLeft: Int, _ plotW: Int,
    _ ch: ChartChars,
    _ hexCanvas: inout HexCanvas, _ hexColor: String
) {
    if data.isEmpty { return }

    let points = data.enumerated().map { i, v in (row: bandMid(i), col: valueToCol(v)) }

    func drawAt(_ row: Int, _ col: Int, _ char: Character) {
        if row >= plotTop && row < plotTop + plotH && col >= plotLeft && col < plotLeft + plotW {
            _set(&canvas, &roles, row, col, char, .arrow, &hexCanvas, hexColor)
        }
    }

    if points.count == 1 {
        drawAt(points[0].row, points[0].col, ch.vLine)
        return
    }

    for i in 0..<(points.count - 1) {
        let p1 = points[i]
        let p2 = points[i + 1]

        if p1.col == p2.col {
            for r in p1.row...p2.row { drawAt(r, p1.col, ch.vLine) }
            continue
        }

        let midRow = (p1.row + p2.row + 1) / 2
        let goingRight = p2.col > p1.col

        for r in p1.row..<midRow { drawAt(r, p1.col, ch.vLine) }

        drawAt(midRow, p1.col, goingRight ? ch.cornerBL : ch.cornerBR)

        let minCol = min(p1.col, p2.col)
        let maxCol = max(p1.col, p2.col)
        for c in (minCol + 1)..<maxCol { drawAt(midRow, c, ch.hLine) }

        drawAt(midRow, p2.col, goingRight ? ch.cornerTR : ch.cornerTL)

        for r in (midRow + 1)...p2.row { drawAt(r, p2.col, ch.vLine) }
    }
}

// MARK: - Legend

private func _drawLegend(
    _ canvas: inout XYCanvas, _ roles: inout XYRoleCanvas, _ hexCanvas: inout HexCanvas,
    _ chart: XYChart, _ row: Int, _ totalW: Int, _ ch: ChartChars, _ seriesColors: [String]
) {
    struct LItem {
        let symbol: Character
        let label: String
        let globalIdx: Int
    }

    var items: [LItem] = []
    var barIdx = 0, lineIdx = 0
    for si in 0..<chart.series.count {
        let s = chart.series[si]
        if s.type == .bar {
            items.append(LItem(symbol: ch.bar, label: "Bar \(barIdx + 1)", globalIdx: si))
            barIdx += 1
        } else {
            items.append(LItem(symbol: ch.hLine, label: "Line \(lineIdx + 1)", globalIdx: si))
            lineIdx += 1
        }
    }

    var totalLen = 0
    for i in 0..<items.count {
        if i > 0 { totalLen += 2 }
        totalLen += 1 + 1 + items[i].label.count
    }

    let startCol = max(0, totalW / 2 - totalLen / 2)
    var col = startCol

    for i in 0..<items.count {
        if i > 0 { col += 2 }
        let item = items[i]
        _set(&canvas, &roles, row, col, item.symbol, .arrow, &hexCanvas, seriesColors[item.globalIdx])
        col += 1
        col += 1
        _writeText(&canvas, &roles, row, col, item.label, .text)
        col += item.label.count
    }
}

// MARK: - Canvas utilities

private func _createCanvas(_ width: Int, _ height: Int) -> XYCanvas {
    Array(repeating: Array(repeating: Character(" "), count: height), count: width)
}

private func _createRoleCanvas(_ width: Int, _ height: Int) -> XYRoleCanvas {
    Array(repeating: Array(repeating: nil as CharRole?, count: height), count: width)
}

private func _createHexCanvas(_ width: Int, _ height: Int) -> HexCanvas {
    Array(repeating: Array(repeating: nil as String?, count: height), count: width)
}

private func _set(
    _ canvas: inout XYCanvas, _ roles: inout XYRoleCanvas,
    _ row: Int, _ col: Int, _ char: Character, _ role: CharRole,
    _ hexCanvas: inout HexCanvas, _ hex: String?
) {
    guard col >= 0 && col < canvas.count && row >= 0 && row < canvas[0].count else { return }
    canvas[col][row] = char
    roles[col][row] = role
    if let hex { hexCanvas[col][row] = hex }
}

private func _set(
    _ canvas: inout XYCanvas, _ roles: inout XYRoleCanvas,
    _ row: Int, _ col: Int, _ char: Character, _ role: CharRole
) {
    guard col >= 0 && col < canvas.count && row >= 0 && row < canvas[0].count else { return }
    canvas[col][row] = char
    roles[col][row] = role
}

private func _get(_ canvas: XYCanvas, _ row: Int, _ col: Int) -> Character {
    guard col >= 0 && col < canvas.count && row >= 0 && row < canvas[0].count else { return " " }
    return canvas[col][row]
}

private func _writeText(_ canvas: inout XYCanvas, _ roles: inout XYRoleCanvas, _ row: Int, _ startCol: Int, _ text: String, _ role: CharRole) {
    for (i, char) in text.enumerated() {
        _set(&canvas, &roles, row, startCol + i, char, role)
    }
}

// MARK: - Canvas → string

private func _canvasToString(
    _ canvas: XYCanvas, _ roles: XYRoleCanvas, _ hexCanvas: HexCanvas,
    _ colorMode: ColorMode, _ theme: AsciiTheme
) -> String {
    if canvas.isEmpty { return "" }
    let height = canvas[0].count
    let width = canvas.count
    var lines: [String] = []

    for row in 0..<height {
        var chars: [Character] = []
        var rowRoles: [CharRole?] = []
        var rowHex: [String?] = []
        for col in 0..<width {
            chars.append(canvas[col][row])
            rowRoles.append(roles[col][row])
            rowHex.append(hexCanvas[col][row])
        }
        // Trim trailing spaces
        var end = chars.count - 1
        while end >= 0 && chars[end] == " " { end -= 1 }
        if end < 0 {
            lines.append("")
        } else {
            lines.append(_colorizeRow(
                Array(chars[0...end]),
                Array(rowRoles[0...end]),
                Array(rowHex[0...end]),
                theme, colorMode
            ))
        }
    }

    // Trim trailing empty lines
    while !lines.isEmpty && lines.last == "" { lines.removeLast() }

    return lines.joined(separator: "\n")
}

private func _colorizeRow(
    _ chars: [Character], _ roles: [CharRole?], _ hexOverrides: [String?],
    _ theme: AsciiTheme, _ mode: ColorMode
) -> String {
    if mode == .none { return String(chars) }

    var result = ""
    var currentColor: String? = nil
    var buffer = ""

    for i in 0..<chars.count {
        let char = chars[i]

        if char == " " {
            if !buffer.isEmpty {
                result += currentColor != nil ? colorizeText(buffer, currentColor!, mode) : buffer
                buffer = ""
                currentColor = nil
            }
            result += " "
            continue
        }

        let hexOvr = hexOverrides[i]
        let roleVal = roles[i]
        let color = hexOvr ?? (roleVal.map { _roleToHex($0, theme) })

        if color == currentColor {
            buffer.append(char)
        } else {
            if !buffer.isEmpty {
                result += currentColor != nil ? colorizeText(buffer, currentColor!, mode) : buffer
            }
            buffer = String(char)
            currentColor = color
        }
    }

    if !buffer.isEmpty {
        result += currentColor != nil ? colorizeText(buffer, currentColor!, mode) : buffer
    }

    return result
}
