// SPDX-License-Identifier: MIT
//
//  SwiftDagreAdapter.swift
//  BeautifulMermaid
//
//  Adapter to use SwiftDagre for graph layout
//

import Foundation
import CoreGraphics
import SwiftDagre

// MARK: - Layout Constants (matching TypeScript)

/// Padding between group header band and content (GROUP_HEADER_CONTENT_PAD in TypeScript)
private let groupHeaderContentPad: CGFloat = 8

/// Header height for subgraph labels (calculated from font size + 16, matching TypeScript)
private var groupHeaderHeight: CGFloat {
    RenderConfig.shared.fontSizeGroupHeader + 16
}

/// Padding around subgraph content
private let groupPadding: CGFloat = 24

// MARK: - Pre-computed Subgraph

/// Pre-computed layout data for a direction-overridden subgraph
private struct PreComputedSubgraph {
    let id: String
    let label: String
    /// Bounding box for the placeholder node in the main layout
    let width: CGFloat
    let height: CGFloat
    /// Internal nodes positioned relative to (0,0) of the bounding box
    var nodes: [MermaidNode]
    /// Internal edges positioned relative to (0,0) of the bounding box
    var edges: [MermaidEdge]
    /// Nested subgroup boxes positioned relative to (0,0)
    var subgraphs: [Subgraph]
    /// All node IDs contained in this subgraph (including nested)
    let nodeIds: Set<String>
    /// Indices of edges in graph.edges that are internal to this subgraph
    let internalEdgeIndices: Set<Int>
}

/// Adapter that uses SwiftDagre for layout instead of the internal dagre implementation
public struct SwiftDagreAdapter: GraphLayoutAlgorithm {

    public init() {}

    /// Layout a graph using SwiftDagre
    public func layout(_ graph: MermaidGraph, config: LayoutConfig) throws -> PositionedGraph {
        // -------------------------------------------------------------------------
        // Phase 1: Pre-compute layouts for subgraphs with direction overrides.
        //
        // Dagre only supports a single global rankdir. Subgraphs with a different
        // direction (e.g. `direction LR` inside `graph TD`) get their own dagre
        // layout pass. The result is injected as a fixed-size placeholder in the
        // main layout, then composited back after positioning.
        // -------------------------------------------------------------------------
        var preComputed: [String: PreComputedSubgraph] = [:]
        for sg in graph.subgraphs {
            if let sgDirection = sg.direction, sgDirection != config.direction {
                preComputed[sg.id] = try preComputeSubgraphLayout(sg: sg, graph: graph, config: config)
            }
        }

        // -------------------------------------------------------------------------
        // Phase 2: Build the main dagre graph.
        // Pre-computed subgraphs become fixed-size leaf nodes instead of compound nodes.
        // -------------------------------------------------------------------------
        // IMPORTANT: dagre's internal layout graph is ALWAYS a multigraph (layout.js:116)
        // This allows the acyclic algorithm to use named edges for reversed edges
        // Without multigraph=true, reversed edges would overwrite original edges
        let dagreOptions = SwiftDagre.GraphOptions(
            directed: true,
            multigraph: true,
            compound: !graph.subgraphs.isEmpty
        )
        let g = SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>(options: dagreOptions)

        // Set layout options
        let layoutOptions = SwiftDagre.LayoutOptions()
        layoutOptions.nodesep = config.nodeSeparation
        layoutOptions.ranksep = config.rankSeparation
        layoutOptions.edgesep = config.edgeSeparation
        layoutOptions.marginx = config.margin
        layoutOptions.marginy = config.margin

        // Convert direction
        switch config.direction.normalized {
        case .topDown, .topToBottom:
            layoutOptions.rankdir = .topBottom
        case .bottomUp, .bottomToTop:
            layoutOptions.rankdir = .bottomTop
        case .leftRight:
            layoutOptions.rankdir = .leftRight
        case .rightLeft:
            layoutOptions.rankdir = .rightLeft
        }

        g.setGraph(layoutOptions)

        // Collect node IDs in subgraphs
        var subgraphNodeIds = Set<String>()
        for sg in graph.subgraphs {
            subgraphNodeIds.insert(sg.id)
            collectSubgraphNodeIds(sg, into: &subgraphNodeIds)
        }

        // Add top-level nodes
        for nodeId in graph.nodeOrder {
            guard let mermaidNode = graph.nodes[nodeId] else { continue }
            if subgraphNodeIds.contains(nodeId) { continue }

            let size = ShapeBounds.calculateSize(
                for: mermaidNode.shape,
                label: mermaidNode.label,
                font: config.font,
                padding: config.nodePadding
            )

            let label = SwiftDagre.DagreNodeLabel(size: size)
            g.setNode(nodeId, label: label)
        }

        // Add subgraphs and their children.
        // Pre-computed subgraphs are added as fixed-size leaf nodes instead.
        for sg in graph.subgraphs {
            if let pc = preComputed[sg.id] {
                // Pre-computed subgraph becomes a fixed-size leaf node
                let label = SwiftDagre.DagreNodeLabel(width: pc.width, height: pc.height)
                g.setNode(sg.id, label: label)
            } else {
                try addSubgraphNodes(g, sg: sg, graph: graph, config: config, parentId: nil)
            }
        }

        // Build redirect maps for compound nodes
        var subgraphEntryNode: [String: String] = [:]
        var subgraphExitNode: [String: String] = [:]
        for sg in graph.subgraphs {
            if preComputed[sg.id] == nil {
                buildSubgraphRedirects(sg, entryMap: &subgraphEntryNode, exitMap: &subgraphExitNode)
            }
        }

        // For pre-computed subgraphs, redirect all internal node references to the
        // placeholder leaf node. External edges to/from internal nodes get routed
        // to the placeholder boundary; endpoints are fixed up after compositing.
        for (sgId, pc) in preComputed {
            for nodeId in pc.nodeIds {
                subgraphEntryNode[nodeId] = sgId
                subgraphExitNode[nodeId] = sgId
            }
        }

        // Collect all internal edge indices from pre-computed subgraphs
        var allInternalIndices = Set<Int>()
        for pc in preComputed.values {
            allInternalIndices.formUnion(pc.internalEdgeIndices)
        }

        // Add edges — skip internal edges of pre-computed subgraphs
        let renderConfig = RenderConfig.shared
        var introducedTargets = Set<String>()

        for (index, edge) in graph.edges.enumerated() {
            // Skip internal edges of pre-computed subgraphs
            if allInternalIndices.contains(index) { continue }

            var labelWidth: CGFloat = 0
            var labelHeight: CGFloat = 0

            if let label = edge.label, !label.isEmpty {
                let fontSize = renderConfig.fontSizeEdgeLabel
                let fontWeight = renderConfig.fontWeightEdgeLabel
                labelWidth = estimateTextWidth(label, fontSize: fontSize, fontWeight: fontWeight) + 8
                labelHeight = fontSize + 6
            }

            // Apply subgraph redirects
            let source = subgraphExitNode[edge.sourceId] ?? edge.sourceId
            let target = subgraphEntryNode[edge.targetId] ?? edge.targetId

            // Skip if source or target don't exist
            guard g.hasNode(source), g.hasNode(target) else { continue }

            // Spine edges get higher weight
            var weight = 1
            if !introducedTargets.contains(target) {
                weight = 2
                introducedTargets.insert(target)
            }

            let edgeLabel = SwiftDagre.DagreEdgeLabel(minlen: 1, weight: weight)
            edgeLabel.width = labelWidth
            edgeLabel.height = labelHeight
            try g.setEdge(source, target, label: edgeLabel)
        }

        // -------------------------------------------------------------------------
        // Phase 3: Run synchronous layout — mutates g in place.
        // -------------------------------------------------------------------------
        try SwiftDagre.layout(g, options: layoutOptions)

        // -------------------------------------------------------------------------
        // Phase 4: Extract positions and compose pre-computed layouts.
        // -------------------------------------------------------------------------
        return extractPositionedGraph(from: g, originalGraph: graph, config: config,
                                       subgraphEntryNode: subgraphEntryNode, subgraphExitNode: subgraphExitNode,
                                       preComputed: preComputed)
    }

