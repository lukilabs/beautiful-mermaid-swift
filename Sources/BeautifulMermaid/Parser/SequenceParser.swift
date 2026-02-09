// SPDX-License-Identifier: MIT
//
//  SequenceParser.swift
//  BeautifulMermaid
//
//  Parser for sequence diagrams with full syntax support
//

import Foundation

/// Parser for Mermaid sequence diagram syntax
public struct SequenceParser {

    public init() {}

    // MARK: - Block Stack for Nesting

    private struct BlockContext {
        var type: SequenceBlockType
        var label: String
        var startIndex: Int
        var dividers: [SequenceBlockDivider]
    }

    // MARK: - Main Parse Method

    /// Parse sequence diagram lines into a SequenceDiagram
    public func parseSequence(_ lines: [String], startIndex: Int) -> SequenceDiagram {
        var actors: [String: SequenceActor] = [:]
        var actorOrder: [String] = []
        var messages: [SequenceMessage] = []
        var blocks: [SequenceBlock] = []
        var notes: [SequenceNote] = []

        var blockStack: [BlockContext] = []
        var currentMessageIndex = 0

        for lineIndex in startIndex..<lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("%%") {
                continue
            }

            // Check for participant/actor declaration
            if trimmed.hasPrefix("participant ") || trimmed.hasPrefix("actor ") {
                if let actor = parseActorDeclaration(trimmed) {
                    if actors[actor.id] == nil {
                        actors[actor.id] = actor
                        actorOrder.append(actor.id)
                    }
                }
                continue
            }

            // Check for block start keywords
            if let blockStart = parseBlockStart(trimmed) {
                blockStack.append(BlockContext(
                    type: blockStart.type,
                    label: blockStart.label,
                    startIndex: currentMessageIndex,
                    dividers: []
                ))
                continue
            }

            // Check for block dividers (else, and)
            if let divider = parseBlockDivider(trimmed) {
                if var current = blockStack.popLast() {
                    current.dividers.append(SequenceBlockDivider(
                        afterIndex: currentMessageIndex - 1,
                        label: divider
                    ))
                    blockStack.append(current)
                }
                continue
            }

            // Check for block end
            if trimmed == "end" {
                if let context = blockStack.popLast() {
                    let block = SequenceBlock(
                        type: context.type,
                        label: context.label,
                        startIndex: context.startIndex,
                        endIndex: currentMessageIndex - 1,
                        dividers: context.dividers
                    )
                    blocks.append(block)
                }
                continue
            }

            // Check for notes
            if trimmed.hasPrefix("Note ") || trimmed.hasPrefix("note ") {
                if let note = parseNote(trimmed, afterIndex: currentMessageIndex - 1) {
                    notes.append(note)
                    // Ensure actors mentioned in notes exist
                    for actorId in note.actorIds {
                        if actors[actorId] == nil {
                            actors[actorId] = SequenceActor(id: actorId, label: actorId)
                            actorOrder.append(actorId)
                        }
                    }
                }
                continue
            }

            // Check for message
            if let message = parseMessage(trimmed) {
                // Ensure actors exist
                for actorId in [message.from, message.to] {
                    if actors[actorId] == nil {
                        actors[actorId] = SequenceActor(id: actorId, label: actorId)
                        actorOrder.append(actorId)
                    }
                }
                messages.append(message)
                currentMessageIndex += 1
                continue
            }
        }

        // Handle any unclosed blocks
        while let context = blockStack.popLast() {
            let block = SequenceBlock(
                type: context.type,
                label: context.label,
                startIndex: context.startIndex,
                endIndex: currentMessageIndex - 1,
                dividers: context.dividers
            )
            blocks.append(block)
        }

