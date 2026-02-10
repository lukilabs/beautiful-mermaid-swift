// SPDX-License-Identifier: MIT
//
//  SequenceLayout.swift
//  BeautifulMermaid
//
//  Layout algorithm for sequence diagrams
//  EXACT PORT of original/src/sequence/layout.ts
//

import Foundation
import CoreGraphics

/// Layout algorithm for sequence diagrams
/// Port of: original/src/sequence/layout.ts
public struct SequenceLayout: GraphLayoutAlgorithm {

    public init() {}

    // MARK: - GraphLayoutAlgorithm Conformance (Legacy)

    /// Layout a MermaidGraph (for backwards compatibility)
    public func layout(_ graph: MermaidGraph, config: LayoutConfig) throws -> PositionedGraph {
        // Parse into SequenceDiagram if we have the raw content
        // For now, use the simple layout based on nodes/edges
        var positionedNodes: [MermaidNode] = []
        var positionedEdges: [MermaidEdge] = []

        let c = SequenceConstants.self

        // Participants are laid out horizontally
        var actorX: [String: CGFloat] = [:]
        var currentX: CGFloat = c.padding

        // Position participants
        for nodeId in graph.nodeOrder {
            guard var node = graph.nodes[nodeId] else { continue }

            let labelWidth = measureText(node.label, fontSize: RenderConfig.shared.fontSizeNodeLabel, fontWeight: RenderConfig.shared.fontWeightNodeLabel)
            let width = max(c.actorMinWidth, labelWidth + c.actorPadding * 2)
            let height = c.actorHeight

            node.size = CGSize(width: width, height: height)
            node.position = CGPoint(x: currentX + width / 2, y: c.padding + height / 2)

            actorX[nodeId] = currentX + width / 2
            currentX += width + c.actorGap - c.actorMinWidth

            positionedNodes.append(node)
        }

        // Position messages (edges)
        var currentY = c.padding + c.actorHeight + c.headerGap

        for var edge in graph.edges {
            guard let sourceX = actorX[edge.sourceId],
                  let targetX = actorX[edge.targetId] else { continue }

            let y = currentY + c.messageRowHeight / 2

            if edge.sourceId == edge.targetId {
                // Self-message
                let loopWidth = c.selfMessageWidth
                let loopHeight = c.selfMessageHeight

                edge.points = [
                    CGPoint(x: sourceX, y: y),
                    CGPoint(x: sourceX + loopWidth, y: y),
                    CGPoint(x: sourceX + loopWidth, y: y + loopHeight),
                    CGPoint(x: sourceX, y: y + loopHeight)
                ]
                edge.labelPosition = CGPoint(x: sourceX + loopWidth + 5, y: y + loopHeight / 2)
                edge.targetAngle = .pi  // Points left
                currentY += c.messageRowHeight + c.selfMessageHeight
            } else {
                // Normal message
                let startPoint = CGPoint(x: sourceX, y: y)
                let endPoint = CGPoint(x: targetX, y: y)

                edge.points = [startPoint, endPoint]
                // TypeScript positions label ~8px above the arrow line (accounting for baseline)
                edge.labelPosition = startPoint.midpoint(to: endPoint) - CGPoint(x: 0, y: 8)

                if startPoint.x < endPoint.x {
                    edge.targetAngle = 0 // Right
                } else {
                    edge.targetAngle = .pi // Left
                }

                currentY += c.messageRowHeight
            }

            positionedEdges.append(edge)
        }

        // Calculate bounds
        let maxY = currentY + c.padding
        let maxX = currentX + c.padding

        let bounds = CGRect(x: 0, y: 0, width: maxX, height: maxY)

        return PositionedGraph(
            nodes: positionedNodes,
            edges: positionedEdges,
            subgraphs: [],
            bounds: bounds,
            direction: .leftRight
        )
    }

    // MARK: - Full Sequence Layout

