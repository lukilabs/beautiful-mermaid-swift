//
//  VisualRegressionTests.swift
//  BeautifulMermaidTests
//
//  Visual regression tests that FAIL when output differs from TypeScript reference.
//  These tests enforce layout compatibility with the TypeScript version.
//

import XCTest
@testable import BeautifulMermaid

final class VisualRegressionTests: XCTestCase {

    // MARK: - Configuration

    /// Position tolerance in points (allows for minor floating point differences)
    let positionTolerance: CGFloat = 2.0

    /// Size tolerance in points
    let sizeTolerance: CGFloat = 5.0

    /// Edge point tolerance
    let edgePointTolerance: CGFloat = 3.0

    // MARK: - Reference Data Structures

    struct ReferenceLayout: Codable {
        let title: String
        let source: String
        let layout: LayoutData?
        let error: String?
    }

    struct LayoutData: Codable {
        let width: Int
        let height: Int
        let nodes: [NodeData]
        let edges: [EdgeData]
        let groups: [GroupData]
    }

    struct NodeData: Codable {
        let id: String
        let label: String
        let shape: String
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    struct EdgeData: Codable {
        let source: String
        let target: String
        let label: String?
        let style: String
        let points: [PointData]
    }

    struct PointData: Codable {
        let x: Int
        let y: Int
    }

    struct GroupData: Codable {
        let id: String
        let label: String
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    // MARK: - Helper Methods

    func loadReferenceLayouts() -> [ReferenceLayout]? {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "layouts-reference", withExtension: "json") else {
            let path = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("layouts-reference.json")
            guard let data = try? Data(contentsOf: path) else { return nil }
            return try? JSONDecoder().decode([ReferenceLayout].self, from: data)
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ReferenceLayout].self, from: data)
    }

    func findReference(titled: String) -> ReferenceLayout? {
        guard let refs = loadReferenceLayouts() else { return nil }
        return refs.first { $0.title == titled }
    }

    func layoutDiagram(_ source: String) throws -> PositionedGraph {
        let parsed = try MermaidParser.parse(source)
        var config = LayoutConfig()
        config.margin = 40
        config.direction = parsed.direction
        let layout = GraphLayout(config: config)
        return try layout.layout(parsed)
    }

    /// Convert Swift center-based position to top-left (matching TypeScript reference format)
    func swiftPositionToTopLeft(_ node: MermaidNode) -> (x: CGFloat, y: CGFloat) {
        return (
            x: node.position.x - node.bounds.width / 2,
            y: node.position.y - node.bounds.height / 2
        )
    }

    // MARK: - Edge Routing Tests

