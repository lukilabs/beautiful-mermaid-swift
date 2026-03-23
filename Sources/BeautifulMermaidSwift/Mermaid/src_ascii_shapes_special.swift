// Ported from original/src/ascii/shapes/special.ts
import Foundation
import ElkSwift

private func _shapeBaseBoxDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
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

private func _shapeRenderPlainBox(
    _ label: String,
    _ dimensions: ShapeDimensions,
    _ options: ShapeRenderOptions,
    _ topLeft: Character,
    _ topRight: Character,
    _ bottomLeft: Character,
    _ bottomRight: Character,
    _ h: Character,
    _ v: Character
) -> Canvas {
    let width = dimensions.width
    let height = dimensions.height
    var canvas = mkCanvas(width - 1, height - 1)

    canvas[0][0] = topLeft
    canvas[width - 1][0] = topRight
    canvas[0][height - 1] = bottomLeft
    canvas[width - 1][height - 1] = bottomRight

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
        let textX = (width / 2) - (line.count / 2)
        let y = startY + i
        for (j, ch) in line.enumerated() {
            let x = textX + j
            if x > 0, x < width - 1, y > 0, y < height - 1 {
                canvas[x][y] = ch
            }
        }
    }

    _ = options
    return canvas
}

private func _shapeBoxAttachmentPoint(
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

public let subroutineRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: { label, options in
        let lines = splitLines(label)
        let maxLineWidth = max(lines.map(\.count).max() ?? 0, 0)
        let lineCount = max(lines.count, 1)

        let innerWidth = 2 * options.padding + maxLineWidth
        let width = innerWidth + 4
        let innerHeight = lineCount + 2 * options.padding
        let height = innerHeight + 2

        return ShapeDimensions(
            width: width,
            height: height,
            labelArea: ShapeLabelArea(
                x: 2 + options.padding,
                y: 1 + options.padding,
                width: maxLineWidth,
                height: lineCount
            ),
            gridColumns: [2, innerWidth, 2],
            gridRows: [1, innerHeight, 1]
        )
    },
    renderFn: { label, dimensions, options in
        let width = dimensions.width
        let height = dimensions.height
        var canvas = mkCanvas(width - 1, height - 1)

        let hChar: Character = options.useAscii ? "-" : "─"
        let vChar: Character = options.useAscii ? "|" : "│"

        canvas[0][0] = options.useAscii ? "+" : "┌"
        canvas[1][0] = options.useAscii ? "+" : "┬"
        if width > 4 {
            for x in 2 ..< (width - 2) {
                canvas[x][0] = hChar
            }
        }
        canvas[width - 2][0] = options.useAscii ? "+" : "┬"
        canvas[width - 1][0] = options.useAscii ? "+" : "┐"

        if height > 2 {
            for y in 1 ..< (height - 1) {
                canvas[0][y] = vChar
                canvas[1][y] = vChar
                canvas[width - 2][y] = vChar
                canvas[width - 1][y] = vChar
            }
        }

        canvas[0][height - 1] = options.useAscii ? "+" : "└"
        canvas[1][height - 1] = options.useAscii ? "+" : "┴"
        if width > 4 {
            for x in 2 ..< (width - 2) {
                canvas[x][height - 1] = hChar
            }
        }
        canvas[width - 2][height - 1] = options.useAscii ? "+" : "┴"
        canvas[width - 1][height - 1] = options.useAscii ? "+" : "┘"

        let lines = splitLines(label)
        let centerY = height / 2
        let startY = centerY - ((max(lines.count, 1) - 1) / 2)
        for (i, line) in lines.enumerated() {
            let textX = (width / 2) - (line.count / 2)
            let y = startY + i
            for (j, ch) in line.enumerated() {
                let x = textX + j
                if x > 1, x < width - 2, y > 0, y < height - 1 {
                    canvas[x][y] = ch
                }
            }
        }

        return canvas
    },
    getAttachmentPointFn: _shapeBoxAttachmentPoint
)

public let doublecircleRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: _shapeBaseBoxDimensions,
    renderFn: { label, dimensions, options in
        _shapeRenderPlainBox(
            label,
            dimensions,
            options,
            options.useAscii ? "@" : "◎",
            options.useAscii ? "@" : "◎",
            options.useAscii ? "@" : "◎",
            options.useAscii ? "@" : "◎",
            options.useAscii ? "-" : "─",
            options.useAscii ? "|" : "│"
        )
    },
    getAttachmentPointFn: _shapeBoxAttachmentPoint
)

