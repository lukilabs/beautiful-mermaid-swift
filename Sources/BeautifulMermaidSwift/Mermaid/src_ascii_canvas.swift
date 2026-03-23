// Ported from original/src/ascii/canvas.ts
import Foundation
import ElkSwift

// Global compatibility aliases expected by ascii/*.swift modules.
public typealias AsciiNodeShape = original_src_ascii_types.AsciiNodeShape
public typealias GridCoord = original_src_ascii_types.GridCoord
public typealias DrawingCoord = original_src_ascii_types.DrawingCoord
public typealias Direction = original_src_ascii_types.Direction
public let Up = original_src_ascii_types.Up
public let Down = original_src_ascii_types.Down
public let Left = original_src_ascii_types.Left
public let Right = original_src_ascii_types.Right
public let UpperRight = original_src_ascii_types.UpperRight
public let UpperLeft = original_src_ascii_types.UpperLeft
public let LowerRight = original_src_ascii_types.LowerRight
public let LowerLeft = original_src_ascii_types.LowerLeft
public let Middle = original_src_ascii_types.Middle
public let ALL_DIRECTIONS = original_src_ascii_types.ALL_DIRECTIONS
public typealias Canvas = original_src_ascii_types.Canvas
public typealias AsciiStyleClass = original_src_ascii_types.AsciiStyleClass
public typealias AsciiEdgeStyle = original_src_ascii_types.AsciiEdgeStyle
public typealias AsciiNode = original_src_ascii_types.AsciiNode
public typealias AsciiEdge = original_src_ascii_types.AsciiEdge
public typealias AsciiSubgraph = original_src_ascii_types.AsciiSubgraph
public typealias AsciiConfig = original_src_ascii_types.AsciiConfig
public typealias AsciiGraph = original_src_ascii_types.AsciiGraph
public typealias CharRole = original_src_ascii_types.CharRole
public typealias RoleCanvas = [[CharRole?]]
public typealias AsciiTheme = original_src_ascii_types.AsciiTheme
public typealias ColorMode = original_src_ascii_types.ColorMode
public typealias EdgeBundle = original_src_ascii_types.EdgeBundle

public struct CanvasToStringOptions: Sendable {
    public var roleCanvas: RoleCanvas?
    public var colorMode: ColorMode?
    public var theme: AsciiTheme?

    public init(roleCanvas: RoleCanvas? = nil, colorMode: ColorMode? = nil, theme: AsciiTheme? = nil) {
        self.roleCanvas = roleCanvas
        self.colorMode = colorMode
        self.theme = theme
    }
}

public func mkCanvas(_ x: Int, _ y: Int) -> Canvas {
    let maxX = max(0, x)
    let maxY = max(0, y)
    return (0 ... maxX).map { _ in Array(repeating: Character(" "), count: maxY + 1) }
}

public func copyCanvas(_ source: Canvas) -> Canvas {
    let (maxX, maxY) = getCanvasSize(source)
    return mkCanvas(maxX, maxY)
}

public func mkRoleCanvas(_ x: Int, _ y: Int) -> RoleCanvas {
    let maxX = max(0, x)
    let maxY = max(0, y)
    return (0 ... maxX).map { _ in Array(repeating: nil, count: maxY + 1) }
}

public func copyRoleCanvas(_ source: RoleCanvas) -> RoleCanvas {
    let maxX = max(0, source.count - 1)
    let maxY = max(0, (source.first?.count ?? 1) - 1)
    return mkRoleCanvas(maxX, maxY)
}

@discardableResult
public func increaseRoleCanvasSize(_ roleCanvas: inout RoleCanvas, _ newX: Int, _ newY: Int) -> RoleCanvas {
    let currX = max(0, roleCanvas.count - 1)
    let currY = max(0, (roleCanvas.first?.count ?? 1) - 1)
    let targetX = max(newX, currX)
    let targetY = max(newY, currY)

    var grown = mkRoleCanvas(targetX, targetY)
    for x in 0 ..< grown.count {
        for y in 0 ..< grown[0].count {
            if x < roleCanvas.count, y < (roleCanvas.first?.count ?? 0) {
                grown[x][y] = roleCanvas[x][y]
            }
        }
    }

    roleCanvas = grown
    return roleCanvas
}

public func setRole(_ roleCanvas: inout RoleCanvas, _ x: Int, _ y: Int, _ role: CharRole) {
    if x >= roleCanvas.count || y >= (roleCanvas.first?.count ?? 0) {
        _ = increaseRoleCanvasSize(&roleCanvas, x, y)
    }
    if x >= 0, x < roleCanvas.count, y >= 0, y < (roleCanvas.first?.count ?? 0) {
        roleCanvas[x][y] = role
    }
}

