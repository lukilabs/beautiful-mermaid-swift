// Ported from original/src/layout.ts
import Foundation
import ElkSwift

private typealias _ParsedGraph = original_src_types.MermaidGraph
private typealias _ParsedNode = original_src_types.MermaidNode
private typealias _ParsedEdge = original_src_types.MermaidEdge

private typealias _ElkNode = [String: Any]

public struct _PositionedPointPayload: Sendable {
    public var x: Double
    public var y: Double
}

public struct _PositionedNodePayload: Sendable {
    public var id: String
    public var label: String
    public var shape: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var inlineStyle: [String: String]
}

public struct _PositionedEdgePayload: Sendable {
    public var source: String
    public var target: String
    public var label: String?
    public var style: String
    public var hasArrowStart: Bool
    public var hasArrowEnd: Bool
    public var points: [_PositionedPointPayload]
    public var labelPosition: _PositionedPointPayload?
    public var inlineStyle: [String: String]?
}

private func _asDict(_ value: Any?) -> [String: Any]? {
    value as? [String: Any]
}

private func _asDictArray(_ value: Any?) -> [[String: Any]] {
    if let direct = value as? [[String: Any]] { return direct }
    if let anyArray = value as? [Any] { return anyArray.compactMap { $0 as? [String: Any] } }
    return []
}

private func _asString(_ value: Any?) -> String? {
    value as? String
}

private func _asDouble(_ value: Any?) -> Double? {
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    if let f = value as? Float { return Double(f) }
    if let n = value as? NSNumber { return n.doubleValue }
    return nil
}

private func _mapDirection(_ direction: original_src_types.Direction) -> String {
    switch direction {
    case .LR: return "RIGHT"
    case .RL: return "LEFT"
    case .BT: return "UP"
    case .TD, .TB: return "DOWN"
    }
}

private func _nodeSize(_ node: _ParsedNode) -> (width: Double, height: Double) {
    let metrics = original_src_text_metrics.measureMultilineText(
        node.label,
        fontSize: original_src_styles.FONT_SIZES.nodeLabel,
        fontWeight: original_src_styles.FONT_WEIGHTS.nodeLabel
    )
    // Match TS NODE_PADDING: horizontal=20 (*2=40), vertical=10 (*2=20)
    var width = metrics.width + 40
    var height = metrics.height + 20

    switch node.shape {
    case .diamond:
        let side = max(width, height) + 24  // TS diamondExtra=24
        width = side; height = side
    case .circle:
        let d = ceil(sqrt(width * width + height * height)) + 8
        width = d; height = d
    case .doublecircle:
        let d = ceil(sqrt(width * width + height * height)) + 8 + 12
        width = d; height = d
    case .hexagon:
        width += 20  // TS adds NODE_PADDING.horizontal
    case .trapezoid, .trapezoidAlt:
        width += 20
    case .asymmetric:
        width += 12
    case .cylinder:
        height += 14
    case .stateStart, .stateEnd:
        return (28, 28)
    default: break
    }

    width = max(width, 60)
    height = max(height, 36)
    return (width, height)
}

private func _buildElkGraph(_ graph: _ParsedGraph) -> _ElkNode {
    // Determine which nodes belong to which subgraph
    let subgraphOwnership = _buildSubgraphOwnership(graph.subgraphs)

    // Build edge label helper
    func _edgeDict(_ idx: Int, _ edge: original_src_types.MermaidEdge) -> [String: Any] {
        var out: [String: Any] = [
            "id": "e\(idx)",
            "sources": [edge.source],
            "targets": [edge.target]
        ]
        if let label = edge.label, !label.isEmpty {
            let m = original_src_text_metrics.measureMultilineText(
                label,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            out["labels"] = [[
                "text": label,
                "width": m.width + 8,
                "height": m.height + 6,
                "layoutOptions": [
                    "elk.edgeLabels.inline": "true",
                    "elk.edgeLabels.placement": "CENTER"
                ]
            ] as [String: Any]]
        }
        return out
    }

    if graph.subgraphs.isEmpty {
        // Fast path: flat graph
        var children: [[String: Any]] = []
        for entry in graph.nodesInOrder {
            let size = _nodeSize(entry.node)
            children.append([
                "id": entry.id,
                "width": size.width,
                "height": size.height,
                "labels": [["text": entry.node.label]]
            ])
        }
        var edges: [[String: Any]] = []
        for (idx, edge) in graph.edges.enumerated() {
            edges.append(_edgeDict(idx, edge))
        }
        return [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.direction": _mapDirection(graph.direction),
                "elk.spacing.nodeNode": "28",
                "elk.spacing.edgeEdge": "12",
                "elk.layered.spacing.nodeNodeBetweenLayers": "48",
                "elk.layered.spacing.edgeEdgeBetweenLayers": "12",
                "elk.layered.spacing.edgeNodeBetweenLayers": "12",
                "elk.padding": "[top=40,left=40,bottom=40,right=40]",
                "elk.edgeRouting": "ORTHOGONAL",
                "elk.contentAlignment": "H_CENTER V_CENTER",
                "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
                "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
                "elk.layered.thoroughness": "3",
                "elk.layered.compaction.postCompaction.strategy": "LEFT_RIGHT_CONSTRAINT_LOCKING",
                "elk.layered.highDegreeNodes.treatment": "true",
                "elk.layered.highDegreeNodes.threshold": "8",
                "elk.layered.wrapping.strategy": "OFF",
                "elk.hierarchyHandling": "INCLUDE_CHILDREN"
            ],
            "children": children,
            "edges": edges
        ]
    }

    // Build set of all nodes claimed by any subgraph
    let allClaimedNodes = Set(subgraphOwnership.values.flatMap { $0 })
    let nodeById = Dictionary(graph.nodesInOrder.map { ($0.id, $0.node) }, uniquingKeysWith: { _, last in last })

    // Determine which subgraph (deepest) contains a node
    func _deepestSubgraph(for nodeId: String, in subs: [original_src_types.MermaidSubgraph]) -> String? {
        for sub in subs {
            if let deeper = _deepestSubgraph(for: nodeId, in: sub.children) {
                return deeper
            }
            if sub.nodeIds.contains(nodeId) {
                return sub.id
            }
        }
        return nil
    }

    // Build nodeToSubgraph map (innermost subgraph for each node)
    var nodeToSubgraph: [String: String] = [:]
    for entry in graph.nodesInOrder {
        if let sg = _deepestSubgraph(for: entry.id, in: graph.subgraphs) {
            nodeToSubgraph[entry.id] = sg
        }
    }

    // Classify edges: internal (same subgraph), root (no subgraph), cross-hierarchy
    var edgesBySubgraph: [String: [[String: Any]]] = [:]
    var rootOnlyEdges: [[String: Any]] = []
    struct CrossEdge {
        let idx: Int
        let edge: original_src_types.MermaidEdge
        let srcSub: String?
        let tgtSub: String?
    }
    var crossEdges: [CrossEdge] = []

    for (idx, edge) in graph.edges.enumerated() {
        let srcSub = nodeToSubgraph[edge.source]
        let tgtSub = nodeToSubgraph[edge.target]
        if let s = srcSub, let t = tgtSub, s == t {
            // Internal edge — both in same subgraph
            edgesBySubgraph[s, default: []].append(_edgeDict(idx, edge))
        } else if srcSub == nil && tgtSub == nil {
            // Root-level edge — neither in a subgraph
            rootOnlyEdges.append(_edgeDict(idx, edge))
        } else {
            // Cross-hierarchy edge — needs port-based routing in SEPARATE mode
            crossEdges.append(CrossEdge(idx: idx, edge: edge, srcSub: srcSub, tgtSub: tgtSub))
        }
    }

    var rootEdges = rootOnlyEdges

    // Build hierarchical ports for cross-hierarchy edges (SEPARATE mode)
    var portsBySubgraph: [String: [([String: Any], [String: Any])]] = [:]

    for ce in crossEdges {
        let idx = ce.idx
        if let srcSg = ce.srcSub {
            let portId = "\(srcSg)_out_\(idx)"
            let port: [String: Any] = ["id": portId]
            var internalEdge: [String: Any] = [
                "id": "e\(idx)_out",
                "sources": [ce.edge.source],
                "targets": [portId]
            ]
            if let label = ce.edge.label, !label.isEmpty {
                let m = original_src_text_metrics.measureMultilineText(
                    label, fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                    fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel)
                internalEdge["labels"] = [["text": label, "width": m.width + 8, "height": m.height + 6, "layoutOptions": ["elk.edgeLabels.inline": "true", "elk.edgeLabels.placement": "CENTER"]] as [String: Any]]
            }
            portsBySubgraph[srcSg, default: []].append((port, internalEdge))
        }

        if let tgtSg = ce.tgtSub {
            let portId = "\(tgtSg)_in_\(idx)"
            let port: [String: Any] = ["id": portId]
            let internalEdge: [String: Any] = [
                "id": "e\(idx)_in",
                "sources": [portId],
                "targets": [ce.edge.target]
            ]
            portsBySubgraph[tgtSg, default: []].append((port, internalEdge))
        }

        let srcId = ce.srcSub.map { "\($0)_out_\(idx)" } ?? ce.edge.source
        let tgtId = ce.tgtSub.map { "\($0)_in_\(idx)" } ?? ce.edge.target
        var rootEdge: [String: Any] = [
            "id": "e\(idx)",
            "sources": [srcId],
            "targets": [tgtId]
        ]
        if ce.srcSub == nil, let label = ce.edge.label, !label.isEmpty {
            let m = original_src_text_metrics.measureMultilineText(
                label, fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel)
            rootEdge["labels"] = [["text": label, "width": m.width + 8, "height": m.height + 6, "layoutOptions": ["elk.edgeLabels.inline": "true", "elk.edgeLabels.placement": "CENTER"]] as [String: Any]]
        }
        rootEdges.append(rootEdge)
    }

    // Recursive builder for subgraph compound nodes
    func buildSubgraphNode(_ sub: original_src_types.MermaidSubgraph) -> [String: Any] {
        let directNodeIds = sub.nodeIds.filter { nodeId in
            !sub.children.contains { child in
                _subgraphContainsNode(child, nodeId: nodeId)
            }
        }

        var children: [[String: Any]] = []
        for nodeId in directNodeIds {
            guard let node = nodeById[nodeId] else { continue }
            let size = _nodeSize(node)
            children.append([
                "id": nodeId,
                "width": size.width,
                "height": size.height,
                "labels": [["text": node.label]]
            ])
        }
        for child in sub.children {
            children.append(buildSubgraphNode(child))
        }

        // Add ports for cross-hierarchy edges
        var ports: [[String: Any]] = []
        var internalEdges: [[String: Any]] = []
        if let pairs = portsBySubgraph[sub.id] {
            for (port, edge) in pairs {
                ports.append(port)
                internalEdges.append(edge)
            }
        }

        var subgraphEdges = edgesBySubgraph[sub.id] ?? []
        subgraphEdges.append(contentsOf: internalEdges)

        // Match TS subgraph layout options exactly
        var opts: [String: String] = [
            "elk.algorithm": "layered",
            "elk.padding": "[top=44,left=16,bottom=16,right=16]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.contentAlignment": "H_CENTER V_CENTER",
            "elk.spacing.edgeEdge": "12",
            "elk.layered.spacing.edgeEdgeBetweenLayers": "12",
            "elk.layered.spacing.edgeNodeBetweenLayers": "12",
            "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.spacing.nodeNode": "28"
        ]
        if let dir = sub.direction {
            opts["elk.direction"] = _mapDirection(dir)
        }

        let subLabel = sub.label ?? sub.id
        var result: [String: Any] = [
            "id": sub.id,
            "layoutOptions": opts,
            "children": children,
            "labels": [["text": subLabel]]
        ]
        if !ports.isEmpty { result["ports"] = ports }
        if !subgraphEdges.isEmpty { result["edges"] = subgraphEdges }
        return result
    }

    // Root children: top-level subgraphs + unclaimed nodes
    var rootChildren: [[String: Any]] = []
    for entry in graph.nodesInOrder {
        if !allClaimedNodes.contains(entry.id) {
            let size = _nodeSize(entry.node)
            rootChildren.append([
                "id": entry.id,
                "width": size.width,
                "height": size.height,
                "labels": [["text": entry.node.label]]
            ])
        }
    }
    for sub in graph.subgraphs {
        rootChildren.append(buildSubgraphNode(sub))
    }

    return [
        "id": "root",
        "layoutOptions": [
            "elk.algorithm": "layered",
            "elk.direction": _mapDirection(graph.direction),
            "elk.spacing.nodeNode": "28",
            "elk.spacing.edgeEdge": "12",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.layered.spacing.edgeEdgeBetweenLayers": "12",
            "elk.layered.spacing.edgeNodeBetweenLayers": "12",
            "elk.padding": "[top=40,left=40,bottom=40,right=40]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.contentAlignment": "H_CENTER V_CENTER",
            "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
            "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
            "elk.layered.thoroughness": "3",
            "elk.layered.compaction.postCompaction.strategy": "LEFT_RIGHT_CONSTRAINT_LOCKING",
            "elk.layered.highDegreeNodes.treatment": "true",
            "elk.layered.highDegreeNodes.threshold": "8",
            "elk.layered.wrapping.strategy": "OFF",
            "elk.hierarchyHandling": "SEPARATE"
        ],
        "children": rootChildren,
        "edges": rootEdges
    ]
}

