import Foundation
import ElkSwift

internal enum _ElkBridge {
    // Keeps explicit linkage to ElkSwift runtime.
    static var version: String { ElkSwift.version }
}

public enum MermaidParser {
    private static func _diagramLines(from source: String) -> [String] {
        source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }

    private static func _decodeXMLEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
         .replacingOccurrences(of: "&lt;", with: "<")
         .replacingOccurrences(of: "&gt;", with: ">")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&#39;", with: "'")
    }

    public static func parse(_ source: String) throws -> MermaidGraph {
        _ = _ElkBridge.version
        let decoded = _decodeXMLEntities(source)
        let lines = _diagramLines(from: decoded)
        let firstLine = lines.first?.lowercased() ?? ""

        if firstLine.hasPrefix("sequencediagram") {
            let parsed = try parseSequenceDiagram(lines)
            return MermaidGraph(type: .sequenceDiagram, payload: parsed)
        }
        if firstLine.hasPrefix("classdiagram") {
            let parsed = try parseClassDiagram(lines)
            return MermaidGraph(type: .classDiagram, payload: parsed)
        }
        if firstLine.hasPrefix("erdiagram") {
            let parsed = try parseErDiagram(lines)
            return MermaidGraph(type: .erDiagram, payload: parsed)
        }
        if firstLine.hasPrefix("xychart") {
            let chart = parseXYChart(lines)
            return MermaidGraph(type: .xyChart, payload: chart)
        }

        // Flowchart + stateDiagram-v2 share the same parser entry in the original TS.
        let parsed = try parseMermaid(decoded)
        let parsedType: DiagramType = firstLine.hasPrefix("statediagram") ? .stateDiagram : .flowchart
        return MermaidGraph(type: parsedType, payload: parsed.payload)
    }
}
