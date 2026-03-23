// Ported from original/src/ascii/shapes/index.ts
import Foundation
import ElkSwift

private func _basicBoxDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
    let lines = splitLines(label)
    let maxLineWidth = max(lines.map(\.count).max() ?? 0, 0)
    let lineCount = max(lines.count, 1)

    let innerWidth = 2 * options.padding + maxLineWidth
    let width = innerWidth + 2
    let innerHeight = lineCount + 2 * options.padding
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

private func _basicBoxRender(_ label: String, _ dimensions: ShapeDimensions, _ options: ShapeRenderOptions) -> Canvas {
    let width = dimensions.width
    let height = dimensions.height
    var canvas = mkCanvas(width - 1, height - 1)

    let tl: Character = options.useAscii ? "+" : "┌"
    let tr: Character = options.useAscii ? "+" : "┐"
    let bl: Character = options.useAscii ? "+" : "└"
    let br: Character = options.useAscii ? "+" : "┘"
    let h: Character = options.useAscii ? "-" : "─"
    let v: Character = options.useAscii ? "|" : "│"

    canvas[0][0] = tl
    canvas[width - 1][0] = tr
    canvas[0][height - 1] = bl
    canvas[width - 1][height - 1] = br

    if width > 2 {
        for x in 1 ..< (width - 1) {
            canvas[x][0] = h
            canvas[x][height - 1] = h
        }
    }
    if height > 2 {
        for y in 1 ..< (height - 1) {
            canvas[0][y] = v
            canvas[width - 1][y] = v
        }
    }

    let lines = splitLines(label)
    let centerY = height / 2
    let startY = centerY - ((max(lines.count, 1) - 1) / 2)
    for (i, line) in lines.enumerated() {
        let startX = (width / 2) - (line.count / 2)
        let y = startY + i
        for (j, ch) in line.enumerated() {
            let x = startX + j
            if x > 0, x < width - 1, y > 0, y < height - 1 {
                canvas[x][y] = ch
            }
        }
    }

    return canvas
}

private func _basicAttachment(_ dir: Direction, _ dimensions: ShapeDimensions, _ baseCoord: DrawingCoord) -> DrawingCoord {
    let centerX = baseCoord.x + (dimensions.width / 2)
    let centerY = baseCoord.y + (dimensions.height / 2)

    if dirEquals(dir, Up) {
        return DrawingCoord(x: centerX, y: baseCoord.y)
    }
    if dirEquals(dir, Down) {
        return DrawingCoord(x: centerX, y: baseCoord.y + dimensions.height - 1)
    }
    if dirEquals(dir, Left) {
        return DrawingCoord(x: baseCoord.x, y: centerY)
    }
    if dirEquals(dir, Right) {
        return DrawingCoord(x: baseCoord.x + dimensions.width - 1, y: centerY)
    }
    return DrawingCoord(x: centerX, y: centerY)
}

private let _defaultBoxRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: _basicBoxDimensions,
    renderFn: _basicBoxRender,
    getAttachmentPointFn: _basicAttachment
)

public let shapeRegistry: ShapeRegistry = [
    "rectangle": _defaultBoxRenderer,
    "rounded": _defaultBoxRenderer,
    "diamond": _defaultBoxRenderer,
    "stadium": _defaultBoxRenderer,
    "circle": _defaultBoxRenderer,
    "subroutine": subroutineRenderer,
    "doublecircle": doublecircleRenderer,
    "hexagon": _defaultBoxRenderer,
    "cylinder": cylinderRenderer,
    "asymmetric": asymmetricRenderer,
    "trapezoid": trapezoidRenderer,
    "trapezoid-alt": trapezoidAltRenderer,
    "state-start": stateStartRenderer,
    "state-end": stateEndRenderer,
]

public func getShapeRenderer(_ shape: AsciiNodeShape) -> any ShapeRenderer {
    shapeRegistry[shape] ?? _defaultBoxRenderer
}

public func renderShape(
    _ shape: AsciiNodeShape,
    _ label: String,
    _ options: ShapeRenderOptions
) -> Canvas {
    let renderer = getShapeRenderer(shape)
    let dimensions = renderer.getDimensions(label, options)
    return renderer.render(label, dimensions, options)
}

public func getShapeDimensions(
    _ shape: AsciiNodeShape,
    _ label: String,
    _ options: ShapeRenderOptions
) -> ShapeDimensions {
    getShapeRenderer(shape).getDimensions(label, options)
}

public func getShapeAttachmentPoint(
    _ shape: AsciiNodeShape,
    _ dir: Direction,
    _ dimensions: ShapeDimensions,
    _ baseCoord: DrawingCoord
) -> DrawingCoord {
    getShapeRenderer(shape).getAttachmentPoint(dir, dimensions, baseCoord)
}

open class original_src_ascii_shapes_index {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
