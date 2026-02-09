// SPDX-License-Identifier: MIT
//
//  ERParser.swift
//  BeautifulMermaid
//
//  EXACT PORT of original/src/er/parser.ts
//  Parser for ER (Entity-Relationship) diagrams returning ErDiagram structure.
//

import Foundation

/// Parser for Mermaid ER diagram syntax
/// Port of: original/src/er/parser.ts
struct ERParser {

    // MARK: - Legacy Parse (for MermaidGraph compatibility)

    /// Parse into MermaidGraph for backwards compatibility
    func parse(_ lines: [String], startIndex: Int) throws -> MermaidGraph {
        let erDiagram = try parseErDiagram(lines, startIndex: startIndex)

        var graph = MermaidGraph(type: .erDiagram, direction: .leftRight)
        var edgeCounter = 0

        // Convert entities to nodes
        for entity in erDiagram.entities {
            var node = MermaidNode(id: entity.id, label: entity.label, shape: .entity)

            // Store attributes in inlineStyles
            for (index, attr) in entity.attributes.enumerated() {
                let attrInfo = "\(attr.type) \(attr.name) \(attr.keys.joined(separator: " "))"
                node.inlineStyles["attr_\(index)"] = attrInfo.trimmingCharacters(in: .whitespaces)
            }

            graph.addNode(node)
        }

        // Convert relationships to edges
        for rel in erDiagram.relationships {
            var style = EdgeStyle.solidArrow

            // Identifying relationships are solid, non-identifying are dashed
            if !rel.identifying {
                style.lineStyle = .dotted
            }

            // Combine cardinality with label
            let cardText = "\(rel.cardinality1) - \(rel.cardinality2)"
            let edgeLabel = "\(cardText): \(rel.label)"

            let edge = MermaidEdge(
                id: "e\(edgeCounter)",
                sourceId: rel.entity1,
                targetId: rel.entity2,
                label: edgeLabel,
                style: style
            )
            graph.addEdge(edge)
            edgeCounter += 1
        }

        return graph
    }

    // MARK: - Specialized Parse

    /// Parse a Mermaid ER diagram.
    /// Expects the first line to be "erDiagram".
    /// Port of: parseErDiagram() lines 31-82
    func parseErDiagram(_ lines: [String], startIndex: Int) throws -> ErDiagram {
        var diagram = ErDiagram(
            entities: [],
            relationships: []
        )

        // Track entities by ID for deduplication
        var entityMap: [String: ErEntity] = [:]
        // Track insertion order (Swift Dictionary doesn't preserve order like JS Map does)
        var entityOrder: [String] = []
        // Track entity body parsing
        var currentEntity: ErEntity? = nil

        for i in startIndex..<lines.count {
            let line = lines[i]

            // Skip empty lines and comments
            if line.isEmpty || line.hasPrefix("%%") {
                continue
            }

            // --- Inside entity body ---
            if currentEntity != nil {
                if line == "}" {
                    // Save the entity back to the map before clearing
                    if let entity = currentEntity {
                        entityMap[entity.id] = entity
                    }
                    currentEntity = nil
                    continue
                }

                // Attribute line: type name [PK|FK|UK] ["comment"]
                if let attr = parseAttribute(line) {
                    currentEntity?.attributes.append(attr)
                }
                continue
            }

            // --- Entity block start: `ENTITY_NAME {` ---
            if let entityBlockMatch = line.matchWithOptionalGroups(pattern: #"^(\S+)\s*\{$"#) {
                let id = entityBlockMatch[1]!
                let entity = ensureEntity(&entityMap, entityOrder: &entityOrder, id: id)
                currentEntity = entity
                continue
            }

            // --- Relationship: `ENTITY1 cardinality1--cardinality2 ENTITY2 : label` ---
            if let rel = parseRelationshipLine(line) {
                // Ensure both entities exist
                _ = ensureEntity(&entityMap, entityOrder: &entityOrder, id: rel.entity1)
                _ = ensureEntity(&entityMap, entityOrder: &entityOrder, id: rel.entity2)
                diagram.relationships.append(rel)
                continue
            }
        }

        // Preserve insertion order (TypeScript Map.values() maintains insertion order)
        diagram.entities = entityOrder.compactMap { entityMap[$0] }
        return diagram
    }

