// Ported from original/src/ascii/sequence.ts
import Foundation
import ElkSwift

public struct AsciiSequenceActor {
    public var id: String
    public var label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public struct AsciiSequenceMessage {
    public var from: String
    public var to: String
    public var label: String
    public var lineStyle: String
    public var arrowHead: String

    public init(from: String, to: String, label: String, lineStyle: String = "solid", arrowHead: String = "filled") {
        self.from = from
        self.to = to
        self.label = label
        self.lineStyle = lineStyle
        self.arrowHead = arrowHead
    }
}

public struct AsciiSequenceDivider {
    public var index: Int
    public var label: String?

    public init(index: Int, label: String? = nil) {
        self.index = index
        self.label = label
    }
}

public struct AsciiSequenceBlock {
    public var type: String
    public var label: String?
    public var startIndex: Int
    public var endIndex: Int
    public var dividers: [AsciiSequenceDivider]

    public init(type: String, label: String? = nil, startIndex: Int, endIndex: Int, dividers: [AsciiSequenceDivider] = []) {
        self.type = type
        self.label = label
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.dividers = dividers
    }
}

public struct AsciiSequenceNote {
    public var afterIndex: Int
    public var text: String
    public var position: String
    public var actorIds: [String]

    public init(afterIndex: Int, text: String, position: String, actorIds: [String]) {
        self.afterIndex = afterIndex
        self.text = text
        self.position = position
        self.actorIds = actorIds
    }
}

public struct AsciiSequenceDiagram {
    public var actors: [AsciiSequenceActor]
    public var messages: [AsciiSequenceMessage]
    public var blocks: [AsciiSequenceBlock]
    public var notes: [AsciiSequenceNote]

