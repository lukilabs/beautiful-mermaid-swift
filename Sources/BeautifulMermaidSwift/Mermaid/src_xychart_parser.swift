// Ported from original/src/xychart/parser.ts
import Foundation

public func parseXYChart(_ lines: [String]) -> XYChart {
    var xAxis = XYAxis()
    var yAxis = XYAxis()
    var series: [XYChartSeries] = []
    var title: String?
    var horizontal = false

    for line in lines {
        // Header line — detect horizontal
        if line.range(of: #"^xychart(-beta)?\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            if line.range(of: #"\bhorizontal\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
                horizontal = true
            }
            continue
        }

        // Title
        if let match = line.range(of: #"^title\s+"([^"]+)""#, options: .regularExpression) {
            let titleStr = String(line[match])
            if let qStart = titleStr.firstIndex(of: "\""), let qEnd = titleStr.lastIndex(of: "\""), qStart != qEnd {
                title = String(titleStr[titleStr.index(after: qStart)..<qEnd])
            }
            continue
        }

        // x-axis with categories: x-axis "Title" [a, b, c] or x-axis [a, b, c]
        if let match = try? _matchXAxisCategories(line) {
            if let t = match.title { xAxis.title = t }
            xAxis.categories = match.categories
            continue
        }

        // x-axis with range: x-axis "Title" min --> max or x-axis min --> max
        if let match = try? _matchAxisRange(line, prefix: "x-axis") {
            if let t = match.title { xAxis.title = t }
            xAxis.range = (min: match.min, max: match.max)
            continue
        }

        // y-axis with range
        if let match = try? _matchAxisRange(line, prefix: "y-axis") {
            if let t = match.title { yAxis.title = t }
            yAxis.range = (min: match.min, max: match.max)
            continue
        }

        // y-axis with just title
        if let match = line.range(of: #"^y-axis\s+"([^"]+)"\s*$"#, options: .regularExpression) {
            let sub = String(line[match])
            if let qStart = sub.firstIndex(of: "\""), let qEnd = sub.lastIndex(of: "\""), qStart != qEnd {
                yAxis.title = String(sub[sub.index(after: qStart)..<qEnd])
            }
            continue
        }

        // bar [...]
        if let match = line.range(of: #"^bar\s+\[([^\]]+)\]"#, options: .regularExpression) {
            let sub = String(line[match])
            if let bracketStart = sub.firstIndex(of: "["), let bracketEnd = sub.firstIndex(of: "]") {
                let nums = _parseNumericArray(String(sub[sub.index(after: bracketStart)..<bracketEnd]))
                series.append(XYChartSeries(type: .bar, data: nums))
            }
            continue
        }

        // line [...]
        if let match = line.range(of: #"^line\s+\[([^\]]+)\]"#, options: .regularExpression) {
            let sub = String(line[match])
            if let bracketStart = sub.firstIndex(of: "["), let bracketEnd = sub.firstIndex(of: "]") {
                let nums = _parseNumericArray(String(sub[sub.index(after: bracketStart)..<bracketEnd]))
                series.append(XYChartSeries(type: .line, data: nums))
            }
            continue
        }
    }

    // Auto-derive y-axis range from data if not specified
    if yAxis.range == nil && !series.isEmpty {
        let allValues = series.flatMap { $0.data }
        var minVal = allValues.min() ?? 0
        var maxVal = allValues.max() ?? 0
        let span = maxVal - minVal == 0 ? 1 : maxVal - minVal
        minVal -= span * 0.1
        maxVal += span * 0.1
        if minVal > 0 && minVal < span * 0.5 { minVal = 0 }
        yAxis.range = (min: minVal, max: maxVal)
    }

    // Fallback y-axis range
    if yAxis.range == nil {
        yAxis.range = (min: 0, max: 100)
    }

    return XYChart(title: title, horizontal: horizontal, xAxis: xAxis, yAxis: yAxis, series: series)
}

// MARK: - Private helpers

private func _parseNumericArray(_ str: String) -> [Double] {
    str.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
}

private struct _XAxisCatResult {
    var title: String?
    var categories: [String]
}

private func _matchXAxisCategories(_ line: String) throws -> _XAxisCatResult? {
    // x-axis "Title" [a, b, c] or x-axis [a, b, c]
    guard line.hasPrefix("x-axis") else { return nil }
    guard let bracketStart = line.firstIndex(of: "["), let bracketEnd = line.firstIndex(of: "]") else { return nil }

    let beforeBracket = String(line[line.index(line.startIndex, offsetBy: 6)..<bracketStart]).trimmingCharacters(in: .whitespaces)
    var title: String?
    if let qStart = beforeBracket.firstIndex(of: "\""), let qEnd = beforeBracket.lastIndex(of: "\""), qStart != qEnd {
        title = String(beforeBracket[beforeBracket.index(after: qStart)..<qEnd])
    }

    let catStr = String(line[line.index(after: bracketStart)..<bracketEnd])
    let categories = catStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

    return _XAxisCatResult(title: title, categories: categories)
}

private struct _AxisRangeResult {
    var title: String?
    var min: Double
    var max: Double
}

private func _matchAxisRange(_ line: String, prefix: String) throws -> _AxisRangeResult? {
    guard line.hasPrefix(prefix) else { return nil }
    guard line.contains("-->") else { return nil }

    let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)

    var title: String?
    var numPart = afterPrefix

    if let qStart = afterPrefix.firstIndex(of: "\""), let qEnd = afterPrefix.lastIndex(of: "\""), qStart != qEnd {
        title = String(afterPrefix[afterPrefix.index(after: qStart)..<qEnd])
        numPart = String(afterPrefix[afterPrefix.index(after: qEnd)...]).trimmingCharacters(in: .whitespaces)
    }

    let parts = numPart.components(separatedBy: "-->")
    guard parts.count == 2,
          let minVal = Double(parts[0].trimmingCharacters(in: .whitespaces)),
          let maxVal = Double(parts[1].trimmingCharacters(in: .whitespaces))
    else { return nil }

    return _AxisRangeResult(title: title, min: minVal, max: maxVal)
}
