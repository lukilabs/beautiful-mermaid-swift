// Ported from original/src/ascii/grid.ts
import Foundation
import ElkSwift

open class original_src_ascii_grid {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    public typealias GridCoord = original_src_ascii_converter.GridCoord
    public typealias DrawingCoord = original_src_ascii_converter.DrawingCoord
    public typealias AsciiGraph = original_src_ascii_converter.AsciiGraph
    public typealias AsciiNode = original_src_ascii_converter.AsciiNode
    public typealias AsciiSubgraph = original_src_ascii_converter.AsciiSubgraph

    public static func gridToDrawingCoord(
        _ graph: AsciiGraph,
        _ c: GridCoord,
        dir: original_src_ascii_converter.Direction? = nil
    ) -> DrawingCoord {
        let target = dir.map { GridCoord(x: c.x + $0.x, y: c.y + $0.y) } ?? c

        var x = 0
        if target.x > 0 {
            for col in 0..<target.x {
                x += graph.columnWidth[col] ?? 0
            }
        }

        var y = 0
        if target.y > 0 {
            for row in 0..<target.y {
                y += graph.rowHeight[row] ?? 0
            }
        }

        let colW = graph.columnWidth[target.x] ?? 0
        let rowH = graph.rowHeight[target.y] ?? 0
        return DrawingCoord(
            x: x + (colW / 2) + graph.offsetX,
            y: y + (rowH / 2) + graph.offsetY
        )
    }

    public static func lineToDrawing(_ graph: AsciiGraph, _ line: [GridCoord]) -> [DrawingCoord] {
        line.map { gridToDrawingCoord(graph, $0) }
    }

    public static func reserveSpotInGrid(
        _ graph: AsciiGraph,
        _ node: AsciiNode,
        _ requested: GridCoord,
        effectiveDir: String? = nil
    ) -> GridCoord {
        let dir = effectiveDir ?? getEffectiveDirection(graph, node)

        if graph.grid[original_src_ascii_converter.gridKey(requested)] != nil {
            if dir == "LR" {
                return reserveSpotInGrid(graph, node, GridCoord(x: requested.x, y: requested.y + 4), effectiveDir: dir)
            }
            return reserveSpotInGrid(graph, node, GridCoord(x: requested.x + 4, y: requested.y), effectiveDir: dir)
        }

        for dx in 0..<3 {
            for dy in 0..<3 {
                let reserved = GridCoord(x: requested.x + dx, y: requested.y + dy)
                graph.grid[original_src_ascii_converter.gridKey(reserved)] = node
            }
        }

        node.gridCoord = requested
        return requested
    }

    public static func setColumnWidth(_ graph: AsciiGraph, _ node: AsciiNode) {
        guard let gc = node.gridCoord else { return }

        let padding = graph.config.boxBorderPadding

        // Use shape-aware dimensions
        let shapeDims = getShapeDimensions(
            node.shape,
            node.displayLabel,
            ShapeRenderOptions(useAscii: graph.config.useAscii, padding: padding)
        )

        let colWidths = shapeDims.gridColumns
        let rowHeights = shapeDims.gridRows

        for (idx, width) in colWidths.enumerated() {
            let xCoord = gc.x + idx
            graph.columnWidth[xCoord] = max(graph.columnWidth[xCoord] ?? 0, width)
        }

        for (idx, height) in rowHeights.enumerated() {
            let yCoord = gc.y + idx
            graph.rowHeight[yCoord] = max(graph.rowHeight[yCoord] ?? 0, height)
        }

        if gc.x > 0 {
            graph.columnWidth[gc.x - 1] = max(graph.columnWidth[gc.x - 1] ?? 0, graph.config.paddingX)
        }
        if gc.y > 0 {
            var basePadding = graph.config.paddingY
            if hasIncomingEdgeFromOutsideSubgraph(graph, node) {
                basePadding += 4
            }
            graph.rowHeight[gc.y - 1] = max(graph.rowHeight[gc.y - 1] ?? 0, basePadding)
        }
    }

