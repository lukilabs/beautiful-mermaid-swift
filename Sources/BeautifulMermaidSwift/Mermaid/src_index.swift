// Ported from original/src/index.ts
import Foundation
import ElkSwift

public struct RenderOptions: Sendable {
    public var bg: String?
    public var fg: String?
    public var line: String?
    public var accent: String?
    public var muted: String?
    public var surface: String?
    public var border: String?
    public var font: String?
    public var transparent: Bool?
    public var interactive: Bool?

    public init(
        bg: String? = nil,
        fg: String? = nil,
        line: String? = nil,
        accent: String? = nil,
        muted: String? = nil,
        surface: String? = nil,
        border: String? = nil,
        font: String? = nil,
        transparent: Bool? = nil,
        interactive: Bool? = nil
    ) {
        self.bg = bg
        self.fg = fg
        self.line = line
        self.accent = accent
        self.muted = muted
        self.surface = surface
        self.border = border
        self.font = font
        self.transparent = transparent
        self.interactive = interactive
    }
}

public struct DiagramColors: Sendable {
    public var bg: String
    public var fg: String
    public var line: String?
    public var accent: String?
    public var muted: String?
    public var surface: String?
    public var border: String?

    public init(
        bg: String,
        fg: String,
        line: String? = nil,
        accent: String? = nil,
        muted: String? = nil,
        surface: String? = nil,
        border: String? = nil
    ) {
        self.bg = bg
        self.fg = fg
        self.line = line
        self.accent = accent
        self.muted = muted
        self.surface = surface
        self.border = border
    }
}

private enum _IndexDefaults {
    static let bg = "#FFFFFF"
    static let fg = "#27272A"
}

private enum _DiagramRoutingType {
    case flowchart
    case sequence
    case `class`
    case er
    case xychart
}

private func _decodeXML(_ text: String) -> String {
    // Aligns with TS decodeXML intent for markdown-escaped Mermaid source.
    text
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
}

private func detectDiagramType(_ text: String) -> _DiagramRoutingType {
    let firstLine = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .components(separatedBy: CharacterSet(charactersIn: "\n;"))
        .first?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() ?? ""

    if firstLine.range(of: "^sequencediagram\\s*$", options: .regularExpression) != nil {
        return .sequence
    }
    if firstLine.range(of: "^classdiagram\\s*$", options: .regularExpression) != nil {
        return .class
    }
    if firstLine.range(of: "^erdiagram\\s*$", options: .regularExpression) != nil {
        return .er
    }
    if firstLine.hasPrefix("xychart") {
        return .xychart
    }

    return .flowchart
}

private func buildColors(_ options: RenderOptions) -> DiagramColors {
    DiagramColors(
        bg: options.bg ?? _IndexDefaults.bg,
        fg: options.fg ?? _IndexDefaults.fg,
        line: options.line,
        accent: options.accent,
        muted: options.muted,
        surface: options.surface,
        border: options.border
    )
}

public func renderMermaidSVG(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) throws -> String {
    _ = ElkSwift.version

    let decodedText = _decodeXML(text)
    let colors = buildColors(options)
    let font = options.font ?? "Inter"
    let transparent = options.transparent ?? false
    let diagramType = detectDiagramType(decodedText)

    let lines = decodedText
        .components(separatedBy: CharacterSet(charactersIn: "\n;"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }

    switch diagramType {
    case .sequence:
        let diagram = try parseSequenceDiagram(lines)
        let positioned = try layoutSequenceDiagram(diagram, options)
        return try renderSequenceSvg(positioned, colors, font, transparent)
    case .class:
        let diagram = try parseClassDiagram(lines)
        let positioned = try layoutClassDiagramSync(diagram, options: options)
        return try renderClassSvg(positioned, colors, font, transparent)
    case .er:
        let diagram = try parseErDiagram(lines)
        let positioned = try layoutErDiagramSync(diagram, options: options)
        return try renderErSvg(positioned, colors, font, transparent)
    case .xychart:
        let chart = parseXYChart(lines)
        let positioned = layoutXYChart(chart, options)
        return renderXYChartSvg(positioned, colors, font, transparent, interactive: options.interactive ?? false)
    case .flowchart:
        let graph = try parseMermaid(decodedText)
        let positioned = try layoutGraphSync(graph, options)
        return try renderSvg(positioned, colors, font, transparent)
    }
}

public func renderMermaidSVGAsync(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try renderMermaidSVG(text, options)
}

@available(*, deprecated, message: "Use renderMermaidSVG")
public func renderMermaidSync(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) throws -> String {
    try renderMermaidSVG(text, options)
}

@available(*, deprecated, message: "Use renderMermaidSVGAsync")
public func renderMermaid(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await renderMermaidSVGAsync(text, options)
}

open class original_src_index {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version
}
