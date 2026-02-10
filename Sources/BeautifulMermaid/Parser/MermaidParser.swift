// SPDX-License-Identifier: MIT
//
//  MermaidParser.swift
//  BeautifulMermaid
//
//  Main entry point for parsing Mermaid diagram syntax
//

import Foundation

/// Errors that can occur during parsing
public enum MermaidParseError: Error, LocalizedError {
    case emptyInput
    case unknownDiagramType
    case invalidSyntax(line: Int, message: String)
    case missingEndKeyword(startLine: Int)
    case invalidNodeDefinition(String)
    case invalidEdgeDefinition(String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Empty input"
        case .unknownDiagramType:
            return "Could not determine diagram type from input"
        case .invalidSyntax(let line, let message):
            return "Syntax error at line \(line): \(message)"
        case .missingEndKeyword(let startLine):
            return "Missing 'end' keyword for block starting at line \(startLine)"
        case .invalidNodeDefinition(let def):
            return "Invalid node definition: \(def)"
        case .invalidEdgeDefinition(let def):
            return "Invalid edge definition: \(def)"
        }
    }
}

/// Main parser for Mermaid diagrams
public struct MermaidParser {

    public init() {}

    /// Parse a Mermaid diagram from source text
    public func parse(_ source: String) throws -> MermaidGraph {
        let lines = source.components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: ";") }
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard !lines.isEmpty else {
            throw MermaidParseError.emptyInput
        }

        // Detect diagram type from first non-empty line
        guard let (type, direction, startIndex) = detectDiagramType(lines) else {
            throw MermaidParseError.unknownDiagramType
        }

        // Parse based on diagram type
        switch type {
        case .flowchart:
            return try FlowchartParser().parse(lines, startIndex: startIndex, direction: direction)
        case .stateDiagram:
            var stateParser = StateParser()
            return try stateParser.parse(lines, startIndex: startIndex)
        case .sequenceDiagram:
            return try SequenceParser().parse(lines, startIndex: startIndex)
        case .classDiagram:
            return try ClassParser().parse(lines, startIndex: startIndex)
        case .erDiagram:
            return try ERParser().parse(lines, startIndex: startIndex)
        }
    }

    /// Detect the diagram type from the source lines
    private func detectDiagramType(_ lines: [String]) -> (type: DiagramType, direction: Direction, startIndex: Int)? {
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("%%") {
                continue
            }

            // Check flowchart/graph
            if trimmed.hasPrefix("graph") || trimmed.hasPrefix("flowchart") {
                let direction = parseFlowchartDirection(trimmed) ?? .topDown
                return (.flowchart, direction, index + 1)
            }

            // Check state diagram
            if trimmed.hasPrefix("stateDiagram") {
                return (.stateDiagram, .topDown, index + 1)
            }

            // Check sequence diagram
            if trimmed.hasPrefix("sequenceDiagram") {
                return (.sequenceDiagram, .leftRight, index + 1)
            }

            // Check class diagram
            if trimmed.hasPrefix("classDiagram") {
                return (.classDiagram, .topDown, index + 1)
            }

            // Check ER diagram
            if trimmed.hasPrefix("erDiagram") {
                return (.erDiagram, .leftRight, index + 1)
            }
        }

        return nil
    }

    /// Parse direction from flowchart/graph declaration
    private func parseFlowchartDirection(_ line: String) -> Direction? {
        // Match: graph TD, graph LR, flowchart TB, etc.
        let parts = line.split(separator: " ")
        if parts.count >= 2 {
            let dirString = String(parts[1]).uppercased()
            return Direction.from(dirString)
        }
        return nil
    }
}

// MARK: - Convenience API

extension MermaidParser {
    /// Parse with static method
    public static func parse(_ source: String) throws -> MermaidGraph {
        try MermaidParser().parse(source)
    }
}