    private static func hasIncomingEdgeFromOutsideSubgraph(_ graph: AsciiGraph, _ node: AsciiNode) -> Bool {
        let nodeSg = getNodeSubgraph(graph, node)
        guard let nodeSg = nodeSg else { return false }

        var hasExternalEdge = false
        for edge in graph.edges where edge.to === node {
            let sourceSg = getNodeSubgraph(graph, edge.from)
            if sourceSg !== nodeSg {
                hasExternalEdge = true
                break
            }
        }

        guard hasExternalEdge else { return false }

        // Check if the node is actually a first-row node in its subgraph
        let sgNodes = nodeSg.nodes.filter { $0.gridCoord != nil }
        guard let nodeGc = node.gridCoord else { return false }
        let minY = sgNodes.compactMap(\.gridCoord?.y).min() ?? nodeGc.y
        return nodeGc.y == minY
    }

    public static func increaseGridSizeForPath(_ graph: AsciiGraph, _ path: [GridCoord]) {
        for c in path {
            if graph.columnWidth[c.x] == nil {
                graph.columnWidth[c.x] = graph.config.paddingX / 2
            }
            if graph.rowHeight[c.y] == nil {
                graph.rowHeight[c.y] = graph.config.paddingY / 2
            }
        }
    }

    public static func getNodeSubgraph(_ graph: AsciiGraph, _ node: AsciiNode) -> AsciiSubgraph? {
        var innermost: AsciiSubgraph?
        for sg in graph.subgraphs where sg.nodes.contains(where: { $0 === node }) {
            if let inner = innermost {
                if isAncestorOrSelf(inner, sg) {
                    innermost = sg
                }
            } else {
                innermost = sg
            }
        }
        return innermost
    }

    public static func getEffectiveDirection(_ graph: AsciiGraph, _ node: AsciiNode) -> String {
        if let sgDirection = getNodeSubgraph(graph, node)?.direction {
            return sgDirection
        }
        return graph.config.graphDirection
    }

    public static func calculateSubgraphBoundingBoxes(_ graph: AsciiGraph) {
        for sg in graph.subgraphs {
            calculateSubgraphBoundingBox(graph, sg)
        }
        ensureSubgraphSpacing(graph)
    }

    public static func offsetDrawingForSubgraphs(_ graph: AsciiGraph) {
        guard !graph.subgraphs.isEmpty else { return }

        var minX = 0
        var minY = 0
        for sg in graph.subgraphs {
            minX = min(minX, sg.minX)
            minY = min(minY, sg.minY)
        }

        let offsetX = -minX
        let offsetY = -minY
        if offsetX == 0 && offsetY == 0 {
            return
        }

        graph.offsetX = offsetX
        graph.offsetY = offsetY

        for sg in graph.subgraphs {
            sg.minX += offsetX
            sg.minY += offsetY
            sg.maxX += offsetX
            sg.maxY += offsetY
        }

        for node in graph.nodes where node.drawingCoord != nil {
            node.drawingCoord?.x += offsetX
            node.drawingCoord?.y += offsetY
        }
    }