        return SequenceDiagram(
            actors: actorOrder.compactMap { actors[$0] },
            messages: messages,
            blocks: blocks,
            notes: notes
        )
    }

    // MARK: - Legacy Parse (for MermaidGraph compatibility)

    /// Parse into MermaidGraph for backwards compatibility
    func parse(_ lines: [String], startIndex: Int) throws -> MermaidGraph {
        let seqDiagram = parseSequence(lines, startIndex: startIndex)

        var graph = MermaidGraph(type: .sequenceDiagram, direction: .leftRight)

        // Convert actors to nodes
        for actor in seqDiagram.actors {
            let shape: NodeShape = actor.type == .actor ? .circle : .rectangle
            let node = MermaidNode(id: actor.id, label: actor.label, shape: shape)
            graph.addNode(node)
        }

        // Convert messages to edges
        for (index, message) in seqDiagram.messages.enumerated() {
            var style = EdgeStyle.solidArrow

            // Line style
            if message.lineStyle == .dashed {
                style.lineStyle = .dotted
            }

            // Arrow head
            switch message.arrowHead {
            case .filled:
                style.targetArrow = .arrow
            case .open:
                style.targetArrow = .open
            case .cross:
                style.targetArrow = .cross
            case .none:
                style.targetArrow = .none
            }

            let edge = MermaidEdge(
                id: "e\(index)",
                sourceId: message.from,
                targetId: message.to,
                label: message.label.isEmpty ? nil : message.label,
                style: style
            )
            graph.addEdge(edge)
        }

        return graph
    }

    // MARK: - Actor Parsing

    private func parseActorDeclaration(_ line: String) -> SequenceActor? {
        var text = line
        var type = ActorType.participant

        if text.hasPrefix("actor ") {
            text = String(text.dropFirst(6))
            type = .actor
        } else if text.hasPrefix("participant ") {
            text = String(text.dropFirst(12))
        }

        // Check for alias: "A as Alice"
        if let asRange = text.range(of: " as ") {
            let id = String(text[..<asRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let label = String(text[asRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return SequenceActor(id: id, label: label, type: type)
        }

        let id = text.trimmingCharacters(in: .whitespaces)
        if !id.isEmpty {
            return SequenceActor(id: id, label: id, type: type)
        }

        return nil
    }

    // MARK: - Message Parsing

    private func parseMessage(_ line: String) -> SequenceMessage? {
        // Arrow patterns in order of specificity (longer patterns first)
        // Format: (pattern, lineStyle, arrowHead)
        let arrowPatterns: [(String, SequenceLineStyle, SequenceArrowHead)] = [
            ("-->>", .dashed, .filled),   // Dashed with filled arrow
            ("->>", .solid, .filled),     // Solid with filled arrow
            ("--)", .dashed, .open),      // Dashed with open arrow
            ("-)", .solid, .open),        // Solid with open arrow
            ("--x", .dashed, .cross),     // Dashed with cross
            ("-x", .solid, .cross),       // Solid with cross
            ("-->", .dashed, .none),      // Dashed line only
            ("->", .solid, .none),        // Solid line only
        ]

        var bestMatch: (range: Range<String.Index>, lineStyle: SequenceLineStyle, arrowHead: SequenceArrowHead)? = nil

        for (pattern, lineStyle, arrowHead) in arrowPatterns {
            if let range = line.range(of: pattern) {
                if bestMatch == nil || range.lowerBound < bestMatch!.range.lowerBound {
                    bestMatch = (range, lineStyle, arrowHead)
                }
            }
        }

        guard let match = bestMatch else {
            return nil
        }

        let sourcePart = String(line[..<match.range.lowerBound]).trimmingCharacters(in: .whitespaces)
        var targetPart = String(line[match.range.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Check for activation markers before the arrow
        var activate = false
        var deactivate = false

        // Check for activation/deactivation on target
        if targetPart.hasPrefix("+") {
            activate = true
            targetPart = String(targetPart.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if targetPart.hasPrefix("-") {
            deactivate = true
            targetPart = String(targetPart.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Check for message text after colon
        var label = ""
        if let colonRange = targetPart.range(of: ":") {
            label = String(targetPart[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            targetPart = String(targetPart[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        // Handle activation markers at end of target (A->>+B or A->>B+)
        if targetPart.hasSuffix("+") {
            activate = true
            targetPart = String(targetPart.dropLast()).trimmingCharacters(in: .whitespaces)
        } else if targetPart.hasSuffix("-") {
            deactivate = true
            targetPart = String(targetPart.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        guard !sourcePart.isEmpty && !targetPart.isEmpty else {
            return nil
        }

        return SequenceMessage(
            from: sourcePart,
            to: targetPart,
            label: label,
            lineStyle: match.lineStyle,
            arrowHead: match.arrowHead,
            activate: activate,
            deactivate: deactivate
        )
    }

    // MARK: - Block Parsing

    private func parseBlockStart(_ line: String) -> (type: SequenceBlockType, label: String)? {
        let blockKeywords: [(String, SequenceBlockType)] = [
            ("loop ", .loop),
            ("alt ", .alt),
            ("opt ", .opt),
            ("par ", .par),
            ("critical ", .critical),
            ("break ", .break),
            ("rect ", .rect),
        ]

        for (keyword, type) in blockKeywords {
            if line.hasPrefix(keyword) {
                let label = String(line.dropFirst(keyword.count)).trimmingCharacters(in: .whitespaces)
                return (type, label)
            }
        }

        return nil
    }

    private func parseBlockDivider(_ line: String) -> String? {
        if line.hasPrefix("else ") {
            return String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        }
        if line == "else" {
            return ""
        }
        if line.hasPrefix("and ") {
            return String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }
        if line == "and" {
            return ""
        }
        return nil
    }

    // MARK: - Note Parsing

    private func parseNote(_ line: String, afterIndex: Int) -> SequenceNote? {
        // Patterns:
        // Note left of A: text
        // Note right of B: text
        // Note over A: text
        // Note over A,B: text

        let lowercased = line.lowercased()

        var position: SequenceNotePosition?
        var actorsPart: String = ""
        var textPart: String = ""

        // Check position keywords
        if lowercased.contains(" left of ") {
            position = .left
            if let range = line.range(of: " left of ", options: .caseInsensitive) {
                let afterPosition = String(line[range.upperBound...])
                if let colonRange = afterPosition.range(of: ":") {
                    actorsPart = String(afterPosition[..<colonRange.lowerBound])
                    textPart = String(afterPosition[colonRange.upperBound...])
                } else {
                    actorsPart = afterPosition
                }
            }
        } else if lowercased.contains(" right of ") {
            position = .right
            if let range = line.range(of: " right of ", options: .caseInsensitive) {
                let afterPosition = String(line[range.upperBound...])
                if let colonRange = afterPosition.range(of: ":") {
                    actorsPart = String(afterPosition[..<colonRange.lowerBound])
                    textPart = String(afterPosition[colonRange.upperBound...])
                } else {
                    actorsPart = afterPosition
                }
            }
        } else if lowercased.contains(" over ") {
            position = .over
            if let range = line.range(of: " over ", options: .caseInsensitive) {
                let afterPosition = String(line[range.upperBound...])
                if let colonRange = afterPosition.range(of: ":") {
                    actorsPart = String(afterPosition[..<colonRange.lowerBound])
                    textPart = String(afterPosition[colonRange.upperBound...])
                } else {
                    actorsPart = afterPosition
                }
            }
        }

        guard let pos = position else {
            return nil
        }

        // Parse actor IDs (may be comma-separated)
        let actorIds = actorsPart
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !actorIds.isEmpty else {
            return nil
        }

        let text = textPart.trimmingCharacters(in: .whitespaces)

        return SequenceNote(
            actorIds: actorIds,
            text: text,
            position: pos,
            afterIndex: afterIndex
        )
    }
}
