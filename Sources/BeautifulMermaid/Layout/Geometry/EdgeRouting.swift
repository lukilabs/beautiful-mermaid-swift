// SPDX-License-Identifier: MIT
//
//  EdgeRouting.swift
//  BeautifulMermaid
//
//  Edge routing and path generation
//  Ported from beautiful-mermaid TypeScript dagre-adapter.ts
//

import Foundation
import CoreGraphics

// MARK: - Point Type Alias

/// Point type for edge routing (matches TypeScript Point interface)
public typealias Point = CGPoint

// MARK: - Node Rectangle

/// Node rectangle for endpoint clipping — uses center-based coordinates
public struct NodeRect {
    /// Center x coordinate
    public let cx: CGFloat
    /// Center y coordinate
    public let cy: CGFloat
    /// Half-width
    public let hw: CGFloat
    /// Half-height
    public let hh: CGFloat

    public init(cx: CGFloat, cy: CGFloat, hw: CGFloat, hh: CGFloat) {
        self.cx = cx
        self.cy = cy
        self.hw = hw
        self.hh = hh
    }

    /// Create from a node's bounds (top-left based)
    public init(bounds: CGRect) {
        self.cx = bounds.midX
        self.cy = bounds.midY
        self.hw = bounds.width / 2
        self.hh = bounds.height / 2
    }
}

// MARK: - Dagre Adapter Functions

/// Convert dagre's center-based node coordinates to top-left origin.
/// Dagre returns (x, y) as the center of the node bounding box.
/// Our renderers expect top-left coordinates.
public func centerToTopLeft(cx: CGFloat, cy: CGFloat, width: CGFloat, height: CGFloat) -> CGPoint {
    return CGPoint(x: cx - width / 2, y: cy - height / 2)
}

/// Project a point from the rectangular bounding box onto the diamond boundary.
///
/// Dagre treats all nodes as rectangles, so edge connection points land on the
/// rectangle boundary. For diamond shapes (rotated squares), the actual visual
/// boundary is an inscribed diamond whose vertices touch the rectangle's edge
/// midpoints. At non-cardinal angles, the rectangle boundary is *outside* the
/// diamond — making edges appear to float in the air.
///
/// Math: the diamond boundary satisfies |dx|/hw + |dy|/hh = 1 where (dx,dy) is
/// the offset from center and (hw,hh) are half-width/height. We scale the
/// direction vector so it lands exactly on this boundary.
public func clipToDiamondBoundary(
    point: CGPoint,
    cx: CGFloat,
    cy: CGFloat,
    hw: CGFloat,
    hh: CGFloat
) -> CGPoint {
    let dx = point.x - cx
    let dy = point.y - cy

    // Point is at (or very near) center — nothing to clip
    if abs(dx) < 0.5 && abs(dy) < 0.5 { return point }

    // Scale the direction vector to land on the diamond boundary
    let scale = 1.0 / (abs(dx) / hw + abs(dy) / hh)
    return CGPoint(x: cx + scale * dx, y: cy + scale * dy)
}

/// Project a point from the rectangular bounding box onto the circle boundary.
///
/// Dagre treats all nodes as rectangles, so edge connection points land on the
/// rectangle boundary. For circular shapes (circle, doublecircle, state-start,
/// state-end), the actual visual boundary is inscribed within the rectangle.
/// At non-cardinal angles, the rectangle boundary is *outside* the circle —
/// making edges appear to float in the air.
///
/// Math: scale the direction vector (from center to point) so its length equals
/// the circle radius.
public func clipToCircleBoundary(
    point: CGPoint,
    cx: CGFloat,
    cy: CGFloat,
    r: CGFloat
) -> CGPoint {
    let dx = point.x - cx
    let dy = point.y - cy
    let dist = sqrt(dx * dx + dy * dy)

    // Point is at (or very near) center — nothing to clip
    if dist < 0.5 { return point }

    let scale = r / dist
    return CGPoint(x: cx + scale * dx, y: cy + scale * dy)
}

