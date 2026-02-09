//
//  SwiftDagreBidirectionalTest.swift
//  BeautifulMermaidTests
//
//  Test to verify SwiftDagre handles bidirectional edges correctly.
//

import XCTest
@testable import BeautifulMermaid
import SwiftDagre

final class SwiftDagreBidirectionalTest: XCTestCase {

    /// Test that SwiftDagre preserves both edges when two nodes have bidirectional edges
    func testBidirectionalEdges() throws {
        let g = SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>(
            options: SwiftDagre.GraphOptions(directed: true, multigraph: false, compound: false)
        )

        let layoutOptions = SwiftDagre.LayoutOptions()
        layoutOptions.rankdir = .topBottom
        layoutOptions.nodesep = 24
        layoutOptions.ranksep = 40
        g.setGraph(layoutOptions)

        // Add nodes
        g.setNode("A", label: SwiftDagre.DagreNodeLabel(width: 100, height: 36))
        g.setNode("B", label: SwiftDagre.DagreNodeLabel(width: 100, height: 36))

        // Add bidirectional edges (like Connected <-> Reconnecting in state diagram)
        let edgeLabel1 = SwiftDagre.DagreEdgeLabel(minlen: 1, weight: 1)
        let edgeLabel2 = SwiftDagre.DagreEdgeLabel(minlen: 1, weight: 1)
        try g.setEdge("A", "B", label: edgeLabel1)
        try g.setEdge("B", "A", label: edgeLabel2)

        print("Edges BEFORE layout: \(g.edges().count)")
        for e in g.edges() {
            print("  \(e.v) -> \(e.w)")
        }

        // Run layout
        try SwiftDagre.layout(g, options: layoutOptions)

        print("\nEdges AFTER layout: \(g.edges().count)")
        for e in g.edges() {
            let edge = g.edge(e.v, e.w)
            print("  \(e.v) -> \(e.w), points: \(edge?.points.count ?? 0)")
        }

        // Verify both edges exist
        XCTAssertEqual(g.edges().count, 2, "Should have 2 edges for bidirectional connection")

        // Verify we can find both edges
        let edgeAB = g.edge("A", "B")
        let edgeBA = g.edge("B", "A")

        XCTAssertNotNil(edgeAB, "Edge A->B should exist")
        XCTAssertNotNil(edgeBA, "Edge B->A should exist")
    }

    /// Test the actual state diagram case
    func testStateDiagramBidirectionalEdges() throws {
        let source = """
        stateDiagram-v2
          [*] --> Closed
          Closed --> Connecting : connect
          Connecting --> Connected : success
          Connecting --> Closed : timeout
          Connected --> Disconnecting : close
          Connected --> Reconnecting : error
          Reconnecting --> Connected : success
          Reconnecting --> Closed : max_retries
          Disconnecting --> Closed : done
          Closed --> [*]
        """

        let parsed = try MermaidParser.parse(source)

        print("Parsed edges: \(parsed.edges.count)")
        for edge in parsed.edges {
            print("  \(edge.sourceId) -> \(edge.targetId): \(edge.label ?? "")")
        }

        // Build dagre graph like the layout does
        let g = SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>(
            options: SwiftDagre.GraphOptions(directed: true, multigraph: false, compound: false)
        )

        let layoutOptions = SwiftDagre.LayoutOptions()
        layoutOptions.rankdir = .topBottom
        layoutOptions.nodesep = 24
        layoutOptions.ranksep = 40
        g.setGraph(layoutOptions)

        // Add nodes
        for nodeId in parsed.nodeOrder {
            guard let node = parsed.nodes[nodeId] else { continue }
            // Use fixed sizes for simplicity
            g.setNode(nodeId, label: SwiftDagre.DagreNodeLabel(width: 100, height: 36))
        }

        // Add edges
        for edge in parsed.edges {
            let edgeLabel = SwiftDagre.DagreEdgeLabel(minlen: 1, weight: 1)
            try g.setEdge(edge.sourceId, edge.targetId, label: edgeLabel)
        }

        print("\nEdges BEFORE layout: \(g.edges().count)")
        for e in g.edges() {
            print("  \(e.v) -> \(e.w)")
        }

        // Run layout
        try SwiftDagre.layout(g, options: layoutOptions)

        print("\nEdges AFTER layout: \(g.edges().count)")
        for e in g.edges() {
            let edge = g.edge(e.v, e.w)
            print("  \(e.v) -> \(e.w), points: \(edge?.points.count ?? 0)")
        }

        // Check for the bidirectional edges
        let hasConnectedToReconnecting = g.edge("Connected", "Reconnecting") != nil
        let hasReconnectingToConnected = g.edge("Reconnecting", "Connected") != nil

        let hasConnectingToClosed = g.edge("Connecting", "Closed") != nil
        let hasClosedToConnecting = g.edge("Closed", "Connecting") != nil

        print("\nBidirectional edge status:")
        print("  Connected -> Reconnecting: \(hasConnectedToReconnecting)")
        print("  Reconnecting -> Connected: \(hasReconnectingToConnected)")
        print("  Connecting -> Closed: \(hasConnectingToClosed)")
        print("  Closed -> Connecting: \(hasClosedToConnecting)")

        // We expect all edges to be preserved
        XCTAssertEqual(g.edges().count, 10, "Should have all 10 edges after layout")
    }
}
