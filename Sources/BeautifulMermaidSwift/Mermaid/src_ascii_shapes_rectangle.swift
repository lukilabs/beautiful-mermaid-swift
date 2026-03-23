// Ported from original/src/ascii/shapes/rectangle.ts
import Foundation
import ElkSwift

private func _shapeSplitLines(_ label: String) -> [String] {
    label.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
}

public func getBoxDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
    let lines = _shapeSplitLines(label)
    let maxLineWidth = max(lines.map { $0.count }.max() ?? 0, 0)
    let lineCount = lines.count

    let innerWidth = 2 * options.padding + maxLineWidth
    let width = innerWidth + 2

    let rawInnerHeight = lineCount + 2 * options.padding
    let innerHeight = rawInnerHeight % 2 == 0 ? rawInnerHeight + 1 : rawInnerHeight
    let height = innerHeight + 2

    return ShapeDimensions(
        width: width,
        height: height,
        labelArea: ShapeLabelArea(
            x: 1 + options.padding,
            y: 1 + options.padding,
            width: maxLineWidth,
            height: lineCount
        ),
        gridColumns: [1, innerWidth, 1],
        gridRows: [1, innerHeight, 1]
    )
}

public func renderBox(
    _ label: String,
    _ dimensions: ShapeDimensions,
    _ corners: CornerChars,
    _ useAscii: Bool
) -> Canvas {
    let width = dimensions.width
    let height = dimensions.height
    var canvas = mkCanvas(width - 1, height - 1)

    let fromX = 0
    let fromY = 0
    let toX = width - 1
    let toY = height - 1

    let hLine: Character = useAscii ? "-" : "─"
    let vLine: Character = useAscii ? "|" : "│"

    if fromX + 1 < toX {
        for x in (fromX + 1)..<toX {
            canvas[x][fromY] = hLine
            canvas[x][toY] = hLine
        }
    }

    if fromY + 1 < toY {
        for y in (fromY + 1)..<toY {
            canvas[fromX][y] = vLine
            canvas[toX][y] = vLine
        }
    }

    canvas[fromX][fromY] = corners.tl
    canvas[toX][fromY] = corners.tr
    canvas[fromX][toY] = corners.bl
    canvas[toX][toY] = corners.br

    let lines = _shapeSplitLines(label)
    let w = width - 1
    let h = height - 1
    let centerY = Int(floor(Double(h) / 2.0))
    let startY = centerY - Int(floor(Double(lines.count - 1) / 2.0))

    for (i, line) in lines.enumerated() {
        let chars = Array(line)
        let textX = Int(floor(Double(w) / 2.0)) - Int(ceil(Double(chars.count) / 2.0)) + 1
        for j in 0..<chars.count {
            let x = textX + j
            let y = startY + i
            if x >= 0, x < canvas.count, y >= 0, y < (canvas.first?.count ?? 0) {
                canvas[x][y] = chars[j]
            }
        }
    }

    return canvas
}

public func getBoxAttachmentPoint(
    _ dir: Direction,
    _ dimensions: ShapeDimensions,
    _ baseCoord: DrawingCoord
) -> DrawingCoord {
    let width = dimensions.width
    let height = dimensions.height
    let centerX = baseCoord.x + Int(floor(Double(width) / 2.0))
    let centerY = baseCoord.y + Int(floor(Double(height) / 2.0))

    if dirEquals(dir, Up) { return DrawingCoord(x: centerX, y: baseCoord.y) }
    if dirEquals(dir, Down) { return DrawingCoord(x: centerX, y: baseCoord.y + height - 1) }
    if dirEquals(dir, Left) { return DrawingCoord(x: baseCoord.x, y: centerY) }
    if dirEquals(dir, Right) { return DrawingCoord(x: baseCoord.x + width - 1, y: centerY) }
    if dirEquals(dir, UpperLeft) { return DrawingCoord(x: baseCoord.x, y: baseCoord.y) }
    if dirEquals(dir, UpperRight) { return DrawingCoord(x: baseCoord.x + width - 1, y: baseCoord.y) }
    if dirEquals(dir, LowerLeft) { return DrawingCoord(x: baseCoord.x, y: baseCoord.y + height - 1) }
    if dirEquals(dir, LowerRight) { return DrawingCoord(x: baseCoord.x + width - 1, y: baseCoord.y + height - 1) }
    return DrawingCoord(x: centerX, y: centerY)
}

public struct RectangleRenderer: ShapeRenderer {
    public init() {}

    public func getDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
        getBoxDimensions(label, options)
    }

    public func render(_ label: String, _ dimensions: ShapeDimensions, _ options: ShapeRenderOptions) -> Canvas {
        let corners = getCorners("rectangle", options.useAscii)
        return renderBox(label, dimensions, corners, options.useAscii)
    }

    public func getAttachmentPoint(_ dir: Direction, _ dimensions: ShapeDimensions, _ baseCoord: DrawingCoord) -> DrawingCoord {
        getBoxAttachmentPoint(dir, dimensions, baseCoord)
    }
}

public let rectangleRenderer: any ShapeRenderer = RectangleRenderer()

open class original_src_ascii_shapes_rectangle {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