/// Post-process dagre edge points into strictly orthogonal (90-degree) segments.
///
/// Dagre's Sugiyama layout routes edges through intermediate dummy nodes at each
/// rank, so most segments are already axis-aligned. However, when source and target
/// are at different horizontal positions, diagonal segments can appear.
///
/// Strategy: walk consecutive point pairs. If both x and y differ, insert ONE
/// intermediate bend point to create an L-shaped orthogonal path (matching TypeScript).
///
/// The bend direction depends on the layout axis:
///   - verticalFirst=true  (TD/BT): edge drops along rank axis, then adjusts horizontally
///   - verticalFirst=false (LR/RL): edge moves along rank axis, then adjusts vertically
///
/// After orthogonalization, collinear points (three consecutive points on the
/// same axis) are eliminated to avoid redundant micro-segments.
public func snapToOrthogonal(_ points: [CGPoint], verticalFirst: Bool = true) -> [CGPoint] {
    guard points.count >= 2 else { return points }

    var result: [CGPoint] = [points[0]]

    for i in 1..<points.count {
        let prev = result[result.count - 1]
        let curr = points[i]

        let dx = abs(curr.x - prev.x)
        let dy = abs(curr.y - prev.y)

        // If already axis-aligned (or close enough), keep as-is
        if dx < 1 || dy < 1 {
            result.append(curr)
            continue
        }

        // Insert L-bend (matching TypeScript dagre-adapter.ts)
        // TD/BT layouts: vertical first — edge drops along the rank axis, then adjusts horizontally
        // LR/RL layouts: horizontal first — edge moves along the rank axis, then adjusts vertically
        if verticalFirst {
            result.append(CGPoint(x: prev.x, y: curr.y))
        } else {
            result.append(CGPoint(x: curr.x, y: prev.y))
        }
        result.append(curr)
    }

    // Eliminate collinear points — if three consecutive points share the same x
    // (vertical segment) or same y (horizontal segment), the middle point is
    // redundant and creates visual artifacts at polyline corners.
    return removeCollinear(result)
}

/// Remove middle points from three-in-a-row collinear sequences.
private func removeCollinear(_ pts: [CGPoint]) -> [CGPoint] {
    guard pts.count >= 3 else { return pts }

    var out: [CGPoint] = [pts[0]]

    for i in 1..<(pts.count - 1) {
        let a = out[out.count - 1]
        let b = pts[i]
        let c = pts[i + 1]

        // Skip b if a-b-c are all on the same horizontal or vertical line
        let sameX = abs(a.x - b.x) < 1 && abs(b.x - c.x) < 1
        let sameY = abs(a.y - b.y) < 1 && abs(b.y - c.y) < 1

        if sameX || sameY { continue }
        out.append(b)
    }

    out.append(pts[pts.count - 1])
    return out
}

