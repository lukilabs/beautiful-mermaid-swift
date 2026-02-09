// SPDX-License-Identifier: MIT
//
//  StateParser.swift
//  BeautifulMermaid
//
//  Parser for state diagrams
//

import Foundation

/// Parser for Mermaid state diagram syntax
struct StateParser {

    // Counters for unique [*] pseudostate IDs (matching TypeScript behavior)
    private var startCount = 0
    private var endCount = 0

    mutating func parse(_ lines: [String], startIndex: Int) throws -> MermaidGraph {
        var graph = MermaidGraph(type: .stateDiagram, direction: .topDown)
        var edgeCounter = 0

        // Track composite state nesting (like subgraphs)
        var compositeStack: [Subgraph] = []

        for lineIndex in startIndex..<lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("%%") {
                continue
            }

            // Check for direction
            if trimmed.hasPrefix("direction ") {
                if let dir = parseDirection(trimmed) {
                    if compositeStack.isEmpty {
                        graph.direction = dir
                    } else {
                        compositeStack[compositeStack.count - 1].direction = dir
                    }
                }
                continue
            }

            // Check for composite state end: "}"
            // TypeScript (parser.ts lines 203-214): nests via parent.children
            if trimmed == "}" {
                if var completed = compositeStack.popLast() {
                    if compositeStack.isEmpty {
                        graph.subgraphs.append(completed)
                    } else {
                        // Nest in parent's children (matching TypeScript)
                        compositeStack[compositeStack.count - 1].children.append(completed)
                    }
                }
                continue
            }

            // Check for composite state start: "state CompositeState {"
            if let compositeMatch = trimmed.range(of: #"^state\s+(?:"([^"]+)"\s+as\s+)?(\w+)\s*\{$"#, options: .regularExpression) {
                let matchStr = String(trimmed[compositeMatch])
                if let (id, label) = parseCompositeState(matchStr) {
                    let sg = Subgraph(id: id, label: label, nodeIds: [])
                    compositeStack.append(sg)
                }
                continue
            }

            // Check for state alias: `state "Description" as s1` (without brace)
            if let aliasMatch = trimmed.range(of: #"^state\s+"([^"]+)"\s+as\s+(\w+)\s*$"#, options: .regularExpression) {
                if let (id, label) = parseStateAlias(String(trimmed[aliasMatch])) {
                    let node = MermaidNode(id: id, label: label, shape: .rounded)
                    registerNode(&graph, compositeStack: &compositeStack, node: node)
                }
                continue
            }

            // Check for state definition: "state StateName"
            if trimmed.hasPrefix("state ") {
                if let node = parseStateDefinition(trimmed) {
                    registerNode(&graph, compositeStack: &compositeStack, node: node)
                }
                continue
            }

            // Check for transition: StateA --> StateB : label
            if let (sourceId, targetId, label) = parseTransitionLine(trimmed, graph: &graph, compositeStack: &compositeStack) {
                let edge = MermaidEdge(
                    id: "e\(edgeCounter)",
                    sourceId: sourceId,
                    targetId: targetId,
                    label: label,
                    style: .solidArrow
                )
                edgeCounter += 1
                graph.addEdge(edge)
                continue
            }

            // Check for state description: `s1 : Description`
            if let (id, label) = parseStateDescription(trimmed) {
                let node = MermaidNode(id: id, label: label, shape: .rounded)
                registerNode(&graph, compositeStack: &compositeStack, node: node)
                continue
            }

            // Check for note
            if trimmed.hasPrefix("note ") {
                // Notes are not fully supported yet
                continue
            }
        }

