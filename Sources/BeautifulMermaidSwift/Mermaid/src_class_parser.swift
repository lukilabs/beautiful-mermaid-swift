// Ported from original/src/class/parser.ts
import Foundation
import ElkSwift

public struct ClassDiagram: Sendable {
    public var classes: [ClassNode]
    public var relationships: [ClassRelationship]
    public var namespaces: [ClassNamespace]
}

public struct ClassNode: Sendable {
    public var id: String
    public var label: String
    public var attributes: [ClassMember]
    public var methods: [ClassMember]
    public var annotation: String?
}

public struct ClassMember: Sendable {
    public var visibility: String
    public var name: String
    public var type: String?
    public var isStatic: Bool
    public var isAbstract: Bool
    public var isMethod: Bool
    public var params: String?
}

public typealias RelationshipType = String

public struct ClassRelationship: Sendable {
    public var from: String
    public var to: String
    public var type: RelationshipType
    public var markerAt: String
    public var label: String?
    public var fromCardinality: String?
    public var toCardinality: String?
}

public struct ClassNamespace: Sendable {
    public var name: String
    public var classIds: [String]
}

public struct PositionedClassDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var classes: [PositionedClassNode]
    public var relationships: [PositionedClassRelationship]
}

public struct PositionedClassNode: Sendable {
    public var id: String
    public var label: String
    public var annotation: String?
    public var attributes: [ClassMember]
    public var methods: [ClassMember]
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var headerHeight: Double
    public var attrHeight: Double
    public var methodHeight: Double
}

public struct PositionedClassRelationship: Sendable {
    public var from: String
    public var to: String
    public var type: RelationshipType
    public var markerAt: String
    public var label: String?
    public var fromCardinality: String?
    public var toCardinality: String?
    public var points: [ClassPoint]
    public var labelPosition: ClassPoint?
}

public struct ClassPoint: Sendable {
    public var x: Double
    public var y: Double
}

public enum ClassParserError: Error, LocalizedError {
    case invalidHeader(expected: String, found: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHeader(expected, found):
            return "Invalid class diagram header. Expected '\(expected)', found '\(found)'."
        }
    }
}

private struct _ParsedMember {
    var member: ClassMember
    var isMethod: Bool
}

public func parseClassDiagram(_ lines: [String]) throws -> ClassDiagram {
    try _parseClassDiagramEntry(lines)
}

