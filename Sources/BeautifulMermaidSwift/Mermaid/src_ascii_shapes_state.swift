// Ported from original/src/ascii/shapes/state.ts
import Foundation
import ElkSwift

private func _stateDimensions() -> ShapeDimensions {
    ShapeDimensions(
        width: 5,
        height: 3,
        labelArea: ShapeLabelArea(x: 2, y: 1, width: 1, height: 1),
        gridColumns: [1, 3, 1],
        gridRows: [1, 1, 1]
    )
}

private func _stateAttachmentPoint(
    _ dir: Direction,
    _ dimensions: ShapeDimensions,
    _ baseCoord: DrawingCoord
) -> DrawingCoord {
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

public let stateStartRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: { _, _ in _stateDimensions() },
    renderFn: { _, dimensions, options in
        let width = dimensions.width
        _ = dimensions.height
        var canvas = mkCanvas(dimensions.width - 1, dimensions.height - 1)
        let centerX = width / 2

        if !options.useAscii {
            canvas[0][0] = "╭"
            canvas[1][0] = "─"
            canvas[2][0] = "─"
            canvas[3][0] = "─"
            canvas[4][0] = "╮"

            canvas[0][1] = "│"
            canvas[centerX][1] = "●"
            canvas[4][1] = "│"

            canvas[0][2] = "╰"
            canvas[1][2] = "─"
            canvas[2][2] = "─"
            canvas[3][2] = "─"
            canvas[4][2] = "╯"
        } else {
            canvas[0][0] = "."
            canvas[1][0] = "-"
            canvas[2][0] = "-"
            canvas[3][0] = "-"
            canvas[4][0] = "."

            canvas[0][1] = "|"
            canvas[centerX][1] = "*"
            canvas[4][1] = "|"

            canvas[0][2] = "'"
            canvas[1][2] = "-"
            canvas[2][2] = "-"
            canvas[3][2] = "-"
            canvas[4][2] = "'"
        }

        return canvas
    },
    getAttachmentPointFn: _stateAttachmentPoint
)

public let stateEndRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: { _, _ in _stateDimensions() },
    renderFn: { _, dimensions, options in
        let width = dimensions.width
        _ = dimensions.height
        var canvas = mkCanvas(dimensions.width - 1, dimensions.height - 1)
        let centerX = width / 2

        if !options.useAscii {
            canvas[0][0] = "╔"
            canvas[1][0] = "═"
            canvas[2][0] = "═"
            canvas[3][0] = "═"
            canvas[4][0] = "╗"

            canvas[0][1] = "║"
            canvas[centerX][1] = "◎"
            canvas[4][1] = "║"

            canvas[0][2] = "╚"
            canvas[1][2] = "═"
            canvas[2][2] = "═"
            canvas[3][2] = "═"
            canvas[4][2] = "╝"
        } else {
            canvas[0][0] = "#"
            canvas[1][0] = "="
            canvas[2][0] = "="
            canvas[3][0] = "="
            canvas[4][0] = "#"

            canvas[0][1] = "#"
            canvas[centerX][1] = "*"
            canvas[4][1] = "#"

            canvas[0][2] = "#"
            canvas[1][2] = "="
            canvas[2][2] = "="
            canvas[3][2] = "="
            canvas[4][2] = "#"
        }

        return canvas
    },
    getAttachmentPointFn: _stateAttachmentPoint
)

open class original_src_ascii_shapes_state {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