public let cylinderRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: { label, options in
        let lines = splitLines(label)
        let maxLineWidth = max(lines.map(\.count).max() ?? 0, 0)
        let lineCount = max(lines.count, 1)

        let innerWidth = 2 * options.padding + maxLineWidth
        let width = innerWidth + 2
        let innerHeight = lineCount + 2 * options.padding + 2
        let height = innerHeight + 2

        return ShapeDimensions(
            width: width,
            height: height,
            labelArea: ShapeLabelArea(
                x: 1 + options.padding,
                y: 2 + options.padding,
                width: maxLineWidth,
                height: lineCount
            ),
            gridColumns: [1, innerWidth, 1],
            gridRows: [2, innerHeight - 2, 2]
        )
    },
    renderFn: { label, dimensions, options in
        let width = dimensions.width
        let height = dimensions.height
        var canvas = mkCanvas(width - 1, height - 1)

        let hChar: Character = options.useAscii ? "-" : "─"
        let vChar: Character = options.useAscii ? "|" : "│"

        canvas[0][0] = options.useAscii ? "." : "╭"
        if width > 2 {
            for x in 1 ..< (width - 1) {
                canvas[x][0] = hChar
            }
        }
        canvas[width - 1][0] = options.useAscii ? "." : "╮"

        canvas[0][1] = vChar
        if width > 2 {
            for x in 1 ..< (width - 1) {
                canvas[x][1] = hChar
            }
        }
        canvas[width - 1][1] = vChar

        if height > 4 {
            for y in 2 ..< (height - 2) {
                canvas[0][y] = vChar
                canvas[width - 1][y] = vChar
            }
        }

        canvas[0][height - 2] = vChar
        if width > 2 {
            for x in 1 ..< (width - 1) {
                canvas[x][height - 2] = hChar
            }
        }
        canvas[width - 1][height - 2] = vChar

        canvas[0][height - 1] = options.useAscii ? "'" : "╰"
        if width > 2 {
            for x in 1 ..< (width - 1) {
                canvas[x][height - 1] = hChar
            }
        }
        canvas[width - 1][height - 1] = options.useAscii ? "'" : "╯"

        let lines = splitLines(label)
        let centerY = height / 2
        let startY = centerY - ((max(lines.count, 1) - 1) / 2)
        for (i, line) in lines.enumerated() {
            let textX = (width / 2) - (line.count / 2)
            let y = startY + i
            for (j, ch) in line.enumerated() {
                let x = textX + j
                if x > 0, x < width - 1, y > 1, y < height - 2 {
                    canvas[x][y] = ch
                }
            }
        }

        return canvas
    },
    getAttachmentPointFn: _shapeBoxAttachmentPoint
)

public let asymmetricRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: _shapeBaseBoxDimensions,
    renderFn: { label, dimensions, options in
        _shapeRenderPlainBox(
            label,
            dimensions,
            options,
            options.useAscii ? ">" : "▷",
            options.useAscii ? "+" : "┐",
            options.useAscii ? ">" : "▷",
            options.useAscii ? "+" : "┘",
            options.useAscii ? "-" : "─",
            options.useAscii ? "|" : "│"
        )
    },
    getAttachmentPointFn: _shapeBoxAttachmentPoint
)

public let trapezoidRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: _shapeBaseBoxDimensions,
    renderFn: { label, dimensions, options in
        _shapeRenderPlainBox(
            label,
            dimensions,
            options,
            options.useAscii ? "/" : "◸",
            options.useAscii ? "\\" : "◹",
            options.useAscii ? "+" : "└",
            options.useAscii ? "+" : "┘",
            options.useAscii ? "-" : "─",
            options.useAscii ? "|" : "│"
        )
    },
    getAttachmentPointFn: _shapeBoxAttachmentPoint
)

public let trapezoidAltRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: _shapeBaseBoxDimensions,
    renderFn: { label, dimensions, options in
        _shapeRenderPlainBox(
            label,
            dimensions,
            options,
            options.useAscii ? "+" : "┌",
            options.useAscii ? "+" : "┐",
            options.useAscii ? "\\" : "◺",
            options.useAscii ? "/" : "◿",
            options.useAscii ? "-" : "─",
            options.useAscii ? "|" : "│"
        )
    },
    getAttachmentPointFn: _shapeBoxAttachmentPoint
)

open class original_src_ascii_shapes_special {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