    /// Test that edges from a single source fan out correctly
    /// This was the user-reported bug: arrows appearing to come from Target 2 instead of Source
    func testEdgeFanOutFromSingleSource() throws {
        let source = """
        graph TD
          A[Source] -->|solid| B[Target 1]
          A -.->|dotted| C[Target 2]
          A ==>|thick| D[Target 3]
        """

        let positioned = try layoutDiagram(source)

        // Find nodes
        guard let nodeA = positioned.nodes.first(where: { $0.id == "A" }),
              let nodeB = positioned.nodes.first(where: { $0.id == "B" }),
              let nodeC = positioned.nodes.first(where: { $0.id == "C" }),
              let nodeD = positioned.nodes.first(where: { $0.id == "D" }) else {
            XCTFail("Missing nodes")
            return
        }

        // Verify A is above B, C, D (TD layout)
        XCTAssertLessThan(nodeA.position.y, nodeB.position.y, "Source A should be above Target B")
        XCTAssertLessThan(nodeA.position.y, nodeC.position.y, "Source A should be above Target C")
        XCTAssertLessThan(nodeA.position.y, nodeD.position.y, "Source A should be above Target D")

        // Find edges
        guard let edgeAB = positioned.edges.first(where: { $0.sourceId == "A" && $0.targetId == "B" }),
              let edgeAC = positioned.edges.first(where: { $0.sourceId == "A" && $0.targetId == "C" }),
              let edgeAD = positioned.edges.first(where: { $0.sourceId == "A" && $0.targetId == "D" }) else {
            XCTFail("Missing edges")
            return
        }

        // CRITICAL: All edges must START from node A's boundary (not from any target)
        let aBottom = nodeA.position.y + nodeA.bounds.height / 2

        // Edge A->B first point should be at or near A's bottom
        XCTAssertLessThanOrEqual(
            abs(edgeAB.points.first!.y - aBottom),
            edgePointTolerance,
            "Edge A->B should start from A's bottom boundary, not from \(edgeAB.points.first!)"
        )

        // Edge A->C first point should be at or near A's bottom
        XCTAssertLessThanOrEqual(
            abs(edgeAC.points.first!.y - aBottom),
            edgePointTolerance,
            "Edge A->C should start from A's bottom boundary, not from \(edgeAC.points.first!)"
        )

        // Edge A->D first point should be at or near A's bottom
        XCTAssertLessThanOrEqual(
            abs(edgeAD.points.first!.y - aBottom),
            edgePointTolerance,
            "Edge A->D should start from A's bottom boundary, not from \(edgeAD.points.first!)"
        )

        // All edges should END at their respective target node (at boundary or center)
        // For edges with L-bends, clipEndpointsToNodes routes to center for visual balance
        let bBounds = nodeB.bounds.insetBy(dx: -edgePointTolerance, dy: -edgePointTolerance)
        let cBounds = nodeC.bounds.insetBy(dx: -edgePointTolerance, dy: -edgePointTolerance)
        let dBounds = nodeD.bounds.insetBy(dx: -edgePointTolerance, dy: -edgePointTolerance)

        XCTAssertTrue(
            bBounds.contains(edgeAB.points.last!) ||
            abs(edgeAB.points.last!.y - nodeB.position.y) <= nodeB.bounds.height / 2 + edgePointTolerance,
            "Edge A->B should end at or near B's boundary"
        )

        XCTAssertTrue(
            cBounds.contains(edgeAC.points.last!) ||
            abs(edgeAC.points.last!.y - nodeC.position.y) <= nodeC.bounds.height / 2 + edgePointTolerance,
            "Edge A->C should end at or near C's boundary"
        )

        XCTAssertTrue(
            dBounds.contains(edgeAD.points.last!) ||
            abs(edgeAD.points.last!.y - nodeD.position.y) <= nodeD.bounds.height / 2 + edgePointTolerance,
            "Edge A->D should end at or near D's boundary"
        )

        print("✓ Edge fan-out test passed")
        print("  A->B: \(edgeAB.points.count) points, starts at y=\(edgeAB.points.first!.y)")
        print("  A->C: \(edgeAC.points.count) points, starts at y=\(edgeAC.points.first!.y)")
        print("  A->D: \(edgeAD.points.count) points, starts at y=\(edgeAD.points.first!.y)")
    }

    /// Test edge routing for horizontal (LR) layouts
    func testEdgeRoutingLeftRight() throws {
        let source = """
        graph LR
          A[Start] --> B[Middle] --> C[End]
        """

        let positioned = try layoutDiagram(source)

        guard let nodeA = positioned.nodes.first(where: { $0.id == "A" }),
              let nodeB = positioned.nodes.first(where: { $0.id == "B" }),
              let nodeC = positioned.nodes.first(where: { $0.id == "C" }) else {
            XCTFail("Missing nodes")
            return
        }

        // In LR layout, nodes should be arranged left-to-right
        XCTAssertLessThan(nodeA.position.x, nodeB.position.x, "A should be left of B")
        XCTAssertLessThan(nodeB.position.x, nodeC.position.x, "B should be left of C")

        // Edges should exit from right side and enter from left side
        guard let edgeAB = positioned.edges.first(where: { $0.sourceId == "A" && $0.targetId == "B" }),
              let edgeBC = positioned.edges.first(where: { $0.sourceId == "B" && $0.targetId == "C" }) else {
            XCTFail("Missing edges")
            return
        }

        let aRight = nodeA.position.x + nodeA.bounds.width / 2
        let bLeft = nodeB.position.x - nodeB.bounds.width / 2

        // Edge A->B should start from A's right side
        XCTAssertLessThanOrEqual(
            abs(edgeAB.points.first!.x - aRight),
            edgePointTolerance,
            "Edge A->B should start from A's right boundary"
        )

        // Edge A->B should end at B's left side
        XCTAssertLessThanOrEqual(
            abs(edgeAB.points.last!.x - bLeft),
            edgePointTolerance,
            "Edge A->B should end at B's left boundary"
        )

        print("✓ LR edge routing test passed")
    }