    /// Ensure an entity exists in the map
    /// Port of: ensureEntity() lines 85-92
    private func ensureEntity(_ entityMap: inout [String: ErEntity], entityOrder: inout [String], id: String) -> ErEntity {
        if let entity = entityMap[id] {
            return entity
        }
        let entity = ErEntity(id: id, label: id, attributes: [])
        entityMap[id] = entity
        entityOrder.append(id)  // Track insertion order
        return entity
    }

    /// Parse an attribute line inside an entity block
    /// Port of: parseAttribute() lines 95-124
    private func parseAttribute(_ line: String) -> ErAttribute? {
        // Format: type name [PK|FK|UK [...]] ["comment"]
        guard let match = line.matchWithOptionalGroups(pattern: #"^(\S+)\s+(\S+)(?:\s+(.+))?$"#) else {
            return nil
        }

        let type = match[1]!
        let name = match[2]!
        let rest = match[3]?.trimmingCharacters(in: .whitespaces) ?? ""

        // Extract key constraints (PK, FK, UK) and optional comment
        var keys: [String] = []
        var comment: String? = nil

        // Extract quoted comment first
        if let commentMatch = rest.matchWithOptionalGroups(pattern: #""([^"]*)""#) {
            comment = commentMatch[1]
        }

        // Extract key constraints
        let restWithoutComment = rest.replacingOccurrences(of: #""[^"]*""#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        for part in restWithoutComment.split(separator: " ") {
            let upper = String(part).uppercased()
            if upper == "PK" || upper == "FK" || upper == "UK" {
                keys.append(upper)
            }
        }

        return ErAttribute(type: type, name: name, keys: keys, comment: comment)
    }

    /// Parse a relationship line.
    ///
    /// Cardinality symbols on each side of the line style:
    ///   Left side (entity1):  ||  |o  o|  }|  |{  o{  {o
    ///   Line:                 --  (identifying) or  ..  (non-identifying)
    ///   Right side (entity2): ||  o|  |o  |{  }|  {o  o{
    ///
    /// Full pattern example: CUSTOMER ||--o{ ORDER : places
    /// Port of: parseRelationshipLine() lines 136-161
    private func parseRelationshipLine(_ line: String) -> ErRelationship? {
        // Match: ENTITY1 <cardinality_and_line> ENTITY2 : label
        guard let match = line.matchWithOptionalGroups(pattern: #"^(\S+)\s+([|o}{]+(?:--|\.\.)[|o}{]+)\s+(\S+)\s*:\s*(.+)$"#) else {
            return nil
        }

        let entity1 = match[1]!
        let cardinalityStr = match[2]!
        let entity2 = match[3]!
        let label = match[4]!.trimmingCharacters(in: .whitespaces)

        // Split the cardinality string into left side, line style, right side
        guard let lineMatch = cardinalityStr.matchWithOptionalGroups(pattern: #"^([|o}{]+)(--|\.\.?)([|o}{]+)$"#) else {
            return nil
        }

        let leftStr = lineMatch[1]!
        let lineStyle = lineMatch[2]!
        let rightStr = lineMatch[3]!

        guard let cardinality1 = parseCardinality(leftStr),
              let cardinality2 = parseCardinality(rightStr) else {
            return nil
        }

        let identifying = lineStyle == "--"

        return ErRelationship(
            entity1: entity1,
            entity2: entity2,
            cardinality1: cardinality1,
            cardinality2: cardinality2,
            label: label,
            identifying: identifying
        )
    }

    /// Parse a cardinality notation string into a Cardinality type
    /// Port of: parseCardinality() lines 164-178
    private func parseCardinality(_ str: String) -> String? {
        // Normalize: sort the characters to handle both orders (e.g., |o and o|)
        let sorted = String(str.sorted())

        // Character code order: { (123) < | (124) < } (125) < o (111)
        // Wait, o=111 is LESS than {=123, so o comes first!
        // Actual sort order: o (111) < { (123) < | (124) < } (125)

        // Exact one: || → sorted "||"
        if sorted == "||" { return "one" }
        // Zero or one: o| or |o → sorted "o|" (o=111 < |=124)
        if sorted == "o|" { return "zero-one" }
        // One or more: }| or |{ → sorted "|}" (|=124 < }=125) or "{|" ({=123 < |=124)
        if sorted == "|}" || sorted == "{|" { return "many" }
        // Zero or more: o{ or {o → sorted "o{" (o=111 < {=123)
        if sorted == "o{" { return "zero-many" }

        return nil
    }
}

