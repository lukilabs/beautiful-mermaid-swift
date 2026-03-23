// Ported from original/src/er/parser.ts
import Foundation
import ElkSwift

public struct ErDiagram: Sendable {
    public var entities: [ErEntity]
    public var relationships: [ErRelationship]
}

public struct ErEntity: Sendable {
    public var id: String
    public var label: String
    public var attributes: [ErAttribute]
}

public struct ErAttribute: Sendable {
    public var type: String
    public var name: String
    public var keys: [String]
    public var comment: String?
}

public typealias Cardinality = String

public struct ErRelationship: Sendable {
    public var entity1: String
    public var entity2: String
    public var cardinality1: Cardinality
    public var cardinality2: Cardinality
    public var label: String
    public var identifying: Bool
}

public struct PositionedErDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var entities: [PositionedErEntity]
    public var relationships: [PositionedErRelationship]
}

public struct PositionedErEntity: Sendable {
    public var id: String
    public var label: String
    public var attributes: [ErAttribute]
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var headerHeight: Double
    public var rowHeight: Double
}

public struct PositionedErRelationship: Sendable {
    public var entity1: String
    public var entity2: String
    public var cardinality1: Cardinality
    public var cardinality2: Cardinality
    public var label: String
    public var identifying: Bool
    public var points: [ErPoint]
}

public struct ErPoint: Sendable {
    public var x: Double
    public var y: Double
}

public enum ErParserError: Error, LocalizedError {
    case invalidHeader(expected: String, found: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHeader(expected, found):
            return "Invalid ER diagram header. Expected '\(expected)', found '\(found)'."
        }
    }
}

public func parseErDiagram(_ lines: [String]) throws -> ErDiagram {
    try _parseErDiagramEntry(lines)
}

private func _parseErDiagramEntry(_ lines: [String]) throws -> ErDiagram {
    guard let header = lines.first else {
        return ErDiagram(entities: [], relationships: [])
    }
    if header.range(of: #"^erdiagram\s*$"#, options: [.regularExpression, .caseInsensitive]) == nil {
        throw ErParserError.invalidHeader(expected: "erDiagram", found: header)
    }

    var diagram = ErDiagram(entities: [], relationships: [])
    var entityMap: [String: ErEntity] = [:]
    var entityOrder: [String] = []
    var currentEntityId: String?

    if lines.count <= 1 {
        return diagram
    }

    for line in lines.dropFirst() {
        let rawLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawLine.isEmpty {
            continue
        }

        if let activeEntityId = currentEntityId {
            if rawLine == "}" {
                currentEntityId = nil
                continue
            }

            if let attr = _parseAttribute(rawLine) {
                var entity = _ensureEntity(&entityMap, &entityOrder, activeEntityId)
                entity.attributes.append(attr)
                entityMap[activeEntityId] = entity
            }
            continue
        }

        if let id = _firstGroup(#"^(\S+)\s*\{$"#, rawLine) {
            _ = _ensureEntity(&entityMap, &entityOrder, id)
            currentEntityId = id
            continue
        }

        if let rel = _parseRelationshipLine(rawLine) {
            _ = _ensureEntity(&entityMap, &entityOrder, rel.entity1)
            _ = _ensureEntity(&entityMap, &entityOrder, rel.entity2)
            diagram.relationships.append(rel)
        }
    }

    diagram.entities = entityOrder.compactMap { entityMap[$0] }
    return diagram
}

private func _ensureEntity(_ map: inout [String: ErEntity], _ order: inout [String], _ id: String) -> ErEntity {
    if let entity = map[id] {
        return entity
    }
    let entity = ErEntity(id: id, label: id, attributes: [])
    map[id] = entity
    order.append(id)
    return entity
}

private func _parseAttribute(_ line: String) -> ErAttribute? {
    guard let groups = _groups(#"^(\S+)\s+(\S+)(?:\s+(.+))?$"#, line),
          let type = groups[safe: 1],
          let name = groups[safe: 2]
    else {
        return nil
    }

    let rest = groups[safe: 3]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    var keys: [String] = []
    var comment: String?

    if let commentMatch = _firstGroup(#""([^"]*)""#, rest) {
        comment = original_src_multiline_utils.normalizeBrTags(commentMatch)
    }

    let restWithoutComment = rest.replacingOccurrences(of: #""[^"]*""#, with: "", options: .regularExpression)
    for part in restWithoutComment.split(whereSeparator: \.isWhitespace) {
        let token = String(part).uppercased()
        if token == "PK" || token == "FK" || token == "UK" {
            keys.append(token)
        }
    }

    return ErAttribute(type: type, name: name, keys: keys, comment: comment)
}

private func _parseRelationshipLine(_ line: String) -> ErRelationship? {
    guard let groups = _groups(#"^(\S+)\s+([|o}{]+(?:--|\.\.)[|o}{]+)\s+(\S+)\s*:\s*(.+)$"#, line),
          let entity1 = groups[safe: 1],
          let cardinalityStr = groups[safe: 2],
          let entity2 = groups[safe: 3],
          let rawLabel = groups[safe: 4]
    else {
        return nil
    }

    let label = original_src_multiline_utils.normalizeBrTags(rawLabel.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #"^["']|["']$"#, with: "", options: .regularExpression))

    guard let lineMatch = _groups(#"^([|o}{]+)(--|\.\.?)([|o}{]+)$"#, cardinalityStr),
          let leftStr = lineMatch[safe: 1],
          let lineStyle = lineMatch[safe: 2],
          let rightStr = lineMatch[safe: 3],
          let cardinality1 = _parseCardinality(leftStr),
          let cardinality2 = _parseCardinality(rightStr)
    else {
        return nil
    }

    return ErRelationship(
        entity1: entity1,
        entity2: entity2,
        cardinality1: cardinality1,
        cardinality2: cardinality2,
        label: label,
        identifying: lineStyle == "--"
    )
}

private func _parseCardinality(_ raw: String) -> Cardinality? {
    let sorted = String(raw.sorted())
    if sorted == "||" { return "one" }
    if sorted == "o|" { return "zero-one" }
    if sorted == "|}" || sorted == "{|" { return "many" }
    if sorted == "{o" || sorted == "o{" { return "zero-many" }
    return nil
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

open class original_src_er_parser {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export function parseErDiagram
    public static func parseErDiagram(_ lines: [String]) throws -> ErDiagram {
        try _parseErDiagramEntry(lines)
    }
}
