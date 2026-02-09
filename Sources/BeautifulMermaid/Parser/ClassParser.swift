// SPDX-License-Identifier: MIT
//
//  ClassParser.swift
//  BeautifulMermaid
//
//  EXACT PORT of original/src/class/parser.ts
//  Parser for class diagrams returning ClassDiagram structure.
//

import Foundation

/// Parser for Mermaid class diagram syntax
/// Port of: original/src/class/parser.ts
struct ClassParser {

    // MARK: - Legacy Parse (for MermaidGraph compatibility)

    /// Parse into MermaidGraph for backwards compatibility
    func parse(_ lines: [String], startIndex: Int) throws -> MermaidGraph {
        let classDiagram = try parseClassDiagram(lines, startIndex: startIndex)

        var graph = MermaidGraph(type: .classDiagram, direction: .topDown)
        var edgeCounter = 0

        // Convert classes to nodes
        for cls in classDiagram.classes {
            var node = MermaidNode(id: cls.id, label: cls.label, shape: .classBox)

            // Store annotation
            if let annotation = cls.annotation {
                node.inlineStyles["annotation"] = annotation
            }

            // Store members in inlineStyles
            var memberIndex = 0
            for attr in cls.attributes {
                let memberInfo = "\(attr.visibility)|a|\(attr.name)|\(attr.type ?? "")"
                node.inlineStyles["member_\(memberIndex)"] = memberInfo
                memberIndex += 1
            }
            for method in cls.methods {
                let memberInfo = "\(method.visibility)|m|\(method.name)|\(method.type ?? "")"
                node.inlineStyles["member_\(memberIndex)"] = memberInfo
                memberIndex += 1
            }

            graph.addNode(node)
        }

        // Convert relationships to edges
        for rel in classDiagram.relationships {
            var style = EdgeStyle.solidArrow

            // Determine line style
            if rel.type == "dependency" || rel.type == "realization" {
                style.lineStyle = .dotted
            }

            // Determine arrow style
            switch rel.type {
            case "inheritance", "realization":
                style.targetArrow = .diamond
            case "composition":
                style.targetArrow = .diamond
            case "aggregation":
                style.targetArrow = .circle
            default:
                style.targetArrow = .arrow
            }

            let edge = MermaidEdge(
                id: "e\(edgeCounter)",
                sourceId: rel.from,
                targetId: rel.to,
                label: rel.label,
                style: style
            )
            graph.addEdge(edge)
            edgeCounter += 1
        }

        return graph
    }

    // MARK: - Specialized Parse