private func _parseClassDiagramEntry(_ lines: [String]) throws -> ClassDiagram {
    guard let header = lines.first else {
        return ClassDiagram(classes: [], relationships: [], namespaces: [])
    }
    if header.range(of: #"^classdiagram\s*$"#, options: [.regularExpression, .caseInsensitive]) == nil {
        throw ClassParserError.invalidHeader(expected: "classDiagram", found: header)
    }

    var diagram = ClassDiagram(classes: [], relationships: [], namespaces: [])
    var classMap: [String: ClassNode] = [:]
    var classOrder: [String] = []
    var currentNamespace: ClassNamespace?
    var currentClassId: String?
    var braceDepth = 0

    if lines.count <= 1 {
        return diagram
    }

    for line in lines.dropFirst() {
        let rawLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawLine.isEmpty {
            continue
        }

        if let activeClassId = currentClassId, braceDepth > 0 {
            if rawLine == "}" {
                braceDepth -= 1
                if braceDepth == 0 {
                    currentClassId = nil
                }
                continue
            }

            if let annot = _firstGroup(#"^<<(\w+)>>$"#, rawLine) {
                var cls = _ensureClass(&classMap, &classOrder, activeClassId)
                cls.annotation = annot
                classMap[activeClassId] = cls
                continue
            }

            if let parsed = _parseMember(rawLine) {
                var cls = _ensureClass(&classMap, &classOrder, activeClassId)
                if parsed.isMethod {
                    cls.methods.append(parsed.member)
                } else {
                    cls.attributes.append(parsed.member)
                }
                classMap[activeClassId] = cls
            }
            continue
        }

        if let namespaceName = _firstGroup(#"^namespace\s+(\S+)\s*\{$"#, rawLine) {
            currentNamespace = ClassNamespace(name: namespaceName, classIds: [])
            continue
        }

        if rawLine == "}", let ns = currentNamespace {
            diagram.namespaces.append(ns)
            currentNamespace = nil
            continue
        }

        if let groups = _groups(#"^class\s+(\S+?)(?:\s*~(\w+)~)?\s*\{$"#, rawLine),
           let id = groups[safe: 1] {
            var cls = _ensureClass(&classMap, &classOrder, id)
            if let generic = groups[safe: 2], !generic.isEmpty {
                cls.label = "\(id)<\(generic)>"
            }
            classMap[id] = cls
            currentClassId = id
            braceDepth = 1
            currentNamespace?.classIds.append(id)
            continue
        }

        if let groups = _groups(#"^class\s+(\S+?)(?:\s*~(\w+)~)?\s*$"#, rawLine),
           let id = groups[safe: 1] {
            var cls = _ensureClass(&classMap, &classOrder, id)
            if let generic = groups[safe: 2], !generic.isEmpty {
                cls.label = "\(id)<\(generic)>"
            }
            classMap[id] = cls
            currentNamespace?.classIds.append(id)
            continue
        }

        if let groups = _groups(#"^class\s+(\S+?)\s*\{\s*<<(\w+)>>\s*\}$"#, rawLine),
           let id = groups[safe: 1], let annot = groups[safe: 2] {
            var cls = _ensureClass(&classMap, &classOrder, id)
            cls.annotation = annot
            classMap[id] = cls
            continue
        }

        if let groups = _groups(#"^(\S+?)\s*:\s*(.+)$"#, rawLine),
           let id = groups[safe: 1], let rest = groups[safe: 2] {
            if !_regexTest(#"<\|--|--|\*--|o--|-->|\.\.>|\.\.\|>"#, rest) {
                var cls = _ensureClass(&classMap, &classOrder, id)
                if let parsed = _parseMember(rest) {
                    if parsed.isMethod {
                        cls.methods.append(parsed.member)
                    } else {
                        cls.attributes.append(parsed.member)
                    }
                    classMap[id] = cls
                }
                continue
            }
        }

        if let rel = _parseRelationship(rawLine) {
            _ = _ensureClass(&classMap, &classOrder, rel.from)
            _ = _ensureClass(&classMap, &classOrder, rel.to)
            diagram.relationships.append(rel)
            continue
        }
    }

    diagram.classes = classOrder.compactMap { classMap[$0] }
    return diagram
}

private func _ensureClass(_ map: inout [String: ClassNode], _ order: inout [String], _ id: String) -> ClassNode {
    if let cls = map[id] {
        return cls
    }
    let cls = ClassNode(id: id, label: id, attributes: [], methods: [], annotation: nil)
    map[id] = cls
    order.append(id)
    return cls
}

private func _parseMember(_ line: String) -> _ParsedMember? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #";$"#, with: "", options: .regularExpression)
    if trimmed.isEmpty { return nil }

    var visibility = ""
    var rest = trimmed
    if let first = rest.first, "+-#~".contains(first) {
        visibility = String(first)
        rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if let groups = _groups(#"^(.+?)\(([^)]*)\)(?:\s*(.+))?$"#, rest),
       let nameRaw = groups[safe: 1] {
        let params = groups[safe: 2]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = groups[safe: 3]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isStatic = nameRaw.hasSuffix("$") || rest.contains("$")
        let isAbstract = nameRaw.hasSuffix("*") || rest.contains("*")
        let cleanName = nameRaw.replacingOccurrences(of: #"[$*]$"#, with: "", options: .regularExpression)
        return _ParsedMember(
            member: ClassMember(
                visibility: visibility,
                name: cleanName,
                type: (type?.isEmpty == false ? type : nil),
                isStatic: isStatic,
                isAbstract: isAbstract,
                isMethod: true,
                params: (params?.isEmpty == false ? params : nil)
            ),
            isMethod: true
        )
    }

    let parts = rest.split(separator: " ").map(String.init)
    let name: String
    let type: String?
    if parts.count >= 2 {
        type = parts[0]
        name = parts.dropFirst().joined(separator: " ")
    } else {
        name = parts.first ?? rest
        type = nil
    }

    let isStatic = name.hasSuffix("$")
    let isAbstract = name.hasSuffix("*")
    let cleanName = name.replacingOccurrences(of: #"[$*]$"#, with: "", options: .regularExpression)
    return _ParsedMember(
        member: ClassMember(
            visibility: visibility,
            name: cleanName,
            type: type,
            isStatic: isStatic,
            isAbstract: isAbstract,
            isMethod: false,
            params: nil
        ),
        isMethod: false
    )
}

private func _parseRelationship(_ line: String) -> ClassRelationship? {
    let pattern = #"^(\S+?)\s+(?:"([^"]*?)"\s+)?(<\|--|<\|\.\.|\*--|o--|-->|--\*|--o|--\|>|\.\.>|\.\.\|>|<--|<\.\.?|--)\s+(?:"([^"]*?)"\s+)?(\S+?)(?:\s*:\s*(.+))?$"#
    guard let groups = _groups(pattern, line),
          let from = groups[safe: 1],
          let arrow = groups[safe: 3],
          let to = groups[safe: 5]
    else { return nil }

    let fromCardinality = groups[safe: 2].flatMap { $0.isEmpty ? nil : original_src_multiline_utils.normalizeBrTags($0) }
    let toCardinality = groups[safe: 4].flatMap { $0.isEmpty ? nil : original_src_multiline_utils.normalizeBrTags($0) }
    let label = groups[safe: 6].flatMap {
        let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : original_src_multiline_utils.normalizeBrTags(value)
    }

    guard let parsed = _parseArrow(arrow.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return nil
    }

    return ClassRelationship(
        from: from,
        to: to,
        type: parsed.type,
        markerAt: parsed.markerAt,
        label: label,
        fromCardinality: fromCardinality,
        toCardinality: toCardinality
    )
}

private func _parseArrow(_ arrow: String) -> (type: RelationshipType, markerAt: String)? {
    switch arrow {
    case "<|--": return ("inheritance", "from")
    case "--|>": return ("inheritance", "to")
    case "<|..": return ("realization", "from")
    case "..|>": return ("realization", "to")
    case "*--": return ("composition", "from")
    case "--*": return ("composition", "to")
    case "o--": return ("aggregation", "from")
    case "--o": return ("aggregation", "to")
    case "-->": return ("association", "to")
    case "<--": return ("association", "from")
    case "..>": return ("dependency", "to")
    case "<..": return ("dependency", "from")
    case "--": return ("association", "to")
    default: return nil
    }
}

private func _regexTest(_ pattern: String, _ value: String, caseInsensitive: Bool = false) -> Bool {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return false }
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return regex.firstMatch(in: value, options: [], range: range) != nil
}

private func _firstGroup(_ pattern: String, _ value: String, caseInsensitive: Bool = false) -> String? {
    _groups(pattern, value, caseInsensitive: caseInsensitive)?[safe: 1]
}

private func _groups(_ pattern: String, _ value: String, caseInsensitive: Bool = false) -> [String]? {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
    let nsValue = value as NSString
    let range = NSRange(location: 0, length: nsValue.length)
    guard let match = regex.firstMatch(in: value, options: [], range: range) else { return nil }

    var results: [String] = []
    for idx in 0..<match.numberOfRanges {
        let r = match.range(at: idx)
        if r.location == NSNotFound {
            results.append("")
        } else {
            results.append(nsValue.substring(with: r))
        }
    }
    return results
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

open class original_src_class_parser {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export function parseClassDiagram
    public static func parseClassDiagram(_ lines: [String]) throws -> ClassDiagram {
        try _parseClassDiagramEntry(lines)
    }
}