    /// Feasible parity for grid.ts orchestration with current Swift dependencies:
    /// - root/child placement, row/column sizing
    /// - non-bundled edge routing + label line sizing
    /// - grid->drawing coordinate mapping, node drawing, canvas sizing
    /// - subgraph bounding boxes and offsetting
    public static func createMapping(_ graph: AsciiGraph) throws {
        let dir = graph.config.graphDirection
        var highestPositionPerLevel = Array(repeating: 0, count: 100)

        var nodesFound = Set<String>()
        var initialRoots: [AsciiNode] = []
        for node in graph.nodes {
            if !nodesFound.contains(node.name) {
                initialRoots.append(node)
            }
            nodesFound.insert(node.name)
            for child in getChildren(graph, node) {
                nodesFound.insert(child.name)
            }
        }

        let rootNodes = initialRoots.filter { node in
            guard let nodeSg = getNodeSubgraph(graph, node) else {
                return true
            }
            for edge in graph.edges where edge.to === node {
                let sourceSg = getNodeSubgraph(graph, edge.from)
                if sourceSg !== nodeSg {
                    return false
                }
            }
            return true
        }

        var hasExternalRoots = false
        var hasSubgraphRootsWithEdges = false
        for node in rootNodes {
            if isNodeInAnySubgraph(graph, node) {
                if !getChildren(graph, node).isEmpty {
                    hasSubgraphRootsWithEdges = true
                }
            } else {
                hasExternalRoots = true
            }
        }
        let shouldSeparate = dir == "LR" && hasExternalRoots && hasSubgraphRootsWithEdges

        let externalRootNodes: [AsciiNode]
        let subgraphRootNodes: [AsciiNode]
        if shouldSeparate {
            externalRootNodes = rootNodes.filter { !isNodeInAnySubgraph(graph, $0) }
            subgraphRootNodes = rootNodes.filter { isNodeInAnySubgraph(graph, $0) }
        } else {
            externalRootNodes = rootNodes
            subgraphRootNodes = []
        }

        for node in externalRootNodes {
            let requested = dir == "LR"
                ? GridCoord(x: 0, y: highestPositionPerLevel[0])
                : GridCoord(x: highestPositionPerLevel[0], y: 0)
            _ = reserveSpotInGrid(graph, node, requested)
            highestPositionPerLevel[0] += 4
        }

        if shouldSeparate, !subgraphRootNodes.isEmpty {
            let subgraphLevel = 4
            for node in subgraphRootNodes {
                let requested = dir == "LR"
                    ? GridCoord(x: subgraphLevel, y: highestPositionPerLevel[subgraphLevel])
                    : GridCoord(x: highestPositionPerLevel[subgraphLevel], y: subgraphLevel)
                _ = reserveSpotInGrid(graph, node, requested)
                highestPositionPerLevel[subgraphLevel] += 4
            }
        }

        var placedCount = externalRootNodes.count + subgraphRootNodes.count
        while placedCount < graph.nodes.count {
            let prevCount = placedCount
            for node in graph.nodes {
                guard let gc = node.gridCoord else { continue }
                for child in getChildren(graph, node) where child.gridCoord == nil {
                    let parentSg = getNodeSubgraph(graph, node)
                    let childSg = getNodeSubgraph(graph, child)
                    let edgeDir: String
                    if let parentSg, parentSg === childSg, let override = parentSg.direction {
                        edgeDir = override
                    } else {
                        edgeDir = graph.config.graphDirection
                    }

                    let childLevel = edgeDir == "LR" ? gc.x + 4 : gc.y + 4
                    let highestPosition: Int
                    if edgeDir != graph.config.graphDirection {
                        highestPosition = edgeDir == "LR" ? gc.y : gc.x
                    } else {
                        highestPosition = highestPositionPerLevel[childLevel]
                    }

                    let requested = edgeDir == "LR"
                        ? GridCoord(x: childLevel, y: highestPosition)
                        : GridCoord(x: highestPosition, y: childLevel)
                    _ = reserveSpotInGrid(graph, child, requested, effectiveDir: edgeDir)
                    if edgeDir == graph.config.graphDirection {
                        highestPositionPerLevel[childLevel] = highestPosition + 4
                    }
                    placedCount += 1
                }
            }
            if placedCount == prevCount {
                break
            }
        }

        for node in graph.nodes {
            setColumnWidth(graph, node)
        }

        graph.bundles = []
        for edge in graph.edges {
            _determinePath(graph, edge)
            increaseGridSizeForPath(graph, edge.path)
            _determineLabelLine(graph, edge)
        }

        for node in graph.nodes {
            guard let gc = node.gridCoord else { continue }
            node.drawingCoord = gridToDrawingCoord(graph, gc)
            node.drawing = _drawBox(node, graph)
        }

        setCanvasSizeToGrid(&graph.canvas, graph.columnWidth, graph.rowHeight)
        _setRoleCanvasSizeToGrid(graph)
        calculateSubgraphBoundingBoxes(graph)
        offsetDrawingForSubgraphs(graph)
    }

    // MARK: - Internal helpers

    private static let Up = original_src_ascii_converter.Direction(x: 1, y: 0)
    private static let Down = original_src_ascii_converter.Direction(x: 1, y: 2)
    private static let Left = original_src_ascii_converter.Direction(x: 0, y: 1)
    private static let Right = original_src_ascii_converter.Direction(x: 2, y: 1)
    private static let UpperRight = original_src_ascii_converter.Direction(x: 2, y: 0)
    private static let UpperLeft = original_src_ascii_converter.Direction(x: 0, y: 0)
    private static let LowerRight = original_src_ascii_converter.Direction(x: 2, y: 2)
    private static let LowerLeft = original_src_ascii_converter.Direction(x: 0, y: 2)
    private static let Middle = original_src_ascii_converter.Direction(x: 1, y: 1)