/// Build a map of subgraph ID -> set of all transitively contained node IDs
private func _buildSubgraphOwnership(
    _ subs: [original_src_types.MermaidSubgraph]
) -> [String: Set<String>] {
    var result: [String: Set<String>] = [:]
    for sub in subs {
        result[sub.id] = _allNodeIds(in: sub)
        for (k, v) in _buildSubgraphOwnership(sub.children) {
            result[k] = v
        }
    }
    return result
}

private func _allNodeIds(in sub: original_src_types.MermaidSubgraph) -> Set<String> {
    var ids = Set(sub.nodeIds)
    for child in sub.children {
        ids.formUnion(_allNodeIds(in: child))
    }
    return ids
}

private func _subgraphContainsNode(_ sub: original_src_types.MermaidSubgraph, nodeId: String) -> Bool {
    if sub.nodeIds.contains(nodeId) { return true }
    return sub.children.contains { _subgraphContainsNode($0, nodeId: nodeId) }
}

public struct _PositionedGroupPayload: Sendable {
    public var id: String
    public var label: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var headerHeight: Double = 28
    public var children: [_PositionedGroupPayload]
}

/// Collect all leaf-node children from the ELK result, including those nested inside compound nodes.
/// Returns tuples of (child dict, cumulative parent offset).
private func _collectAllChildren(
    _ elkNode: [String: Any],
    nodeById: [String: original_src_types.MermaidNode],
    parentOffset: (x: Double, y: Double) = (0, 0)
) -> [([String: Any], (x: Double, y: Double))] {
    var result: [([String: Any], (x: Double, y: Double))] = []
    for child in _asDictArray(elkNode["children"]) {
        guard let id = _asString(child["id"]) else { continue }
        if nodeById[id] != nil && _asDictArray(child["children"]).isEmpty {
            // Leaf node
            result.append((child, parentOffset))
        } else {
            // Compound node — recurse into its children with accumulated offset
            let cx = (_asDouble(child["x"]) ?? 0) + parentOffset.x
            let cy = (_asDouble(child["y"]) ?? 0) + parentOffset.y
            result += _collectAllChildren(child, nodeById: nodeById, parentOffset: (cx, cy))
        }
    }
    return result
}

/// Edge segments collected from ELK result, grouped by original edge index.
private struct _EdgeSegments {
    var external: [_PositionedPointPayload]?
    var incoming: [_PositionedPointPayload]?
    var outgoing: [_PositionedPointPayload]?
    var labelPosition: _PositionedPointPayload?
}