        return graph
    }

    // MARK: - Helper Methods

    private func parseDirection(_ line: String) -> Direction? {
        if line.hasPrefix("direction ") {
            let dirString = String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces)
            return Direction.from(dirString)
        }
        return nil
    }

    private func parseCompositeState(_ line: String) -> (id: String, label: String)? {
        // Pattern: state "Label" as id { or state id {
        let pattern = #"^state\s+(?:"([^"]+)"\s+as\s+)?(\w+)\s*\{$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        let idRange = Range(match.range(at: 2), in: line)!
        let id = String(line[idRange])
        let label: String

        if let labelRange = Range(match.range(at: 1), in: line) {
            label = String(line[labelRange])
        } else {
            label = id
        }

        return (id, label)
    }

    private func parseStateAlias(_ line: String) -> (id: String, label: String)? {
        // Pattern: state "Description" as s1
        let pattern = #"^state\s+"([^"]+)"\s+as\s+(\w+)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let labelRange = Range(match.range(at: 1), in: line),
              let idRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        return (String(line[idRange]), String(line[labelRange]))
    }

    private func parseStateDefinition(_ line: String) -> MermaidNode? {
        var text = line
        if text.hasPrefix("state ") {
            text = String(text.dropFirst(6))
        }

        // Check for "State as Alias" pattern
        if let asRange = text.range(of: " as ") {
            let id = String(text[..<asRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let label = String(text[asRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return MermaidNode(id: id, label: label, shape: .rounded)
        }

        // Check for quoted state name
        if text.hasPrefix("\"") && text.hasSuffix("\"") {
            let label = String(text.dropFirst().dropLast())
            return MermaidNode(id: label.replacingOccurrences(of: " ", with: "_"), label: label, shape: .rounded)
        }

        // Simple state name
        let id = text.trimmingCharacters(in: .whitespaces)
        if !id.isEmpty {
            return MermaidNode(id: id, label: id, shape: .rounded)
        }

        return nil
    }

    private func parseStateDescription(_ line: String) -> (id: String, label: String)? {
        // Pattern: s1 : Description (IDs can contain dots, e.g., App.State)
        let pattern = #"^([\w.-]+)\s*:\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let idRange = Range(match.range(at: 1), in: line),
              let labelRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        return (String(line[idRange]), String(line[labelRange]).trimmingCharacters(in: .whitespaces))
    }

    /// Parse transition line and handle [*] pseudostates
    /// Returns (sourceId, targetId, label) where sourceId/targetId are the actual node IDs
    private mutating func parseTransitionLine(
        _ line: String,
        graph: inout MermaidGraph,
        compositeStack: inout [Subgraph]
    ) -> (sourceId: String, targetId: String, label: String?)? {
        // Pattern: StateA --> StateB : label or [*] --> s1 or s1 --> [*]
        // IDs can contain dots (e.g., App.State)
        let pattern = #"^(\[\*\]|[\w.-]+)\s*(-->)\s*(\[\*\]|[\w.-]+)(?:\s*:\s*(.+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let sourceRange = Range(match.range(at: 1), in: line),
              let targetRange = Range(match.range(at: 3), in: line) else {
            return nil
        }

        var sourceId = String(line[sourceRange])
        var targetId = String(line[targetRange])
        let label: String?

        if let labelRange = Range(match.range(at: 4), in: line) {
            label = String(line[labelRange]).trimmingCharacters(in: .whitespaces)
        } else {
            label = nil
        }

        // Handle [*] pseudostates — each occurrence gets a unique ID
        // Matching TypeScript: _start, _start2, _start3... and _end, _end2, _end3...
        if sourceId == "[*]" {
            startCount += 1
            sourceId = startCount > 1 ? "_start\(startCount)" : "_start"
            let node = MermaidNode(id: sourceId, label: "", shape: .stateStart)
            registerNode(&graph, compositeStack: &compositeStack, node: node)
        } else {
            ensureStateNode(&graph, compositeStack: &compositeStack, id: sourceId)
        }

        if targetId == "[*]" {
            endCount += 1
            targetId = endCount > 1 ? "_end\(endCount)" : "_end"
            let node = MermaidNode(id: targetId, label: "", shape: .stateEnd)
            registerNode(&graph, compositeStack: &compositeStack, node: node)
        } else {
            ensureStateNode(&graph, compositeStack: &compositeStack, id: targetId)
        }

        return (sourceId, targetId, label)
    }

    /// Register a state node and track in composite state if applicable
    private func registerNode(_ graph: inout MermaidGraph, compositeStack: inout [Subgraph], node: MermaidNode) {
        if graph.nodes[node.id] == nil {
            graph.addNode(node)
        }
        if !compositeStack.isEmpty {
            let idx = compositeStack.count - 1
            if !compositeStack[idx].nodeIds.contains(node.id) {
                compositeStack[idx].nodeIds.append(node.id)
            }
        }
    }

    /// Ensure a state node exists with default rounded shape
    private func ensureStateNode(_ graph: inout MermaidGraph, compositeStack: inout [Subgraph], id: String) {
        if graph.nodes[id] == nil {
            let node = MermaidNode(id: id, label: id, shape: .rounded)
            registerNode(&graph, compositeStack: &compositeStack, node: node)
        } else if !compositeStack.isEmpty {
            // Track in composite if applicable
            let idx = compositeStack.count - 1
            if !compositeStack[idx].nodeIds.contains(id) {
                compositeStack[idx].nodeIds.append(id)
            }
        }
    }
}