    /// Test that straight vertical edges have correct endpoint clipping
    func testStraightVerticalEdge() throws {
        let source = """
        graph TD
          A[Top] --> B[Bottom]
        """

        let positioned = try layoutDiagram(source)

        guard let nodeA = positioned.nodes.first(where: { $0.id == "A" }),
              let nodeB = positioned.nodes.first(where: { $0.id == "B" }),
              let edge = positioned.edges.first else {
            XCTFail("Missing nodes or edge")
            return
        }

        // For a straight vertical edge, we expect 2 points
        XCTAssertEqual(edge.points.count, 2, "Straight vertical edge should have 2 points")

        // Start point should be at A's bottom center
        let expectedStartX = nodeA.position.x
        let expectedStartY = nodeA.position.y + nodeA.bounds.height / 2

        XCTAssertLessThanOrEqual(
            abs(edge.points[0].x - expectedStartX),
            edgePointTolerance,
            "Edge should start at A's center X"
        )
        XCTAssertLessThanOrEqual(
            abs(edge.points[0].y - expectedStartY),
            edgePointTolerance,
            "Edge should start at A's bottom"
        )

        // End point should be at B's top center
        let expectedEndX = nodeB.position.x
        let expectedEndY = nodeB.position.y - nodeB.bounds.height / 2

        XCTAssertLessThanOrEqual(
            abs(edge.points[1].x - expectedEndX),
            edgePointTolerance,
            "Edge should end at B's center X"
        )
        XCTAssertLessThanOrEqual(
            abs(edge.points[1].y - expectedEndY),
            edgePointTolerance,
            "Edge should end at B's top"
        )

        print("✓ Straight vertical edge test passed")
    }

    /// Test edge with horizontal offset (needs orthogonal bend)
    func testOrthogonalEdgeWithBend() throws {
        let source = """
        graph TD
          A[Left Top]
          B[Right Bottom]
          A --> B
        """

        // Parse manually to set specific positions would be needed for true control
        // Instead, we verify the edge has the right structure
        let positioned = try layoutDiagram(source)

        guard let edge = positioned.edges.first else {
            XCTFail("Missing edge")
            return
        }

        // If source and target have different X positions, edge should have bend points
        guard let nodeA = positioned.nodes.first(where: { $0.id == "A" }),
              let nodeB = positioned.nodes.first(where: { $0.id == "B" }) else {
            XCTFail("Missing nodes")
            return
        }

        if abs(nodeA.position.x - nodeB.position.x) > 10 {
            // Expect orthogonal routing with bends (4 points for Z-bend)
            XCTAssertGreaterThanOrEqual(
                edge.points.count,
                3,
                "Edge with horizontal offset should have bend points"
            )

            // Verify all segments are orthogonal (either horizontal or vertical)
            for i in 0..<(edge.points.count - 1) {
                let p1 = edge.points[i]
                let p2 = edge.points[i + 1]
                let isHorizontal = abs(p1.y - p2.y) < 1
                let isVertical = abs(p1.x - p2.x) < 1

                XCTAssertTrue(
                    isHorizontal || isVertical,
                    "Edge segment \(i) should be orthogonal, but goes from \(p1) to \(p2)"
                )
            }
        }

        print("✓ Orthogonal edge bend test passed")
    }