/// Recursively collect edge segments from ELK result.
/// Parses edge IDs to identify external ("e3"), outgoing ("e3_out"), and incoming ("e3_in") segments.
private func _collectEdgeSegments(
    _ elkNode: [String: Any],
    segments: inout [Int: _EdgeSegments],
    offsetX: Double,
    offsetY: Double
) {
    for elkEdge in _asDictArray(elkNode["edges"]) {
        guard let eid = _asString(elkEdge["id"]) else { continue }

        // Parse edge ID
        let isOut = eid.hasSuffix("_out")
        let isIn = eid.hasSuffix("_in")
        let isInternal = eid.hasSuffix("_internal")
        let indexStr: String
        if isOut {
            indexStr = String(eid.dropFirst(1).dropLast(4)) // "e3_out" → "3"
        } else if isIn {
            indexStr = String(eid.dropFirst(1).dropLast(3)) // "e3_in" → "3"
        } else if isInternal {
            indexStr = String(eid.dropFirst(1).dropLast(9)) // "e3_internal" → "3"
        } else {
            indexStr = String(eid.dropFirst(1)) // "e3" → "3"
        }
        guard let edgeIndex = Int(indexStr) else { continue }

        // Extract points from sections
        var points: [_PositionedPointPayload] = []
        if let section = _asDictArray(elkEdge["sections"]).first {
            if let s = _asDict(section["startPoint"]) {
                points.append(_PositionedPointPayload(
                    x: (_asDouble(s["x"]) ?? 0) + offsetX,
                    y: (_asDouble(s["y"]) ?? 0) + offsetY
                ))
            }
            for bp in _asDictArray(section["bendPoints"]) {
                points.append(_PositionedPointPayload(
                    x: (_asDouble(bp["x"]) ?? 0) + offsetX,
                    y: (_asDouble(bp["y"]) ?? 0) + offsetY
                ))
            }
            if let e = _asDict(section["endPoint"]) {
                points.append(_PositionedPointPayload(
                    x: (_asDouble(e["x"]) ?? 0) + offsetX,
                    y: (_asDouble(e["y"]) ?? 0) + offsetY
                ))
            }
        }

        // Extract label position
        var labelPos: _PositionedPointPayload?
        if let label = _asDictArray(elkEdge["labels"]).first {
            if let lx = _asDouble(label["x"]), let ly = _asDouble(label["y"]) {
                let lw = _asDouble(label["width"]) ?? 0
                let lh = _asDouble(label["height"]) ?? 0
                labelPos = _PositionedPointPayload(
                    x: lx + lw / 2 + offsetX,
                    y: ly + lh / 2 + offsetY
                )
            }
        }

        // Store segment
        if segments[edgeIndex] == nil {
            segments[edgeIndex] = _EdgeSegments()
        }

        if isOut {
            segments[edgeIndex]?.outgoing = points
        } else if isIn {
            segments[edgeIndex]?.incoming = points
        } else if isInternal {
            let sources = (elkEdge["sources"] as? [String]) ?? []
            let src = sources.first ?? ""
            if src.contains("_in_") || src.contains("_out_") {
                segments[edgeIndex]?.incoming = points
            } else {
                segments[edgeIndex]?.outgoing = points
            }
        } else {
            segments[edgeIndex]?.external = points
            if let lp = labelPos {
                segments[edgeIndex]?.labelPosition = lp
            }
        }
    }

    // Recurse into compound children with accumulated offset
    for child in _asDictArray(elkNode["children"]) {
        if !_asDictArray(child["children"]).isEmpty {
            let cx = (_asDouble(child["x"]) ?? 0) + offsetX
            let cy = (_asDouble(child["y"]) ?? 0) + offsetY
            _collectEdgeSegments(child, segments: &segments, offsetX: cx, offsetY: cy)
        }
    }
}

/// Flatten all group bounding boxes for margin computation.
private func _flattenGroupBounds(_ groups: [_PositionedGroupPayload]) -> [_PositionedGroupPayload] {
    var result: [_PositionedGroupPayload] = []
    for g in groups {
        result.append(g)
        result.append(contentsOf: _flattenGroupBounds(g.children))
    }
    return result
}

/// Ensure all edge segments are orthogonal (horizontal or vertical only).
/// Matches TS orthogonalizeEdgePoints: when margins are available, routes through
/// left/right margins (alternating sides with spacing). Without margins, uses Z-path
/// through the vertical midpoint.
/// Returns (points, didChange) so caller can track margin edge index.
private func _orthogonalizeEdgePoints(
    _ points: [_PositionedPointPayload],
    margins: (leftX: Double, rightX: Double)?,
    edgeIndex: Int
) -> (points: [_PositionedPointPayload], changed: Bool) {
    guard points.count >= 2 else { return (points, false) }

    var needsWork = false
    for i in 1..<points.count {
        let dx = abs(points[i].x - points[i-1].x)
        let dy = abs(points[i].y - points[i-1].y)
        if dx > 1 && dy > 1 { needsWork = true; break }
    }
    guard needsWork else { return (points, false) }

    let edgeSpacing: Double = 12
    var result: [_PositionedPointPayload] = [points[0]]

    for i in 1..<points.count {
        let prev = result[result.count - 1]
        let curr = points[i]
        let dx = abs(curr.x - prev.x)
        let dy = abs(curr.y - prev.y)

        if dx > 1 && dy > 1 {
            if let margins {
                // Margin routing: exit horizontally → travel vertically along margin → enter horizontally
                let useRight = edgeIndex % 2 == 0
                let offset = Double(edgeIndex / 2) * edgeSpacing
                let marginX = useRight
                    ? margins.rightX + offset
                    : margins.leftX - offset
                result.append(_PositionedPointPayload(x: marginX, y: prev.y))
                result.append(_PositionedPointPayload(x: marginX, y: curr.y))
            } else {
                // Fallback: Z-path through vertical midpoint
                let midY = (prev.y + curr.y) / 2
                result.append(_PositionedPointPayload(x: prev.x, y: midY))
                result.append(_PositionedPointPayload(x: curr.x, y: midY))
            }
        }
        result.append(curr)
    }
    return (result, true)
}


/// Snap same-layer nodes to uniform positions along the flow axis.
/// ELK's orthogonal routing staggers nodes within a layer; this post-processing
/// aligns them, matching the original TypeScript implementation.
private func _alignLayerNodes(
    _ nodes: inout [_PositionedNodePayload],
    _ edges: inout [_PositionedEdgePayload],
    _ direction: original_src_types.Direction
) {
    guard !nodes.isEmpty else { return }

    let isHorizontal = direction == .LR || direction == .RL
    let layerSpacing: Double = 48
    let threshold = layerSpacing * 0.6

    // Build connected pairs set
    var connectedPairs = Set<String>()
    for edge in edges {
        connectedPairs.insert("\(edge.source):\(edge.target)")
        connectedPairs.insert("\(edge.target):\(edge.source)")
    }

    // Sort nodes by flow-axis position
    let sorted = nodes.sorted { a, b in
        isHorizontal ? a.x < b.x : a.y < b.y
    }

    // Cluster into layers using single-linkage with connected-pair exclusion
    var layers: [[Int]] = [] // indices into `nodes`
    let nodeIndexMap = Dictionary(nodes.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { _, last in last })
    let sortedIndices = sorted.compactMap { nodeIndexMap[$0.id] }

    var currentLayer: [Int] = [sortedIndices[0]]
    for i in 1..<sortedIndices.count {
        let idx = sortedIndices[i]
        let prevIdx = sortedIndices[i - 1]
        let pos = isHorizontal ? nodes[idx].x : nodes[idx].y
        let prevPos = isHorizontal ? nodes[prevIdx].x : nodes[prevIdx].y
        let gap = pos - prevPos

        let hasEdgeToLayer = currentLayer.contains { layerIdx in
            connectedPairs.contains("\(nodes[layerIdx].id):\(nodes[idx].id)")
        }

        if gap <= threshold && !hasEdgeToLayer {
            currentLayer.append(idx)
        } else {
            layers.append(currentLayer)
            currentLayer = [idx]
        }
    }
    layers.append(currentLayer)

    // Snap each layer's nodes to the center
    var deltas: [String: Double] = [:]
    for layer in layers {
        guard layer.count > 1 else { continue }
        let positions = layer.map { isHorizontal ? nodes[$0].x : nodes[$0].y }
        let minPos = positions.min() ?? positions[0]
        let maxPos = positions.max() ?? positions[0]
        guard maxPos - minPos > 1 else { continue }

        let target = (minPos + maxPos) / 2
        for idx in layer {
            let oldPos = isHorizontal ? nodes[idx].x : nodes[idx].y
            let delta = target - oldPos
            if abs(delta) > 0.5 {
                if isHorizontal {
                    nodes[idx].x = target
                } else {
                    nodes[idx].y = target
                }
                deltas[nodes[idx].id] = delta
            }
        }
    }

    guard !deltas.isEmpty else { return }

    // Adjust edge endpoints to match shifted nodes
    for i in edges.indices {
        guard edges[i].points.count >= 2 else { continue }

        if let srcDelta = deltas[edges[i].source] {
            if isHorizontal {
                let oldX = edges[i].points[0].x
                edges[i].points[0].x += srcDelta
                if edges[i].points.count > 1 && edges[i].points[1].x == oldX {
                    edges[i].points[1].x += srcDelta
                }
            } else {
                let oldY = edges[i].points[0].y
                edges[i].points[0].y += srcDelta
                if edges[i].points.count > 1 && edges[i].points[1].y == oldY {
                    edges[i].points[1].y += srcDelta
                }
            }
        }

        if let tgtDelta = deltas[edges[i].target] {
            let lastIdx = edges[i].points.count - 1
            if isHorizontal {
                let oldX = edges[i].points[lastIdx].x
                edges[i].points[lastIdx].x += tgtDelta
                if lastIdx > 0 && edges[i].points[lastIdx - 1].x == oldX {
                    edges[i].points[lastIdx - 1].x += tgtDelta
                }
            } else {
                let oldY = edges[i].points[lastIdx].y
                edges[i].points[lastIdx].y += tgtDelta
                if lastIdx > 0 && edges[i].points[lastIdx - 1].y == oldY {
                    edges[i].points[lastIdx - 1].y += tgtDelta
                }
            }
        }
    }
}

