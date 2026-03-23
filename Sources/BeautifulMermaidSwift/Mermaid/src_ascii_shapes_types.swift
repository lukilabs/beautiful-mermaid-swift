// Ported from original/src/ascii/shapes/types.ts
import Foundation
import ElkSwift

public struct ShapeLabelArea: Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ShapeDimensions: Sendable {
    public var width: Int
    public var height: Int
    public var labelArea: ShapeLabelArea
    public var gridColumns: [Int]
    public var gridRows: [Int]

    public init(
        width: Int,
        height: Int,
        labelArea: ShapeLabelArea,
        gridColumns: [Int],
        gridRows: [Int]
    ) {
        self.width = width
        self.height = height
        self.labelArea = labelArea
        self.gridColumns = gridColumns
        self.gridRows = gridRows
    }
}

public struct ShapeRenderOptions: Sendable {
    public var useAscii: Bool
    public var padding: Int

    public init(useAscii: Bool, padding: Int) {
        self.useAscii = useAscii
        self.padding = padding
    }
}

public protocol ShapeRenderer {
    func getDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions
    func render(_ label: String, _ dimensions: ShapeDimensions, _ options: ShapeRenderOptions) -> Canvas
    func getAttachmentPoint(_ dir: Direction, _ dimensions: ShapeDimensions, _ baseCoord: DrawingCoord) -> DrawingCoord
}

public typealias ShapeRegistry = [AsciiNodeShape: any ShapeRenderer]

public struct ClosureShapeRenderer: ShapeRenderer {
    public let getDimensionsFn: (String, ShapeRenderOptions) -> ShapeDimensions
    public let renderFn: (String, ShapeDimensions, ShapeRenderOptions) -> Canvas
    public let getAttachmentPointFn: (Direction, ShapeDimensions, DrawingCoord) -> DrawingCoord

    public init(
        getDimensionsFn: @escaping (String, ShapeRenderOptions) -> ShapeDimensions,
        renderFn: @escaping (String, ShapeDimensions, ShapeRenderOptions) -> Canvas,
        getAttachmentPointFn: @escaping (Direction, ShapeDimensions, DrawingCoord) -> DrawingCoord
    ) {
        self.getDimensionsFn = getDimensionsFn
        self.renderFn = renderFn
        self.getAttachmentPointFn = getAttachmentPointFn
    }

    public func getDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
        getDimensionsFn(label, options)
    }

    public func render(_ label: String, _ dimensions: ShapeDimensions, _ options: ShapeRenderOptions) -> Canvas {
        renderFn(label, dimensions, options)
    }

    public func getAttachmentPoint(_ dir: Direction, _ dimensions: ShapeDimensions, _ baseCoord: DrawingCoord) -> DrawingCoord {
        getAttachmentPointFn(dir, dimensions, baseCoord)
    }
}

open class original_src_ascii_shapes_types {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
