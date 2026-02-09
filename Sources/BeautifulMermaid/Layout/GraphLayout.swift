// SPDX-License-Identifier: MIT
//
//  GraphLayout.swift
//  BeautifulMermaid
//
//  Protocol and coordinator for graph layout algorithms
//

import Foundation
import CoreGraphics

/// Configuration for layout algorithms
public struct LayoutConfig {
    /// Horizontal spacing between nodes in the same rank (nodesep in dagre)
    public var nodeSeparation: CGFloat = 24

    /// Vertical spacing between ranks (ranksep in dagre)
    public var rankSeparation: CGFloat = 40

    /// Spacing between edges (matches dagre default of 20)
    public var edgeSeparation: CGFloat = 20

    /// Margin around the entire graph (marginx/marginy in dagre)
    public var margin: CGFloat = 40

    /// Font for measuring text (matches TypeScript FONT_SIZES.nodeLabel = 13)
    public var font: BMFont = BMFont.systemFont(ofSize: 13)

    /// Padding inside nodes (matches TypeScript NODE_PADDING)
    public var nodePadding: CGSize = CGSize(width: 16, height: 10)

    /// Direction of the layout
    public var direction: Direction = .topDown

    /// Whether to align nodes in the same rank
    public var alignRanks: Bool = true

    public init() {}
}

/// Protocol for graph layout algorithms
public protocol GraphLayoutAlgorithm {
    /// Layout a graph and return positioned nodes and edges
    /// - Throws: `GraphError` if the layout encounters an invalid graph state
    func layout(_ graph: MermaidGraph, config: LayoutConfig) throws -> PositionedGraph
}

/// Main layout coordinator that delegates to appropriate algorithm
public class GraphLayout {
    private let config: LayoutConfig

    public init(config: LayoutConfig = LayoutConfig()) {
        self.config = config
    }

    /// Layout a parsed Mermaid graph
    public func layout(_ graph: MermaidGraph) throws -> PositionedGraph {
        var effectiveConfig = config
        effectiveConfig.direction = graph.direction

        // Choose algorithm based on diagram type
        let algorithm: GraphLayoutAlgorithm

        switch graph.type {
        case .flowchart, .stateDiagram, .classDiagram:
            algorithm = SwiftDagreAdapter()

        case .sequenceDiagram:
            algorithm = SequenceLayout()

        case .erDiagram:
            algorithm = GridLayout()
        }

        return try algorithm.layout(graph, config: effectiveConfig)
    }

    /// Layout with custom configuration
    public func layout(_ graph: MermaidGraph, config: LayoutConfig) throws -> PositionedGraph {
        // config.direction takes precedence (set by UI), graph.direction is from parsed source
        let algorithm = SwiftDagreAdapter()
        return try algorithm.layout(graph, config: config)
    }
}