/// Bundle fan-out and fan-in edge paths so they share a common trunk segment.
/// Edges in a bundle must share the same style and have no labels.
private func _bundleEdgePaths(
    _ edges: inout [_PositionedEdgePayload],
    _ nodes: [_PositionedNodePayload],
    _ groups: [_PositionedGroupPayload],
    _ direction: original_src_types.Direction
) {
    let nodeMap = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    var processed = Set<Int>() // edge indices

    let isLR = direction == .LR
    let isRL = direction == .RL
    let isBT = direction == .BT
    let isHorizontal = isLR || isRL

    // --- Fan-out: group edges by shared source ---
    var fanOutGroups: [String: [Int]] = [:]
    for (i, edge) in edges.enumerated() {
        guard edge.source != edge.target else { continue }
        fanOutGroups[edge.source, default: []].append(i)
    }

    for (sourceId, group) in fanOutGroups {
        guard group.count >= 2 else { continue }
        let style = edges[group[0]].style
        if group.contains(where: { edges[$0].label != nil || edges[$0].style != style }) { continue }
        guard let source = nodeMap[sourceId] else { continue }

        let forward = group.filter { idx in
            guard let t = nodeMap[edges[idx].target] else { return false }
            if isLR { return t.x > source.x + source.width }
            if isRL { return t.x + t.width < source.x }
            // y=0 at top: TD forward = target has higher y; BT forward = target has lower y
            if isBT { return t.y + t.height < source.y }
            return t.y > source.y + source.height // TD
        }
        guard forward.count >= 2 else { continue }

        let srcCX = source.x + source.width / 2
        let srcCY = source.y + source.height / 2

        if isHorizontal {
            let exitX = isLR ? source.x + source.width : source.x
            let exitY = srcCY
            let nearestX = isLR
                ? forward.compactMap { nodeMap[edges[$0].target]?.x }.min() ?? exitX
                : forward.compactMap { nodeMap[edges[$0].target] }.map { $0.x + $0.width }.max() ?? exitX
            let junctionX = _adjustJunctionForGroups(exitX + (nearestX - exitX) / 2, refX: srcCX, refY: srcCY, groups: groups, direction: direction)
            for idx in forward {
                guard let target = nodeMap[edges[idx].target] else { continue }
                let entryX = isLR ? target.x : target.x + target.width
                let entryY = target.y + target.height / 2
                edges[idx].points = [
                    _PositionedPointPayload(x: exitX, y: exitY),
                    _PositionedPointPayload(x: junctionX, y: exitY),
                    _PositionedPointPayload(x: junctionX, y: entryY),
                    _PositionedPointPayload(x: entryX, y: entryY),
                ]
                processed.insert(idx)
            }
        } else {
            let exitX = srcCX
            // y=0 at top: TD exit at bottom of node = node.y + height
            let exitY = isBT ? source.y : source.y + source.height
            let nearestY = isBT
                ? forward.compactMap { nodeMap[edges[$0].target] }.map { $0.y + $0.height }.max() ?? exitY
                : forward.compactMap { nodeMap[edges[$0].target]?.y }.min() ?? exitY
            let junctionY = _adjustJunctionForGroups(exitY + (nearestY - exitY) / 2, refX: srcCX, refY: srcCY, groups: groups, direction: direction)
            for idx in forward {
                guard let target = nodeMap[edges[idx].target] else { continue }
                let entryX = target.x + target.width / 2
                // y=0 at top: TD enter at top of node = node.y
                let entryY = isBT ? target.y + target.height : target.y
                edges[idx].points = [
                    _PositionedPointPayload(x: exitX, y: exitY),
                    _PositionedPointPayload(x: exitX, y: junctionY),
                    _PositionedPointPayload(x: entryX, y: junctionY),
                    _PositionedPointPayload(x: entryX, y: entryY),
                ]
                processed.insert(idx)
            }
        }
    }

    // --- Fan-in: group edges by shared target (skip already-bundled) ---
    var fanInGroups: [String: [Int]] = [:]
    for (i, edge) in edges.enumerated() {
        guard !processed.contains(i), edge.source != edge.target else { continue }
        fanInGroups[edge.target, default: []].append(i)
    }

    for (targetId, group) in fanInGroups {
        guard group.count >= 2 else { continue }
        let style = edges[group[0]].style
        if group.contains(where: { edges[$0].label != nil || edges[$0].style != style }) { continue }
        guard let target = nodeMap[targetId] else { continue }

        // y=0 at top: TD "forward" means source is above target (source has lower y)
        let forward = group.filter { idx in
            guard let s = nodeMap[edges[idx].source] else { return false }
            if isLR { return s.x + s.width < target.x }
            if isRL { return s.x > target.x + target.width }
            if isBT { return s.y > target.y + target.height }
            return s.y + s.height < target.y // TD
        }
        guard forward.count >= 2 else { continue }

        let tgtCX = target.x + target.width / 2
        let tgtCY = target.y + target.height / 2

        if isHorizontal {
            let entryX = isLR ? target.x : target.x + target.width
            let entryY = tgtCY
            let farthestX = isLR
                ? forward.compactMap { nodeMap[edges[$0].source] }.map { $0.x + $0.width }.max() ?? entryX
                : forward.compactMap { nodeMap[edges[$0].source]?.x }.min() ?? entryX
            let junctionX = _adjustJunctionForGroups(farthestX + (entryX - farthestX) / 2, refX: tgtCX, refY: tgtCY, groups: groups, direction: direction)
            for idx in forward {
                guard let src = nodeMap[edges[idx].source] else { continue }
                let exitX = isLR ? src.x + src.width : src.x
                let exitY = src.y + src.height / 2
                edges[idx].points = [
                    _PositionedPointPayload(x: exitX, y: exitY),
                    _PositionedPointPayload(x: junctionX, y: exitY),
                    _PositionedPointPayload(x: junctionX, y: entryY),
                    _PositionedPointPayload(x: entryX, y: entryY),
                ]
            }
        } else {
            let entryX = tgtCX
            // y=0 at top: TD enter at top = node.y
            let entryY = isBT ? target.y + target.height : target.y
            let farthestY = isBT
                ? forward.compactMap { nodeMap[edges[$0].source]?.y }.min() ?? entryY
                : forward.compactMap { nodeMap[edges[$0].source] }.map { $0.y + $0.height }.max() ?? entryY
            let junctionY = _adjustJunctionForGroups(farthestY + (entryY - farthestY) / 2, refX: tgtCX, refY: tgtCY, groups: groups, direction: direction)
            for idx in forward {
                guard let src = nodeMap[edges[idx].source] else { continue }
                let exitX = src.x + src.width / 2
                // y=0 at top: TD exit at bottom = src.y + height
                let exitY = isBT ? src.y : src.y + src.height
                edges[idx].points = [
                    _PositionedPointPayload(x: exitX, y: exitY),
                    _PositionedPointPayload(x: exitX, y: junctionY),
                    _PositionedPointPayload(x: entryX, y: junctionY),
                    _PositionedPointPayload(x: entryX, y: entryY),
                ]
            }
        }
    }
}

private func _adjustJunctionForGroups(
    _ junctionMain: Double,
    refX: Double,
    refY: Double,
    groups: [_PositionedGroupPayload],
    direction: original_src_types.Direction
) -> Double {
    let gap: Double = 12
    let isLR = direction == .LR
    let isRL = direction == .RL
    let isBT = direction == .BT
    let isHorizontal = isLR || isRL

    let refGroupIds = Set(_findGroupsContainingPoint(refX, refY, groups).map { $0.id })
    let probeX = isHorizontal ? junctionMain : refX
    let probeY = isHorizontal ? refY : junctionMain
    let junctionGroups = _findGroupsContainingPoint(probeX, probeY, groups)

    guard let crossingGroup = junctionGroups.first(where: { !refGroupIds.contains($0.id) }) else {
        return junctionMain
    }

    if isLR { return crossingGroup.x - gap }
    if isRL { return crossingGroup.x + crossingGroup.width + gap }
    // y=0 at top: higher Y = visually lower on screen
    // y=0 at top: TD "above" = smaller y; BT "above" = larger y
    if isBT { return crossingGroup.y + crossingGroup.height + gap }
    return crossingGroup.y - gap  // TD: above group = smaller y
}

private func _findGroupsContainingPoint(
    _ x: Double, _ y: Double,
    _ groups: [_PositionedGroupPayload]
) -> [_PositionedGroupPayload] {
    var result: [_PositionedGroupPayload] = []
    for group in groups {
        if x >= group.x && x <= group.x + group.width &&
           y >= group.y && y <= group.y + group.height {
            result.append(group)
            result.append(contentsOf: _findGroupsContainingPoint(x, y, group.children))
        }
    }
    return result
}