    /// Parse a Mermaid class diagram.
    /// Expects the first line to be "classDiagram".
    /// Port of: parseClassDiagram() lines 26-162
    func parseClassDiagram(_ lines: [String], startIndex: Int) throws -> ClassDiagram {
        var diagram = ClassDiagram(
            classes: [],
            relationships: [],
            namespaces: []
        )

        // Track classes by ID for deduplication
        var classMap: [String: ClassNode] = [:]
        // Track insertion order (Swift Dictionary doesn't preserve order like JS Map does)
        var classOrder: [String] = []
        // Track namespace nesting
        var currentNamespace: ClassNamespace? = nil
        // Track class body parsing
        var currentClass: ClassNode? = nil
        var braceDepth = 0

        for i in startIndex..<lines.count {
            let line = lines[i]

            // Skip empty lines and comments
            if line.isEmpty || line.hasPrefix("%%") {
                continue
            }

            // --- Inside a class body block ---
            if currentClass != nil && braceDepth > 0 {
                if line == "}" {
                    braceDepth -= 1
                    if braceDepth == 0 {
                        // Save back to map before clearing
                        if let cls = currentClass {
                            classMap[cls.id] = cls
                        }
                        currentClass = nil
                    }
                    continue
                }

                // Check for annotation like <<interface>>
                if let annotMatch = line.matchWithOptionalGroups(pattern: #"^<<(\w+)>>$"#) {
                    currentClass?.annotation = annotMatch[1]
                    continue
                }

                // Parse member: visibility, name, type, optional parens for method
                if let memberResult = parseMember(line) {
                    if memberResult.isMethod {
                        currentClass?.methods.append(memberResult.member)
                    } else {
                        currentClass?.attributes.append(memberResult.member)
                    }
                }
                continue
            }

            // --- Namespace block start ---
            if let nsMatch = line.matchWithOptionalGroups(pattern: #"^namespace\s+(\S+)\s*\{$"#) {
                currentNamespace = ClassNamespace(name: nsMatch[1]!, classIds: [])
                continue
            }

            // --- Namespace end ---
            if line == "}" && currentNamespace != nil {
                diagram.namespaces.append(currentNamespace!)
                currentNamespace = nil
                continue
            }

            // --- Class block start: `class ClassName {` or `class ClassName~Type~ {` ---
            if let classBlockMatch = line.matchWithOptionalGroups(pattern: #"^class\s+(\S+?)(?:\s*~(\w+)~)?\s*\{$"#) {
                let id = classBlockMatch[1]!
                let generic = classBlockMatch[2]
                var cls = ensureClass(&classMap, classOrder: &classOrder, id: id)
                if let generic = generic {
                    cls.label = "\(id)<\(generic)>"
                }
                classMap[id] = cls
                currentClass = cls
                braceDepth = 1
                if currentNamespace != nil {
                    currentNamespace?.classIds.append(id)
                }
                continue
            }

            // --- Standalone class declaration (no body): `class ClassName` ---
            if let classOnlyMatch = line.matchWithOptionalGroups(pattern: #"^class\s+(\S+?)(?:\s*~(\w+)~)?\s*$"#) {
                let id = classOnlyMatch[1]!
                let generic = classOnlyMatch[2]
                var cls = ensureClass(&classMap, classOrder: &classOrder, id: id)
                if let generic = generic {
                    cls.label = "\(id)<\(generic)>"
                }
                classMap[id] = cls
                if currentNamespace != nil {
                    currentNamespace?.classIds.append(id)
                }
                continue
            }

            // --- Inline annotation: `class ClassName { <<interface>> }` (single line) ---
            if let inlineAnnotMatch = line.matchWithOptionalGroups(pattern: #"^class\s+(\S+?)\s*\{\s*<<(\w+)>>\s*\}$"#) {
                var cls = ensureClass(&classMap, classOrder: &classOrder, id: inlineAnnotMatch[1]!)
                cls.annotation = inlineAnnotMatch[2]!
                classMap[cls.id] = cls
                continue
            }

            // --- Inline attribute: `ClassName : +String name` ---
            if let inlineAttrMatch = line.matchWithOptionalGroups(pattern: #"^(\S+?)\s*:\s*(.+)$"#) {
                // Make sure this isn't a relationship line (those have arrows)
                let rest = inlineAttrMatch[2]!
                if rest.matchWithOptionalGroups(pattern: #"<\|--|--|\*--|o--|-->|\.\.>|\.\.\|>"#) == nil {
                    var cls = ensureClass(&classMap, classOrder: &classOrder, id: inlineAttrMatch[1]!)
                    if let memberResult = parseMember(rest) {
                        if memberResult.isMethod {
                            cls.methods.append(memberResult.member)
                        } else {
                            cls.attributes.append(memberResult.member)
                        }
                    }
                    classMap[cls.id] = cls
                    continue
                }
            }

            // --- Relationship ---
            // Pattern: [FROM] ["card"] ARROW ["card"] [TO] [: label]
            // Arrows: <|--, *--, o--, -->, ..|>, ..>
            // Can also be reversed: --o, --*, --|>
            if let rel = parseRelationship(line) {
                // Ensure both classes exist
                _ = ensureClass(&classMap, classOrder: &classOrder, id: rel.from)
                _ = ensureClass(&classMap, classOrder: &classOrder, id: rel.to)
                diagram.relationships.append(rel)
                continue
            }
        }

        // Preserve insertion order (TypeScript Map.values() maintains insertion order)
        diagram.classes = classOrder.compactMap { classMap[$0] }
        return diagram
    }

    /// Ensure a class exists in the map, creating a default if needed
    /// Port of: ensureClass() lines 165-172
    private func ensureClass(_ classMap: inout [String: ClassNode], classOrder: inout [String], id: String) -> ClassNode {
        if let cls = classMap[id] {
            return cls
        }
        let cls = ClassNode(id: id, label: id, annotation: nil, attributes: [], methods: [])
        classMap[id] = cls
        classOrder.append(id)  // Track insertion order
        return cls
    }

    /// Parse a class member line (attribute or method)
    /// Port of: parseMember() lines 175-234
    private func parseMember(_ line: String) -> (member: ClassDiagramMember, isMethod: Bool)? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        // Remove trailing semicolon
        if trimmed.hasSuffix(";") {
            trimmed = String(trimmed.dropLast())
        }
        if trimmed.isEmpty { return nil }

