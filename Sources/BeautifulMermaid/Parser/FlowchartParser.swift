// SPDX-License-Identifier: MIT
//
//  FlowchartParser.swift
//  BeautifulMermaid
//
//  Parser for flowchart/graph diagrams
//  Ported from beautiful-mermaid TypeScript implementation
//

import Foundation

/// Parser for Mermaid flowchart syntax
/// Line-by-line regex approach — the grammar is regular enough
/// that we don't need a grammar generator or full parser combinator.
struct FlowchartParser {

    // MARK: - Arrow Pattern

    /// Arrow regex — matches all arrow operators with optional labels.
    ///
    /// Supported operators:
    ///   -->  ---       solid arrow / solid line
    ///   -.-> -.-       dotted arrow / dotted line
    ///   ==>  ===       thick arrow / thick line
    ///   <--> <-.-> <==>  bidirectional variants
    ///
    /// Optional label: -->|label text|
    private static let arrowPattern = "^(<)?(-->|-.->|==>|---|-\\.-|===)(?:\\|([^|]*)\\|)?"

    // MARK: - Node Shape Patterns

    /// Node shape patterns — ordered from most specific delimiters to least.
    /// Multi-char delimiters must be tried before single-char to avoid false matches.
    /// Node IDs can contain word characters, hyphens, and dots (e.g., Craft.AIAssistant)
    private static let nodePatterns: [(pattern: String, shape: NodeShape)] = [
        // Triple delimiters (must be first)
        ("^([\\w.-]+)\\(\\(\\((.+?)\\)\\)\\)", .doublecircle),  // A(((text)))

        // Double delimiters with mixed brackets
        ("^([\\w.-]+)\\(\\[(.+?)\\]\\)",     .stadium),        // A([text])
        ("^([\\w.-]+)\\(\\((.+?)\\)\\)",     .circle),         // A((text))
        ("^([\\w.-]+)\\[\\[(.+?)\\]\\]",     .subroutine),     // A[[text]]
        ("^([\\w.-]+)\\[\\((.+?)\\)\\]",     .cylinder),       // A[(text)]

        // Trapezoid variants — must come before plain [text]
        ("^([\\w.-]+)\\[/(.+?)\\\\\\]",      .trapezoid),      // A[/text\]
        ("^([\\w.-]+)\\[\\\\(.+?)/\\]",      .trapezoidAlt),   // A[\text/]

        // Asymmetric flag shape
        ("^([\\w.-]+)>(.+?)\\]",             .asymmetric),     // A>text]

        // Double curly braces (hexagon) — must come before single {text}
        ("^([\\w.-]+)\\{\\{(.+?)\\}\\}",     .hexagon),        // A{{text}}

        // Single-char delimiters (last — most common, least specific)
        ("^([\\w.-]+)\\[(.+?)\\]",           .rectangle),      // A[text]
        ("^([\\w.-]+)\\((.+?)\\)",           .rounded),        // A(text)
        ("^([\\w.-]+)\\{(.+?)\\}",           .diamond),        // A{text}
    ]

    /// Regex for a bare node reference (just an ID, no shape brackets)
    /// Node IDs can contain word characters, hyphens, and dots (e.g., Craft.AIAssistant)
    private static let bareNodePattern = "^([\\w.-]+)"

    /// Regex for ::: class shorthand suffix
    private static let classShorthandPattern = "^:::([\\w][\\w-]*)"

    // MARK: - Main Parse Function