/// Extract positioned subgraph groups from the ELK result.
private func _extractSubgraphGroups(
    _ elkNode: [String: Any],
    source: _ParsedGraph,
    graphHeight: Double,
    parentOffset: (x: Double, y: Double) = (0, 0)
) -> [_PositionedGroupPayload] {
    let subgraphIds = Set(_allSubgraphIds(source.subgraphs))
    var groups: [_PositionedGroupPayload] = []
    for child in _asDictArray(elkNode["children"]) {
        guard let id = _asString(child["id"]), subgraphIds.contains(id) else { continue }
        let rawX = (_asDouble(child["x"]) ?? 0) + parentOffset.x
        let rawY = (_asDouble(child["y"]) ?? 0) + parentOffset.y
        let w = _asDouble(child["width"]) ?? 0
        let h = _asDouble(child["height"]) ?? 0
        let label = _findSubgraphLabel(id, in: source.subgraphs) ?? id
        let childGroups = _extractSubgraphGroups(
            child, source: source, graphHeight: graphHeight,
            parentOffset: (rawX, rawY)
        )
        groups.append(_PositionedGroupPayload(
            id: id, label: label,
            x: rawX, y: rawY,
            width: w, height: h,
            children: childGroups
        ))
    }
    return groups
}

private func _allSubgraphIds(_ subs: [original_src_types.MermaidSubgraph]) -> [String] {
    subs.flatMap { [$0.id] + _allSubgraphIds($0.children) }
}

private func _findSubgraphLabel(_ id: String, in subs: [original_src_types.MermaidSubgraph]) -> String? {
    for sub in subs {
        if sub.id == id { return sub.label }
        if let found = _findSubgraphLabel(id, in: sub.children) { return found }
    }
    return nil
}

private func _resolveInlineStyle(_ id: String, _ graph: _ParsedGraph) -> [String: String] {
    var style: [String: String] = [:]
    if let className = graph.classAssignments[id], let classStyle = graph.classDefs[className] {
        for (k, v) in classStyle { style[k] = v }
    }
    if let nodeStyle = graph.nodeStyles[id] {
        for (k, v) in nodeStyle { style[k] = v }
    }
    return style
}

/// Resolve inline styles for an edge from linkStyles map.
/// Default link style (key -1) is applied first, then index-specific overrides.
private func _resolveEdgeStyle(edgeIndex: Int, graph: _ParsedGraph) -> [String: String]? {
    var result: [String: String]?
    if let defaultStyle = graph.linkStyles[-1] {
        result = defaultStyle
    }
    if let indexStyle = graph.linkStyles[edgeIndex] {
        if var r = result {
            for (k, v) in indexStyle { r[k] = v }
            result = r
        } else {
            result = indexStyle
        }
    }
    return result
}

private func _extractPositionedGraph(
    _ source: _ParsedGraph,
    _ laidOut: _ElkNode,
    diagramType: DiagramType
) -> PositionedGraph {
    let nodeById = Dictionary(source.nodesInOrder.map { ($0.id, $0.node) }, uniquingKeysWith: { _, last in last })
    let graphHeight = _asDouble(laidOut["height"]) ?? 0

    // Collect nodes from root and all compound children (subgraphs) recursively
    let allChildren = _collectAllChildren(laidOut, nodeById: nodeById)

    // ELK coordinates (y=0 at top) — rendering handles CGContext flip
    var nodes: [_PositionedNodePayload] = allChildren.compactMap { (child, parentOffset) in
        guard
            let id = _asString(child["id"]),
            let original = nodeById[id]
        else { return nil }
        let w = _asDouble(child["width"]) ?? _nodeSize(original).width
        let h = _asDouble(child["height"]) ?? _nodeSize(original).height
        let rawX = (_asDouble(child["x"]) ?? 0) + parentOffset.x
        let rawY = (_asDouble(child["y"]) ?? 0) + parentOffset.y
        return _PositionedNodePayload(
            id: id,
            label: original.label,
            shape: original.shape.rawValue,
            x: rawX,
            y: rawY,
            width: w,
            height: h,
            inlineStyle: _resolveInlineStyle(id, source)
        )
    }

    // Collect edge segments from all levels (root + subgraphs) with coordinate offsets.
    // Groups segments by original edge index, combining outgoing + external + incoming.
    var segmentsByIndex: [Int: _EdgeSegments] = [:]
    _collectEdgeSegments(laidOut, segments: &segmentsByIndex, offsetX: 0, offsetY: 0)

    // Extract subgraph groups — needed for margin routing
    var groups = _extractSubgraphGroups(laidOut, source: source, graphHeight: graphHeight)

    // Compute margin positions for cross-hierarchy edge routing.
    // Margins sit outside all group bounding boxes so edges don't cross through subgraphs.
    let allBounds = _flattenGroupBounds(groups)
    let margins: (leftX: Double, rightX: Double)? = allBounds.isEmpty ? nil : (
        leftX: (allBounds.map(\.x).min() ?? 0) - 20,
        rightX: (allBounds.map { $0.x + $0.width }.max() ?? 0) + 20
    )

    // Track margin-routed edge count for spacing offsets (matching TS marginEdgeIndex)
    var marginEdgeIndex = 0

    var edges: [_PositionedEdgePayload] = []
    for (idx, edge) in source.edges.enumerated() {
        // Combine points from all segments in correct order:
        // outgoing (source→exit port) + external (exit port→entry port) + incoming (entry port→target)
        let seg = segmentsByIndex[idx]
        var points: [_PositionedPointPayload] = []

        // First: outgoing internal segment (source node → exit port)
        if let outgoing = seg?.outgoing, !outgoing.isEmpty {
            points.append(contentsOf: outgoing)
        }

        // Second: external segment (exit port → entry port)
        if let external = seg?.external, !external.isEmpty {
            if !points.isEmpty {
                // Skip first point to avoid duplicate at outgoing port
                points.append(contentsOf: Array(external.dropFirst()))
            } else {
                points.append(contentsOf: external)
            }
        }

        // Third: incoming internal segment (entry port → target node)
        if let incoming = seg?.incoming, !incoming.isEmpty {
            if !points.isEmpty {
                // Skip first point to avoid duplicate at incoming port
                points.append(contentsOf: Array(incoming.dropFirst()))
            } else {
                points.append(contentsOf: incoming)
            }
        }

        // Label position from ELK, or fall back to path midpoint later
        let labelPos = seg?.labelPosition

        // Orthogonalize: fix diagonal segments from SEPARATE mode stitching.
        // Route through left/right margins when available (matching TS behavior).
        let ortho = _orthogonalizeEdgePoints(points, margins: margins, edgeIndex: marginEdgeIndex)
        if ortho.changed {
            points = ortho.points
            marginEdgeIndex += 1
        }

        // Recalculate label position for margin-routed edges
        var finalLabelPos: _PositionedPointPayload? = nil
        if let _ = edge.label, !points.isEmpty {
            if ortho.changed {
                finalLabelPos = _edgePathMidpoint(points, direction: source.direction)
            } else {
                finalLabelPos = labelPos
            }
        }

        edges.append(
            _PositionedEdgePayload(
                source: edge.source,
                target: edge.target,
                label: edge.label,
                style: edge.style.rawValue,
                hasArrowStart: edge.hasArrowStart,
                hasArrowEnd: edge.hasArrowEnd,
                points: points,
                labelPosition: finalLabelPos,
                inlineStyle: _resolveEdgeStyle(edgeIndex: idx, graph: source)
            )
        )
    }

    // Layer alignment: snap same-layer nodes to uniform positions
    _alignLayerNodes(&nodes, &edges, source.direction)

    // Bundle fan-out/fan-in edge paths into shared trunks
    _bundleEdgePaths(&edges, nodes, groups, source.direction)

    // Shape clipping: adjust edge endpoints to actual shape boundaries
    let nodeMap = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    for i in edges.indices {
        guard edges[i].points.count >= 2 else { continue }
        if let srcNode = nodeMap[edges[i].source] {
            edges[i].points = _clipEdgeToShape(points: edges[i].points, node: srcNode, isStart: true)
        }
        if let tgtNode = nodeMap[edges[i].target] {
            edges[i].points = _clipEdgeToShape(points: edges[i].points, node: tgtNode, isStart: false)
        }
    }

    // Compute label positions for edges that don't have an ELK-provided position
    for i in edges.indices {
        if let label = edges[i].label, !label.isEmpty, edges[i].points.count >= 2,
           edges[i].labelPosition == nil {
            edges[i].labelPosition = _edgePathMidpoint(edges[i].points, direction: source.direction)
        }
    }

    // Calculate final bounds including all edge points and labels
    var minX: Double = 0
    var minY: Double = 0
    var maxX = _asDouble(laidOut["width"]) ?? 0
    var maxY = graphHeight
    let arrowMargin: Double = 10
    let padding: Double = 40
    let labelHalfW: Double = 60  // estimated half-width of label pill
    let labelHalfH: Double = 16  // estimated half-height of label pill
    for edge in edges {
        for p in edge.points {
            maxX = max(maxX, p.x + arrowMargin + padding)
            maxY = max(maxY, p.y + arrowMargin + padding)
        }
        if let lp = edge.labelPosition {
            minX = min(minX, lp.x - labelHalfW - padding)
            minY = min(minY, lp.y - labelHalfH - padding)
            maxX = max(maxX, lp.x + labelHalfW + padding)
            maxY = max(maxY, lp.y + labelHalfH + padding)
        }
    }

    // If any label extends past origin, shift everything right/down
    if minX < 0 || minY < 0 {
        let shiftX = minX < 0 ? -minX : 0
        let shiftY = minY < 0 ? -minY : 0
        for i in nodes.indices {
            nodes[i].x += shiftX
            nodes[i].y += shiftY
        }
        for i in edges.indices {
            for j in edges[i].points.indices {
                edges[i].points[j].x += shiftX
                edges[i].points[j].y += shiftY
            }
            if var lp = edges[i].labelPosition {
                lp.x += shiftX
                lp.y += shiftY
                edges[i].labelPosition = lp
            }
        }
        for i in groups.indices {
            groups[i].x += shiftX
            groups[i].y += shiftY
        }
        maxX += shiftX
        maxY += shiftY
    }

    let content: PositionedContent
    switch diagramType {
    case .stateDiagram:
        content = .stateDiagram(nodes: nodes, edges: edges, groups: groups)
    default:
        content = .flowchart(nodes: nodes, edges: edges, groups: groups)
    }
    return PositionedGraph(
        diagram: MermaidGraph(type: diagramType, payload: source),
        width: maxX,
        height: maxY,
        content: content
    )
}