        // Extract visibility prefix
        var visibility: String = ""
        var rest = trimmed
        if let first = rest.first, ["+", "-", "#", "~"].contains(String(first)) {
            visibility = String(first)
            rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Check if it's a method (has parentheses)
        if let methodMatch = rest.matchWithOptionalGroups(pattern: #"^(.+?)\(([^)]*)\)(?:\s*(.+))?$"#) {
            let name = methodMatch[1]!.trimmingCharacters(in: .whitespaces)
            let typeStr = methodMatch[3]?.trimmingCharacters(in: .whitespaces)
            // Check for static ($) or abstract (*) markers
            let isStatic = name.hasSuffix("$") || rest.contains("$")
            let isAbstract = name.hasSuffix("*") || rest.contains("*")
            return (
                member: ClassDiagramMember(
                    visibility: visibility,
                    name: name.replacingOccurrences(of: "[$*]$", with: "", options: .regularExpression),
                    type: typeStr?.isEmpty == false ? typeStr : nil,
                    isStatic: isStatic,
                    isAbstract: isAbstract
                ),
                isMethod: true
            )
        }

        // It's an attribute: [Type] name or name Type
        // Common patterns: "String name", "+int age", "name"
        let parts = rest.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
        var name: String
        var type: String?

        if parts.count >= 2 {
            // "Type name" pattern
            type = parts[0]
            name = parts.dropFirst().joined(separator: " ")
        } else {
            name = parts.first ?? rest
        }

        let isStatic = name.hasSuffix("$")
        let isAbstract = name.hasSuffix("*")

        return (
            member: ClassDiagramMember(
                visibility: visibility,
                name: name.replacingOccurrences(of: "[$*]$", with: "", options: .regularExpression),
                type: type,
                isStatic: isStatic,
                isAbstract: isAbstract
            ),
            isMethod: false
        )
    }

    /// Parse a relationship line into a ClassRelationship
    /// Port of: parseRelationship() lines 237-256
    private func parseRelationship(_ line: String) -> ClassRelationship? {
        // Relationship regex — handles all arrow types with optional cardinality and labels
        // Pattern: FROM ["card"] ARROW ["card"] TO [: label]
        guard let match = line.matchWithOptionalGroups(pattern: #"^(\S+?)\s+(?:"([^"]*?)"\s+)?(<\|--|<\|\.\.|\*--|o--|-->|--\*|--o|--|>\s*|\.\.>|\.\.\|>|--)\s+(?:"([^"]*?)"\s+)?(\S+?)(?:\s*:\s*(.+))?$"#) else {
            return nil
        }

        let from = match[1]!
        let fromCardinality: String? = match[2]?.isEmpty == false ? match[2] : nil
        let arrow = match[3]!.trimmingCharacters(in: .whitespaces)
        let toCardinality: String? = match[4]?.isEmpty == false ? match[4] : nil
        let to = match[5]!
        let label: String? = match[6]?.trimmingCharacters(in: .whitespaces)

        guard let parsed = parseArrow(arrow) else { return nil }

        return ClassRelationship(
            from: from,
            to: to,
            type: parsed.type,
            markerAt: parsed.markerAt,
            label: label?.isEmpty == false ? label : nil,
            fromCardinality: fromCardinality,
            toCardinality: toCardinality
        )
    }

    /// Map arrow syntax to relationship type and marker placement side.
    /// Prefix markers (`<|--`, `*--`, `o--`) place the UML shape at the 'from' end.
    /// Suffix markers (`..|>`, `-->`, `..>`, `--*`, `--o`) place it at the 'to' end.
    /// Port of: parseArrow() lines 263-277
    private func parseArrow(_ arrow: String) -> (type: String, markerAt: String)? {
        switch arrow {
        case "<|--": return (type: "inheritance", markerAt: "from")
        case "<|..": return (type: "realization", markerAt: "from")
        case "*--":  return (type: "composition", markerAt: "from")
        case "--*":  return (type: "composition", markerAt: "to")
        case "o--":  return (type: "aggregation", markerAt: "from")
        case "--o":  return (type: "aggregation", markerAt: "to")
        case "-->":  return (type: "association", markerAt: "to")
        case "..>":  return (type: "dependency", markerAt: "to")
        case "..|>": return (type: "realization", markerAt: "to")
        case "--":   return (type: "association", markerAt: "to")
        default:     return nil
        }
    }
}