/// Clip edge endpoints to the correct side of rectangular node boundaries.
///
/// After snapToOrthogonal(), the final/first segment direction may differ from
/// dagre's original boundary intersection direction. Dagre computes boundary
/// points based on the diagonal direction between nodes, but orthogonalization
/// converts the path to L-bends — changing the approach direction of the
/// first/last segment.
///
/// This function corrects both endpoints so they connect to the side the edge
/// actually approaches from:
///   - Horizontal last segment → endpoint on left/right side
///   - Vertical last segment  → endpoint on top/bottom
public func clipEndpointsToNodes(
    _ points: [CGPoint],
    sourceNode: NodeRect?,
    targetNode: NodeRect?
) -> [CGPoint] {
    guard points.count >= 2 else { return points }

    var result = points

    // --- Fix target endpoint for 2-point edges FIRST (matching TypeScript order) ---
    // For 2-point edges, clip target before source so source clipping can
    // use the updated target position for direction calculation
    if let targetNode = targetNode, points.count == 2 {
        let first = result[0]
        let curr = result[1]
        let dx = abs(curr.x - first.x)
        let dy = abs(curr.y - first.y)

        if dy >= dx {
            // Primarily vertical — clip to top/bottom
            let approachFromTop = curr.y > first.y
            let sideY = approachFromTop
                ? targetNode.cy - targetNode.hh
                : targetNode.cy + targetNode.hh
            result[1] = CGPoint(x: targetNode.cx, y: sideY)
        } else {
            // Primarily horizontal — clip to left/right
            let approachFromLeft = curr.x > first.x
            let sideX = approachFromLeft
                ? targetNode.cx - targetNode.hw
                : targetNode.cx + targetNode.hw
            result[1] = CGPoint(x: sideX, y: targetNode.cy)
        }
    }

    // NOTE: TypeScript does NOT clip source for 2-point edges - only target is clipped.
    // This is intentional: 2-point edges don't need source adjustment because dagre's
    // original source endpoint is already reasonable. Only 3+ point edges need source
    // clipping to account for orthogonalization changes.

    // --- Fix target endpoint for 3+ point edges ---
    if let targetNode = targetNode, points.count >= 3 {
        let last = result.count - 1
        // 3+ point edge: use last segment direction
        let prev = result[last - 1]
        let curr = result[last]
        let dx = abs(curr.x - prev.x)
        let dy = abs(curr.y - prev.y)

        let isStrictlyHorizontal = dy < 1 && dx >= 1
        let isStrictlyVertical = dx < 1 && dy >= 1
        let isPrimarilyHorizontal = !isStrictlyHorizontal && !isStrictlyVertical && dy < dx
        let isPrimarilyVertical = !isStrictlyHorizontal && !isStrictlyVertical && dx < dy

        if isStrictlyHorizontal {
            // Strictly horizontal — route to center for visual balance
            let approachFromLeft = curr.x > prev.x
            let sideX = approachFromLeft
                ? targetNode.cx - targetNode.hw
                : targetNode.cx + targetNode.hw
            result[last] = CGPoint(x: sideX, y: targetNode.cy)
            result[last - 1] = CGPoint(x: prev.x, y: targetNode.cy)
        } else if isStrictlyVertical {
            // Strictly vertical — route to center for visual balance
            let approachFromTop = curr.y > prev.y
            let sideY = approachFromTop
                ? targetNode.cy - targetNode.hh
                : targetNode.cy + targetNode.hh
            result[last] = CGPoint(x: targetNode.cx, y: sideY)
            result[last - 1] = CGPoint(x: targetNode.cx, y: prev.y)
        } else if isPrimarilyHorizontal {
            // Primarily horizontal — use natural Y if within bounds
            let approachFromLeft = curr.x > prev.x
            let sideX = approachFromLeft
                ? targetNode.cx - targetNode.hw
                : targetNode.cx + targetNode.hw

            let withinVerticalBounds =
                prev.y >= targetNode.cy - targetNode.hh &&
                prev.y <= targetNode.cy + targetNode.hh

            if withinVerticalBounds {
                result[last] = CGPoint(x: sideX, y: prev.y)
            } else {
                result[last] = CGPoint(x: sideX, y: targetNode.cy)
                result[last - 1] = CGPoint(x: prev.x, y: targetNode.cy)
            }
        } else if isPrimarilyVertical {
            // Primarily vertical — use natural X if within bounds
            let approachFromTop = curr.y > prev.y
            let sideY = approachFromTop
                ? targetNode.cy - targetNode.hh
                : targetNode.cy + targetNode.hh

            let withinHorizontalBounds =
                prev.x >= targetNode.cx - targetNode.hw &&
                prev.x <= targetNode.cx + targetNode.hw

            if withinHorizontalBounds {
                result[last] = CGPoint(x: prev.x, y: sideY)
            } else {
                result[last] = CGPoint(x: targetNode.cx, y: sideY)
                result[last - 1] = CGPoint(x: targetNode.cx, y: prev.y)
            }
        }
    }

    // --- Fix source endpoint (first segment) ---
    if let sourceNode = sourceNode, points.count >= 3 {
        let first = result[0]
        let next = result[1]
        let dx = abs(next.x - first.x)
        let dy = abs(next.y - first.y)

        let isStrictlyHorizontal = dy < 1 && dx >= 1
        let isStrictlyVertical = dx < 1 && dy >= 1
        let isPrimarilyHorizontal = !isStrictlyHorizontal && !isStrictlyVertical && dy < dx
        let isPrimarilyVertical = !isStrictlyHorizontal && !isStrictlyVertical && dx < dy

        if isStrictlyHorizontal {
            let exitToRight = next.x > first.x
            let sideX = exitToRight
                ? sourceNode.cx + sourceNode.hw
                : sourceNode.cx - sourceNode.hw
            result[0] = CGPoint(x: sideX, y: sourceNode.cy)
            result[1] = CGPoint(x: result[1].x, y: sourceNode.cy)
        } else if isStrictlyVertical {
            let exitDownward = next.y > first.y
            let sideY = exitDownward
                ? sourceNode.cy + sourceNode.hh
                : sourceNode.cy - sourceNode.hh
            result[0] = CGPoint(x: sourceNode.cx, y: sideY)
            result[1] = CGPoint(x: sourceNode.cx, y: result[1].y)
        } else if isPrimarilyHorizontal {
            let exitToRight = next.x > first.x
            let sideX = exitToRight
                ? sourceNode.cx + sourceNode.hw
                : sourceNode.cx - sourceNode.hw

            let withinVerticalBounds =
                next.y >= sourceNode.cy - sourceNode.hh &&
                next.y <= sourceNode.cy + sourceNode.hh

            if withinVerticalBounds {
                result[0] = CGPoint(x: sideX, y: next.y)
            } else {
                result[0] = CGPoint(x: sideX, y: sourceNode.cy)
                result[1] = CGPoint(x: result[1].x, y: sourceNode.cy)
            }
        } else if isPrimarilyVertical {
            let exitDownward = next.y > first.y
            let sideY = exitDownward
                ? sourceNode.cy + sourceNode.hh
                : sourceNode.cy - sourceNode.hh

            let withinHorizontalBounds =
                next.x >= sourceNode.cx - sourceNode.hw &&
                next.x <= sourceNode.cx + sourceNode.hw

            if withinHorizontalBounds {
                result[0] = CGPoint(x: next.x, y: sideY)
            } else {
                result[0] = CGPoint(x: sourceNode.cx, y: sideY)
                result[1] = CGPoint(x: sourceNode.cx, y: result[1].y)
            }
        }
    }

    return result
}