public func layoutGraphSync(
    _ graph: MermaidGraph,
    _ options: RenderOptions = RenderOptions()
) throws -> PositionedGraph {
    // layout.ts re-exports layout-engine.ts; route through the same public entry.
    return try _layoutGraphSyncEntry(graph, options)
}

/// Overload that accepts LayoutConfig to control ELK spacing parameters.
public func layoutGraphSync(
    _ graph: MermaidGraph,
    config: LayoutConfig
) throws -> PositionedGraph {
    return try _layoutGraphSyncWithConfig(graph, config)
}

private func _layoutGraphSyncWithConfig(
    _ graph: MermaidGraph,
    _ config: LayoutConfig
) throws -> PositionedGraph {
    guard let parsed = graph.payload as? _ParsedGraph else {
        return PositionedGraph(diagram: graph)
    }

    var elkGraph: _ElkNode
    if !parsed.subgraphs.isEmpty {
        let hasDirectionOverride = parsed.subgraphs.contains(where: { $0.direction != nil })
        elkGraph = hasDirectionOverride ? _buildElkGraph(parsed) : _buildElkGraphNoCrossEdges(parsed)
    } else {
        elkGraph = _buildElkGraph(parsed)
    }

    // Override ELK spacing options with LayoutConfig values
    _applyLayoutConfig(config, to: &elkGraph)

    do {
        let laidOut = try elkLayoutSync(elkGraph)
        return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
    } catch {
        var flatGraph = _buildFlatElkGraph(parsed)
        _applyLayoutConfig(config, to: &flatGraph)
        let laidOut = try elkLayoutSync(flatGraph)
        return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
    }
}

/// Patch ELK layout options on a built graph with LayoutConfig values.
private func _applyLayoutConfig(_ config: LayoutConfig, to elkGraph: inout _ElkNode) {
    var opts = (elkGraph["layoutOptions"] as? [String: String]) ?? [:]
    let p = Int(config.padding)
    opts["elk.spacing.nodeNode"] = "\(Int(config.nodeSpacing))"
    opts["elk.layered.spacing.nodeNodeBetweenLayers"] = "\(Int(config.layerSpacing))"
    opts["elk.padding"] = "[top=\(p),left=\(p),bottom=\(p),right=\(p)]"
    opts["elk.spacing.componentComponent"] = "\(Int(config.componentSpacing))"
    elkGraph["layoutOptions"] = opts
}

public func layoutGraphWithDiagnosticsSync(
    _ graph: MermaidGraph,
    _ options: RenderOptions = RenderOptions()
) throws -> PositionedGraph {
    return try _layoutGraphWithDiagnosticsEntry(graph, options)
}

private func _layoutGraphSyncEntry(
    _ graph: MermaidGraph,
    _ options: RenderOptions
) throws -> PositionedGraph {
    try _layoutGraphSyncFromLayoutEngine(graph, options)
}

private func _layoutGraphWithDiagnosticsEntry(
    _ graph: MermaidGraph,
    _ options: RenderOptions
) throws -> PositionedGraph {
    try _layoutGraphWithDiagnosticsSyncFromLayoutEngine(graph, options)
}

/// Build hierarchical ELK graph but EXCLUDE cross-subgraph edges that crash ELK JS.
/// INCLUDE_CHILDREN mode: all edges at root level, ELK resolves nested node IDs.
/// Used when no subgraph has a direction override.
private func _buildElkGraphNoCrossEdges(_ graph: _ParsedGraph) -> _ElkNode {
    let subgraphOwnership = _buildSubgraphOwnership(graph.subgraphs)
    let allClaimedNodes = Set(subgraphOwnership.values.flatMap { $0 })
    let nodeById = Dictionary(graph.nodesInOrder.map { ($0.id, $0.node) }, uniquingKeysWith: { _, last in last })

    func _deepestSubgraph(for nodeId: String, in subs: [original_src_types.MermaidSubgraph]) -> String? {
        for sub in subs {
            if let deeper = _deepestSubgraph(for: nodeId, in: sub.children) { return deeper }
            if sub.nodeIds.contains(nodeId) { return sub.id }
        }
        return nil
    }

    // Classify edges into: internal (same subgraph), root-level (no subgraph),
    // cross-hierarchy (different subgraph levels). Matching TS edge ordering:
    // root-level edges first, then cross-hierarchy edges.
    var edgesBySubgraph: [String: [[String: Any]]] = [:]
    var rootLevelEdges: [[String: Any]] = []
    var crossHierarchyEdges: [[String: Any]] = []
    var includedEdgeIndices = Set<Int>()
    for (idx, edge) in graph.edges.enumerated() {
        let srcSub = _deepestSubgraph(for: edge.source, in: graph.subgraphs)
        let tgtSub = _deepestSubgraph(for: edge.target, in: graph.subgraphs)
        var edict: [String: Any] = ["id": "e\(idx)", "sources": [edge.source], "targets": [edge.target]]
        if let label = edge.label, !label.isEmpty {
            let m = original_src_text_metrics.measureMultilineText(label, fontSize: original_src_styles.FONT_SIZES.edgeLabel, fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel)
            edict["labels"] = [["text": label, "width": m.width + 8, "height": m.height + 6, "layoutOptions": ["elk.edgeLabels.inline": "true", "elk.edgeLabels.placement": "CENTER"]] as [String: Any]]
        }
        if let s = srcSub, let t = tgtSub, s == t {
            // Internal edge: both endpoints in same subgraph
            edgesBySubgraph[s, default: []].append(edict)
            includedEdgeIndices.insert(idx)
        } else if srcSub == nil && tgtSub == nil {
            // Root-level edge: neither endpoint in a subgraph
            rootLevelEdges.append(edict)
            includedEdgeIndices.insert(idx)
        } else {
            // Cross-hierarchy edge: endpoints in different levels
            crossHierarchyEdges.append(edict)
            includedEdgeIndices.insert(idx)
        }
    }
    // Match TS ordering: root-level edges first, then cross-hierarchy
    let rootEdges = rootLevelEdges + crossHierarchyEdges

    func buildSubgraphNode(_ sub: original_src_types.MermaidSubgraph) -> [String: Any] {
        let directNodeIds = sub.nodeIds.filter { nodeId in
            !sub.children.contains { child in _subgraphContainsNode(child, nodeId: nodeId) }
        }
        var children: [[String: Any]] = []
        for nodeId in directNodeIds {
            guard let node = nodeById[nodeId] else { continue }
            let size = _nodeSize(node)
            children.append(["id": nodeId, "width": size.width, "height": size.height, "labels": [["text": node.label]]])
        }
        for child in sub.children { children.append(buildSubgraphNode(child)) }

        // Match TS subgraph options. Our Swift ELK port doesn't implement
        // option inheritance, so we explicitly set considerModelOrder
        // (elk.js inherits it from root via LayoutConfigurator).
        var opts: [String: String] = [
            "elk.algorithm": "layered",
            "elk.padding": "[top=44,left=16,bottom=16,right=16]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.contentAlignment": "H_CENTER V_CENTER",
            "elk.spacing.edgeEdge": "12",
            "elk.layered.spacing.edgeEdgeBetweenLayers": "12",
            "elk.layered.spacing.edgeNodeBetweenLayers": "12",
            "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.spacing.nodeNode": "28"
        ]
        // Only set direction on subgraph if it has an explicit override.
        // In INCLUDE_CHILDREN mode, direction inherits from root automatically.
        // Setting it explicitly can cause ELK to create different external port
        // dummy structures, leading to wider compound nodes.
        if let dir = sub.direction {
            opts["elk.direction"] = _mapDirection(dir)
        }

        let subLabel = sub.label ?? sub.id
        var result: [String: Any] = [
            "id": sub.id,
            "layoutOptions": opts,
            "children": children,
            "labels": [["text": subLabel]]
        ]
        if let subEdges = edgesBySubgraph[sub.id], !subEdges.isEmpty {
            result["edges"] = subEdges
        }
        return result
    }

    var rootChildren: [[String: Any]] = []
    for entry in graph.nodesInOrder {
        if !allClaimedNodes.contains(entry.id) {
            let size = _nodeSize(entry.node)
            rootChildren.append(["id": entry.id, "width": size.width, "height": size.height, "labels": [["text": entry.node.label]]])
        }
    }
    for sub in graph.subgraphs { rootChildren.append(buildSubgraphNode(sub)) }

    return [
        "id": "root",
        "layoutOptions": [
            "elk.algorithm": "layered",
            "elk.direction": _mapDirection(graph.direction),
            "elk.spacing.nodeNode": "28",
            "elk.spacing.edgeEdge": "12",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.layered.spacing.edgeEdgeBetweenLayers": "12",
            "elk.layered.spacing.edgeNodeBetweenLayers": "12",
            "elk.padding": "[top=40,left=40,bottom=40,right=40]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.contentAlignment": "H_CENTER V_CENTER",
            "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
            "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
            "elk.layered.thoroughness": "3",
            "elk.layered.compaction.postCompaction.strategy": "LEFT_RIGHT_CONSTRAINT_LOCKING",
            "elk.layered.highDegreeNodes.treatment": "true",
            "elk.layered.highDegreeNodes.threshold": "8",
            "elk.layered.wrapping.strategy": "OFF",
            "elk.hierarchyHandling": "INCLUDE_CHILDREN"
        ],
        "children": rootChildren,
        "edges": rootEdges
    ]
}

