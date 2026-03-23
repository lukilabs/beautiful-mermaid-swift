// Ported from original/src/ascii/edge-routing.ts
import Foundation
import ElkSwift

// ============================================================================
// Compatibility helpers shared by ASCII routing/bundling ports
// ============================================================================

public func gridCoordEquals(_ a: GridCoord, _ b: GridCoord) -> Bool {
    original_src_ascii_types.gridCoordEquals(a, b)
}

public func gridCoordDirection(_ c: GridCoord, _ dir: Direction) -> GridCoord {
    original_src_ascii_types.gridCoordDirection(c, dir)
}

public func gridKey(_ c: GridCoord) -> String {
    original_src_ascii_types.gridKey(c)
}

public func getPath(_ grid: [String: AsciiNode], _ from: GridCoord, _ to: GridCoord) -> [GridCoord]? {
    struct PQItem {
        var coord: GridCoord
        var priority: Int
    }

    func heuristic(_ a: GridCoord, _ b: GridCoord) -> Int {
        let absX = abs(a.x - b.x)
        let absY = abs(a.y - b.y)
        if absX == 0 || absY == 0 {
            return absX + absY
        }
        return absX + absY + 1
    }

    func isFreeInGrid(_ coord: GridCoord) -> Bool {
        if coord.x < 0 || coord.y < 0 {
            return false
        }
        return grid[gridKey(coord)] == nil
    }

    let moveDirs = [
        GridCoord(x: 1, y: 0),
        GridCoord(x: -1, y: 0),
        GridCoord(x: 0, y: 1),
        GridCoord(x: 0, y: -1),
    ]

    var pq: [PQItem] = [PQItem(coord: from, priority: 0)]
    var costSoFar: [String: Int] = [gridKey(from): 0]
    var cameFrom: [String: GridCoord?] = [gridKey(from): nil]

    while !pq.isEmpty {
        pq.sort { $0.priority < $1.priority }
        let current = pq.removeFirst().coord

        if gridCoordEquals(current, to) {
            var path: [GridCoord] = []
            var cursor: GridCoord? = current
            while let c = cursor {
                path.insert(c, at: 0)
                cursor = cameFrom[gridKey(c)] ?? nil
            }
            return path
        }

        let currentCost = costSoFar[gridKey(current)] ?? 0
        for dir in moveDirs {
            let next = GridCoord(x: current.x + dir.x, y: current.y + dir.y)
            if !isFreeInGrid(next) && !gridCoordEquals(next, to) {
                continue
            }

            let newCost = currentCost + 1
            let nextKey = gridKey(next)
            if costSoFar[nextKey] == nil || newCost < (costSoFar[nextKey] ?? Int.max) {
                costSoFar[nextKey] = newCost
                let priority = newCost + heuristic(next, to)
                pq.append(PQItem(coord: next, priority: priority))
                cameFrom[nextKey] = current
            }
        }
    }

    return nil
}

public func mergePath(_ path: [GridCoord]) -> [GridCoord] {
    if path.count <= 2 {
        return path
    }

    var toRemove = Set<Int>()
    var step0 = path[0]
    var step1 = path[1]

    for idx in 2 ..< path.count {
        let step2 = path[idx]
        let prevDx = step1.x - step0.x
        let prevDy = step1.y - step0.y
        let dx = step2.x - step1.x
        let dy = step2.y - step1.y

        if prevDx == dx && prevDy == dy {
            toRemove.insert(idx - 1)
        }

        step0 = step1
        step1 = step2
    }

    return path.enumerated().compactMap { idx, coord in
        toRemove.contains(idx) ? nil : coord
    }
}

private func nodeEquals(_ a: AsciiNode, _ b: AsciiNode) -> Bool {
    a.name == b.name && a.index == b.index
}

private func isAncestorOrSelf(_ graph: AsciiGraph, ancestorIndex: Int, descendantIndex: Int) -> Bool {
    var current: Int? = descendantIndex
    while let idx = current {
        if idx == ancestorIndex {
            return true
        }
        current = graph.subgraphs[idx].parent
    }
    return false
}

public func getNodeSubgraph(_ graph: AsciiGraph, _ node: AsciiNode) -> AsciiSubgraph? {
    var innermostIndex: Int? = nil

    for (idx, sg) in graph.subgraphs.enumerated()
        where sg.nodes.contains(where: { nodeEquals($0, node) }) {
        if let current = innermostIndex {
            if isAncestorOrSelf(graph, ancestorIndex: current, descendantIndex: idx) {
                innermostIndex = idx
            }
        } else {
            innermostIndex = idx
        }
    }

    if let idx = innermostIndex {
        return graph.subgraphs[idx]
    }
    return nil
}