// MARK: - Shape Sets

/// Shapes that render as circles — need edge endpoint clipping to the circle boundary
public let circularShapes: Set<NodeShape> = [.circle, .doublecircle, .stateStart, .stateEnd]

/// Non-rectangular shapes — skip rectangular endpoint clipping for these
/// (they use their own boundary equations via clipToDiamondBoundary / clipToCircleBoundary)
public let nonRectShapes: Set<NodeShape> = [.diamond, .circle, .doublecircle, .stateStart, .stateEnd]

// MARK: - EdgeRouter (Compatibility Layer)

/// Handles edge routing between nodes
public struct EdgeRouter {

    /// Route type for edges
    public enum RouteType {
        case direct       // Straight line
        case orthogonal   // Right-angle turns only
        case curved       // Smooth Bezier curves
    }

    /// Route an edge between two nodes
    public static func route(
        from source: MermaidNode,
        to target: MermaidNode,
        routeType: RouteType = .orthogonal,
        direction: Direction
    ) -> [CGPoint] {
        let sourceCenter = source.position
        let targetCenter = target.position

        // Get intersection points with shape boundaries
        let sourceExit = ShapeBounds.intersectionPoint(
            shape: source.shape,
            bounds: source.bounds,
            from: sourceCenter,
            to: targetCenter
        )

        let targetEntry = ShapeBounds.intersectionPoint(
            shape: target.shape,
            bounds: target.bounds,
            from: targetCenter,
            to: sourceCenter
        )

        switch routeType {
        case .direct:
            return [sourceExit, targetEntry]

        case .orthogonal:
            // Use the new snapToOrthogonal approach
            let verticalFirst = direction.isVertical
            let rawPoints = [sourceExit, targetEntry]
            let orthoPoints = snapToOrthogonal(rawPoints, verticalFirst: verticalFirst)

            // Apply endpoint clipping for non-circular/non-diamond shapes
            let sourceRect = nonRectShapes.contains(source.shape) ? nil : NodeRect(bounds: source.bounds)
            let targetRect = nonRectShapes.contains(target.shape) ? nil : NodeRect(bounds: target.bounds)

            return clipEndpointsToNodes(orthoPoints, sourceNode: sourceRect, targetNode: targetRect)

        case .curved:
            return routeCurved(
                from: sourceExit,
                to: targetEntry,
                sourceCenter: sourceCenter,
                targetCenter: targetCenter,
                direction: direction
            )
        }
    }

    // MARK: - Curved Routing

    private static func routeCurved(
        from source: CGPoint,
        to target: CGPoint,
        sourceCenter: CGPoint,
        targetCenter: CGPoint,
        direction: Direction
    ) -> [CGPoint] {
        let dx = target.x - source.x
        let dy = target.y - source.y
        let curveFactor: CGFloat = 0.3

        var control1: CGPoint
        var control2: CGPoint

        if direction.isVertical {
            let offsetY = dy * curveFactor
            control1 = CGPoint(x: source.x, y: source.y + offsetY)
            control2 = CGPoint(x: target.x, y: target.y - offsetY)
        } else {
            let offsetX = dx * curveFactor
            control1 = CGPoint(x: source.x + offsetX, y: source.y)
            control2 = CGPoint(x: target.x - offsetX, y: target.y)
        }

        return [source, control1, control2, target]
    }

    // MARK: - Label Position

    /// Calculate the position for an edge label (at midpoint of path)
    public static func labelPosition(for points: [CGPoint]) -> CGPoint {
        guard points.count >= 2 else { return .zero }

        var totalLength: CGFloat = 0
        var segments: [(start: CGPoint, end: CGPoint, length: CGFloat)] = []

        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]
            let length = start.distance(to: end)
            totalLength += length
            segments.append((start, end, length))
        }

        let midDistance = totalLength / 2
        var traveled: CGFloat = 0

        for segment in segments {
            if traveled + segment.length >= midDistance {
                let remaining = midDistance - traveled
                let t = remaining / segment.length
                return segment.start.lerp(to: segment.end, t: t)
            }
            traveled += segment.length
        }

        return points.first!.midpoint(to: points.last!)
    }

    /// Calculate the angle at the end of an edge (for arrow direction)
    public static func endAngle(for points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        let secondLast = points[points.count - 2]
        let last = points.last!
        return secondLast.angle(to: last)
    }

    /// Calculate the angle at the start of an edge (for reverse arrows)
    public static func startAngle(for points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        let first = points[0]
        let second = points[1]
        return second.angle(to: first)
    }
}