private func _buildFlatElkGraph(_ graph: _ParsedGraph) -> _ElkNode {
    var children: [[String: Any]] = []
    for entry in graph.nodesInOrder {
        let size = _nodeSize(entry.node)
        children.append([
            "id": entry.id,
            "width": size.width,
            "height": size.height
        ])
    }
    var edges: [[String: Any]] = []
    for (idx, edge) in graph.edges.enumerated() {
        var out: [String: Any] = [
            "id": "e\(idx)",
            "sources": [edge.source],
            "targets": [edge.target]
        ]
        if let label = edge.label, !label.isEmpty {
            let m = original_src_text_metrics.measureMultilineText(
                label,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            out["labels"] = [[
                "text": label,
                "width": m.width + 8,
                "height": m.height + 6,
                "layoutOptions": [
                    "elk.edgeLabels.inline": "true",
                    "elk.edgeLabels.placement": "CENTER"
                ]
            ] as [String: Any]]
        }
        edges.append(out)
    }
    return [
        "id": "root",
        "layoutOptions": [
            "elk.algorithm": "layered",
            "elk.direction": _mapDirection(graph.direction),
            "elk.spacing.nodeNode": "28",
            "elk.spacing.edgeEdge": "12",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.layered.spacing.edgeEdgeBetweenLayers": "12",
            "elk.layered.spacing.edgeNodeBetweenLayers": "12",
            "elk.padding": "[top=40,left=40,bottom=40,right=40]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.contentAlignment": "H_CENTER V_CENTER",
            "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
            "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
            "elk.layered.thoroughness": "3",
            "elk.layered.compaction.postCompaction.strategy": "LEFT_RIGHT_CONSTRAINT_LOCKING",
            "elk.layered.highDegreeNodes.treatment": "true",
            "elk.layered.highDegreeNodes.threshold": "8",
            "elk.randomSeed": "1"
        ],
        "children": children,
        "edges": edges
    ]
}

private func _layoutGraphSyncFromLayoutEngine(
    _ graph: MermaidGraph,
    _ options: RenderOptions
) throws -> PositionedGraph {
    _ = options
    guard let parsed = graph.payload as? _ParsedGraph else {
        return PositionedGraph(diagram: graph)
    }
    // Matching TS: use SEPARATE when any subgraph has a direction override,
    // INCLUDE_CHILDREN otherwise (simpler cross-hierarchy edge routing).
    if !parsed.subgraphs.isEmpty {
        let hasDirectionOverride = parsed.subgraphs.contains(where: { $0.direction != nil })
        let elkGraph: _ElkNode
        if hasDirectionOverride {
            // SEPARATE mode: port-based edge splitting for proper direction handling
            elkGraph = _buildElkGraph(parsed)
        } else {
            // INCLUDE_CHILDREN mode: ELK handles cross-hierarchy edges natively
            elkGraph = _buildElkGraphNoCrossEdges(parsed)
        }
        do {
            let laidOut = try elkLayoutSync(elkGraph)
            return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
        } catch {
            // Fallback: fully flat layout
            let flatGraph = _buildFlatElkGraph(parsed)
            let laidOut = try elkLayoutSync(flatGraph)
            return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
        }
    }
    // No subgraphs — use the standard flat graph builder
    let elkGraph = _buildElkGraph(parsed)
    let laidOut = try elkLayoutSync(elkGraph)
    return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
}

private func _layoutGraphWithDiagnosticsSyncFromLayoutEngine(
    _ graph: MermaidGraph,
    _ options: RenderOptions
) throws -> PositionedGraph {
    try _layoutGraphSyncFromLayoutEngine(graph, options)
}

private func _convertToElkFormat(
    _ graph: MermaidGraph,
    _ options: RenderOptions
) throws {
    _ = graph
    _ = options
    // Intentionally a no-op adapter until full layout-engine parity lands.
}

open class original_src_layout {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export { layoutGraphSync } from './layout-engine.ts'
    public static func layoutGraphSync(
        _ graph: MermaidGraph,
        _ options: RenderOptions = RenderOptions()
    ) throws -> PositionedGraph {
        try _layoutGraphSyncEntry(graph, options)
    }
}

// MARK: - Shape Clipping

/// Compute the midpoint along the edge's polyline path.
private func _edgePathMidpoint(_ points: [_PositionedPointPayload], direction: original_src_types.Direction = .TD) -> _PositionedPointPayload {
    guard points.count >= 2 else {
        return points.first ?? _PositionedPointPayload(x: 0, y: 0)
    }

    // For edges with bends, prefer the longest segment aligned with the flow direction.
    // In TD/BT graphs, labels go on vertical segments; in LR/RL, on horizontal segments.
    let isVerticalFlow = direction == .TD || direction == .TB || direction == .BT

    if points.count >= 3 {
        var bestIdx = -1
        var bestLen: Double = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i-1].x
            let dy = points[i].y - points[i-1].y
            let segLen = sqrt(dx * dx + dy * dy)
            let isFlowAligned = isVerticalFlow ? (abs(dy) > abs(dx)) : (abs(dx) > abs(dy))
            if isFlowAligned && segLen > bestLen {
                bestLen = segLen
                bestIdx = i
            }
        }
        if bestIdx > 0 {
            return _PositionedPointPayload(
                x: (points[bestIdx - 1].x + points[bestIdx].x) / 2,
                y: (points[bestIdx - 1].y + points[bestIdx].y) / 2
            )
        }
    }

    // Fallback: total path distance midpoint
    var totalLen: Double = 0
    for i in 1..<points.count {
        let dx = points[i].x - points[i-1].x
        let dy = points[i].y - points[i-1].y
        totalLen += sqrt(dx * dx + dy * dy)
    }
    let halfLen = totalLen / 2
    var accumulated: Double = 0
    for i in 1..<points.count {
        let dx = points[i].x - points[i-1].x
        let dy = points[i].y - points[i-1].y
        let segLen = sqrt(dx * dx + dy * dy)
        if accumulated + segLen >= halfLen {
            let remaining = halfLen - accumulated
            let t = segLen > 0 ? remaining / segLen : 0.5
            return _PositionedPointPayload(
                x: points[i-1].x + dx * t,
                y: points[i-1].y + dy * t
            )
        }
        accumulated += segLen
    }
    return _PositionedPointPayload(
        x: (points[0].x + points[points.count - 1].x) / 2,
        y: (points[0].y + points[points.count - 1].y) / 2
    )
}

