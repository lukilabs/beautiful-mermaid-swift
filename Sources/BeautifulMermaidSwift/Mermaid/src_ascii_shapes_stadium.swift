// Ported from original/src/ascii/shapes/stadium.ts
import Foundation
import ElkSwift

open class original_src_ascii_shapes_stadium {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export const stadiumRenderer
}

public let stadiumRenderer = ClosureShapeRenderer(
    getDimensionsFn: { label, options in
        let lines = splitLines(label)
        let maxLineWidth = max(lines.map(\.count).max() ?? 0, 0)
        let lineCount = max(lines.count, 1)

        let innerWidth = (2 * options.padding) + maxLineWidth
        let width = innerWidth + 4
        let innerHeight = lineCount + (2 * options.padding)
        let height = max(innerHeight + 2, 3)

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

        let centerY = Int(floor(Double(height) / 2.0))
        let hChar: Character = options.useAscii ? "-" : "─"

        if height == 3 {
            canvas[0][centerY] = "("
            canvas[width - 1][centerY] = ")"
        } else if !options.useAscii {
            canvas[0][0] = "╭"
            if width > 2 {
                for x in 1..<(width - 1) {
                    canvas[x][0] = hChar
                }
            }
            canvas[width - 1][0] = "╮"

            if height > 2 {
                for y in 1..<(height - 1) {
                    canvas[0][y] = "│"
                    canvas[width - 1][y] = "│"
                }
            }

            canvas[0][height - 1] = "╰"
            if width > 2 {
                for x in 1..<(width - 1) {
                    canvas[x][height - 1] = hChar
                }
            }
            canvas[width - 1][height - 1] = "╯"
        } else {
            for y in 0..<height {
                canvas[0][y] = "("
                canvas[width - 1][y] = ")"
            }
            if width > 2 {
                for x in 1..<(width - 1) {
                    canvas[x][0] = hChar
                    canvas[x][height - 1] = hChar
                }
            }
        }

        let lines = splitLines(label)
        let startY = centerY - Int(floor(Double(lines.count - 1) / 2.0))
        for (i, line) in lines.enumerated() {
            let textX = Int(floor(Double(width) / 2.0)) - Int(floor(Double(line.count) / 2.0))
            for (j, ch) in line.enumerated() {
                let x = textX + j
                let y = startY + i
                if x > 0, x < width - 1, y >= 0, y < height {
                    canvas[x][y] = ch
                }
            }
        }

        return canvas
    },
    getAttachmentPointFn: { dir, dimensions, baseCoord in
        getBoxAttachmentPoint(dir, dimensions, baseCoord)
    }
)
