//
//  LayoutTests.swift
//  BeautifulMermaidTests
//
//  Tests for layout algorithms
//

import XCTest
@testable import BeautifulMermaid

final class LayoutTests: XCTestCase {

    func testBasicLayout() throws {
        let source = """
        graph TD
            A[Start] --> B[End]
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        XCTAssertEqual(positioned.nodes.count, 2)
        XCTAssertEqual(positioned.edges.count, 1)

        // Check that nodes have positions
        for node in positioned.nodes {
            XCTAssertNotEqual(node.position, .zero, "Node \(node.id) should have a position")
            XCTAssertGreaterThan(node.size.width, 0, "Node \(node.id) should have width")
            XCTAssertGreaterThan(node.size.height, 0, "Node \(node.id) should have height")
        }

        // Check that edge has points
        XCTAssertGreaterThanOrEqual(positioned.edges[0].points.count, 2)
    }

    func testTopDownLayout() throws {
        let source = """
        graph TD
            A --> B
            B --> C
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        let nodeA = positioned.nodes.first { $0.id == "A" }
        let nodeB = positioned.nodes.first { $0.id == "B" }
        let nodeC = positioned.nodes.first { $0.id == "C" }

        XCTAssertNotNil(nodeA)
        XCTAssertNotNil(nodeB)
        XCTAssertNotNil(nodeC)

        // In TD layout, Y should increase from A to B to C
        XCTAssertLessThan(nodeA!.position.y, nodeB!.position.y)
        XCTAssertLessThan(nodeB!.position.y, nodeC!.position.y)
    }

    func testLeftRightLayout() throws {
        let source = """
        graph LR
            A --> B
            B --> C
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        let nodeA = positioned.nodes.first { $0.id == "A" }
        let nodeB = positioned.nodes.first { $0.id == "B" }
        let nodeC = positioned.nodes.first { $0.id == "C" }

        // In LR layout, X should increase from A to B to C
        XCTAssertLessThan(nodeA!.position.x, nodeB!.position.x)
        XCTAssertLessThan(nodeB!.position.x, nodeC!.position.x)
    }

    func testLayoutBounds() throws {
        let source = """
        graph TD
            A --> B
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        // All nodes should be within bounds
        for node in positioned.nodes {
            XCTAssertTrue(positioned.bounds.contains(node.bounds),
                         "Node \(node.id) should be within bounds")
        }
    }

    func testSubgraphLayout() throws {
        let source = """
        graph TD
            subgraph Group[My Group]
                A --> B
            end
            C --> A
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        XCTAssertEqual(positioned.subgraphs.count, 1)

        // Subgraph bounds should contain its nodes
        let subgraph = positioned.subgraphs[0]
        let nodeA = positioned.nodes.first { $0.id == "A" }
        let nodeB = positioned.nodes.first { $0.id == "B" }

        XCTAssertNotNil(nodeA)
        XCTAssertNotNil(nodeB)

        // Nodes A and B should be within subgraph bounds
        // (accounting for header height)
        let expandedBounds = subgraph.bounds.expanded(by: 10)
        XCTAssertTrue(expandedBounds.contains(nodeA!.bounds.center),
                     "Node A should be within subgraph")
        XCTAssertTrue(expandedBounds.contains(nodeB!.bounds.center),
                     "Node B should be within subgraph")
    }

    func testEdgeRouting() throws {
        let source = """
        graph TD
            A --> B
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        let edge = positioned.edges[0]

        // Edge should have valid points
        XCTAssertGreaterThanOrEqual(edge.points.count, 2)

        // First point should be near source node
        let sourceNode = positioned.nodes.first { $0.id == edge.sourceId }!
        let firstPoint = edge.points.first!
        let distanceToSource = sourceNode.position.distance(to: firstPoint)
        XCTAssertLessThan(distanceToSource, sourceNode.size.width,
                         "Edge start should be near source node")

        // Last point should be near target node
        let targetNode = positioned.nodes.first { $0.id == edge.targetId }!
        let lastPoint = edge.points.last!
        let distanceToTarget = targetNode.position.distance(to: lastPoint)
        XCTAssertLessThan(distanceToTarget, targetNode.size.width,
                         "Edge end should be near target node")
    }

    func testLayoutConfig() throws {
        let source = """
        graph TD
            A --> B
        """

        var config = LayoutConfig()
        config.nodeSeparation = 100
        config.rankSeparation = 100

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout(config: config)
        let positioned = try layout.layout(graph)

        let nodeA = positioned.nodes.first { $0.id == "A" }!
        let nodeB = positioned.nodes.first { $0.id == "B" }!

        // With larger rank separation, nodes should be further apart
        let distance = abs(nodeB.position.y - nodeA.position.y)
        XCTAssertGreaterThan(distance, 80, "Nodes should be separated by configured distance")
    }

    // MARK: - Self-Loop Layout Tests

    func testSelfLoopLayout() throws {
        let source = """
        graph TD
            A[Node] --> A
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        XCTAssertEqual(positioned.nodes.count, 1)
        XCTAssertEqual(positioned.edges.count, 1)

        let edge = positioned.edges[0]
        XCTAssertEqual(edge.sourceId, "A")
        XCTAssertEqual(edge.targetId, "A")

        // Self-loop should have multiple points forming a loop
        XCTAssertGreaterThanOrEqual(edge.points.count, 3,
            "Self-loop should have at least 3 points to form a visible loop")
    }

    func testSelfLoopWithLabelLayout() throws {
        let source = """
        graph TD
            A[Retry] -->|again| A
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        let edge = positioned.edges[0]

        // Self-loop with label should have points
        XCTAssertGreaterThanOrEqual(edge.points.count, 3,
            "Self-loop with label should have points for the loop")

        // The edge label should be preserved
        XCTAssertEqual(edge.label, "again", "Self-loop label should be preserved through layout")
    }

    func testSelfLoopMixedWithRegularEdges() throws {
        let source = """
        graph TD
            A[Start] --> B[Process]
            B -->|retry| B
            B --> C[End]
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        XCTAssertEqual(positioned.nodes.count, 3)
        XCTAssertEqual(positioned.edges.count, 3)

        // Find the self-loop edge
        let selfLoop = positioned.edges.first { $0.sourceId == "B" && $0.targetId == "B" }
        XCTAssertNotNil(selfLoop, "Self-loop edge should exist")
        XCTAssertEqual(selfLoop?.label, "retry", "Self-loop label should be preserved")

        // Find regular edges
        let edgeAB = positioned.edges.first { $0.sourceId == "A" && $0.targetId == "B" }
        let edgeBC = positioned.edges.first { $0.sourceId == "B" && $0.targetId == "C" }
        XCTAssertNotNil(edgeAB, "Edge A->B should exist")
        XCTAssertNotNil(edgeBC, "Edge B->C should exist")

        // All edges should have valid points
        for edge in positioned.edges {
            XCTAssertGreaterThanOrEqual(edge.points.count, 2,
                "Edge \(edge.sourceId)->\(edge.targetId) should have points")
        }
    }
}

// MARK: - Helper Extensions

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
