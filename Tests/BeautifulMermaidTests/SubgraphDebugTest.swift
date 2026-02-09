//
//  SubgraphDebugTest.swift
//  BeautifulMermaidTests
//
//  Debug test for compound node handling
//

import XCTest
@testable import BeautifulMermaid
import SwiftDagre

final class SubgraphDebugTest: XCTestCase {

    func testSimpleNonCompoundGraph() throws {
        // First test: simple graph without compound nodes to verify basic layout works
        let g = SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>(
            options: SwiftDagre.GraphOptions(directed: true, multigraph: false, compound: false)
        )

        let layoutOptions = SwiftDagre.LayoutOptions()
        layoutOptions.nodesep = 24
        layoutOptions.ranksep = 40
        g.setGraph(layoutOptions)

        // Add simple nodes
        g.setNode("A", label: SwiftDagre.DagreNodeLabel(width: 74.9, height: 36))
        g.setNode("B", label: SwiftDagre.DagreNodeLabel(width: 74.9, height: 36))
        try g.setEdge("A", "B", label: SwiftDagre.DagreEdgeLabel())

        print("Simple graph test:")
        try SwiftDagre.layout(g, options: layoutOptions)

        if let nodeA = g.node("A") {
            print("  A position: (\(nodeA.x), \(nodeA.y))")
        }
        if let nodeB = g.node("B") {
            print("  B position: (\(nodeB.x), \(nodeB.y))")
        }

        XCTAssertTrue(true) // Just checking it doesn't crash
    }

    func testCompoundGraphWithoutParenting() throws {
        // Second test: compound graph but no actual parenting
        let g = SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>(
            options: SwiftDagre.GraphOptions(directed: true, multigraph: false, compound: true)
        )

        let layoutOptions = SwiftDagre.LayoutOptions()
        layoutOptions.nodesep = 24
        layoutOptions.ranksep = 40
        g.setGraph(layoutOptions)

        g.setNode("A", label: SwiftDagre.DagreNodeLabel(width: 74.9, height: 36))
        g.setNode("B", label: SwiftDagre.DagreNodeLabel(width: 74.9, height: 36))
        try g.setEdge("A", "B", label: SwiftDagre.DagreEdgeLabel())

        print("\nCompound graph without parenting:")
        try SwiftDagre.layout(g, options: layoutOptions)

        if let nodeA = g.node("A") {
            print("  A position: (\(nodeA.x), \(nodeA.y))")
        }
        if let nodeB = g.node("B") {
            print("  B position: (\(nodeB.x), \(nodeB.y))")
        }

        XCTAssertTrue(true)
    }

    func testCompoundNodeDimensions() throws {
        // Create a compound graph like SwiftDagreAdapter does
        let g = SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>(
            options: SwiftDagre.GraphOptions(directed: true, multigraph: false, compound: true)
        )

        let layoutOptions = SwiftDagre.LayoutOptions()
        layoutOptions.nodesep = 24
        layoutOptions.ranksep = 40
        g.setGraph(layoutOptions)

        // Add subgraph compound node with zero dimensions
        g.setNode("Group", label: SwiftDagre.DagreNodeLabel(width: 0, height: 0))

        // Add child nodes
        g.setNode("A", label: SwiftDagre.DagreNodeLabel(width: 74.9, height: 36))
        g.setNode("B", label: SwiftDagre.DagreNodeLabel(width: 74.9, height: 36))
        try g.setParent("A", parent: "Group")
        try g.setParent("B", parent: "Group")

        // Add edge
        try g.setEdge("A", "B", label: SwiftDagre.DagreEdgeLabel())

        // Run layout
        try SwiftDagre.layout(g, options: layoutOptions)

        // Verify compound node got dimensions
        let groupLabel = g.node("Group")
        XCTAssertNotNil(groupLabel)
        XCTAssertGreaterThan(groupLabel!.width, 0, "Group should have width after layout")
        XCTAssertGreaterThan(groupLabel!.height, 0, "Group should have height after layout")
    }
}