// ============================================================================
// Direction utilities
// ============================================================================

public func getOpposite(_ d: Direction) -> Direction {
    if dirEquals(d, Up) { return Down }
    if dirEquals(d, Down) { return Up }
    if dirEquals(d, Left) { return Right }
    if dirEquals(d, Right) { return Left }
    if dirEquals(d, UpperRight) { return LowerLeft }
    if dirEquals(d, UpperLeft) { return LowerRight }
    if dirEquals(d, LowerRight) { return UpperLeft }
    if dirEquals(d, LowerLeft) { return UpperRight }
    return Middle
}

public func dirEquals(_ a: Direction, _ b: Direction) -> Bool {
    a.x == b.x && a.y == b.y
}

public func determineDirection(from: GridCoord, to: GridCoord) -> Direction {
    if from.x == to.x {
        return from.y < to.y ? Down : Up
    }
    if from.y == to.y {
        return from.x < to.x ? Right : Left
    }
    if from.x < to.x {
        return from.y < to.y ? LowerRight : UpperRight
    }
    return from.y < to.y ? LowerLeft : UpperLeft
}

private func selfReferenceDirection(_ graphDirection: String) -> (Direction, Direction, Direction, Direction) {
    if graphDirection == "LR" {
        return (Right, Down, Down, Right)
    }
    return (Down, Right, Right, Down)
}

public func determineStartAndEndDir(
    _ edge: AsciiEdge,
    _ graphDirection: String
) -> (Direction, Direction, Direction, Direction) {
    if nodeEquals(edge.from, edge.to) {
        return selfReferenceDirection(graphDirection)
    }

    let from = edge.from.gridCoord ?? GridCoord(x: 0, y: 0)
    let to = edge.to.gridCoord ?? GridCoord(x: 0, y: 0)
    let d = determineDirection(from: from, to: to)

    let isBackwards = graphDirection == "LR"
        ? (dirEquals(d, Left) || dirEquals(d, UpperLeft) || dirEquals(d, LowerLeft))
        : (dirEquals(d, Up) || dirEquals(d, UpperLeft) || dirEquals(d, UpperRight))

    var preferredDir = d
    var preferredOppositeDir = getOpposite(d)
    var alternativeDir = d
    var alternativeOppositeDir = getOpposite(d)

    if dirEquals(d, LowerRight) {
        if graphDirection == "LR" {
            preferredDir = Down
            preferredOppositeDir = Left
            alternativeDir = Right
            alternativeOppositeDir = Up
        } else {
            preferredDir = Right
            preferredOppositeDir = Up
            alternativeDir = Down
            alternativeOppositeDir = Left
        }
    } else if dirEquals(d, UpperRight) {
        if graphDirection == "LR" {
            preferredDir = Up
            preferredOppositeDir = Left
            alternativeDir = Right
            alternativeOppositeDir = Down
        } else {
            preferredDir = Right
            preferredOppositeDir = Down
            alternativeDir = Up
            alternativeOppositeDir = Left
        }
    } else if dirEquals(d, LowerLeft) {
        if graphDirection == "LR" {
            preferredDir = Down
            preferredOppositeDir = Down
            alternativeDir = Left
            alternativeOppositeDir = Up
        } else {
            preferredDir = Left
            preferredOppositeDir = Up
            alternativeDir = Down
            alternativeOppositeDir = Right
        }
    } else if dirEquals(d, UpperLeft) {
        if graphDirection == "LR" {
            preferredDir = Down
            preferredOppositeDir = Down
            alternativeDir = Left
            alternativeOppositeDir = Down
        } else {
            preferredDir = Right
            preferredOppositeDir = Right
            alternativeDir = Up
            alternativeOppositeDir = Right
        }
    } else if isBackwards {
        if graphDirection == "LR" && dirEquals(d, Left) {
            preferredDir = Down
            preferredOppositeDir = Down
            alternativeDir = Left
            alternativeOppositeDir = Right
        } else if graphDirection == "TD" && dirEquals(d, Up) {
            preferredDir = Right
            preferredOppositeDir = Right
            alternativeDir = Up
            alternativeOppositeDir = Down
        }
    }

    return (preferredDir, preferredOppositeDir, alternativeDir, alternativeOppositeDir)
}

// ============================================================================
// Edge path determination
// ============================================================================