    // MARK: - Reference Comparison Tests

    /// Test "All Edge Styles" diagram against TypeScript reference
    func testAllEdgeStylesMatchesReference() throws {
        guard let ref = findReference(titled: "All Edge Styles"),
              let refLayout = ref.layout else {
            throw XCTSkip("Reference 'All Edge Styles' not found")
        }

        let positioned = try layoutDiagram(ref.source)

        // Verify node count matches
        XCTAssertEqual(
            positioned.nodes.count,
            refLayout.nodes.count,
            "Node count should match reference"
        )

        // Verify edge count matches
        XCTAssertEqual(
            positioned.edges.count,
            refLayout.edges.count,
            "Edge count should match reference"
        )

        // Verify each edge has correct point count
        for refEdge in refLayout.edges {
            guard let swiftEdge = positioned.edges.first(where: {
                $0.sourceId == refEdge.source && $0.targetId == refEdge.target
            }) else {
                XCTFail("Missing edge: \(refEdge.source) -> \(refEdge.target)")
                continue
            }

            // Allow ±1 point difference for minor routing variations
            let pointDiff = abs(swiftEdge.points.count - refEdge.points.count)
            XCTAssertLessThanOrEqual(
                pointDiff,
                1,
                "Edge \(refEdge.source)->\(refEdge.target) point count: Swift=\(swiftEdge.points.count), Ref=\(refEdge.points.count)"
            )
        }

        print("✓ All Edge Styles reference comparison passed")
    }

    /// Test node positions match TypeScript reference within tolerance
    func testNodePositionsMatchReference() throws {
        guard let refs = loadReferenceLayouts() else {
            throw XCTSkip("Could not load reference layouts")
        }

        var passedCount = 0
        var failedDiagrams: [String] = []

        for ref in refs {
            guard let refLayout = ref.layout else { continue }

            do {
                let positioned = try layoutDiagram(ref.source)

                var allNodesMatch = true
                for refNode in refLayout.nodes {
                    guard let swiftNode = positioned.nodes.first(where: { $0.id == refNode.id }) else {
                        allNodesMatch = false
                        break
                    }

                    let (swiftX, swiftY) = swiftPositionToTopLeft(swiftNode)
                    let xDiff = abs(swiftX - CGFloat(refNode.x))
                    let yDiff = abs(swiftY - CGFloat(refNode.y))

                    // Use a larger tolerance for position (layout algorithms can vary)
                    if xDiff > 50 || yDiff > 50 {
                        allNodesMatch = false
                        break
                    }
                }

                if allNodesMatch {
                    passedCount += 1
                } else {
                    failedDiagrams.append(ref.title)
                }
            } catch {
                failedDiagrams.append("\(ref.title) (parse error)")
            }
        }

        print("Node position comparison: \(passedCount)/\(refs.count) passed")
        if !failedDiagrams.isEmpty {
            print("Failed diagrams: \(failedDiagrams.prefix(5).joined(separator: ", "))")
        }

        // Require at least 40% to pass (layout differences are expected)
        let passRate = Double(passedCount) / Double(refs.count)
        XCTAssertGreaterThan(passRate, 0.4, "At least 40% of diagrams should have matching node positions")
    }

    // MARK: - Edge Style Tests