/// Clip edge endpoints to actual shape boundaries instead of bounding boxes.
/// Handles diamond, circle, hexagon, stadium, rounded rect, etc.
private func _clipEdgeToShape(
    points: [_PositionedPointPayload],
    node: _PositionedNodePayload,
    isStart: Bool
) -> [_PositionedPointPayload] {
    guard points.count >= 2 else { return points }

    let shape = node.shape
    // Rectangular shapes: bounding box is already correct
    if shape == "rectangle" || shape == "rounded" || shape == "stadium" ||
       shape == "subroutine" || shape == "stateStart" || shape == "stateEnd" ||
       shape == "stateFork" {
        return points
    }

    var result = points
    let cx = node.x + node.width / 2
    let cy = node.y + node.height / 2
    let halfW = node.width / 2
    let halfH = node.height / 2

    if isStart {
        let endpoint = points[0]
        let adjacent = points[1]
        if let clipped = _clipPoint(endpoint: endpoint, adjacent: adjacent, shape: shape, cx: cx, cy: cy, halfW: halfW, halfH: halfH) {
            result[0] = clipped
        }
    } else {
        let lastIdx = points.count - 1
        let endpoint = points[lastIdx]
        let adjacent = points[lastIdx - 1]
        if let clipped = _clipPoint(endpoint: endpoint, adjacent: adjacent, shape: shape, cx: cx, cy: cy, halfW: halfW, halfH: halfH) {
            result[lastIdx] = clipped
        }
    }

    return result
}

private func _clipPoint(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    shape: String,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    switch shape {
    case "diamond", "rhombus", "stateChoice":
        return _clipToDiamond(endpoint: endpoint, adjacent: adjacent, cx: cx, cy: cy, halfW: halfW, halfH: halfH)
    case "circle", "doublecircle":
        return _clipToCircle(endpoint: endpoint, adjacent: adjacent, cx: cx, cy: cy, halfW: halfW, halfH: halfH)
    case "hexagon":
        return _clipToHexagon(endpoint: endpoint, adjacent: adjacent, cx: cx, cy: cy, halfW: halfW, halfH: halfH)
    default:
        // For other non-rect shapes, use general center→external intersection
        return _clipToEllipseApprox(endpoint: endpoint, adjacent: adjacent, cx: cx, cy: cy, halfW: halfW, halfH: halfH)
    }
}

// MARK: - Diamond

private func _clipToDiamond(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    // Diamond vertices
    let top    = (x: cx,        y: cy - halfH)
    let right  = (x: cx + halfW, y: cy)
    let bottom = (x: cx,        y: cy + halfH)
    let left   = (x: cx - halfW, y: cy)

    let dx = endpoint.x - adjacent.x
    let dy = endpoint.y - adjacent.y
    let isVertical = abs(dx) < abs(dy)

    if isVertical {
        let rayX = endpoint.x
        if dy > 0 {
            // Moving down → top half
            if rayX <= cx {
                return _intersectVerticalRay(rayX: rayX, p1x: left.x, p1y: left.y, p2x: top.x, p2y: top.y)
            } else {
                return _intersectVerticalRay(rayX: rayX, p1x: top.x, p1y: top.y, p2x: right.x, p2y: right.y)
            }
        } else {
            // Moving up → bottom half
            if rayX <= cx {
                return _intersectVerticalRay(rayX: rayX, p1x: bottom.x, p1y: bottom.y, p2x: left.x, p2y: left.y)
            } else {
                return _intersectVerticalRay(rayX: rayX, p1x: right.x, p1y: right.y, p2x: bottom.x, p2y: bottom.y)
            }
        }
    } else {
        let rayY = endpoint.y
        if dx > 0 {
            // Moving right → left half
            if rayY <= cy {
                return _intersectHorizontalRay(rayY: rayY, p1x: top.x, p1y: top.y, p2x: left.x, p2y: left.y)
            } else {
                return _intersectHorizontalRay(rayY: rayY, p1x: left.x, p1y: left.y, p2x: bottom.x, p2y: bottom.y)
            }
        } else {
            // Moving left → right half
            if rayY <= cy {
                return _intersectHorizontalRay(rayY: rayY, p1x: top.x, p1y: top.y, p2x: right.x, p2y: right.y)
            } else {
                return _intersectHorizontalRay(rayY: rayY, p1x: right.x, p1y: right.y, p2x: bottom.x, p2y: bottom.y)
            }
        }
    }
}

// MARK: - Circle

private func _clipToCircle(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    let radius = min(halfW, halfH)
    let dx = endpoint.x - cx
    let dy = endpoint.y - cy
    let dist = sqrt(dx * dx + dy * dy)
    guard dist > 0.001 else { return nil }
    let scale = radius / dist
    return _PositionedPointPayload(x: cx + dx * scale, y: cy + dy * scale)
}

// MARK: - Hexagon

private func _clipToHexagon(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    // Hexagon has 6 vertices: left/right points and 4 angled corners
    let inset = halfW * 0.25
    let vertices: [(x: Double, y: Double)] = [
        (cx - halfW, cy),                    // left point
        (cx - halfW + inset, cy - halfH),    // top-left
        (cx + halfW - inset, cy - halfH),    // top-right
        (cx + halfW, cy),                    // right point
        (cx + halfW - inset, cy + halfH),    // bottom-right
        (cx - halfW + inset, cy + halfH),    // bottom-left
    ]
    // Find intersection of ray from adjacent→endpoint with polygon edges
    return _clipToPolygon(endpoint: endpoint, adjacent: adjacent, vertices: vertices)
}

// MARK: - Ellipse approximation for other shapes

private func _clipToEllipseApprox(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    let dx = endpoint.x - cx
    let dy = endpoint.y - cy
    guard abs(dx) > 0.001 || abs(dy) > 0.001 else { return nil }
    // Ellipse boundary: (dx/halfW)^2 + (dy/halfH)^2 = 1
    let normX = dx / halfW
    let normY = dy / halfH
    let dist = sqrt(normX * normX + normY * normY)
    guard dist > 0.001 else { return nil }
    let scale = 1.0 / dist
    return _PositionedPointPayload(x: cx + dx * scale, y: cy + dy * scale)
}

// MARK: - Polygon intersection

private func _clipToPolygon(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    vertices: [(x: Double, y: Double)]
) -> _PositionedPointPayload? {
    let n = vertices.count
    guard n >= 3 else { return nil }

    // Ray from adjacent to endpoint, find closest intersection with polygon edges
    let ox = adjacent.x, oy = adjacent.y
    let dx = endpoint.x - adjacent.x, dy = endpoint.y - adjacent.y

    var bestT = Double.infinity
    var bestPoint: _PositionedPointPayload?

    for i in 0..<n {
        let j = (i + 1) % n
        let ex = vertices[j].x - vertices[i].x
        let ey = vertices[j].y - vertices[i].y

        let denom = dx * ey - dy * ex
        guard abs(denom) > 0.0001 else { continue }

        let t = ((vertices[i].x - ox) * ey - (vertices[i].y - oy) * ex) / denom
        let u = ((vertices[i].x - ox) * dy - (vertices[i].y - oy) * dx) / denom

        if t > 0 && u >= 0 && u <= 1 && t < bestT {
            bestT = t
            bestPoint = _PositionedPointPayload(x: ox + dx * t, y: oy + dy * t)
        }
    }

    return bestPoint
}

// MARK: - Ray-edge intersection helpers

private func _intersectVerticalRay(
    rayX: Double, p1x: Double, p1y: Double, p2x: Double, p2y: Double
) -> _PositionedPointPayload? {
    let dx = p2x - p1x
    guard abs(dx) > 0.001 else { return nil }
    let t = (rayX - p1x) / dx
    guard t >= 0 && t <= 1 else { return nil }
    return _PositionedPointPayload(x: rayX, y: p1y + t * (p2y - p1y))
}

private func _intersectHorizontalRay(
    rayY: Double, p1x: Double, p1y: Double, p2x: Double, p2y: Double
) -> _PositionedPointPayload? {
    let dy = p2y - p1y
    guard abs(dy) > 0.001 else { return nil }
    let t = (rayY - p1y) / dy
    guard t >= 0 && t <= 1 else { return nil }
    return _PositionedPointPayload(x: p1x + t * (p2x - p1x), y: rayY)
}