public func determinePath(_ graph: AsciiGraph, _ edge: inout AsciiEdge) {
    let sourceSg = getNodeSubgraph(graph, edge.from)
    let targetSg = getNodeSubgraph(graph, edge.to)
    let sameSubgraph = sourceSg?.name == targetSg?.name

    let effectiveDir: String
    if sameSubgraph, let sourceDirection = sourceSg?.direction {
        effectiveDir = sourceDirection
    } else {
        effectiveDir = graph.config.graphDirection
    }

    let (preferredDir, preferredOppositeDir, alternativeDir, alternativeOppositeDir) =
        determineStartAndEndDir(edge, effectiveDir)

    let sourceCoord = edge.from.gridCoord ?? GridCoord(x: 0, y: 0)
    let targetCoord = edge.to.gridCoord ?? GridCoord(x: 0, y: 0)

    let prefFrom = gridCoordDirection(sourceCoord, preferredDir)
    let prefTo = gridCoordDirection(targetCoord, preferredOppositeDir)
    let preferredPath = getPath(graph.grid, prefFrom, prefTo)

    let altFrom = gridCoordDirection(sourceCoord, alternativeDir)
    let altTo = gridCoordDirection(targetCoord, alternativeOppositeDir)
    let alternativePath = getPath(graph.grid, altFrom, altTo)

    if var preferred = preferredPath, var alternative = alternativePath {
        preferred = mergePath(preferred)
        alternative = mergePath(alternative)

        if preferred.count <= alternative.count {
            edge.startDir = preferredDir
            edge.endDir = preferredOppositeDir
            edge.path = preferred
        } else {
            edge.startDir = alternativeDir
            edge.endDir = alternativeOppositeDir
            edge.path = alternative
        }
        return
    }

    if let preferredPath {
        edge.startDir = preferredDir
        edge.endDir = preferredOppositeDir
        edge.path = mergePath(preferredPath)
        return
    }

    if let alternativePath {
        edge.startDir = alternativeDir
        edge.endDir = alternativeOppositeDir
        edge.path = mergePath(alternativePath)
        return
    }

    edge.startDir = preferredDir
    edge.endDir = preferredOppositeDir
    edge.path = [prefFrom, prefTo]
}

public func determineLabelLine(_ graph: inout AsciiGraph, _ edge: inout AsciiEdge) {
    if edge.text.isEmpty || edge.path.count < 2 {
        return
    }

    let lenLabel = edge.text.count
    let pathLen = edge.path.count
    _ = graph.config.graphDirection == "TD"

    struct Segment {
        var line: (GridCoord, GridCoord)
        var width: Int
        var index: Int
        var isVertical: Bool
    }

    var segments: [Segment] = []

    for i in 1 ..< pathLen {
        let p1 = edge.path[i - 1]
        let p2 = edge.path[i]
        let line = (p1, p2)
        let width = calculateLineWidth(graph, line)
        let isVertical = p1.x == p2.x
        segments.append(Segment(line: line, width: width, index: i, isVertical: isVertical))
    }

    let suitableSegments = segments.filter { $0.width >= lenLabel && $0.index > 1 }
    let largestLine: (GridCoord, GridCoord)

    if !suitableSegments.isEmpty {
        let ordered = suitableSegments.sorted { $0.index > $1.index }
        largestLine = ordered[0].line
    } else {
        let fallbackSegments = segments.filter { $0.width >= lenLabel }
        if !fallbackSegments.isEmpty {
            let ordered = fallbackSegments.sorted { $0.index > $1.index }
            largestLine = ordered[0].line
        } else {
            let ordered = segments.sorted { $0.width > $1.width }
            largestLine = ordered.first?.line ?? (edge.path[0], edge.path[1])
        }
    }

    let minX = min(largestLine.0.x, largestLine.1.x)
    let maxX = max(largestLine.0.x, largestLine.1.x)
    let middleX = minX + ((maxX - minX) / 2)

    let current = graph.columnWidth[middleX] ?? 0
    graph.columnWidth[middleX] = max(current, lenLabel + 2)
    edge.labelLine = [largestLine.0, largestLine.1]
}

private func calculateLineWidth(_ graph: AsciiGraph, _ line: (GridCoord, GridCoord)) -> Int {
    var total = 0
    let startX = min(line.0.x, line.1.x)
    let endX = max(line.0.x, line.1.x)
    if startX > endX {
        return 0
    }
    for x in startX ... endX {
        total += graph.columnWidth[x] ?? 0
    }
    return total
}

open class original_src_ascii_edge_routing {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version
}