    /// Parse flowchart lines into a MermaidGraph
    func parse(_ lines: [String], startIndex: Int, direction: Direction) throws -> MermaidGraph {
        var graph = MermaidGraph(type: .flowchart, direction: direction)
        var subgraphStack: [Subgraph] = []

        for lineIndex in startIndex..<lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("%%") {
                continue
            }

            // --- classDef: `classDef name prop:val,prop:val` ---
            if let classDefMatch = trimmed.match(pattern: "^classDef\\s+(\\w+)\\s+(.+)$") {
                let name = classDefMatch[0]
                let propsStr = classDefMatch[1]
                let props = parseStyleProps(propsStr)
                graph.styleClasses[name] = StyleClass(name: name, properties: props)
                continue
            }

            // --- class assignment: `class A,B className` ---
            // TypeScript (parser.ts lines 77-85): stores in classAssignments Map for later application
            if let classAssignMatch = trimmed.match(pattern: "^class\\s+([\\w,-]+)\\s+(\\w+)$") {
                let nodeIds = classAssignMatch[0].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                let className = classAssignMatch[1]
                for nodeId in nodeIds {
                    graph.classAssignments[nodeId] = className
                }
                continue
            }

            // --- style statement: `style A,B fill:#f00,stroke:#333` ---
            // TypeScript (parser.ts lines 88-96): stores in nodeStyles Map for later application
            if let styleMatch = trimmed.match(pattern: "^style\\s+([\\w,-]+)\\s+(.+)$") {
                let nodeIds = styleMatch[0].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                let props = parseStyleProps(styleMatch[1])
                for nodeId in nodeIds {
                    var existingStyles = graph.nodeStyles[nodeId] ?? [:]
                    for (key, value) in props {
                        existingStyles[key] = value
                    }
                    graph.nodeStyles[nodeId] = existingStyles
                }
                continue
            }

            // --- direction override inside subgraph: `direction LR` ---
            if let dirMatch = trimmed.match(pattern: "^direction\\s+(TD|TB|LR|BT|RL)\\s*$") {
                if let dir = Direction.from(dirMatch[0]) {
                    if !subgraphStack.isEmpty {
                        subgraphStack[subgraphStack.count - 1].direction = dir
                    } else {
                        graph.direction = dir
                    }
                }
                continue
            }

            // --- subgraph start: `subgraph Label` or `subgraph id [Label]` ---
            if let subgraphMatch = trimmed.match(pattern: "^subgraph\\s+(.+)$") {
                let rest = subgraphMatch[0].trimmingCharacters(in: .whitespaces)

                // Check for "subgraph id [Label]" form
                // ID can contain hyphens and dots (e.g. "us-east", "App.Module")
                var id: String
                var label: String

                if let bracketMatch = rest.match(pattern: "^([\\w.-]+)\\s*\\[(.+)\\]$") {
                    id = bracketMatch[0]
                    label = bracketMatch[1]
                } else {
                    // Use the label text as id (slugified)
                    label = rest
                    id = rest.replacingOccurrences(of: " ", with: "_")
                        .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "-" }
                }

                let sg = Subgraph(id: id.isEmpty ? UUID().uuidString : id, label: label)
                subgraphStack.append(sg)
                continue
            }

            // --- subgraph end ---
            if trimmed == "end" {
                if let completed = subgraphStack.popLast() {
                    // If there's a parent subgraph, add to its children
                    // Otherwise add to the top-level subgraphs
                    if !subgraphStack.isEmpty {
                        subgraphStack[subgraphStack.count - 1].children.append(completed)
                    } else {
                        graph.subgraphs.append(completed)
                    }
                }
                continue
            }