    /// Layout a SequenceDiagram into a PositionedSequenceDiagram
    /// EXACT PORT of: layoutSequenceDiagram() in original/src/sequence/layout.ts
    public func layoutSequence(_ diagram: SequenceDiagram, config: LayoutConfig) -> PositionedSequenceDiagram {
        let c = SequenceConstants.self

        if diagram.actors.isEmpty {
            return PositionedSequenceDiagram(
                width: 0, height: 0, actors: [], lifelines: [],
                messages: [], activations: [], blocks: [], notes: []
            )
        }

        // 1. Calculate actor widths and assign horizontal positions (center X)
        // Port of: lines 63-77
        var actorWidths: [CGFloat] = []
        for actor in diagram.actors {
            let textW = measureText(actor.label, fontSize: RenderConfig.shared.fontSizeNodeLabel, fontWeight: RenderConfig.shared.fontWeightNodeLabel)
            let width = max(textW + c.actorPadding * 2, c.actorMinWidth)
            actorWidths.append(width)
        }

        // Build actor center X positions with minimum gap
        var actorCenterX: [CGFloat] = []
        var currentX = c.padding + actorWidths[0] / 2
        for i in 0..<diagram.actors.count {
            if i > 0 {
                let minGap = max(c.actorGap, (actorWidths[i - 1] + actorWidths[i]) / 2 + 40)
                currentX += minGap
            }
            actorCenterX.append(currentX)
        }

        // Build actor ID → index lookup
        var actorIndex: [String: Int] = [:]
        for (i, actor) in diagram.actors.enumerated() {
            actorIndex[actor.id] = i
        }

        // 2. Position actors at the top
        // Port of: lines 86-95
        let actorY = c.padding
        var actors: [PositionedActor] = []
        for (i, actor) in diagram.actors.enumerated() {
            let width = actorWidths[i]
            let centerX = actorCenterX[i]
            actors.append(PositionedActor(
                id: actor.id,
                label: actor.label,
                type: actor.type,
                bounds: CGRect(
                    x: centerX - width / 2,
                    y: actorY,
                    width: width,
                    height: c.actorHeight
                ),
                bottomBounds: .zero,
                centerX: centerX
            ))
        }

        // 3. Stack messages vertically
        // Port of: lines 97-170
        var messageY = actorY + c.actorHeight + c.headerGap
        var messages: [PositionedSequenceMessage] = []

        // Pre-scan blocks to determine which message indices need extra vertical space
        // Port of: lines 105-116
        var extraSpaceBefore: [Int: CGFloat] = [:]
        for block in diagram.blocks {
            // First message in the block needs room for the block header label
            let prev = extraSpaceBefore[block.startIndex] ?? 0
            extraSpaceBefore[block.startIndex] = max(prev, c.blockHeaderExtra)

            // Each divider (else/and) needs room for the divider label
            // TypeScript uses div.index which is the message index AFTER the divider
            // Swift stores afterIndex which is the message index BEFORE the divider
            // So div.index in TS = afterIndex + 1 in Swift
            for divider in block.dividers {
                let divIndex = divider.afterIndex + 1
                let prevDiv = extraSpaceBefore[divIndex] ?? 0
                extraSpaceBefore[divIndex] = max(prevDiv, c.dividerExtra)
            }
        }

        // Track activation stack per actor: array of start-Y positions
        var activationStacks: [String: [CGFloat]] = [:]
        var activations: [SequenceActivation] = []

        for msgIdx in 0..<diagram.messages.count {
            let msg = diagram.messages[msgIdx]
            let fromIdx = actorIndex[msg.from] ?? 0
            let toIdx = actorIndex[msg.to] ?? 0
            let isSelf = msg.from == msg.to

            // Add extra vertical space if this message sits below a block header or divider
            let extra = extraSpaceBefore[msgIdx] ?? 0
            if extra > 0 {
                messageY += extra
            }

            let x1 = actorCenterX[fromIdx]
            let x2 = actorCenterX[toIdx]

            // Create positioned message
            let positioned: PositionedSequenceMessage
            if isSelf {
                // Self-message: loop to the right
                let loopWidth = c.selfMessageWidth
                let loopHeight = c.selfMessageHeight
                positioned = PositionedSequenceMessage(
                    from: msg.from,
                    to: msg.to,
                    label: msg.label,
                    lineStyle: msg.lineStyle,
                    arrowHead: msg.arrowHead,
                    points: [
                        CGPoint(x: x1, y: messageY),
                        CGPoint(x: x1 + loopWidth, y: messageY),
                        CGPoint(x: x1 + loopWidth, y: messageY + loopHeight),
                        CGPoint(x: x1, y: messageY + loopHeight)
                    ],
                    labelPosition: CGPoint(x: x1 + loopWidth + 5, y: messageY + loopHeight / 2),
                    arrowAngle: .pi
                )
            } else {
                // Normal message
                let isRightward = x2 > x1
                positioned = PositionedSequenceMessage(
                    from: msg.from,
                    to: msg.to,
                    label: msg.label,
                    lineStyle: msg.lineStyle,
                    arrowHead: msg.arrowHead,
                    points: [
                        CGPoint(x: x1, y: messageY),
                        CGPoint(x: x2, y: messageY)
                    ],
                    // TypeScript positions label ~8px above the arrow line (accounting for baseline)
                    labelPosition: CGPoint(x: (x1 + x2) / 2, y: messageY - 8),
                    arrowAngle: isRightward ? 0 : .pi
                )
            }
            messages.append(positioned)

            // Handle activation
            // Port of: lines 147-167
            if msg.activate {
                if activationStacks[msg.to] == nil {
                    activationStacks[msg.to] = []
                }
                activationStacks[msg.to]!.append(messageY)
            }

            if msg.deactivate {
                if var stack = activationStacks[msg.from], !stack.isEmpty {
                    let startY = stack.removeLast()
                    activationStacks[msg.from] = stack
                    let idx = actorIndex[msg.from] ?? 0
                    activations.append(SequenceActivation(
                        actorId: msg.from,
                        bounds: CGRect(
                            x: actorCenterX[idx] - c.activationWidth / 2,
                            y: startY,
                            width: c.activationWidth,
                            height: messageY - startY
                        ),
                        depth: 0
                    ))
                }
            }

            messageY += isSelf ? c.selfMessageHeight + c.messageRowHeight : c.messageRowHeight
        }

        // Close any unclosed activations
        // Port of: lines 172-184
        for (actorId, stack) in activationStacks {
            for startY in stack {
                let idx = actorIndex[actorId] ?? 0
                activations.append(SequenceActivation(
                    actorId: actorId,
                    bounds: CGRect(
                        x: actorCenterX[idx] - c.activationWidth / 2,
                        y: startY,
                        width: c.activationWidth,
                        height: messageY - c.messageRowHeight / 2 - startY
                    ),
                    depth: 0
                ))
            }
        }

        // 4. Position blocks (loop/alt/opt)
        // Port of: lines 186-261
        var blocks: [PositionedSequenceBlock] = []
        for block in diagram.blocks {
            // Block spans from the Y of startIndex to endIndex messages
            let startMsg = block.startIndex < messages.count ? messages[block.startIndex] : nil
            let endMsg = block.endIndex < messages.count ? messages[block.endIndex] : nil
            let blockTop = (startMsg?.points.first?.y ?? messageY) - c.blockPadTop
            let blockBottom = (endMsg?.points.first?.y ?? messageY) + c.blockPadBottom + 12

            // Block width spans all actors involved in its messages
            var involvedActors = Set<Int>()
            for mi in block.startIndex...block.endIndex {
                if mi < diagram.messages.count {
                    let m = diagram.messages[mi]
                    if let idx = actorIndex[m.from] { involvedActors.insert(idx) }
                    if let idx = actorIndex[m.to] { involvedActors.insert(idx) }
                }
            }
            // Fallback: span all actors if none involved
            if involvedActors.isEmpty {
                for ai in 0..<diagram.actors.count {
                    involvedActors.insert(ai)
                }
            }
            let minIdx = involvedActors.min() ?? 0
            let maxIdx = involvedActors.max() ?? 0
            let blockLeft = actorCenterX[minIdx] - actorWidths[minIdx] / 2 - c.blockPadX
            let blockRight = actorCenterX[maxIdx] + actorWidths[maxIdx] / 2 + c.blockPadX

            // Position dividers
            // Port of: lines 222-250
            var positionedDividers: [PositionedBlockDivider] = []
            for divider in block.dividers {
                // TypeScript uses div.index; Swift uses afterIndex + 1
                let divMsgIndex = divider.afterIndex + 1
                let divMsg = divMsgIndex < messages.count ? messages[divMsgIndex] : nil
                let msgY = divMsg?.points.first?.y ?? messageY
                var offset: CGFloat = 28

                // Dynamic overlap detection
                if !divider.label.isEmpty, let divMsg = divMsg, !divMsg.label.isEmpty {
                    let divLabelText = "[\(divider.label)]"
                    let divLabelW = measureText(divLabelText, fontSize: RenderConfig.shared.fontSizeEdgeLabel, fontWeight: RenderConfig.shared.fontWeightEdgeLabel)
                    let divLabelLeft = blockLeft + 8
                    let divLabelRight = divLabelLeft + divLabelW

                    let msgLabelW = measureText(divMsg.label, fontSize: RenderConfig.shared.fontSizeEdgeLabel, fontWeight: RenderConfig.shared.fontWeightEdgeLabel)
                    let msgLabelLeft = divMsg.from == divMsg.to
                        ? (divMsg.points.first?.x ?? 0) + 36
                        : ((divMsg.points.first?.x ?? 0) + (divMsg.points.last?.x ?? 0)) / 2 - msgLabelW / 2
                    let msgLabelRight = msgLabelLeft + msgLabelW

                    if divLabelRight > msgLabelLeft && divLabelLeft < msgLabelRight {
                        offset = 36
                    }
                }

                positionedDividers.append(PositionedBlockDivider(y: msgY - offset, label: divider.label))
            }

            blocks.append(PositionedSequenceBlock(
                type: block.type,
                label: block.label,
                bounds: CGRect(
                    x: blockLeft,
                    y: blockTop,
                    width: blockRight - blockLeft,
                    height: blockBottom - blockTop
                ),
                dividers: positionedDividers
            ))
        }

        // 5. Position notes
        // Port of: lines 263-293
        var notes: [PositionedSequenceNote] = []
        for note in diagram.notes {
            let noteW = max(
                c.noteWidth,
                measureText(note.text, fontSize: RenderConfig.shared.fontSizeEdgeLabel, fontWeight: RenderConfig.shared.fontWeightEdgeLabel) + c.notePadding * 2
            )
            let noteH = RenderConfig.shared.fontSizeEdgeLabel + c.notePadding * 2

            // Position based on the message after which it appears
            let refMsg = note.afterIndex >= 0 && note.afterIndex < messages.count ? messages[note.afterIndex] : nil
            let noteY = (refMsg?.points.first?.y ?? actorY + c.actorHeight) + 4

            // X based on actor position and note type
            let firstActorIdx = actorIndex[note.actorIds.first ?? ""] ?? 0
            let noteX: CGFloat
            switch note.position {
            case .left:
                noteX = actorCenterX[firstActorIdx] - actorWidths[firstActorIdx] / 2 - noteW - c.noteGap
            case .right:
                noteX = actorCenterX[firstActorIdx] + actorWidths[firstActorIdx] / 2 + c.noteGap
            case .over:
                if note.actorIds.count > 1 {
                    let lastActorIdx = actorIndex[note.actorIds.last ?? ""] ?? firstActorIdx
                    noteX = (actorCenterX[firstActorIdx] + actorCenterX[lastActorIdx]) / 2 - noteW / 2
                } else {
                    noteX = actorCenterX[firstActorIdx] - noteW / 2
                }
            }

            notes.append(PositionedSequenceNote(
                text: note.text,
                bounds: CGRect(x: noteX, y: noteY, width: noteW, height: noteH),
                position: note.position
            ))
        }

        // 6. Bounding-box post-processing
        // Port of: lines 295-329
        let diagramBottom = messageY + c.padding

        // Find global X extents across actors, blocks, and notes
        var globalMinX = c.padding
        var globalMaxX: CGFloat = 0
        for a in actors {
            globalMinX = min(globalMinX, a.bounds.minX)
            globalMaxX = max(globalMaxX, a.bounds.maxX)
        }
        for b in blocks {
            globalMinX = min(globalMinX, b.bounds.minX)
            globalMaxX = max(globalMaxX, b.bounds.maxX)
        }
        for n in notes {
            globalMinX = min(globalMinX, n.bounds.minX)
            globalMaxX = max(globalMaxX, n.bounds.maxX)
        }
        // Include message labels in bounding box
        for m in messages {
            if !m.label.isEmpty {
                let labelWidth = measureText(
                    m.label,
                    fontSize: RenderConfig.shared.fontSizeEdgeLabel,
                    fontWeight: RenderConfig.shared.fontWeightEdgeLabel
                )
                if m.isSelfMessage {
                    globalMaxX = max(globalMaxX, m.labelPosition.x + labelWidth)
                } else {
                    globalMinX = min(globalMinX, m.labelPosition.x - labelWidth / 2)
                    globalMaxX = max(globalMaxX, m.labelPosition.x + labelWidth / 2)
                }
            }
        }

        // If elements extend left of the desired padding, shift everything right
        let shiftX = globalMinX < c.padding ? c.padding - globalMinX : 0
        if shiftX > 0 {
            for i in 0..<actors.count {
                actors[i] = PositionedActor(
                    id: actors[i].id,
                    label: actors[i].label,
                    type: actors[i].type,
                    bounds: actors[i].bounds.offsetBy(dx: shiftX, dy: 0),
                    bottomBounds: actors[i].bottomBounds,
                    centerX: actors[i].centerX + shiftX
                )
            }
            for i in 0..<messages.count {
                messages[i] = PositionedSequenceMessage(
                    from: messages[i].from,
                    to: messages[i].to,
                    label: messages[i].label,
                    lineStyle: messages[i].lineStyle,
                    arrowHead: messages[i].arrowHead,
                    points: messages[i].points.map { CGPoint(x: $0.x + shiftX, y: $0.y) },
                    labelPosition: CGPoint(x: messages[i].labelPosition.x + shiftX, y: messages[i].labelPosition.y),
                    arrowAngle: messages[i].arrowAngle
                )
            }
            for i in 0..<activations.count {
                activations[i] = SequenceActivation(
                    actorId: activations[i].actorId,
                    bounds: activations[i].bounds.offsetBy(dx: shiftX, dy: 0),
                    depth: activations[i].depth
                )
            }
            for i in 0..<blocks.count {
                blocks[i] = PositionedSequenceBlock(
                    type: blocks[i].type,
                    label: blocks[i].label,
                    bounds: blocks[i].bounds.offsetBy(dx: shiftX, dy: 0),
                    dividers: blocks[i].dividers
                )
            }
            for i in 0..<notes.count {
                notes[i] = PositionedSequenceNote(
                    text: notes[i].text,
                    bounds: notes[i].bounds.offsetBy(dx: shiftX, dy: 0),
                    position: notes[i].position
                )
            }
            // Also shift actor center X array
            for i in 0..<actorCenterX.count {
                actorCenterX[i] += shiftX
            }
        }

        // 7. Calculate final lifelines (after shift so X positions are correct)
        // Port of: lines 331-337
        var lifelines: [SequenceLifeline] = []
        for (i, actor) in diagram.actors.enumerated() {
            lifelines.append(SequenceLifeline(
                actorId: actor.id,
                x: actorCenterX[i],
                startY: actorY + c.actorHeight,
                endY: diagramBottom - c.padding
            ))
        }

        // 8. Calculate diagram dimensions from the bounding box
        // Port of: lines 339-352
        let diagramWidth = globalMaxX + shiftX + c.padding
        let diagramHeight = diagramBottom

        return PositionedSequenceDiagram(
            width: max(diagramWidth, 200),
            height: max(diagramHeight, 100),
            actors: actors,
            lifelines: lifelines,
            messages: messages,
            activations: activations,
            blocks: blocks,
            notes: notes
        )
    }

    // MARK: - Text Measurement Helpers

    private func measureText(_ text: String, fontSize: CGFloat, fontWeight: Int) -> CGFloat {
        let config = RenderConfig.shared
        return config.estimateTextWidth(text, fontSize: fontSize, fontWeight: fontWeight)
    }

    private func measureNoteHeight(_ text: String) -> CGFloat {
        let lineCount = max(1, text.components(separatedBy: "\n").count)
        let lineHeight: CGFloat = 16
        return CGFloat(lineCount) * lineHeight + SequenceConstants.notePadding * 2
    }
}
