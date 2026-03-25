// Ported from original/src/sequence/layout.ts
import Foundation
import ElkSwift

private enum _SEQ {
    static let padding: Double = 30
    static let actorGap: Double = 140
    static let actorHeight: Double = 40
    static let actorPadX: Double = 16
    static let headerGap: Double = 20
    static let messageRowHeight: Double = 40
    static let selfMessageHeight: Double = 30
    static let activationWidth: Double = 10
    static let blockPadX: Double = 10
    static let blockPadTop: Double = 40
    static let blockPadBottom: Double = 8
    static let blockHeaderExtra: Double = 28
    static let dividerExtra: Double = 24
    static let noteWidth: Double = 120
    static let notePadding: Double = 8
    static let noteGap: Double = 10
}

public func layoutSequenceDiagram(
    _ diagram: SequenceDiagram,
    _ options: RenderOptions = RenderOptions()
) throws -> PositionedSequenceDiagram {
    try _layoutSequenceDiagramEntry(diagram, options)
}

private func _layoutSequenceDiagramEntry(
    _ diagram: SequenceDiagram,
    _ options: RenderOptions
) throws -> PositionedSequenceDiagram {
    _ = options

    if diagram.actors.isEmpty {
        return PositionedSequenceDiagram(
            width: 0,
            height: 0,
            actors: [],
            lifelines: [],
            messages: [],
            activations: [],
            blocks: [],
            notes: []
        )
    }

    let actorWidths = diagram.actors.map { actor in
        let textW = original_src_styles.estimateTextWidth(
            actor.label,
            original_src_styles.FONT_SIZES.nodeLabel,
            original_src_styles.FONT_WEIGHTS.nodeLabel
        )
        return max(textW + _SEQ.actorPadX * 2, 80)
    }

    var actorCenterX: [Double] = []
    var currentX = _SEQ.padding + actorWidths[0] / 2
    for i in 0..<diagram.actors.count {
        if i > 0 {
            let minGap = max(_SEQ.actorGap, (actorWidths[i - 1] + actorWidths[i]) / 2 + 40)
            currentX += minGap
        }
        actorCenterX.append(currentX)
    }

    var actorIndex: [String: Int] = [:]
    for i in 0..<diagram.actors.count {
        actorIndex[diagram.actors[i].id] = i
    }

    let actorY = _SEQ.padding
    let actors: [PositionedSequenceActor] = diagram.actors.enumerated().map { idx, actor in
        PositionedSequenceActor(
            id: actor.id,
            label: actor.label,
            type: actor.type,
            x: actorCenterX[idx],
            y: actorY,
            width: actorWidths[idx],
            height: _SEQ.actorHeight
        )
    }

    var messageY = actorY + _SEQ.actorHeight + _SEQ.headerGap
    var messages: [PositionedSequenceMessage] = []

    var extraSpaceBefore: [Int: Double] = [:]
    for block in diagram.blocks {
        extraSpaceBefore[block.startIndex] = max(extraSpaceBefore[block.startIndex] ?? 0, _SEQ.blockHeaderExtra)
        for div in block.dividers {
            extraSpaceBefore[div.index] = max(extraSpaceBefore[div.index] ?? 0, _SEQ.dividerExtra)
        }
    }

    var activationStacks: [String: [(startY: Double, depth: Int)]] = [:]
    var activations: [SequenceActivation] = []
    let nestingOffset = 4.0

    for msgIdx in 0..<diagram.messages.count {
        let msg = diagram.messages[msgIdx]
        let fromIdx = actorIndex[msg.from] ?? 0
        let toIdx = actorIndex[msg.to] ?? 0
        let isSelfMsg = msg.from == msg.to

        let extra = extraSpaceBefore[msgIdx] ?? 0
        if extra > 0 {
            messageY += extra
        }

        // Push messageY down if a note sits between the previous message and this one
        for note in diagram.notes where note.afterIndex == msgIdx - 1 {
            let noteLines = note.text.components(separatedBy: "\n")
            let nonEmpty = noteLines.isEmpty ? [""] : noteLines
            let lineCount = Double(max(1, nonEmpty.count))
            let lineHeight = ceil(original_src_styles.FONT_SIZES.edgeLabel)
            let lineSpacing: Double = 4
            let noteH = lineCount * lineHeight + max(0, lineCount - 1) * lineSpacing + _SEQ.notePadding * 2
            let noteBottom = messageY + 4 + noteH
            let requiredY = noteBottom + _SEQ.noteGap
            messageY = max(messageY, requiredY)
        }

        let x1 = actorCenterX[fromIdx]
        let x2 = actorCenterX[toIdx]

        messages.append(
            PositionedSequenceMessage(
                from: msg.from,
                to: msg.to,
                label: msg.label,
                lineStyle: msg.lineStyle,
                arrowHead: msg.arrowHead,
                x1: x1,
                x2: x2,
                y: messageY,
                isSelf: isSelfMsg
            )
        )

        if msg.activate {
            var stack = activationStacks[msg.to] ?? []
            let depth = stack.count
            stack.append((startY: messageY, depth: depth))
            activationStacks[msg.to] = stack
        }

        if msg.deactivate {
            var stack = activationStacks[msg.from] ?? []
            if !stack.isEmpty {
                let top = stack.removeLast()
                activationStacks[msg.from] = stack

                let idx = actorIndex[msg.from] ?? 0
                let xOffset = Double(top.depth) * nestingOffset
                activations.append(
                    SequenceActivation(
                        actorId: msg.from,
                        x: actorCenterX[idx] - _SEQ.activationWidth / 2 + xOffset,
                        topY: top.startY,
                        bottomY: messageY,
                        width: _SEQ.activationWidth
                    )
                )
            }
        }

        messageY += isSelfMsg ? (_SEQ.selfMessageHeight + _SEQ.messageRowHeight) : _SEQ.messageRowHeight
    }

    for (actorId, stack) in activationStacks {
        for item in stack {
            let idx = actorIndex[actorId] ?? 0
            let xOffset = Double(item.depth) * nestingOffset
            activations.append(
                SequenceActivation(
                    actorId: actorId,
                    x: actorCenterX[idx] - _SEQ.activationWidth / 2 + xOffset,
                    topY: item.startY,
                    bottomY: messageY - _SEQ.messageRowHeight / 2,
                    width: _SEQ.activationWidth
                )
            )
        }
    }

    let blocks: [PositionedSequenceBlock] = diagram.blocks.map { block in
        let startMsg = block.startIndex < messages.count ? messages[block.startIndex] : nil
        let endMsg = block.endIndex < messages.count ? messages[block.endIndex] : nil
        let blockTop = (startMsg?.y ?? messageY) - _SEQ.blockPadTop
        let blockBottom = (endMsg?.y ?? messageY) + _SEQ.blockPadBottom + 12

        var involvedActors = Set<Int>()
        if block.startIndex <= block.endIndex {
            for mi in block.startIndex...block.endIndex where mi >= 0 && mi < diagram.messages.count {
                let m = diagram.messages[mi]
                involvedActors.insert(actorIndex[m.from] ?? 0)
                involvedActors.insert(actorIndex[m.to] ?? 0)
            }
        }

        if involvedActors.isEmpty {
            for ai in 0..<diagram.actors.count {
                involvedActors.insert(ai)
            }
        }

        let minIdx = involvedActors.min() ?? 0
        let maxIdx = involvedActors.max() ?? max(0, diagram.actors.count - 1)
        let blockLeft = actorCenterX[minIdx] - actorWidths[minIdx] / 2 - _SEQ.blockPadX
        let blockRight = actorCenterX[maxIdx] + actorWidths[maxIdx] / 2 + _SEQ.blockPadX

        let positionedDividers: [PositionedSequenceBlockDivider] = block.dividers.map { divider in
            let msg = divider.index < messages.count ? messages[divider.index] : nil
            let msgY = msg?.y ?? messageY
            var offset = 28.0

            if !divider.label.isEmpty, let msg {
                let divLabelText = "[\(divider.label)]"
                let divLabelW = original_src_styles.estimateTextWidth(
                    divLabelText,
                    original_src_styles.FONT_SIZES.edgeLabel,
                    original_src_styles.FONT_WEIGHTS.edgeLabel
                )
                let divLabelLeft = blockLeft + 8
                let divLabelRight = divLabelLeft + divLabelW

                let msgLabelW = original_src_styles.estimateTextWidth(
                    msg.label,
                    original_src_styles.FONT_SIZES.edgeLabel,
                    original_src_styles.FONT_WEIGHTS.edgeLabel
                )
                let msgLabelLeft = msg.isSelf
                    ? msg.x1 + 36
                    : (msg.x1 + msg.x2) / 2 - msgLabelW / 2
                let msgLabelRight = msgLabelLeft + msgLabelW

                if divLabelRight > msgLabelLeft && divLabelLeft < msgLabelRight {
                    offset = 36
                }
            }

            return PositionedSequenceBlockDivider(y: msgY - offset, label: divider.label)
        }

        return PositionedSequenceBlock(
            type: block.type,
            label: block.label,
            x: blockLeft,
            y: blockTop,
            width: blockRight - blockLeft,
            height: blockBottom - blockTop,
            dividers: positionedDividers
        )
    }

    let notes: [PositionedSequenceNote] = diagram.notes.map { note in
        let noteLines = note.text.components(separatedBy: "\n")
        let nonEmpty = noteLines.isEmpty ? [""] : noteLines
        let maxLineWidth = nonEmpty.map {
            original_src_styles.estimateTextWidth(
                $0,
                original_src_styles.FONT_SIZES.edgeLabel,
                original_src_styles.FONT_WEIGHTS.edgeLabel
            )
        }.max() ?? 0
        let noteW = max(_SEQ.noteWidth, maxLineWidth + _SEQ.notePadding * 2)
        let lineCount = Double(max(1, nonEmpty.count))
        let lineHeight = ceil(original_src_styles.FONT_SIZES.edgeLabel)
        let lineSpacing: Double = 4
        let noteH = lineCount * lineHeight + max(0, lineCount - 1) * lineSpacing + _SEQ.notePadding * 2

        let refMsg = note.afterIndex >= 0 && note.afterIndex < messages.count ? messages[note.afterIndex] : nil
        let noteY = (refMsg?.y ?? actorY + _SEQ.actorHeight) + 4

        let firstActorIdx = actorIndex[note.actorIds.first ?? ""] ?? 0
        let noteX: Double
        if note.position == "left" {
            noteX = actorCenterX[firstActorIdx] - actorWidths[firstActorIdx] / 2 - noteW - _SEQ.noteGap
        } else if note.position == "right" {
            noteX = actorCenterX[firstActorIdx] + actorWidths[firstActorIdx] / 2 + _SEQ.noteGap
        } else {
            if note.actorIds.count > 1 {
                let lastActorIdx = actorIndex[note.actorIds.last ?? ""] ?? firstActorIdx
                noteX = (actorCenterX[firstActorIdx] + actorCenterX[lastActorIdx]) / 2 - noteW / 2
            } else {
                noteX = actorCenterX[firstActorIdx] - noteW / 2
            }
        }

        return PositionedSequenceNote(
            text: note.text,
            x: noteX,
            y: noteY,
            width: noteW,
            height: noteH,
            position: note.position,
            actors: note.actorIds
        )
    }

    let diagramBottom = messageY + _SEQ.padding

    var globalMinX = _SEQ.padding
    var globalMaxX = 0.0

    for actor in actors {
        globalMinX = min(globalMinX, actor.x - actor.width / 2)
        globalMaxX = max(globalMaxX, actor.x + actor.width / 2)
    }
    for block in blocks {
        globalMinX = min(globalMinX, block.x)
        globalMaxX = max(globalMaxX, block.x + block.width)
    }
    for note in notes {
        globalMinX = min(globalMinX, note.x)
        globalMaxX = max(globalMaxX, note.x + note.width)
    }
    for msg in messages where msg.isSelf {
        let loopW = 30.0
        let labelPadding = 8.0
        let labelLeft = msg.x1 + loopW + labelPadding
        let labelWidth = original_src_styles.estimateTextWidth(
            msg.label,
            original_src_styles.FONT_SIZES.edgeLabel,
            original_src_styles.FONT_WEIGHTS.edgeLabel
        )
        globalMaxX = max(globalMaxX, labelLeft + labelWidth + 8)
    }

    let shiftX = globalMinX < _SEQ.padding ? _SEQ.padding - globalMinX : 0

    var shiftedActors = actors
    var shiftedMessages = messages
    var shiftedActivations = activations
    var shiftedBlocks = blocks
    var shiftedNotes = notes

    if shiftX > 0 {
        for i in shiftedActors.indices {
            shiftedActors[i].x += shiftX
        }
        for i in shiftedMessages.indices {
            shiftedMessages[i].x1 += shiftX
            shiftedMessages[i].x2 += shiftX
        }
        for i in shiftedActivations.indices {
            shiftedActivations[i].x += shiftX
        }
        for i in shiftedBlocks.indices {
            shiftedBlocks[i].x += shiftX
        }
        for i in shiftedNotes.indices {
            shiftedNotes[i].x += shiftX
        }
        for i in actorCenterX.indices {
            actorCenterX[i] += shiftX
        }
    }

    let lifelines: [SequenceLifeline] = diagram.actors.enumerated().map { idx, actor in
        SequenceLifeline(
            actorId: actor.id,
            x: actorCenterX[idx],
            topY: actorY + _SEQ.actorHeight,
            bottomY: diagramBottom - _SEQ.padding
        )
    }

    let diagramWidth = globalMaxX + shiftX + _SEQ.padding
    let diagramHeight = diagramBottom

    return PositionedSequenceDiagram(
        width: max(diagramWidth, 200),
        height: max(diagramHeight, 100),
        actors: shiftedActors,
        lifelines: lifelines,
        messages: shiftedMessages,
        activations: shiftedActivations,
        blocks: shiftedBlocks,
        notes: shiftedNotes
    )
}

open class original_src_sequence_layout {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    public static func layoutSequenceDiagram(
        _ diagram: SequenceDiagram,
        _ options: RenderOptions = RenderOptions()
    ) throws -> PositionedSequenceDiagram {
        try _layoutSequenceDiagramEntry(diagram, options)
    }
}
