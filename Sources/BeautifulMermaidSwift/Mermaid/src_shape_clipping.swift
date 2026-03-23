// Ported from original/src/shape-clipping.ts
import Foundation
import ElkSwift

open class original_src_shape_clipping {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    public typealias Point = original_src_types.Point
    public typealias PositionedNode = original_src_types.PositionedNode

    public static func clipEdgeToShape(
        _ points: [Point],
        node: PositionedNode,
        isStart: Bool
    ) -> [Point] {
        if points.count < 2 {
            return points
        }

        switch node.shape {
        case .rectangle, .rounded, .stadium:
            return points
        case .diamond:
            var result = points
            if isStart {
                result[0] = clipToDiamond(endpoint: points[0], adjacent: points[1], node: node)
            } else {
                let last = points.count - 1
                result[last] = clipToDiamond(endpoint: points[last], adjacent: points[last - 1], node: node)
            }
            return result
        default:
            return points
        }
    }

    private static func clipToDiamond(endpoint: Point, adjacent: Point, node: PositionedNode) -> Point {
        let cx = node.x + node.width / 2
        let cy = node.y + node.height / 2

        let top = Point(x: cx, y: node.y)
        let right = Point(x: node.x + node.width, y: cy)
        let bottom = Point(x: cx, y: node.y + node.height)
        let left = Point(x: node.x, y: cy)

        let dx = endpoint.x - adjacent.x
        let dy = endpoint.y - adjacent.y
        let isVertical = abs(dx) < abs(dy)

        if isVertical {
            let rayX = endpoint.x
            if dy > 0 {
                if rayX <= cx {
                    return intersectVerticalRayWithEdge(rayX: rayX, p1: left, p2: top) ?? top
                }
                return intersectVerticalRayWithEdge(rayX: rayX, p1: top, p2: right) ?? top
            }

            if rayX <= cx {
                return intersectVerticalRayWithEdge(rayX: rayX, p1: bottom, p2: left) ?? bottom
            }
            return intersectVerticalRayWithEdge(rayX: rayX, p1: right, p2: bottom) ?? bottom
        }

        let rayY = endpoint.y
        if dx > 0 {
            if rayY <= cy {
                return intersectHorizontalRayWithEdge(rayY: rayY, p1: top, p2: left) ?? left
            }
            return intersectHorizontalRayWithEdge(rayY: rayY, p1: left, p2: bottom) ?? left
        }

        if rayY <= cy {
            return intersectHorizontalRayWithEdge(rayY: rayY, p1: top, p2: right) ?? right
        }
        return intersectHorizontalRayWithEdge(rayY: rayY, p1: right, p2: bottom) ?? right
    }

    private static func intersectHorizontalRayWithEdge(rayY: Double, p1: Point, p2: Point) -> Point? {
        let dy = p2.y - p1.y
        if abs(dy) < 0.001 {
            return nil
        }

        let t = (rayY - p1.y) / dy
        if t < 0 || t > 1 {
            return nil
        }

        let x = p1.x + t * (p2.x - p1.x)
        return Point(x: x, y: rayY)
    }

    private static func intersectVerticalRayWithEdge(rayX: Double, p1: Point, p2: Point) -> Point? {
        let dx = p2.x - p1.x
        if abs(dx) < 0.001 {
            return nil
        }

        let t = (rayX - p1.x) / dx
        if t < 0 || t > 1 {
            return nil
        }

        let y = p1.y + t * (p2.y - p1.y)
        return Point(x: rayX, y: y)
    }
}
