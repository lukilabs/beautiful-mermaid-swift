// Ported from original/src/ascii/shapes/rounded.ts
import Foundation
import ElkSwift

public struct RoundedRenderer: ShapeRenderer {
    public init() {}

    public func getDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
        getBoxDimensions(label, options)
    }

    public func render(_ label: String, _ dimensions: ShapeDimensions, _ options: ShapeRenderOptions) -> Canvas {
        let corners = getCorners("rounded", options.useAscii)
        return renderBox(label, dimensions, corners, options.useAscii)
    }

    public func getAttachmentPoint(_ dir: Direction, _ dimensions: ShapeDimensions, _ baseCoord: DrawingCoord) -> DrawingCoord {
        getBoxAttachmentPoint(dir, dimensions, baseCoord)
    }
}

public let roundedRenderer: any ShapeRenderer = RoundedRenderer()

open class original_src_ascii_shapes_rounded {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
