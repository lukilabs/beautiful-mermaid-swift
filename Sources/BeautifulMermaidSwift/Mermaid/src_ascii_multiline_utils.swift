// Ported from original/src/ascii/multiline-utils.ts
import Foundation
import ElkSwift

public func splitLines(_ label: String) -> [String] {
    label.components(separatedBy: "\n")
}

public func maxLineWidth(_ label: String) -> Int {
    let lines = splitLines(label)
    return lines.map(\.count).max() ?? 0
}

public func lineCount(_ label: String) -> Int {
    splitLines(label).count
}

public func drawMultilineTextCentered(
    _ canvas: inout Canvas,
    _ label: String,
    _ cx: Int,
    _ cy: Int
) {
    let lines = splitLines(label)
    let totalHeight = lines.count
    let startY = cy - Int(floor(Double(totalHeight - 1) / 2.0))

    for (i, line) in lines.enumerated() {
        let startX = cx - Int(floor(Double(line.count) / 2.0))
        drawText(&canvas, start: DrawingCoord(x: startX, y: startY + i), text: line, forceOverwrite: true)
    }
}

public func drawMultilineTextLeft(
    _ canvas: inout Canvas,
    _ label: String,
    _ x: Int,
    _ y: Int
) {
    let lines = splitLines(label)
    for (i, line) in lines.enumerated() {
        drawText(&canvas, start: DrawingCoord(x: x, y: y + i), text: line, forceOverwrite: true)
    }
}

open class original_src_ascii_multiline_utils {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export function splitLines
    // - export function maxLineWidth
    // - export function lineCount
    // - export function drawMultilineTextCentered
    // - export function drawMultilineTextLeft
}