            // --- Edge/node definitions ---
            parseEdgeLine(trimmed, graph: &graph, subgraphStack: &subgraphStack)
        }

        // Resolve style classes to inline styles
        resolveStyleClasses(&graph)

        return graph
    }

    /// Resolve styleClass and nodeStyles references to nodes
    /// Matching TypeScript behavior: classAssignments and nodeStyles are Maps applied after parsing
    private func resolveStyleClasses(_ graph: inout MermaidGraph) {
        for nodeId in graph.nodeOrder {
            guard var node = graph.nodes[nodeId] else { continue }

            // 1. Apply classAssignments (from `class A,B className` statements)
            if let className = graph.classAssignments[nodeId] {
                node.styleClass = className
            }

            // 2. Apply nodeStyles (from `style A fill:#f00` statements)
            if let styles = graph.nodeStyles[nodeId] {
                for (key, value) in styles {
                    node.inlineStyles[key] = value
                }
            }

            // 3. Resolve styleClass to inlineStyles (styleClass properties, inlineStyles take precedence)
            if let className = node.styleClass,
               let styleClass = graph.styleClasses[className] {
                for (key, value) in styleClass.properties {
                    if node.inlineStyles[key] == nil {
                        node.inlineStyles[key] = value
                    }
                }
            }

            graph.nodes[nodeId] = node
        }
    }

    // MARK: - Edge Line Parser

    /// Parse a line that contains node definitions and edges.
    /// Handles chaining: A --> B --> C produces edges A→B and B→C.
    /// Handles parallel links: A & B --> C & D produces 4 edges.
    private func parseEdgeLine(
        _ line: String,
        graph: inout MermaidGraph,
        subgraphStack: inout [Subgraph]
    ) {
        var remaining = line.trimmingCharacters(in: .whitespaces)

        // Parse the first node group (possibly with & separators)
        guard let firstGroup = consumeNodeGroup(&remaining, graph: &graph, subgraphStack: &subgraphStack),
              !firstGroup.isEmpty else {
            return
        }

        remaining = remaining.trimmingCharacters(in: .whitespaces)
        var prevGroupIds = firstGroup

        // Parse arrow + node-group pairs until the line is exhausted
        while !remaining.isEmpty {
            guard let arrowMatch = remaining.matchWithCaptures(pattern: Self.arrowPattern) else {
                break
            }

            let hasArrowStart = !arrowMatch[1].isEmpty
            let arrowOp = arrowMatch[2]
            let edgeLabel = arrowMatch[3].isEmpty ? nil : arrowMatch[3].trimmingCharacters(in: .whitespaces)

            // Advance past the arrow match
            let matchLength = arrowMatch[0].count
            remaining = String(remaining.dropFirst(matchLength)).trimmingCharacters(in: .whitespaces)

            let style = arrowStyleFromOp(arrowOp)
            let hasArrowEnd = arrowOp.hasSuffix(">")

            // Parse the next node group
            guard let nextGroup = consumeNodeGroup(&remaining, graph: &graph, subgraphStack: &subgraphStack),
                  !nextGroup.isEmpty else {
                break
            }

            remaining = remaining.trimmingCharacters(in: .whitespaces)

            // Emit Cartesian product of edges: every source × every target
            for sourceId in prevGroupIds {
                for targetId in nextGroup {
                    let edge = MermaidEdge(
                        id: "e\(graph.edges.count)",
                        sourceId: sourceId,
                        targetId: targetId,
                        label: edgeLabel,
                        style: style,
                        hasArrowStart: hasArrowStart,
                        hasArrowEnd: hasArrowEnd
                    )
                    graph.addEdge(edge)
                }
            }

            prevGroupIds = nextGroup
        }
    }

    /// Consume one or more nodes separated by `&`.
    /// E.g. "A & B & C --> ..." returns ids: ['A', 'B', 'C']
    private func consumeNodeGroup(
        _ text: inout String,
        graph: inout MermaidGraph,
        subgraphStack: inout [Subgraph]
    ) -> [String]? {
        guard let first = consumeNode(&text, graph: &graph, subgraphStack: &subgraphStack) else {
            return nil
        }

        var ids = [first]
        text = text.trimmingCharacters(in: .whitespaces)

        // Check for & separators
        while text.hasPrefix("&") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard let next = consumeNode(&text, graph: &graph, subgraphStack: &subgraphStack) else {
                break
            }
            ids.append(next)
            text = text.trimmingCharacters(in: .whitespaces)
        }

        return ids
    }

    /// Try to consume a node definition from the start of `text`.
    /// If the node has a shape+label (e.g. A[Text]), it's registered in the graph.
    /// If it's a bare reference (e.g. A), we look it up or create a default.
    /// Also handles ::: class shorthand suffix.
    private func consumeNode(
        _ text: inout String,
        graph: inout MermaidGraph,
        subgraphStack: inout [Subgraph]
    ) -> String? {
        var id: String? = nil
        let originalText = text

        // Try each node pattern (shape-qualified)
        for (pattern, shape) in Self.nodePatterns {
            if let match = text.matchWithCaptures(pattern: pattern) {
                id = match[1]
                let label = match[2]
                registerNode(MermaidNode(id: id!, label: label, shape: shape), graph: &graph, subgraphStack: &subgraphStack)
                text = String(text.dropFirst(match[0].count))
                break
            }
        }

        // Bare node reference
        if id == nil {
            if let bareMatch = text.matchWithCaptures(pattern: Self.bareNodePattern) {
                id = bareMatch[1]
                if graph.nodes[id!] == nil {
                    registerNode(MermaidNode(id: id!, label: id!, shape: .rectangle), graph: &graph, subgraphStack: &subgraphStack)
                } else {
                    trackInSubgraph(id!, subgraphStack: &subgraphStack)
                }
                text = String(text.dropFirst(bareMatch[0].count))
            }
        }

        guard let nodeId = id else {
            text = originalText
            return nil
        }

        // Check for ::: class shorthand suffix immediately after the node
        // TypeScript (parser.ts lines 522-526): stores in classAssignments Map
        if let classMatch = text.matchWithCaptures(pattern: Self.classShorthandPattern) {
            graph.classAssignments[nodeId] = classMatch[1]
            text = String(text.dropFirst(classMatch[0].count))
        }

        return nodeId
    }

    /// Register a node in the graph and track it in the current subgraph
    private func registerNode(
        _ node: MermaidNode,
        graph: inout MermaidGraph,
        subgraphStack: inout [Subgraph]
    ) {
        if graph.nodes[node.id] == nil {
            graph.addNode(node)
        }
        trackInSubgraph(node.id, subgraphStack: &subgraphStack)
    }

    /// Add node ID to the innermost subgraph if we're inside one
    private func trackInSubgraph(_ nodeId: String, subgraphStack: inout [Subgraph]) {
        guard !subgraphStack.isEmpty else { return }
        let lastIndex = subgraphStack.count - 1
        if !subgraphStack[lastIndex].nodeIds.contains(nodeId) {
            subgraphStack[lastIndex].nodeIds.append(nodeId)
        }
    }

    /// Map arrow operator string to edge style
    private func arrowStyleFromOp(_ op: String) -> EdgeStyle {
        let hasArrow = op.hasSuffix(">")
        let targetArrow: ArrowHead = hasArrow ? .arrow : .none

        if op == "-.->'" || op == "-.->'" || op == "-.-" || op.contains("-.-") {
            return EdgeStyle(lineStyle: .dotted, targetArrow: targetArrow)
        }
        if op == "==>" || op == "===" || op.contains("==") {
            return EdgeStyle(lineStyle: .thick, targetArrow: targetArrow)
        }
        // '-->' and '---' are both solid
        return EdgeStyle(lineStyle: .solid, targetArrow: targetArrow)
    }

    // MARK: - Style Parsing

    /// Parse "fill:#f00,stroke:#333" style property strings into a Dictionary
    private func parseStyleProps(_ propsStr: String) -> [String: String] {
        var props: [String: String] = [:]
        for pair in propsStr.split(separator: ",") {
            let pairStr = String(pair)
            if let colonIdx = pairStr.firstIndex(of: ":") {
                let key = String(pairStr[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let val = String(pairStr[pairStr.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty && !val.isEmpty {
                    props[key] = val
                }
            }
        }
        return props
    }
}