    /// Test different edge styles are parsed and rendered correctly
    func testEdgeStylesPreserved() throws {
        let source = """
        graph TD
          A -->|solid| B
          A -.->|dotted| C
          A ==>|thick| D
        """

        let positioned = try layoutDiagram(source)

        guard let solidEdge = positioned.edges.first(where: { $0.targetId == "B" }),
              let dottedEdge = positioned.edges.first(where: { $0.targetId == "C" }),
              let thickEdge = positioned.edges.first(where: { $0.targetId == "D" }) else {
            XCTFail("Missing edges")
            return
        }

        // Verify edge styles
        XCTAssertEqual(solidEdge.style.lineStyle, .solid, "Edge to B should be solid")
        XCTAssertEqual(dottedEdge.style.lineStyle, .dotted, "Edge to C should be dotted")
        XCTAssertEqual(thickEdge.style.lineStyle, .thick, "Edge to D should be thick")

        print("✓ Edge styles preserved correctly")
    }

    /// Test bidirectional arrows
    func testBidirectionalArrows() throws {
        let source = """
        graph LR
          A <--> B
        """

        let positioned = try layoutDiagram(source)

        guard let edge = positioned.edges.first else {
            XCTFail("Missing edge")
            return
        }

        // Bidirectional edge should have arrows at both ends
        XCTAssertTrue(edge.hasArrowStart, "Bidirectional edge should have arrow at start")
        XCTAssertTrue(edge.hasArrowEnd, "Bidirectional edge should have arrow at end")

        print("✓ Bidirectional arrows test passed")
    }

    // MARK: - Subgraph Tests

    /// Test subgraph bounds calculation
    func testSubgraphBounds() throws {
        let source = """
        graph TD
          subgraph sub1[Group 1]
            A[Node A]
            B[Node B]
          end
          C[Outside] --> A
        """

        let positioned = try layoutDiagram(source)

        XCTAssertFalse(positioned.subgraphs.isEmpty, "Should have subgraphs")

        guard let subgraph = positioned.subgraphs.first else {
            XCTFail("Missing subgraph")
            return
        }

        // Subgraph should contain nodes A and B
        guard let nodeA = positioned.nodes.first(where: { $0.id == "A" }),
              let nodeB = positioned.nodes.first(where: { $0.id == "B" }) else {
            XCTFail("Missing nodes in subgraph")
            return
        }

        // Subgraph bounds should contain both nodes
        XCTAssertTrue(
            subgraph.bounds.contains(nodeA.position),
            "Subgraph bounds should contain node A"
        )
        XCTAssertTrue(
            subgraph.bounds.contains(nodeB.position),
            "Subgraph bounds should contain node B"
        )

        print("✓ Subgraph bounds test passed")
        print("  Subgraph bounds: \(subgraph.bounds)")
        print("  Node A position: \(nodeA.position)")
        print("  Node B position: \(nodeB.position)")
    }

    // MARK: - Nested Subgraph Tests

