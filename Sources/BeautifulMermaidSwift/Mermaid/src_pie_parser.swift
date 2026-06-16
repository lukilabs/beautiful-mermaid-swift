// Parser for Mermaid pie diagrams.
import Foundation

func _isPieChartHeader(_ line: String) -> Bool {
    line.range(of: #"^pie(?:chart)?(?:\s|$)"#, options: [.regularExpression, .caseInsensitive]) != nil
}

public func parsePieChart(_ lines: [String]) -> PieChart {
    var title: String?
    var showData = false
    var slices: [PieChartSlice] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }

        if _isPieChartHeader(trimmed) {
            var rest = _stripChartHeaderKeyword(trimmed)
            if let payload = _chartPayload(rest, after: "showData") {
                showData = true
                rest = payload
            }
            if let payload = _chartPayload(rest, after: "title"), !payload.isEmpty {
                title = _parseChartText(payload)
            }
            continue
        }

        if trimmed.range(of: #"^showData$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            showData = true
            continue
        }

        if let payload = _chartPayload(trimmed, after: "title"), !payload.isEmpty {
            title = _parseChartText(payload)
            continue
        }

        if let slice = _parsePieSlice(trimmed) {
            slices.append(slice)
        }
    }

    return PieChart(title: title, showData: showData, slices: slices)
}

private func _stripChartHeaderKeyword(_ line: String) -> String {
    guard let firstSpace = line.firstIndex(where: { $0.isWhitespace }) else {
        return ""
    }
    return String(line[firstSpace...]).trimmingCharacters(in: .whitespacesAndNewlines)
}

private func _chartPayload(_ line: String, after keyword: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    let key = keyword.lowercased()
    if lower == key {
        return ""
    }
    guard lower.hasPrefix(key + " ") || lower.hasPrefix(key + "\t") else {
        return nil
    }
    return String(trimmed.dropFirst(keyword.count)).trimmingCharacters(in: .whitespacesAndNewlines)
}

private func _parseChartText(_ raw: String) -> String {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
        text.removeFirst()
        text.removeLast()
    }
    return text
}

private func _parseChartNumber(_ raw: String) -> Double? {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let value = Double(text), value.isFinite else {
        return nil
    }
    return value
}

private func _parsePieSlice(_ line: String) -> PieChartSlice? {
    let quotedPattern = #"^"([^"]+)"\s*:\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*$"#
    if let match = _firstPieMatch(line, quotedPattern),
       match.count == 3,
       let value = _parseChartNumber(match[2]),
       value > 0 {
        return PieChartSlice(label: match[1], value: value)
    }

    let barePattern = #"^([^:]+)\s*:\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*$"#
    if let match = _firstPieMatch(line, barePattern),
       match.count == 3,
       let value = _parseChartNumber(match[2]),
       value > 0 {
        let label = _parseChartText(match[1])
        if !label.isEmpty {
            return PieChartSlice(label: label, value: value)
        }
    }

    return nil
}

private func _firstPieMatch(_ text: String, _ pattern: String) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return nil
    }
    let ns = text as NSString
    let range = NSRange(location: 0, length: ns.length)
    guard let match = regex.firstMatch(in: text, range: range) else {
        return nil
    }

    return (0..<match.numberOfRanges).map { idx in
        let r = match.range(at: idx)
        return r.location == NSNotFound ? "" : ns.substring(with: r)
    }
}