public func mergeRoleCanvases(_ base: RoleCanvas, _ offset: DrawingCoord, _ overlays: RoleCanvas...) -> RoleCanvas {
    var maxX = max(0, base.count - 1)
    var maxY = max(0, (base.first?.count ?? 1) - 1)

    for overlay in overlays {
        let oX = max(0, overlay.count - 1)
        let oY = max(0, (overlay.first?.count ?? 1) - 1)
        maxX = max(maxX, oX + offset.x)
        maxY = max(maxY, oY + offset.y)
    }

    var merged = mkRoleCanvas(maxX, maxY)
    for x in 0 ... maxX {
        for y in 0 ... maxY {
            if x < base.count, y < (base.first?.count ?? 0) {
                merged[x][y] = base[x][y]
            }
        }
    }

    for overlay in overlays {
        for x in 0 ..< overlay.count {
            for y in 0 ..< (overlay.first?.count ?? 0) {
                if let role = overlay[x][y] {
                    let mx = x + offset.x
                    let my = y + offset.y
                    if mx >= 0, mx < merged.count, my >= 0, my < (merged.first?.count ?? 0) {
                        merged[mx][my] = role
                    }
                }
            }
        }
    }

    return merged
}

public func getCanvasSize(_ canvas: Canvas) -> (Int, Int) {
    (max(0, canvas.count - 1), max(0, (canvas.first?.count ?? 1) - 1))
}

@discardableResult
public func increaseSize(_ canvas: inout Canvas, _ newX: Int, _ newY: Int) -> Canvas {
    let (currX, currY) = getCanvasSize(canvas)
    let targetX = max(newX, currX)
    let targetY = max(newY, currY)

    var grown = mkCanvas(targetX, targetY)
    for x in 0 ..< grown.count {
        for y in 0 ..< grown[0].count {
            if x < canvas.count, y < (canvas.first?.count ?? 0) {
                grown[x][y] = canvas[x][y]
            }
        }
    }

    canvas = grown
    return canvas
}

private let JUNCTION_CHARS: Set<Character> = [
    "─", "│", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "╴", "╵", "╶", "╷",
]

public func isJunctionChar(_ c: Character) -> Bool {
    JUNCTION_CHARS.contains(c)
}

private let JUNCTION_MAP: [Character: [Character: Character]] = [
    "─": ["│": "┼", "┌": "┬", "┐": "┬", "└": "┴", "┘": "┴", "├": "┼", "┤": "┼", "┬": "┬", "┴": "┴"],
    "│": ["─": "┼", "┌": "├", "┐": "┤", "└": "├", "┘": "┤", "├": "├", "┤": "┤", "┬": "┼", "┴": "┼"],
    "┌": ["─": "┬", "│": "├", "┐": "┬", "└": "├", "┘": "┼", "├": "├", "┤": "┼", "┬": "┬", "┴": "┼"],
    "┐": ["─": "┬", "│": "┤", "┌": "┬", "└": "┼", "┘": "┤", "├": "┼", "┤": "┤", "┬": "┬", "┴": "┼"],
    "└": ["─": "┴", "│": "├", "┌": "├", "┐": "┼", "┘": "┴", "├": "├", "┤": "┼", "┬": "┼", "┴": "┴"],
    "┘": ["─": "┴", "│": "┤", "┌": "┼", "┐": "┤", "└": "┴", "├": "┼", "┤": "┤", "┬": "┼", "┴": "┴"],
    "├": ["─": "┼", "│": "├", "┌": "├", "┐": "┼", "└": "├", "┘": "┼", "┤": "┼", "┬": "┼", "┴": "┼"],
    "┤": ["─": "┼", "│": "┤", "┌": "┼", "┐": "┤", "└": "┼", "┘": "┤", "├": "┼", "┬": "┼", "┴": "┼"],
    "┬": ["─": "┬", "│": "┼", "┌": "┬", "┐": "┬", "└": "┼", "┘": "┼", "├": "┼", "┤": "┼", "┴": "┼"],
    "┴": ["─": "┴", "│": "┼", "┌": "┼", "┐": "┼", "└": "┴", "┘": "┴", "├": "┼", "┤": "┼", "┬": "┼"],
]

public func mergeJunctions(_ c1: Character, _ c2: Character) -> Character {
    JUNCTION_MAP[c1]?[c2] ?? c1
}

private func isAlphanumeric(_ c: Character) -> Bool {
    c.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
}

public func mergeCanvasArray(_ base: Canvas, _ offset: DrawingCoord, _ useAscii: Bool, _ overlays: [Canvas]) -> Canvas {
    var result = base
    for overlay in overlays {
        result = mergeCanvases(result, offset, useAscii, overlay)
    }
    return result
}