    public init(
        actors: [AsciiSequenceActor],
        messages: [AsciiSequenceMessage],
        blocks: [AsciiSequenceBlock] = [],
        notes: [AsciiSequenceNote] = []
    ) {
        self.actors = actors
        self.messages = messages
        self.blocks = blocks
        self.notes = notes
    }
}

private struct AsciiSequenceNotePlacement {
    var x: Int
    var y: Int
    var width: Int
    var height: Int
    var lines: [String]
}

private func splitAsciiLines(_ text: String) -> [String] {
    text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
}

private func asciiMaxLineWidth(_ text: String) -> Int {
    splitAsciiLines(text).map { $0.count }.max() ?? 0
}

private func asciiLineCount(_ text: String) -> Int {
    splitAsciiLines(text).count
}

private func sequenceClassifyBoxChar(_ ch: Character) -> CharRole {
    let chars: Set<Character> = ["┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "│", "─", "╭", "╮", "╰", "╯", "+", "-", "|"]
    return chars.contains(ch) ? .border : .text
}

public func renderSequenceAscii(
    _ text: String,
    _ config: AsciiConfig,
    _ colorMode: ColorMode? = nil,
    _ theme: AsciiTheme? = nil
) throws -> String {
    let lines = text
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }

    let parsed = try parseSequenceDiagram(lines)

    let asciiActors = parsed.actors.map { actor in
        AsciiSequenceActor(id: actor.id, label: actor.label)
    }
    let asciiMessages = parsed.messages.map { message in
        AsciiSequenceMessage(
            from: message.from,
            to: message.to,
            label: message.label,
            lineStyle: message.lineStyle,
            arrowHead: message.arrowHead
        )
    }
    let asciiBlocks = parsed.blocks.map { block in
        AsciiSequenceBlock(
            type: block.type,
            label: block.label.isEmpty ? nil : block.label,
            startIndex: block.startIndex,
            endIndex: block.endIndex,
            dividers: block.dividers.map { divider in
                AsciiSequenceDivider(
                    index: divider.index,
                    label: divider.label.isEmpty ? nil : divider.label
                )
            }
        )
    }
    let asciiNotes = parsed.notes.map { note in
        AsciiSequenceNote(
            afterIndex: note.afterIndex,
            text: note.text,
            position: note.position,
            actorIds: note.actorIds
        )
    }

    return renderSequenceAsciiDiagram(
        AsciiSequenceDiagram(
            actors: asciiActors,
            messages: asciiMessages,
            blocks: asciiBlocks,
            notes: asciiNotes
        ),
        config,
        colorMode,
        theme
    )
}

public func renderSequenceAsciiDiagram(
    _ diagram: AsciiSequenceDiagram,
    _ config: AsciiConfig,
    _ colorMode: ColorMode? = nil,
    _ theme: AsciiTheme? = nil
) -> String {
    if diagram.actors.isEmpty {
        return ""
    }

    let useAscii = config.useAscii

    let h: Character = useAscii ? "-" : "─"
    let v: Character = useAscii ? "|" : "│"
    let tl: Character = useAscii ? "+" : "┌"
    let tr: Character = useAscii ? "+" : "┐"
    let bl: Character = useAscii ? "+" : "└"
    let br: Character = useAscii ? "+" : "┘"
    let jt: Character = useAscii ? "+" : "┬"
    let jb: Character = useAscii ? "+" : "┴"
    let jl: Character = useAscii ? "+" : "├"
    let jr: Character = useAscii ? "+" : "┤"

    var actorIdx: [String: Int] = [:]
    for (i, a) in diagram.actors.enumerated() {
        actorIdx[a.id] = i
    }

    let boxPad = 1
    let actorBoxWidths = diagram.actors.map { asciiMaxLineWidth($0.label) + 2 * boxPad + 2 }
    let halfBox = actorBoxWidths.map { Int(ceil(Double($0) / 2.0)) }
    let actorBoxHeights = diagram.actors.map { asciiLineCount($0.label) + 2 }
    let actorBoxH = max(actorBoxHeights.max() ?? 3, 3)

    var adjMaxWidth = Array(repeating: 0, count: max(diagram.actors.count - 1, 0))
    for msg in diagram.messages {
        guard let fi = actorIdx[msg.from], let ti = actorIdx[msg.to] else { continue }
        if fi == ti { continue }
        let lo = min(fi, ti)
        let hi = max(fi, ti)
        let needed = asciiMaxLineWidth(msg.label) + 4
        let numGaps = hi - lo
        if numGaps <= 0 { continue }
        let perGap = Int(ceil(Double(needed) / Double(numGaps)))
        if lo < hi {
            for g in lo..<hi where g < adjMaxWidth.count {
                adjMaxWidth[g] = max(adjMaxWidth[g], perGap)
            }
        }
    }

    var llX = Array(repeating: 0, count: diagram.actors.count)
    if !diagram.actors.isEmpty {
        llX[0] = halfBox[0]
    }
    if diagram.actors.count > 1 {
        for i in 1..<diagram.actors.count {
            let gap = max(halfBox[i - 1] + halfBox[i] + 2, max(adjMaxWidth[i - 1] + 2, 10))
            llX[i] = llX[i - 1] + gap
        }
    }

    var msgArrowY: [Int] = Array(repeating: 0, count: diagram.messages.count)
    var msgLabelY: [Int] = Array(repeating: 0, count: diagram.messages.count)
    var blockStartY: [Int: Int] = [:]
    var blockEndY: [Int: Int] = [:]
    var divYMap: [String: Int] = [:]
    var notePositions: [AsciiSequenceNotePlacement] = []

    var curY = actorBoxH

    if !diagram.messages.isEmpty {
        for m in 0..<diagram.messages.count {
            for b in 0..<diagram.blocks.count where diagram.blocks[b].startIndex == m {
                curY += 2
                blockStartY[b] = curY - 1
            }

            for b in 0..<diagram.blocks.count {
                let block = diagram.blocks[b]
                for d in 0..<block.dividers.count where block.dividers[d].index == m {
                    curY += 1
                    divYMap["\(b):\(d)"] = curY
                    curY += 1
                }
            }

            curY += 1
            let msg = diagram.messages[m]
            let isSelfMsg = msg.from == msg.to
            let msgLines = asciiLineCount(msg.label)

            if isSelfMsg {
                msgLabelY[m] = curY + 1
                msgArrowY[m] = curY
                curY += 2 + msgLines
            } else {
                msgLabelY[m] = curY
                msgArrowY[m] = curY + msgLines
                curY += msgLines + 1
            }

            for note in diagram.notes where note.afterIndex == m {
                curY += 1
                let nLines = splitAsciiLines(note.text)
                let nWidth = (nLines.map { $0.count }.max() ?? 0) + 4
                let nHeight = nLines.count + 2

                let aIdx = actorIdx[note.actorIds.first ?? ""] ?? 0
                var nx: Int
                switch note.position {
                case "left":
                    nx = llX[aIdx] - nWidth - 1
                case "right":
                    nx = llX[aIdx] + 2
                default:
                    if note.actorIds.count >= 2 {
                        let aIdx2 = actorIdx[note.actorIds[1]] ?? aIdx
                        nx = Int(floor(Double(llX[aIdx] + llX[aIdx2]) / 2.0)) - Int(floor(Double(nWidth) / 2.0))
                    } else {
                        nx = llX[aIdx] - Int(floor(Double(nWidth) / 2.0))
                    }
                }
                nx = max(0, nx)

                notePositions.append(AsciiSequenceNotePlacement(x: nx, y: curY, width: nWidth, height: nHeight, lines: nLines))
                curY += nHeight
            }

            for b in 0..<diagram.blocks.count where diagram.blocks[b].endIndex == m {
                curY += 1
                blockEndY[b] = curY
                curY += 1
            }
        }
    }

    curY += 1
    let footerY = curY
    let totalH = footerY + actorBoxH

    let lastLL = llX.last ?? 0
    let lastHalf = halfBox.last ?? 0
    var totalW = lastLL + lastHalf + 2

    for msg in diagram.messages {
        if msg.from == msg.to {
            let fi = actorIdx[msg.from] ?? 0
            let selfRight = llX[fi] + 6 + 2 + msg.label.count
            totalW = max(totalW, selfRight + 1)
        }
    }
    for np in notePositions {
        totalW = max(totalW, np.x + np.width + 1)
    }

    var canvas = mkCanvas(totalW, max(0, totalH - 1))
    var rc = mkRoleCanvas(totalW, max(0, totalH - 1))

    func setC(_ x: Int, _ y: Int, _ ch: Character, _ role: CharRole) {
        if x >= 0, y >= 0 {
            if x >= canvas.count || y >= (canvas.first?.count ?? 0) {
                _ = increaseSize(&canvas, x, y)
                _ = increaseRoleCanvasSize(&rc, x, y)
            }
            if x < canvas.count, y < (canvas.first?.count ?? 0) {
                canvas[x][y] = ch
                setRole(&rc, x, y, role)
            }
        }
    }

    func drawActorBox(_ cx: Int, _ topY: Int, _ label: String) {
        let lines = splitAsciiLines(label)
        let maxW = asciiMaxLineWidth(label)
        let w = maxW + (2 * boxPad) + 2
        let hBox = lines.count + 2
        let left = cx - Int(floor(Double(w) / 2.0))

        setC(left, topY, tl, .border)
        if w > 2 {
            for x in 1..<(w - 1) {
                setC(left + x, topY, h, .border)
            }
        }
        setC(left + w - 1, topY, tr, .border)

        for (i, line) in lines.enumerated() {
            let row = topY + 1 + i
            setC(left, row, v, .border)
            setC(left + w - 1, row, v, .border)
            let ls = left + 1 + boxPad + Int(floor(Double(maxW - line.count) / 2.0))
            for (j, ch) in line.enumerated() {
                setC(ls + j, row, ch, .text)
            }
        }

        let bottomY = topY + hBox - 1
        setC(left, bottomY, bl, .border)
        if w > 2 {
            for x in 1..<(w - 1) {
                setC(left + x, bottomY, h, .border)
            }
        }
        setC(left + w - 1, bottomY, br, .border)
    }

    for i in 0..<diagram.actors.count {
        let x = llX[i]
        if actorBoxH <= footerY {
            for y in actorBoxH...footerY {
                setC(x, y, v, .line)
            }
        }
    }

    for i in 0..<diagram.actors.count {
        let actor = diagram.actors[i]
        drawActorBox(llX[i], 0, actor.label)
        drawActorBox(llX[i], footerY, actor.label)

        if !useAscii {
            setC(llX[i], actorBoxH - 1, jt, .junction)
            setC(llX[i], footerY, jb, .junction)
        }
    }

    for m in 0..<diagram.messages.count {
        let msg = diagram.messages[m]
        guard let fi = actorIdx[msg.from], let ti = actorIdx[msg.to] else { continue }
        let fromX = llX[fi]
        let toX = llX[ti]
        let isSelfMsg = fi == ti
        let isDashed = msg.lineStyle == "dashed"
        let isFilled = msg.arrowHead == "filled"

        let lineChar: Character = isDashed ? (useAscii ? "." : "╌") : h

        if isSelfMsg {
            let y0 = msgArrowY[m]
            let loopW = max(4, 4)

            setC(fromX, y0, jl, .junction)
            if fromX + 1 < fromX + loopW {
                for x in (fromX + 1)..<(fromX + loopW) {
                    setC(x, y0, lineChar, .line)
                }
            }
            setC(fromX + loopW, y0, useAscii ? "+" : "┐", .corner)

            setC(fromX + loopW, y0 + 1, v, .line)
            let labelX = fromX + loopW + 2
            let selfLabelLines = splitAsciiLines(msg.label)
            for (lineIdx, selfLine) in selfLabelLines.enumerated() {
                for (i, ch) in selfLine.enumerated() {
                    if labelX + i < totalW {
                        setC(labelX + i, y0 + 1 + lineIdx, ch, .text)
                    }
                }
            }

            let arrowChar: Character = isFilled ? (useAscii ? "<" : "◀") : (useAscii ? "<" : "◁")
            setC(fromX, y0 + 2, arrowChar, .arrow)
            if fromX + 1 < fromX + loopW {
                for x in (fromX + 1)..<(fromX + loopW) {
                    setC(x, y0 + 2, lineChar, .line)
                }
            }
            setC(fromX + loopW, y0 + 2, useAscii ? "+" : "┘", .corner)
        } else {
            let labelY = msgLabelY[m]
            let arrowY = msgArrowY[m]
            let leftToRight = fromX < toX

            let midX = Int(floor(Double(fromX + toX) / 2.0))
            let msgLines = splitAsciiLines(msg.label)
            for (lineIdx, line) in msgLines.enumerated() {
                let labelStart = midX - Int(floor(Double(line.count) / 2.0))
                let y = labelY + lineIdx
                for (i, ch) in line.enumerated() {
                    let lx = labelStart + i
                    if lx >= 0, lx < totalW {
                        setC(lx, y, ch, .text)
                    }
                }
            }

            if leftToRight {
                if fromX + 1 < toX {
                    for x in (fromX + 1)..<toX {
                        setC(x, arrowY, lineChar, .line)
                    }
                }
                let ah: Character = isFilled ? (useAscii ? ">" : "▶") : (useAscii ? ">" : "▷")
                setC(toX, arrowY, ah, .arrow)
            } else {
                if toX + 1 < fromX {
                    for x in (toX + 1)..<fromX {
                        setC(x, arrowY, lineChar, .line)
                    }
                }
                let ah: Character = isFilled ? (useAscii ? "<" : "◀") : (useAscii ? "<" : "◁")
                setC(toX, arrowY, ah, .arrow)
            }
        }
    }

    for b in 0..<diagram.blocks.count {
        let block = diagram.blocks[b]
        guard let topY = blockStartY[b], let botY = blockEndY[b] else { continue }

        var minLX = totalW
        var maxLX = 0
        if block.startIndex <= block.endIndex {
            for m in block.startIndex...block.endIndex {
                if m >= diagram.messages.count { break }
                let msg = diagram.messages[m]
                let f = actorIdx[msg.from] ?? 0
                let t = actorIdx[msg.to] ?? 0
                minLX = min(minLX, llX[min(f, t)])
                maxLX = max(maxLX, llX[max(f, t)])
            }
        }

        let bLeft = max(0, minLX - 4)
        let bRight = min(totalW - 1, maxLX + 4)

        setC(bLeft, topY, tl, .border)
        if bLeft + 1 < bRight {
            for x in (bLeft + 1)..<bRight {
                setC(x, topY, h, .border)
            }
        }
        setC(bRight, topY, tr, .border)

        let hdrLabel = block.label.map { "\(block.type) [\($0)]" } ?? block.type
        let hdrLines = splitAsciiLines(hdrLabel)
        for (lineIdx, line) in hdrLines.enumerated() where topY + lineIdx < botY {
            for (i, ch) in line.enumerated() where bLeft + 1 + i < bRight {
                setC(bLeft + 1 + i, topY + lineIdx, ch, .text)
            }
        }

        setC(bLeft, botY, bl, .border)
        if bLeft + 1 < bRight {
            for x in (bLeft + 1)..<bRight {
                setC(x, botY, h, .border)
            }
        }
        setC(bRight, botY, br, .border)

        if topY + 1 < botY {
            for y in (topY + 1)..<botY {
                setC(bLeft, y, v, .border)
                setC(bRight, y, v, .border)
            }
        }

        for d in 0..<block.dividers.count {
            guard let dY = divYMap["\(b):\(d)"] else { continue }
            let dashChar: Character = useAscii ? "-" : "╌"
            setC(bLeft, dY, jl, .junction)
            if bLeft + 1 < bRight {
                for x in (bLeft + 1)..<bRight {
                    setC(x, dY, dashChar, .line)
                }
            }
            setC(bRight, dY, jr, .junction)
            if let dLabel = block.dividers[d].label {
                let dStr = "[\(dLabel)]"
                for (i, ch) in dStr.enumerated() where bLeft + 1 + i < bRight {
                    setC(bLeft + 1 + i, dY, ch, .text)
                }
            }
        }
    }

    for np in notePositions {
        _ = increaseSize(&canvas, np.x + np.width, np.y + np.height)
        _ = increaseRoleCanvasSize(&rc, np.x + np.width, np.y + np.height)

        setC(np.x, np.y, tl, .border)
        if np.width > 2 {
            for x in 1..<(np.width - 1) {
                setC(np.x + x, np.y, h, .border)
            }
        }
        setC(np.x + np.width - 1, np.y, tr, .border)

        for (l, line) in np.lines.enumerated() {
            let ly = np.y + 1 + l
            setC(np.x, ly, v, .border)
            setC(np.x + np.width - 1, ly, v, .border)
            for (i, ch) in line.enumerated() {
                setC(np.x + 2 + i, ly, ch, .text)
            }
        }

        let by = np.y + np.height - 1
        setC(np.x, by, bl, .border)
        if np.width > 2 {
            for x in 1..<(np.width - 1) {
                setC(np.x + x, by, h, .border)
            }
        }
        setC(np.x + np.width - 1, by, br, .border)
    }

    _ = sequenceClassifyBoxChar("+")
    return canvasToString(
        canvas,
        options: CanvasToStringOptions(roleCanvas: rc, colorMode: colorMode, theme: theme)
    )
}

open class original_src_ascii_sequence {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
