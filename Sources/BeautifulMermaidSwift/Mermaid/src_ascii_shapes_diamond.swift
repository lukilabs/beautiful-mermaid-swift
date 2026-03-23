// Ported from original/src/ascii/shapes/diamond.ts
import Foundation
import ElkSwift

public struct DiamondRenderer: ShapeRenderer {
    public init() {}

    public func getDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
        getBoxDimensions(label, options)
    }

    public func render(_ label: String, _ dimensions: ShapeDimensions, _ options: ShapeRenderOptions) -> Canvas {
        let corners = getCorners("diamond", options.useAscii)
        return renderBox(label, dimensions, corners, options.useAscii)
    }

    public func getAttachmentPoint(_ dir: Direction, _ dimensions: ShapeDimensions, _ baseCoord: DrawingCoord) -> DrawingCoord {
        getBoxAttachmentPoint(dir, dimensions, baseCoord)
    }
}

public let diamondRenderer: any ShapeRenderer = DiamondRenderer()

open class original_src_ascii_shapes_diamond {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