public func mergeCanvases(_ base: Canvas, _ offset: DrawingCoord, _ useAscii: Bool, _ overlays: Canvas...) -> Canvas {
    var (maxX, maxY) = getCanvasSize(base)

    for overlay in overlays {
        let (oX, oY) = getCanvasSize(overlay)
        maxX = max(maxX, oX + offset.x)
        maxY = max(maxY, oY + offset.y)
    }

    var merged = mkCanvas(maxX, maxY)

    for x in 0 ... maxX {
        for y in 0 ... maxY {
            if x < base.count, y < (base.first?.count ?? 0) {
                merged[x][y] = base[x][y]
            }
        }
    }

    for overlay in overlays {
        for x in 0 ..< overlay.count {
            for y in 0 ..< (overlay.first?.count ?? 0) {
                let c = overlay[x][y]
                if c == " " { continue }

                let mx = x + offset.x
                let my = y + offset.y
                if mx < 0 || mx >= merged.count || my < 0 || my >= (merged.first?.count ?? 0) {
                    continue
                }

                let current = merged[mx][my]
                if !useAscii && isJunctionChar(c) && isJunctionChar(current) {
                    merged[mx][my] = mergeJunctions(current, c)
                } else if isAlphanumeric(current) && isAlphanumeric(c) {
                    // preserve first-written label text
                } else {
                    merged[mx][my] = c
                }
            }
        }
    }

    return merged
}

public func canvasToString(_ canvas: Canvas, options: CanvasToStringOptions? = nil) -> String {
    let (maxX, maxY) = getCanvasSize(canvas)

    let roleCanvas = options?.roleCanvas
    let colorMode = options?.colorMode ?? .none
    let theme = options?.theme ?? AsciiTheme(
        fg: "#27272a",
        border: "#a1a1aa",
        line: "#71717a",
        arrow: "#52525b",
        corner: "#71717a",
        junction: "#a1a1aa"
    )

    var lines: [String] = []
    for y in 0 ... maxY {
        if colorMode == .none || roleCanvas == nil {
            // Plain text output — no colors
            var line = ""
            for x in 0 ... maxX {
                line.append(canvas[x][y])
            }
            lines.append(line)
        } else {
            guard let rc = roleCanvas else { continue }
            // Colored output — collect chars and roles for this row
            var chars: [String] = []
            var roles: [CharRole?] = []
            for x in 0 ... maxX {
                chars.append(String(canvas[x][y]))
                if x < rc.count, y < (rc[x].count) {
                    roles.append(rc[x][y])
                } else {
                    roles.append(nil)
                }
            }
            lines.append(colorizeLine(chars, roles, theme, colorMode))
        }
    }
    return lines.joined(separator: "\n")
}

private let VERTICAL_FLIP_MAP: [Character: Character] = [
    "▲": "▼", "▼": "▲",
    "◤": "◣", "◣": "◤",
    "◥": "◢", "◢": "◥",
    "^": "v", "v": "^",
    "┌": "└", "└": "┌",
    "┐": "┘", "┘": "┐",
    "┬": "┴", "┴": "┬",
    "╵": "╷", "╷": "╵",
]

@discardableResult
public func flipCanvasVertically(_ canvas: inout Canvas) -> Canvas {
    for i in canvas.indices {
        canvas[i].reverse()
        for y in canvas[i].indices {
            if let mapped = VERTICAL_FLIP_MAP[canvas[i][y]] {
                canvas[i][y] = mapped
            }
        }
    }
    return canvas
}

@discardableResult
public func flipRoleCanvasVertically(_ roleCanvas: inout RoleCanvas) -> RoleCanvas {
    for i in roleCanvas.indices {
        roleCanvas[i].reverse()
    }
    return roleCanvas
}

public func drawText(_ canvas: inout Canvas, start: DrawingCoord, text: String, forceOverwrite: Bool = false) {
    _ = increaseSize(&canvas, start.x + max(0, text.count), start.y)
    for (i, ch) in text.enumerated() {
        let x = start.x + i
        guard x >= 0, x < canvas.count, start.y >= 0, start.y < (canvas.first?.count ?? 0) else { continue }
        if forceOverwrite || canvas[x][start.y] == " " {
            canvas[x][start.y] = ch
        }
    }
}

public func setCanvasSizeToGrid(
    _ canvas: inout Canvas,
    _ columnWidth: [Int: Int],
    _ rowHeight: [Int: Int]
) {
    let maxX = columnWidth.values.reduce(0, +)
    let maxY = rowHeight.values.reduce(0, +)
    _ = increaseSize(&canvas, maxX - 1, maxY - 1)
}

public func setRoleCanvasSizeToGrid(
    _ roleCanvas: inout RoleCanvas,
    _ columnWidth: [Int: Int],
    _ rowHeight: [Int: Int]
) {
    let maxX = columnWidth.values.reduce(0, +)
    let maxY = rowHeight.values.reduce(0, +)
    _ = increaseRoleCanvasSize(&roleCanvas, maxX - 1, maxY - 1)
}

open class original_src_ascii_canvas {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