    // MARK: - Pre-computed Subgraph Layout

    /// Pre-compute the internal layout of a subgraph that has a direction override.
    private func preComputeSubgraphLayout(sg: Subgraph, graph: MermaidGraph, config: LayoutConfig) throws -> PreComputedSubgraph {
        // IMPORTANT: dagre's internal layout graph is ALWAYS a multigraph
        let subG = SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>(
            options: SwiftDagre.GraphOptions(directed: true, multigraph: true, compound: !sg.children.isEmpty)
        )

        // Set layout options with the overridden direction
        let subLayoutOptions = SwiftDagre.LayoutOptions()
        subLayoutOptions.nodesep = config.nodeSeparation
        subLayoutOptions.ranksep = config.rankSeparation
        subLayoutOptions.edgesep = config.edgeSeparation
        // Tighter margins for subgraph internals — the parent group provides outer padding
        subLayoutOptions.marginx = 16
        subLayoutOptions.marginy = 12

        // Use the subgraph's direction
        if let sgDirection = sg.direction {
            switch sgDirection.normalized {
            case .topDown, .topToBottom:
                subLayoutOptions.rankdir = .topBottom
            case .bottomUp, .bottomToTop:
                subLayoutOptions.rankdir = .bottomTop
            case .leftRight:
                subLayoutOptions.rankdir = .leftRight
            case .rightLeft:
                subLayoutOptions.rankdir = .rightLeft
            }
        }

        subG.setGraph(subLayoutOptions)

        // Collect all node IDs in this subgraph (including nested children)
        var nodeIds = Set<String>()
        nodeIds.insert(sg.id)
        collectSubgraphNodeIds(sg, into: &nodeIds)

        // Add direct child nodes
        for nodeId in sg.nodeIds {
            guard let mermaidNode = graph.nodes[nodeId] else { continue }
            let size = ShapeBounds.calculateSize(
                for: mermaidNode.shape,
                label: mermaidNode.label,
                font: config.font,
                padding: config.nodePadding
            )
            let label = SwiftDagre.DagreNodeLabel(size: size)
            subG.setNode(nodeId, label: label)
        }

        // Add nested subgraphs as compound nodes (they keep the parent's direction)
        for child in sg.children {
            try addSubgraphNodes(subG, sg: child, graph: graph, config: config, parentId: nil)
        }

        // Identify and add internal edges (both endpoints inside this subgraph)
        var internalEdgeIndices = Set<Int>()
        let renderConfig = RenderConfig.shared

        for (index, edge) in graph.edges.enumerated() {
            if nodeIds.contains(edge.sourceId) && nodeIds.contains(edge.targetId) {
                internalEdgeIndices.insert(index)

                var labelWidth: CGFloat = 0
                var labelHeight: CGFloat = 0
                if let label = edge.label, !label.isEmpty {
                    let fontSize = renderConfig.fontSizeEdgeLabel
                    let fontWeight = renderConfig.fontWeightEdgeLabel
                    labelWidth = estimateTextWidth(label, fontSize: fontSize, fontWeight: fontWeight) + 8
                    labelHeight = fontSize + 6
                }

                let edgeLabel = SwiftDagre.DagreEdgeLabel(minlen: 1, weight: 1)
                edgeLabel.width = labelWidth
                edgeLabel.height = labelHeight
                try subG.setEdge(edge.sourceId, edge.targetId, label: edgeLabel)
            }
        }

        // Run layout on the isolated subgraph
        try SwiftDagre.layout(subG, options: subLayoutOptions)

        // Build a set of nested subgraph IDs for node/group separation
        var nestedSubgraphIds = Set<String>()
        for child in sg.children {
            collectAllSubgraphIds(child, into: &nestedSubgraphIds)
        }

        // Extract positioned nodes (skip nested subgraph compound nodes)
        var nodes: [MermaidNode] = []
        for nodeId in subG.nodes() {
            if nestedSubgraphIds.contains(nodeId) { continue }
            guard let mermaidNode = graph.nodes[nodeId] else { continue }
            guard let dagreLabel = subG.node(nodeId) else { continue }

            var node = mermaidNode
            node.position = CGPoint(x: dagreLabel.x, y: dagreLabel.y)
            node.size = CGSize(width: dagreLabel.width, height: dagreLabel.height)
            nodes.append(node)
        }

        // Extract positioned edges
        var edges: [MermaidEdge] = []
        for edgeId in subG.edges() {
            guard let dagreEdge = subG.edge(edgeId.v, edgeId.w) else { continue }

            // Find the original edge
            guard let originalEdge = graph.edges.first(where: { $0.sourceId == edgeId.v && $0.targetId == edgeId.w }) else { continue }

            var edge = originalEdge
            edge.points = dagreEdge.points.map { CGPoint(x: $0.x, y: $0.y) }

            // Get source and target nodes for clipping
            let sourceNode = nodes.first { $0.id == edge.sourceId }
            let targetNode = nodes.first { $0.id == edge.targetId }

            // Apply edge routing cleanup in correct order (matching TypeScript):
            // 1. First clip non-rectangular shapes (diamond/circle) to their boundaries
            edge.points = clipToShapeBoundaries(edge.points, sourceNode: sourceNode, targetNode: targetNode)

            // 2. Then snap to orthogonal segments
            edge.points = snapToOrthogonal(edge.points, config: config)

            // 3. Finally clip rectangular endpoints to correct side
            edge.points = clipRectangularEndpoints(edge.points, sourceNode: sourceNode, targetNode: targetNode)

            // Set label position from dagre's computed position.
            // Dagre returns edge label center position directly as edge.x, edge.y
            // (matching TypeScript: labelPosition = { x: dagreEdge.x, y: dagreEdge.y })
            if edge.label != nil && !edge.label!.isEmpty {
                edge.labelPosition = CGPoint(x: dagreEdge.x, y: dagreEdge.y)
            }

            // Calculate arrow angles from final edge points
            edge.sourceAngle = EdgeRouter.startAngle(for: edge.points)
            edge.targetAngle = EdgeRouter.endAngle(for: edge.points)

            edges.append(edge)
        }

        // Extract nested subgroup positions
        var subgraphs: [Subgraph] = []
        for child in sg.children {
            let positioned = extractSubgraphBoundsRaw(child, from: subG,
                                                       nodes: Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) }),
                                                       config: config)
            subgraphs.append(positioned)
        }

        // Get graph bounds
        let graphLabel = subG.graph() as? SwiftDagre.LayoutOptions
        let width = graphLabel?.width ?? 200
        let height = graphLabel?.height ?? 100

        return PreComputedSubgraph(
            id: sg.id,
            label: sg.label,
            width: width,
            height: height,
            nodes: nodes,
            edges: edges,
            subgraphs: subgraphs,
            nodeIds: nodeIds,
            internalEdgeIndices: internalEdgeIndices
        )
    }

    // MARK: - Private Helpers

    private func collectSubgraphNodeIds(_ sg: Subgraph, into out: inout Set<String>) {
        for id in sg.nodeIds {
            out.insert(id)
        }
        for child in sg.children {
            out.insert(child.id)
            collectSubgraphNodeIds(child, into: &out)
        }
    }

    private func addSubgraphNodes(_ g: SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>,
                                   sg: Subgraph, graph: MermaidGraph, config: LayoutConfig, parentId: String?) throws {
        // Add compound node for subgraph
        let label = SwiftDagre.DagreNodeLabel(width: 0, height: 0)
        g.setNode(sg.id, label: label)

        if let parent = parentId {
            try g.setParent(sg.id, parent: parent)
        }

        // Add child nodes
        for nodeId in sg.nodeIds {
            guard let mermaidNode = graph.nodes[nodeId] else { continue }

            let size = ShapeBounds.calculateSize(
                for: mermaidNode.shape,
                label: mermaidNode.label,
                font: config.font,
                padding: config.nodePadding
            )

            let nodeLabel = SwiftDagre.DagreNodeLabel(size: size)
            g.setNode(nodeId, label: nodeLabel)
            try g.setParent(nodeId, parent: sg.id)
        }

        // Add nested subgraphs
        for child in sg.children {
            try addSubgraphNodes(g, sg: child, graph: graph, config: config, parentId: sg.id)
        }
    }

    private func buildSubgraphRedirects(_ sg: Subgraph, entryMap: inout [String: String], exitMap: inout [String: String]) {
        // Recurse into nested subgraphs FIRST so their entries are available
        for child in sg.children {
            buildSubgraphRedirects(child, entryMap: &entryMap, exitMap: &exitMap)
        }

        // Collect all direct child IDs (both leaf nodes and nested subgraphs)
        let childIds = sg.nodeIds + sg.children.map { $0.id }

        if childIds.isEmpty {
            // Empty subgraph — map it to itself
            entryMap[sg.id] = sg.id
            exitMap[sg.id] = sg.id
            return
        }

        // For nested subgraphs as entry/exit: resolve transitively to a leaf node
        let firstChild = childIds[0]
        let lastChild = childIds[childIds.count - 1]
        entryMap[sg.id] = entryMap[firstChild] ?? firstChild
        exitMap[sg.id] = exitMap[lastChild] ?? lastChild
    }

    private func collectAllSubgraphIds(_ sg: Subgraph, into out: inout Set<String>) {
        out.insert(sg.id)
        for child in sg.children {
            collectAllSubgraphIds(child, into: &out)
        }
    }

    private func extractPositionedGraph(from g: SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>,
                                          originalGraph: MermaidGraph, config: LayoutConfig,
                                          subgraphEntryNode: [String: String], subgraphExitNode: [String: String],
                                          preComputed: [String: PreComputedSubgraph] = [:]) -> PositionedGraph {
        var positionedNodes: [String: MermaidNode] = [:]
        var positionedEdges: [MermaidEdge] = []

        // Collect all pre-computed internal node IDs (they're not in the main dagre graph)
        var preComputedNodeIds = Set<String>()
        var allInternalIndices = Set<Int>()
        for pc in preComputed.values {
            preComputedNodeIds.formUnion(pc.nodeIds)
            allInternalIndices.formUnion(pc.internalEdgeIndices)
        }

        // Build set of subgraph IDs for distinguishing compound nodes from leaf nodes
        var subgraphIds = Set<String>()
        for sg in originalGraph.subgraphs {
            collectAllSubgraphIds(sg, into: &subgraphIds)
        }

        // Extract node positions (skip pre-computed internal nodes and subgraph compound nodes)
        // Use nodeOrder for deterministic iteration order
        for nodeId in originalGraph.nodeOrder {
            guard let originalNode = originalGraph.nodes[nodeId] else { continue }

            // Skip nodes that are inside pre-computed subgraphs (they'll be composited later)
            if preComputedNodeIds.contains(nodeId) && !preComputed.keys.contains(nodeId) { continue }
            // Skip subgraph compound nodes
            if subgraphIds.contains(nodeId) { continue }

            guard let label = g.node(nodeId) else {
                // Node wasn't in dagre graph, add with default position
                var node = originalNode
                node.position = .zero
                positionedNodes[nodeId] = node
                continue
            }

            var node = originalNode

            // Calculate size if not already set
            if node.size == .zero {
                node.size = ShapeBounds.calculateSize(
                    for: node.shape,
                    label: node.label,
                    font: config.font,
                    padding: config.nodePadding
                )
            }

            // Position is center-based
            node.position = CGPoint(x: label.x, y: label.y)
            positionedNodes[nodeId] = node
        }

        // Extract edge points (skip internal edges of pre-computed subgraphs)
        for (index, originalEdge) in originalGraph.edges.enumerated() {
            // Skip internal edges of pre-computed subgraphs
            if allInternalIndices.contains(index) { continue }

            var edge = originalEdge

            // Get edge from dagre (may be redirected for subgraphs)
            let source = subgraphExitNode[edge.sourceId] ?? edge.sourceId
            let target = subgraphEntryNode[edge.targetId] ?? edge.targetId

            // Try forward direction first, then reversed (dagre may reverse edges for acyclic)
            var edgeLabel = g.edge(source, target)
            var wasReversed = false

            if edgeLabel == nil {
                // Try reversed direction - dagre reverses edges to make graph acyclic
                edgeLabel = g.edge(target, source)
                wasReversed = true
            }

            if let edgeLabel = edgeLabel {
                var points = edgeLabel.points.map { CGPoint(x: $0.x, y: $0.y) }

                // If we found the edge in reversed direction, reverse the points
                if wasReversed {
                    points.reverse()
                }

                edge.points = points

                let sourceNode = positionedNodes[edge.sourceId]
                let targetNode = positionedNodes[edge.targetId]

                // Apply edge routing cleanup in correct order (matching TypeScript):
                // 1. First clip non-rectangular shapes (diamond/circle) to their boundaries
                edge.points = clipToShapeBoundaries(edge.points, sourceNode: sourceNode, targetNode: targetNode)

                // 2. Then snap to orthogonal segments
                edge.points = snapToOrthogonal(edge.points, config: config)

                // 3. Finally clip rectangular endpoints to correct side
                edge.points = clipRectangularEndpoints(edge.points, sourceNode: sourceNode, targetNode: targetNode)

                // Set label position from dagre's computed position.
                // Dagre returns edge label center position directly as edge.x, edge.y
                // (matching TypeScript: labelPosition = { x: dagreEdge.x, y: dagreEdge.y })
                if edge.label != nil && !edge.label!.isEmpty {
                    edge.labelPosition = CGPoint(x: edgeLabel.x, y: edgeLabel.y)
                }

                // Calculate arrow angles from final edge points
                edge.sourceAngle = EdgeRouter.startAngle(for: edge.points)
                edge.targetAngle = EdgeRouter.endAngle(for: edge.points)
            }

            positionedEdges.append(edge)
        }

        // -------------------------------------------------------------------------
        // Compose pre-computed subgraph layouts into the main layout.
        //
        // The main dagre graph positioned each pre-computed subgraph as a leaf node.
        // Now we inject the internal elements at the correct offset and fix cross-
        // boundary edge endpoints so they connect to actual internal nodes.
        // -------------------------------------------------------------------------
        if !preComputed.isEmpty {
            for (sgId, pc) in preComputed {
                // Get the placeholder's position from dagre (center-based)
                guard let placeholder = g.node(sgId) else { continue }

                // Convert to top-left for offset calculation
                let offsetX = placeholder.x - pc.width / 2
                let offsetY = placeholder.y - pc.height / 2

                // Inject internal nodes at the correct offset
                for pcNode in pc.nodes {
                    var composedNode = pcNode
                    composedNode.position = CGPoint(
                        x: pcNode.position.x + offsetX,
                        y: pcNode.position.y + offsetY
                    )
                    positionedNodes[composedNode.id] = composedNode
                }

                // Inject internal edges at the correct offset
                for pcEdge in pc.edges {
                    var composedEdge = pcEdge
                    composedEdge.points = pcEdge.points.map { p in
                        CGPoint(x: p.x + offsetX, y: p.y + offsetY)
                    }
                    if pcEdge.labelPosition != .zero {
                        composedEdge.labelPosition = CGPoint(
                            x: pcEdge.labelPosition.x + offsetX,
                            y: pcEdge.labelPosition.y + offsetY
                        )
                    }
                    positionedEdges.append(composedEdge)
                }
            }

            // Fix cross-boundary edge endpoints.
            // Edges that originally connected to internal nodes were redirected to the
            // placeholder during main layout. Now replace the endpoint with the actual
            // composed node position and re-run orthogonal snapping.
            let verticalFirst = config.direction.normalized == .topDown || config.direction.normalized == .bottomUp

            for i in 0..<positionedEdges.count {
                var edge = positionedEdges[i]

                // Skip edges that are from pre-computed layouts (already correctly routed)
                if preComputedNodeIds.contains(edge.sourceId) && preComputedNodeIds.contains(edge.targetId) { continue }

                var modified = false

                // Fix source endpoint — if the source is inside a pre-computed subgraph
                if preComputedNodeIds.contains(edge.sourceId) {
                    if let node = positionedNodes[edge.sourceId], edge.points.count > 0 {
                        edge.points[0] = node.position
                        modified = true
                    }
                }

                // Fix target endpoint — if the target is inside a pre-computed subgraph
                if preComputedNodeIds.contains(edge.targetId) {
                    if let node = positionedNodes[edge.targetId], edge.points.count > 0 {
                        edge.points[edge.points.count - 1] = node.position
                        modified = true
                    }
                }

                // Re-snap to orthogonal after modifying endpoints
                // Note: We do NOT re-apply clipEndpointsToNodes/clipToShapeBoundaries here
                // because the endpoints are already correctly positioned at node centers.
                // Re-clipping would incorrectly move them to node boundaries.
                if modified {
                    edge.points = snapToOrthogonalWithDirection(edge.points, verticalFirst: verticalFirst)
                    // Recalculate arrow angles after modifying points
                    edge.sourceAngle = EdgeRouter.startAngle(for: edge.points)
                    edge.targetAngle = EdgeRouter.endAngle(for: edge.points)
                    positionedEdges[i] = edge
                }
            }
        }

        // -------------------------------------------------------------------------
        // Extract subgraph bounds (initial pass - tight bounds from dagre).
        // -------------------------------------------------------------------------
        var positionedSubgraphs: [Subgraph] = []
        for sg in originalGraph.subgraphs {
            if let pc = preComputed[sg.id] {
                // For pre-computed subgraphs, get bounds from placeholder position (matching TypeScript)
                guard let placeholder = g.node(sg.id) else { continue }
                var positioned = sg
                let offsetX = placeholder.x - pc.width / 2
                let offsetY = placeholder.y - pc.height / 2

                // Offset nested subgraphs
                positioned.children = pc.subgraphs.map { child in
                    var offsetChild = child
                    offsetChild.bounds = CGRect(
                        x: child.bounds.minX + offsetX,
                        y: child.bounds.minY + offsetY,
                        width: child.bounds.width,
                        height: child.bounds.height
                    )
                    return offsetChild
                }

                // Use placeholder bounds directly from dagre (matching TypeScript extractGroup)
                // Convert from center-based to top-left coordinates
                positioned.bounds = CGRect(
                    x: placeholder.x - placeholder.width / 2,
                    y: placeholder.y - placeholder.height / 2,
                    width: placeholder.width,
                    height: placeholder.height
                )
                positioned.headerHeight = groupHeaderHeight

                positionedSubgraphs.append(positioned)
            } else {
                let positioned = extractSubgraphBoundsRaw(sg, from: g, nodes: positionedNodes, config: config)
                positionedSubgraphs.append(positioned)
            }
        }

        // -------------------------------------------------------------------------
        // Post-process: expand groups for header labels (depth-first).
        //
        // Dagre's compound node bounds tightly wrap children. This means the
        // subgraph header label would overlap with content. We expand each
        // labeled group upward by headerHeight + content padding so the header
        // band occupies its own space above the children.
        //
        // Process depth-first so child expansions are incorporated before parent
        // bounds are recalculated.
        // -------------------------------------------------------------------------
        expandGroupsForHeaders(&positionedSubgraphs)

        // -------------------------------------------------------------------------
        // Post-process: translate graph if groups extend above the margin.
        //
        // After expanding groups upward, some may extend above dagre's original
        // margins. Compute the global minimum Y and shift everything down
        // uniformly if needed.
        // -------------------------------------------------------------------------
        let flatGroups = flattenAllGroups(positionedSubgraphs)
        let allYs = Array(positionedNodes.values.map { $0.position.y - $0.size.height / 2 }) +
                    flatGroups.map { $0.bounds.minY }
        let currentMinY = allYs.isEmpty ? config.margin : allYs.min()!

        let graphWidth = (g.graph() as? SwiftDagre.LayoutOptions)?.width ?? 800
        var graphHeight = (g.graph() as? SwiftDagre.LayoutOptions)?.height ?? 600

        if currentMinY < config.margin {
            let dy = config.margin - currentMinY

            // Shift all nodes down
            for key in positionedNodes.keys {
                positionedNodes[key]?.position.y += dy
            }

            // Shift all edge points and labels down
            for i in 0..<positionedEdges.count {
                positionedEdges[i].points = positionedEdges[i].points.map {
                    CGPoint(x: $0.x, y: $0.y + dy)
                }
                if positionedEdges[i].labelPosition != .zero {
                    positionedEdges[i].labelPosition.y += dy
                }
            }

            // Shift all groups down
            for i in 0..<positionedSubgraphs.count {
                shiftSubgraphDown(&positionedSubgraphs[i], by: dy)
            }

            graphHeight += dy
        }

        // Also expand graph height if any group extends beyond the original bottom margin
        let maxBottom = max(
            positionedNodes.values.map { $0.position.y + $0.size.height / 2 }.max() ?? 0,
            flatGroups.map { $0.bounds.maxY }.max() ?? 0,
            positionedEdges.flatMap { $0.points.map { $0.y } }.max() ?? 0
        )
        if maxBottom + config.margin > graphHeight {
            graphHeight = maxBottom + config.margin
        }

        // Calculate final graph bounds using dagre's width/height (includes margins)
        // This matches TypeScript which uses graph.width and graph.height from dagre
        let graphBounds = CGRect(x: 0, y: 0, width: graphWidth, height: graphHeight)

        // Convert nodes dictionary to array
        let nodesArray = originalGraph.nodeOrder.compactMap { positionedNodes[$0] }

        return PositionedGraph(
            nodes: nodesArray,
            edges: positionedEdges,
            subgraphs: positionedSubgraphs,
            bounds: graphBounds,
            direction: config.direction
        )
    }

    // MARK: - Header Expansion (matching TypeScript expandGroupsForHeaders)

    /// Expand all groups upward to make room for header labels.
    /// Processes depth-first so child expansions are accounted for when
    /// parent bounds are recalculated.
    private func expandGroupsForHeaders(_ groups: inout [Subgraph]) {
        for i in 0..<groups.count {
            expandGroupForHeader(&groups[i])
        }
    }

    /// Recursively expand a single group and its children for header space.
    ///
    /// Algorithm (depth-first):
    ///   1. Expand all children first
    ///   2. Re-fit this group's bounds to encompass any expanded children
    ///   3. Expand this group upward by headerHeight + content padding for its own header
    private func expandGroupForHeader(_ group: inout Subgraph) {
        // Step 1: process children first
        for i in 0..<group.children.count {
            expandGroupForHeader(&group.children[i])
        }

        // Step 2: re-fit bounds to encompass expanded children.
        // After children expand upward, they may extend above this group's dagre-computed top.
        if !group.children.isEmpty {
            var minY = group.bounds.minY
            var maxY = group.bounds.maxY
            for child in group.children {
                minY = min(minY, child.bounds.minY)
                maxY = max(maxY, child.bounds.maxY)
            }
            group.bounds = CGRect(
                x: group.bounds.minX,
                y: minY,
                width: group.bounds.width,
                height: maxY - minY
            )
        }

        // Step 3: expand upward for this group's own header band + content padding.
        // The content padding creates a gap between the header band bottom and the
        // content area, preventing nested subgraph headers from being flush against
        // their parent's header band.
        if !group.label.isEmpty {
            let expansion = groupHeaderHeight + groupHeaderContentPad
            group.bounds = CGRect(
                x: group.bounds.minX,
                y: group.bounds.minY - expansion,
                width: group.bounds.width,
                height: group.bounds.height + expansion
            )
        }
    }

    /// Flatten a group tree into a flat array of all groups (including nested).
    private func flattenAllGroups(_ groups: [Subgraph]) -> [Subgraph] {
        var result: [Subgraph] = []
        for g in groups {
            result.append(g)
            result.append(contentsOf: flattenAllGroups(g.children))
        }
        return result
    }

    /// Recursively shift a subgraph and all its children down by dy.
    private func shiftSubgraphDown(_ sg: inout Subgraph, by dy: CGFloat) {
        sg.bounds = CGRect(
            x: sg.bounds.minX,
            y: sg.bounds.minY + dy,
            width: sg.bounds.width,
            height: sg.bounds.height
        )
        for i in 0..<sg.children.count {
            shiftSubgraphDown(&sg.children[i], by: dy)
        }
    }

    /// Snap points to orthogonal with explicit direction (L-bend matching TypeScript)
    private func snapToOrthogonalWithDirection(_ points: [CGPoint], verticalFirst: Bool) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var result: [CGPoint] = [points[0]]

        for i in 1..<points.count {
            let prev = result.last!
            let curr = points[i]

            let dx = abs(curr.x - prev.x)
            let dy = abs(curr.y - prev.y)

            // If already axis-aligned, keep as-is
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

        return removeCollinear(result)
    }

    /// Extract subgraph bounds from dagre's compound node (matching TypeScript extractGroup).
    /// Dagre gives compound nodes absolute coordinates (center-based), which we convert to top-left.
    /// Header expansion is applied separately in expandGroupsForHeaders().
    private func extractSubgraphBoundsRaw(_ sg: Subgraph,
                                           from g: SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>,
                                           nodes: [String: MermaidNode], config: LayoutConfig) -> Subgraph {
        var result = sg

        // Get bounds directly from dagre's compound node (matching TypeScript)
        if let dagreNode = g.node(sg.id) {
            // Convert from center-based to top-left coordinates
            let topLeftX = dagreNode.x - dagreNode.width / 2
            let topLeftY = dagreNode.y - dagreNode.height / 2
            result.bounds = CGRect(
                x: topLeftX,
                y: topLeftY,
                width: dagreNode.width,
                height: dagreNode.height
            )
            result.headerHeight = groupHeaderHeight
        }

        // Recursively extract nested subgraphs
        result.children = sg.children.map { child in
            extractSubgraphBoundsRaw(child, from: g, nodes: nodes, config: config)
        }

        return result
    }

    // MARK: - Edge Routing Helpers

    private func snapToOrthogonal(_ points: [CGPoint], config: LayoutConfig) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        let verticalFirst = config.direction.normalized == .topDown || config.direction.normalized == .bottomUp
        var result: [CGPoint] = [points[0]]

        for i in 1..<points.count {
            let prev = result.last!
            let curr = points[i]

            let dx = abs(curr.x - prev.x)
            let dy = abs(curr.y - prev.y)

            // If already axis-aligned, keep as-is
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

        return removeCollinear(result)
    }

    private func removeCollinear(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 3 else { return points }

        var result: [CGPoint] = [points[0]]
        for i in 1..<points.count - 1 {
            let a = result.last!
            let b = points[i]
            let c = points[i + 1]

            let sameX = abs(a.x - b.x) < 1 && abs(b.x - c.x) < 1
            let sameY = abs(a.y - b.y) < 1 && abs(b.y - c.y) < 1

            if !sameX && !sameY {
                result.append(b)
            }
        }
        result.append(points.last!)
        return result
    }

    /// Clip edge endpoints to rectangular node boundaries only.
    /// Non-rectangular shapes (diamond, circle) are handled separately in clipToShapeBoundaries.
    /// This matches the TypeScript implementation order.
    private func clipRectangularEndpoints(_ points: [CGPoint], sourceNode: MermaidNode?, targetNode: MermaidNode?) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        // Build NodeRect for rectangular shapes only (skip diamonds, circles)
        let sourceRect: NodeRect?
        if let source = sourceNode, !nonRectShapes.contains(source.shape) {
            sourceRect = NodeRect(
                cx: source.position.x,
                cy: source.position.y,
                hw: source.size.width / 2,
                hh: source.size.height / 2
            )
        } else {
            sourceRect = nil
        }

        let targetRect: NodeRect?
        if let target = targetNode, !nonRectShapes.contains(target.shape) {
            targetRect = NodeRect(
                cx: target.position.x,
                cy: target.position.y,
                hw: target.size.width / 2,
                hh: target.size.height / 2
            )
        } else {
            targetRect = nil
        }

        // Use the shared implementation from EdgeRouting.swift
        return clipEndpointsToNodes(points, sourceNode: sourceRect, targetNode: targetRect)
    }

    /// Circular shapes that need circle boundary clipping
    private static let circularShapes: Set<NodeShape> = [.circle, .doublecircle, .stateStart, .stateEnd]

    /// Apply shape-specific boundary clipping for non-rectangular shapes
    private func clipToShapeBoundaries(_ points: [CGPoint], sourceNode: MermaidNode?, targetNode: MermaidNode?) -> [CGPoint] {
        guard points.count >= 2 else { return points }
        var result = points

        // Clip source endpoint for non-rectangular shapes
        if let source = sourceNode {
            let cx = source.position.x
            let cy = source.position.y
            let hw = source.size.width / 2
            let hh = source.size.height / 2

            if source.shape == .diamond {
                result[0] = clipToDiamondBoundary(point: result[0], cx: cx, cy: cy, hw: hw, hh: hh)
            } else if Self.circularShapes.contains(source.shape) {
                let r = min(hw, hh)
                result[0] = clipToCircleBoundary(point: result[0], cx: cx, cy: cy, r: r)
            }
        }

        // Clip target endpoint for non-rectangular shapes
        if let target = targetNode {
            let lastIdx = result.count - 1
            let cx = target.position.x
            let cy = target.position.y
            let hw = target.size.width / 2
            let hh = target.size.height / 2

            if target.shape == .diamond {
                result[lastIdx] = clipToDiamondBoundary(point: result[lastIdx], cx: cx, cy: cy, hw: hw, hh: hh)
            } else if Self.circularShapes.contains(target.shape) {
                let r = min(hw, hh)
                result[lastIdx] = clipToCircleBoundary(point: result[lastIdx], cx: cx, cy: cy, r: r)
            }
        }

        return result
    }

    private func estimateTextWidth(_ text: String, fontSize: CGFloat, fontWeight: Int) -> CGFloat {
        let avgCharWidth: CGFloat = fontSize * 0.55
        return CGFloat(text.count) * avgCharWidth
    }

    /// Compute the midpoint of an edge path for label positioning.
    /// This is used as a fallback when Dagre doesn't provide a label position
    /// (which happens for short edges without dummy nodes).
    /// Matches the TypeScript `edgeMidpoint(edge.points)` fallback behavior.
    private func computeEdgeMidpoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        guard points.count > 1 else { return points[0] }

        // For paths with 2+ points, find the point at 50% of the total path length
        var totalLength: CGFloat = 0
        var segmentLengths: [CGFloat] = []

        for i in 1..<points.count {
            let dx = points[i].x - points[i-1].x
            let dy = points[i].y - points[i-1].y
            let len = sqrt(dx * dx + dy * dy)
            segmentLengths.append(len)
            totalLength += len
        }

        let targetLength = totalLength / 2
        var accumulated: CGFloat = 0

        for i in 0..<segmentLengths.count {
            let segLen = segmentLengths[i]
            if accumulated + segLen >= targetLength {
                // The midpoint is on this segment
                let remaining = targetLength - accumulated
                let t = segLen > 0 ? remaining / segLen : 0
                let p1 = points[i]
                let p2 = points[i + 1]
                return CGPoint(
                    x: p1.x + t * (p2.x - p1.x),
                    y: p1.y + t * (p2.y - p1.y)
                )
            }
            accumulated += segLen
        }

        // Fallback: return geometric center of first and last point
        return CGPoint(
            x: (points.first!.x + points.last!.x) / 2,
            y: (points.first!.y + points.last!.y) / 2
        )
    }
}
