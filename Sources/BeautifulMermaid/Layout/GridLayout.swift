// SPDX-License-Identifier: MIT
//
//  GridLayout.swift
//  BeautifulMermaid
//
//  Grid-based layout algorithm for ER diagrams
//

import Foundation
import CoreGraphics

/// Grid-based layout algorithm for ER diagrams
public struct GridLayout: GraphLayoutAlgorithm {

    public init() {}

    /// Maximum entities per row
    private let maxPerRow = 4

    /// Entity width
    private let entityWidth: CGFloat = 150

    /// Entity height
    private let entityHeight: CGFloat = 100

    public func layout(_ graph: MermaidGraph, config: LayoutConfig) throws -> PositionedGraph {
        var positionedNodes: [MermaidNode] = []
        var positionedEdges: [MermaidEdge] = []

        // Arrange entities in a grid
        var row = 0
        var col = 0

        for nodeId in graph.nodeOrder {
            guard var node = graph.nodes[nodeId] else { continue }

            // Calculate size based on content
            let baseSize = ShapeBounds.calculateSize(
                for: node.shape,
                label: node.label,
                font: config.font
            )

            // Add space for attributes
            let attributeCount = node.inlineStyles.keys.filter { $0.hasPrefix("attr_") }.count
            let height = baseSize.height + CGFloat(attributeCount) * 20

            node.size = CGSize(width: max(entityWidth, baseSize.width), height: height)

            // Position in grid
            let x = config.margin + CGFloat(col) * (entityWidth + config.nodeSeparation) + node.size.width / 2
            let y = config.margin + CGFloat(row) * (entityHeight + config.rankSeparation) + node.size.height / 2

            node.position = CGPoint(x: x, y: y)
            positionedNodes.append(node)

            // Move to next grid position
            col += 1
            if col >= maxPerRow {
                col = 0
                row += 1
            }
        }

        // Route edges
        for var edge in graph.edges {
            guard let sourceNode = positionedNodes.first(where: { $0.id == edge.sourceId }),
                  let targetNode = positionedNodes.first(where: { $0.id == edge.targetId }) else { continue }

            let points = EdgeRouter.route(
                from: sourceNode,
                to: targetNode,
                routeType: .orthogonal,
                direction: config.direction
            )

            edge.points = points
            edge.labelPosition = EdgeRouter.labelPosition(for: points)
            edge.targetAngle = EdgeRouter.endAngle(for: points)

            positionedEdges.append(edge)
        }

        // Calculate bounds
        var bounds = CGRect.zero
        for node in positionedNodes {
            bounds = bounds.union(node.bounds)
        }
        bounds = bounds.expanded(by: config.margin)

        return PositionedGraph(
            nodes: positionedNodes,
            edges: positionedEdges,
            subgraphs: [],
            bounds: bounds,
            direction: config.direction
        )
    }
}