    private static func isNodeInAnySubgraph(_ graph: AsciiGraph, _ node: AsciiNode) -> Bool {
        graph.subgraphs.contains { $0.nodes.contains { $0 === node } }
    }

    private static func dirEquals(
        _ a: original_src_ascii_converter.Direction,
        _ b: original_src_ascii_converter.Direction
    ) -> Bool {
        a.x == b.x && a.y == b.y
    }

    private static func getOpposite(
        _ d: original_src_ascii_converter.Direction
    ) -> original_src_ascii_converter.Direction {
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

    private static func gridCoordDirection(
        _ c: GridCoord,
        _ dir: original_src_ascii_converter.Direction
    ) -> GridCoord {
        GridCoord(x: c.x + dir.x, y: c.y + dir.y)
    }

    private static func determineDirection(from: GridCoord, to: GridCoord) -> original_src_ascii_converter.Direction {
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

    private static func selfReferenceDirection(
        _ graphDirection: String
    ) -> (
        original_src_ascii_converter.Direction,
        original_src_ascii_converter.Direction,
        original_src_ascii_converter.Direction,
        original_src_ascii_converter.Direction
    ) {
        if graphDirection == "LR" {
            return (Right, Down, Down, Right)
        }
        return (Down, Right, Right, Down)
    }

    private static func determineStartAndEndDir(
        _ edge: original_src_ascii_converter.AsciiEdge,
        _ graphDirection: String
    ) -> (
        original_src_ascii_converter.Direction,
        original_src_ascii_converter.Direction,
        original_src_ascii_converter.Direction,
        original_src_ascii_converter.Direction
    ) {
        if edge.from === edge.to {
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
            if graphDirection == "LR", dirEquals(d, Left) {
                preferredDir = Down
                preferredOppositeDir = Down
                alternativeDir = Left
                alternativeOppositeDir = Right
            } else if graphDirection == "TD", dirEquals(d, Up) {
                preferredDir = Right
                preferredOppositeDir = Right
                alternativeDir = Up
                alternativeOppositeDir = Down
            }
        }

        return (preferredDir, preferredOppositeDir, alternativeDir, alternativeOppositeDir)
    }

    private static func _determinePath(_ graph: AsciiGraph, _ edge: original_src_ascii_converter.AsciiEdge) {
        let sourceSg = getNodeSubgraph(graph, edge.from)
        let targetSg = getNodeSubgraph(graph, edge.to)
        let sameSubgraph = sourceSg === targetSg

        let effectiveDir: String
        if sameSubgraph, let override = sourceSg?.direction {
            effectiveDir = override
        } else {
            effectiveDir = graph.config.graphDirection
        }

        let (preferredDir, preferredOppositeDir, alternativeDir, alternativeOppositeDir) =
            determineStartAndEndDir(edge, effectiveDir)

        let sourceCoord = edge.from.gridCoord ?? GridCoord(x: 0, y: 0)
        let targetCoord = edge.to.gridCoord ?? GridCoord(x: 0, y: 0)
        let prefFrom = gridCoordDirection(sourceCoord, preferredDir)
        let prefTo = gridCoordDirection(targetCoord, preferredOppositeDir)
        let altFrom = gridCoordDirection(sourceCoord, alternativeDir)
        let altTo = gridCoordDirection(targetCoord, alternativeOppositeDir)

        let preferredPathRaw = original_src_ascii_pathfinder.getPath(graph.grid, from: prefFrom, to: prefTo)
        let alternativePathRaw = original_src_ascii_pathfinder.getPath(graph.grid, from: altFrom, to: altTo)

        if let preferredPathRaw, let alternativePathRaw {
            let preferredPath = original_src_ascii_pathfinder.mergePath(preferredPathRaw)
            let alternativePath = original_src_ascii_pathfinder.mergePath(alternativePathRaw)
            if preferredPath.count <= alternativePath.count {
                edge.startDir = preferredDir
                edge.endDir = preferredOppositeDir
                edge.path = preferredPath
            } else {
                edge.startDir = alternativeDir
                edge.endDir = alternativeOppositeDir
                edge.path = alternativePath
            }
            return
        }

        if let preferredPathRaw {
            edge.startDir = preferredDir
            edge.endDir = preferredOppositeDir
            edge.path = original_src_ascii_pathfinder.mergePath(preferredPathRaw)
            return
        }
        if let alternativePathRaw {
            edge.startDir = alternativeDir
            edge.endDir = alternativeOppositeDir
            edge.path = original_src_ascii_pathfinder.mergePath(alternativePathRaw)
            return
        }

        edge.startDir = preferredDir
        edge.endDir = preferredOppositeDir
        edge.path = [prefFrom, prefTo]
    }

    private static func _determineLabelLine(_ graph: AsciiGraph, _ edge: original_src_ascii_converter.AsciiEdge) {
        if edge.text.isEmpty || edge.path.count < 2 {
            return
        }

        struct Segment {
            var line: (GridCoord, GridCoord)
            var width: Int
            var index: Int
        }

        let lenLabel = edge.text.count
        var segments: [Segment] = []
        if edge.path.count >= 2 {
            for i in 1 ..< edge.path.count {
                let p1 = edge.path[i - 1]
                let p2 = edge.path[i]
                var width = 0
                let startX = min(p1.x, p2.x)
                let endX = max(p1.x, p2.x)
                if startX <= endX {
                    for x in startX ... endX {
                        width += graph.columnWidth[x] ?? 0
                    }
                }
                segments.append(Segment(line: (p1, p2), width: width, index: i))
            }
        }

        guard !segments.isEmpty else { return }

        let suitable = segments.filter { $0.width >= lenLabel && $0.index > 1 }.sorted { $0.index > $1.index }
        let fallback = segments.filter { $0.width >= lenLabel }.sorted { $0.index > $1.index }
        let largestByWidth = segments.sorted { $0.width > $1.width }
        let chosen = suitable.first ?? fallback.first ?? largestByWidth.first ?? segments[0]

        let p1 = chosen.line.0
        let p2 = chosen.line.1
        let minX = min(p1.x, p2.x)
        let maxX = max(p1.x, p2.x)
        let middleX = minX + ((maxX - minX) / 2)
        graph.columnWidth[middleX] = max(graph.columnWidth[middleX] ?? 0, lenLabel + 2)
        edge.labelLine = [p1, p2]
    }

    private static func _drawBox(_ node: AsciiNode, _ graph: AsciiGraph) -> [[Character]] {
        guard let gc = node.gridCoord else {
            return mkCanvas(0, 0)
        }
        let useAscii = graph.config.useAscii

        // Width spans 2 columns, height spans 2 rows (matching TS drawBoxWithGridDimensions)
        var w = 0
        for i in 0..<2 { w += graph.columnWidth[gc.x + i] ?? 0 }
        var h = 0
        for i in 0..<2 { h += graph.rowHeight[gc.y + i] ?? 0 }

        var box = mkCanvas(max(0, w), max(0, h))

        let corners = getCorners(node.shape, useAscii)
        let isDoubleBox = node.shape == "state-end"
        let hChar: Character = useAscii ? (isDoubleBox ? "=" : "-") : (isDoubleBox ? "═" : "─")
        let vChar: Character = useAscii ? (isDoubleBox ? "‖" : "|") : (isDoubleBox ? "║" : "│")

        let doubleCorners = useAscii
            ? CornerChars(tl: "#", tr: "#", bl: "#", br: "#")
            : CornerChars(tl: "╔", tr: "╗", bl: "╚", br: "╝")
        let effectiveCorners = isDoubleBox ? doubleCorners : corners

        for x in 1..<w { box[x][0] = hChar }
        for x in 1..<w { box[x][h] = hChar }
        for y in 1..<h { box[0][y] = vChar }
        for y in 1..<h { box[w][y] = vChar }
        box[0][0] = effectiveCorners.tl
        box[w][0] = effectiveCorners.tr
        box[0][h] = effectiveCorners.bl
        box[w][h] = effectiveCorners.br

        let lines = splitLines(node.displayLabel)
        let textCenterY = Int(floor(Double(h) / 2.0))
        let startY = textCenterY - Int(floor(Double(lines.count - 1) / 2.0))

        for i in 0..<lines.count {
            let line = lines[i]
            let textX = Int(floor(Double(w) / 2.0)) - Int(ceil(Double(line.count) / 2.0)) + 1
            for (j, ch) in line.enumerated() {
                let px = textX + j
                let py = startY + i
                if px >= 0, px < box.count, py >= 0, py < (box[0].count) {
                    box[px][py] = ch
                }
            }
        }

        return box
    }

    private static func _setRoleCanvasSizeToGrid(_ graph: AsciiGraph) {
        let maxX = max(1, graph.columnWidth.values.reduce(0, +))
        let maxY = max(1, graph.rowHeight.values.reduce(0, +))
        graph.roleCanvas = (0 ..< maxX).map { _ in
            Array(repeating: original_src_ascii_converter.CharRole.none, count: maxY)
        }
    }

    private static func isAncestorOrSelf(_ candidate: AsciiSubgraph, _ target: AsciiSubgraph) -> Bool {
        var current: AsciiSubgraph? = target
        while let c = current {
            if c === candidate {
                return true
            }
            current = c.parent
        }
        return false
    }

    private static func calculateSubgraphBoundingBox(_ graph: AsciiGraph, _ sg: AsciiSubgraph) {
        guard !sg.nodes.isEmpty else { return }
        var minX = Int.max
        var minY = Int.max
        var maxX = Int.min
        var maxY = Int.min

        for child in sg.children {
            calculateSubgraphBoundingBox(graph, child)
            if !child.nodes.isEmpty {
                minX = min(minX, child.minX)
                minY = min(minY, child.minY)
                maxX = max(maxX, child.maxX)
                maxY = max(maxY, child.maxY)
            }
        }

        for node in sg.nodes {
            guard let dc = node.drawingCoord, let drawing = node.drawing, let firstRow = drawing.first else {
                continue
            }
            let nodeMinX = dc.x
            let nodeMinY = dc.y
            let nodeMaxX = nodeMinX + drawing.count - 1
            let nodeMaxY = nodeMinY + firstRow.count - 1
            minX = min(minX, nodeMinX)
            minY = min(minY, nodeMinY)
            maxX = max(maxX, nodeMaxX)
            maxY = max(maxY, nodeMaxY)
        }

        let subgraphPadding = 2
        let subgraphLabelSpace = 2
        sg.minX = minX - subgraphPadding
        sg.minY = minY - subgraphPadding - subgraphLabelSpace
        sg.maxX = maxX + subgraphPadding
        sg.maxY = maxY + subgraphPadding
    }

    private static func ensureSubgraphSpacing(_ graph: AsciiGraph) {
        let minSpacing = 1
        let rootSubgraphs = graph.subgraphs.filter { $0.parent == nil && !$0.nodes.isEmpty }
        for i in 0..<rootSubgraphs.count {
            for j in (i + 1)..<rootSubgraphs.count {
                let sg1 = rootSubgraphs[i]
                let sg2 = rootSubgraphs[j]
                if sg1.minX < sg2.maxX && sg1.maxX > sg2.minX {
                    if sg1.maxY >= sg2.minY - minSpacing && sg1.minY < sg2.minY {
                        sg2.minY = sg1.maxY + minSpacing + 1
                    } else if sg2.maxY >= sg1.minY - minSpacing && sg2.minY < sg1.minY {
                        sg1.minY = sg2.maxY + minSpacing + 1
                    }
                }
                if sg1.minY < sg2.maxY && sg1.maxY > sg2.minY {
                    if sg1.maxX >= sg2.minX - minSpacing && sg1.minX < sg2.minX {
                        sg2.minX = sg1.maxX + minSpacing + 1
                    } else if sg2.maxX >= sg1.minX - minSpacing && sg2.minX < sg1.minX {
                        sg1.minX = sg2.maxX + minSpacing + 1
                    }
                }
            }
        }
    }

    private static func getEdgesFromNode(_ graph: AsciiGraph, _ node: AsciiNode) -> [original_src_ascii_converter.AsciiEdge] {
        graph.edges.filter { $0.from.name == node.name }
    }

    private static func getChildren(_ graph: AsciiGraph, _ node: AsciiNode) -> [AsciiNode] {
        getEdgesFromNode(graph, node).map(\.to)
    }
}