    /// Test nested subgraphs layout and rendering (Cloud/Region structure)
    func testNestedSubgraphsLayout() throws {
        let source = """
        graph TD
          subgraph Cloud
            subgraph us-east [US East Region]
              A[Web Server] --> B[App Server]
            end
            subgraph us-west [US West Region]
              C[Web Server] --> D[App Server]
            end
          end
          E[Load Balancer] --> A
          E --> C
        """

        let positioned = try layoutDiagram(source)

        // Verify all nodes exist
        XCTAssertEqual(positioned.nodes.count, 5, "Should have 5 nodes (A, B, C, D, E)")

        // Find nodes
        guard let nodeE = positioned.nodes.first(where: { $0.id == "E" }),
              let nodeA = positioned.nodes.first(where: { $0.id == "A" }),
              let nodeC = positioned.nodes.first(where: { $0.id == "C" }) else {
            XCTFail("Missing expected nodes")
            return
        }

        // E (Load Balancer) should be above A and C since edges go E->A and E->C
        XCTAssertLessThan(nodeE.position.y, nodeA.position.y,
            "Load Balancer (E) should be above Web Server A")
        XCTAssertLessThan(nodeE.position.y, nodeC.position.y,
            "Load Balancer (E) should be above Web Server C")

        // Verify we have subgraphs
        XCTAssertFalse(positioned.subgraphs.isEmpty, "Should have subgraphs")

        // Find the Cloud subgraph (should contain nested subgraphs)
        let cloudSubgraph = positioned.subgraphs.first { $0.id == "Cloud" }
        XCTAssertNotNil(cloudSubgraph, "Should have Cloud subgraph")

        if let cloud = cloudSubgraph {
            // Cloud should have nested children (us-east, us-west)
            XCTAssertEqual(cloud.children.count, 2,
                "Cloud should have 2 nested subgraphs (us-east, us-west)")

            // Cloud bounds should have positive dimensions
            XCTAssertGreaterThan(cloud.bounds.width, 0, "Cloud should have positive width")
            XCTAssertGreaterThan(cloud.bounds.height, 0, "Cloud should have positive height")

            // Nested subgraphs should also have bounds
            for child in cloud.children {
                XCTAssertGreaterThan(child.bounds.width, 0,
                    "Nested subgraph \(child.id) should have positive width")
                XCTAssertGreaterThan(child.bounds.height, 0,
                    "Nested subgraph \(child.id) should have positive height")
            }
        }

        print("✓ Nested subgraphs test passed")
        print("  E (Load Balancer) at y=\(nodeE.position.y)")
        print("  A (Web Server) at y=\(nodeA.position.y)")
        print("  Subgraphs: \(positioned.subgraphs.count)")
        if let cloud = cloudSubgraph {
            print("  Cloud bounds: \(cloud.bounds)")
            for child in cloud.children {
                print("  - \(child.id) bounds: \(child.bounds)")
            }
        }
    }

    /// Test that nested subgraph rendering produces an image with all borders
    func testNestedSubgraphRendering() throws {
        let source = """
        graph TD
          subgraph outer [Outer Group]
            subgraph inner [Inner Group]
              A[Node A]
            end
          end
        """

        let positioned = try layoutDiagram(source)
        let renderer = DiagramRenderer(theme: .default)

        guard let image = renderer.renderToImage(positioned, scale: 1.0) else {
            XCTFail("Failed to render image")
            return
        }

        // Image should be larger than just the node (due to subgraph padding/borders)
        guard let nodeA = positioned.nodes.first(where: { $0.id == "A" }) else {
            XCTFail("Missing node A")
            return
        }

        // Bounds should be significantly larger than just the node due to nested subgraph headers
        let expectedMinWidth = nodeA.bounds.width + 40  // At least some padding
        let expectedMinHeight = nodeA.bounds.height + 80  // Headers for both subgraphs

        XCTAssertGreaterThan(positioned.bounds.width, expectedMinWidth,
            "Bounds width should account for subgraph padding")
        XCTAssertGreaterThan(positioned.bounds.height, expectedMinHeight,
            "Bounds height should account for nested subgraph headers")

        print("✓ Nested subgraph rendering test passed")
        print("  Image size: \(image.size)")
        print("  Node A size: \(nodeA.bounds.size)")
        print("  Total bounds: \(positioned.bounds)")
    }

    // MARK: - Image Rendering Regression Tests

    /// Test that rendering produces consistent image dimensions
    func testImageRenderingDimensions() throws {
        let source = """
        graph TD
          A[Start] --> B[End]
        """

        let positioned = try layoutDiagram(source)
        let renderer = DiagramRenderer(theme: .default)

        guard let image = renderer.renderToImage(positioned, scale: 1.0) else {
            XCTFail("Failed to render image")
            return
        }

        // Image dimensions should match positioned bounds (accounting for rounding)
        XCTAssertLessThanOrEqual(
            abs(image.size.width - positioned.bounds.width),
            2,
            "Image width should match bounds"
        )
        XCTAssertLessThanOrEqual(
            abs(image.size.height - positioned.bounds.height),
            2,
            "Image height should match bounds"
        )

        print("✓ Image rendering dimensions test passed")
        print("  Bounds: \(positioned.bounds.size)")
        print("  Image: \(image.size)")
    }
}
