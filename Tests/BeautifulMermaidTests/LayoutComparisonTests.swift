//
//  LayoutComparisonTests.swift
//  BeautifulMermaidTests
//
//  Compares Swift layout output against TypeScript reference
//

import XCTest
@testable import BeautifulMermaid

final class LayoutComparisonTests: XCTestCase {

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

    // MARK: - Comparison Results

    struct ComparisonResult {
        let title: String
        let success: Bool
        let nodeCountMatch: Bool
        let edgeCountMatch: Bool
        let nodeDiffs: [String]
        let edgeDiffs: [String]
        let sizeDiff: (width: Int, height: Int)?
    }

    // MARK: - Load Reference Data

    func loadReferenceLayouts() -> [ReferenceLayout]? {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "layouts-reference", withExtension: "json") else {
            // Try relative path for command-line testing
            let path = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("layouts-reference.json")
            guard let data = try? Data(contentsOf: path) else {
                print("Could not load layouts-reference.json")
                return nil
            }
            return try? JSONDecoder().decode([ReferenceLayout].self, from: data)
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ReferenceLayout].self, from: data)
    }

    // MARK: - Compare Single Layout

    func compareLayout(swift: PositionedGraph, reference: LayoutData, tolerance: Int = 5) -> ComparisonResult {
        var nodeDiffs: [String] = []
        var edgeDiffs: [String] = []

        // Compare node counts
        let nodeCountMatch = swift.nodes.count == reference.nodes.count
        if !nodeCountMatch {
            nodeDiffs.append("Node count: Swift=\(swift.nodes.count), Ref=\(reference.nodes.count)")
        }

        // Compare edge counts
        let edgeCountMatch = swift.edges.count == reference.edges.count
        if !edgeCountMatch {
            edgeDiffs.append("Edge count: Swift=\(swift.edges.count), Ref=\(reference.edges.count)")
        }

        // Compare individual nodes
        // NOTE: TypeScript reference stores TOP-LEFT coordinates, Swift stores CENTER
        // Convert Swift center to top-left for comparison
        let swiftNodes = swift.nodes.sorted { $0.id < $1.id }
        for refNode in reference.nodes {
            if let swiftNode = swiftNodes.first(where: { $0.id == refNode.id }) {
                // Convert Swift center-based position to top-left for comparison
                let swiftTopLeftX = Int(swiftNode.position.x - swiftNode.bounds.width / 2)
                let swiftTopLeftY = Int(swiftNode.position.y - swiftNode.bounds.height / 2)

                let xDiff = abs(swiftTopLeftX - refNode.x)
                let yDiff = abs(swiftTopLeftY - refNode.y)
                let wDiff = abs(Int(swiftNode.bounds.width) - refNode.width)
                let hDiff = abs(Int(swiftNode.bounds.height) - refNode.height)

                if xDiff > tolerance || yDiff > tolerance {
                    nodeDiffs.append("\(refNode.id) pos: Swift=(\(swiftTopLeftX),\(swiftTopLeftY)), Ref=(\(refNode.x),\(refNode.y))")
                }
                if wDiff > tolerance || hDiff > tolerance {
                    nodeDiffs.append("\(refNode.id) size: Swift=\(Int(swiftNode.bounds.width))x\(Int(swiftNode.bounds.height)), Ref=\(refNode.width)x\(refNode.height)")
                }
            } else {
                nodeDiffs.append("Missing node: \(refNode.id)")
            }
        }

        // Check for extra nodes in Swift
        for swiftNode in swiftNodes {
            if !reference.nodes.contains(where: { $0.id == swiftNode.id }) {
                nodeDiffs.append("Extra node in Swift: \(swiftNode.id)")
            }
        }

        // Compare edges (by source-target pair)
        let swiftEdges = swift.edges.sorted { "\($0.sourceId)-\($0.targetId)" < "\($1.sourceId)-\($1.targetId)" }
        for refEdge in reference.edges {
            if let swiftEdge = swiftEdges.first(where: { $0.sourceId == refEdge.source && $0.targetId == refEdge.target }) {
                // Compare point counts
                if swiftEdge.points.count != refEdge.points.count {
                    edgeDiffs.append("\(refEdge.source)->\(refEdge.target) points: Swift=\(swiftEdge.points.count), Ref=\(refEdge.points.count)")
                }
            } else {
                edgeDiffs.append("Missing edge: \(refEdge.source)->\(refEdge.target)")
            }
        }

        // Size comparison
        let widthDiff = abs(Int(swift.bounds.width) - reference.width)
        let heightDiff = abs(Int(swift.bounds.height) - reference.height)
        let sizeDiff = (widthDiff > tolerance || heightDiff > tolerance) ? (widthDiff, heightDiff) : nil

        let success = nodeCountMatch && edgeCountMatch && nodeDiffs.isEmpty && edgeDiffs.isEmpty && sizeDiff == nil

        return ComparisonResult(
            title: "",
            success: success,
            nodeCountMatch: nodeCountMatch,
            edgeCountMatch: edgeCountMatch,
            nodeDiffs: nodeDiffs,
            edgeDiffs: edgeDiffs,
            sizeDiff: sizeDiff
        )
    }

    // MARK: - Tests

    func testCompareWithTypeScriptReference() throws {
        guard let references = loadReferenceLayouts() else {
            XCTFail("Could not load reference layouts")
            return
        }

        var passCount = 0
        var failCount = 0
        var skipCount = 0
        var failures: [(String, ComparisonResult)] = []

        for ref in references {
            // Skip if reference had an error
            guard let refLayout = ref.layout else {
                skipCount += 1
                continue
            }

            // Parse with Swift
            do {
                let parsed = try MermaidParser.parse(ref.source)
                var config = LayoutConfig()
                config.margin = 40
                config.direction = parsed.direction  // Use parsed direction from graph
                let layout = GraphLayout(config: config)
                let positioned = try layout.layout(parsed)

                let result = compareLayout(swift: positioned, reference: refLayout)

                if result.success {
                    passCount += 1
                } else {
                    failCount += 1
                    failures.append((ref.title, result))
                }
            } catch {
                failCount += 1
                print("Parse error for '\(ref.title)': \(error)")
            }
        }

        // Print summary
        print("\n========== Layout Comparison Summary ==========")
        print("Passed: \(passCount)")
        print("Failed: \(failCount)")
        print("Skipped: \(skipCount)")
        print("Total: \(references.count)")

        if !failures.isEmpty {
            print("\n========== Failures ==========")
            for (title, result) in failures.prefix(10) {  // Show first 10 failures
                print("\n--- \(title) ---")
                if !result.nodeDiffs.isEmpty {
                    print("Node differences:")
                    for diff in result.nodeDiffs.prefix(5) {
                        print("  - \(diff)")
                    }
                }
                if !result.edgeDiffs.isEmpty {
                    print("Edge differences:")
                    for diff in result.edgeDiffs.prefix(5) {
                        print("  - \(diff)")
                    }
                }
                if let sizeDiff = result.sizeDiff {
                    print("Size difference: width=\(sizeDiff.width), height=\(sizeDiff.height)")
                }
            }
        }

        // Don't fail the test, just report
        // This is for investigation purposes
        print("\n==============================================\n")
    }

    /// Test a specific simple sample for debugging
    func testSimpleFlowComparison() throws {
        let source = """
        graph TD
          A[Start] --> B[Process] --> C[End]
        """

        let parsed = try MermaidParser.parse(source)
        var config = LayoutConfig()
        config.margin = 40
        config.direction = parsed.direction  // Use parsed direction from graph
        let layout = GraphLayout(config: config)
        let positioned = try layout.layout(parsed)

        print("\n=== Swift Layout for Simple Flow ===")
        print("Size: \(positioned.bounds.width) x \(positioned.bounds.height)")
        print("Nodes:")
        for node in positioned.nodes.sorted(by: { $0.id < $1.id }) {
            print("  \(node.id): pos=(\(Int(node.position.x)), \(Int(node.position.y))), size=\(Int(node.bounds.width))x\(Int(node.bounds.height))")
        }
        print("Edges:")
        for edge in positioned.edges {
            print("  \(edge.sourceId) -> \(edge.targetId): \(edge.points.count) points")
            for (i, pt) in edge.points.enumerated() {
                print("    [\(i)]: (\(Int(pt.x)), \(Int(pt.y)))")
            }
        }
    }

    /// Test the exact same state diagram as TypeScript gen-layout.ts
    func testStateDiagramMatchingTypeScript() throws {
        // This is the EXACT same diagram used in original/gen-layout.ts
        let source = """
        stateDiagram-v2
            direction LR
            [*] --> Input
            Input --> Parse: DSL
            Parse --> Layout: AST
            Layout --> SVG: Vector
            Layout --> ASCII: Text
            SVG --> Theme
            ASCII --> Theme
            Theme --> Output
            Output --> [*]
        """

        let parsed = try MermaidParser.parse(source)
        var config = LayoutConfig()
        config.margin = 40
        config.direction = parsed.direction
        let layout = GraphLayout(config: config)
        let positioned = try layout.layout(parsed)

        // Output in same format as TypeScript for easy comparison
        print("\n=== Swift Layout (compare with TypeScript gen-layout.ts output) ===")
        print("Nodes:")
        for node in positioned.nodes.sorted(by: { $0.id < $1.id }) {
            // Convert center to top-left (matching TypeScript output format)
            let topLeftX = node.position.x - node.size.width / 2
            let topLeftY = node.position.y - node.size.height / 2
            print("  \(node.id): pos=(\(topLeftX),\(topLeftY)), size=\(node.size.width)x\(node.size.height)")
        }
        print("\nEdges:")
        for edge in positioned.edges {
            print("  \(edge.sourceId)->\(edge.targetId): \(edge.points.count) points")
            for pt in edge.points {
                print("    (\(pt.x), \(pt.y))")
            }
        }

        // TypeScript reference values (from running gen-layout.ts):
        // Nodes:
        //   _start: pos=(40,70), size=60x36
        //   Input: pos=(140,70), size=67.75x36
        //   Parse: pos=(272.91,70), size=67.75x36
        //   Layout: pos=(405.82,70), size=74.9x36
        //   SVG: pos=(566.915,40), size=60x36
        //   ASCII: pos=(563.04,100), size=67.75x36
        //   Theme: pos=(670.79,70), size=67.75x36
        //   Output: pos=(778.54,70), size=74.9x36
        //   _end: pos=(893.44,70), size=60x36
        //
        // Edges (point counts):
        //   _start->Input: 2 points
        //   Input->Parse: 2 points
        //   Parse->Layout: 2 points
        //   Layout->SVG: 4 points (has bends)
        //   Layout->ASCII: 4 points (has bends)
        //   SVG->Theme: 3 points (L-bend)
        //   ASCII->Theme: 3 points (L-bend)
        //   Theme->Output: 2 points
        //   Output->_end: 2 points

        // Verify node count
        XCTAssertEqual(positioned.nodes.count, 9, "Should have 9 nodes")

        // Verify edge count
        XCTAssertEqual(positioned.edges.count, 9, "Should have 9 edges")

        // Verify edge structure - all edges should have at least 2 points (start and end)
        for edge in positioned.edges {
            XCTAssertGreaterThanOrEqual(edge.points.count, 2,
                "\(edge.sourceId)->\(edge.targetId) should have at least 2 points")
        }

        // Verify edges are orthogonal (each segment is horizontal or vertical)
        for edge in positioned.edges {
            for i in 1..<edge.points.count {
                let prev = edge.points[i - 1]
                let curr = edge.points[i]
                let isHorizontal = abs(curr.y - prev.y) < 1
                let isVertical = abs(curr.x - prev.x) < 1
                XCTAssertTrue(isHorizontal || isVertical,
                    "\(edge.sourceId)->\(edge.targetId) segment \(i) should be orthogonal")
            }
        }

        // Verify all edges start from source node and end at target node
        for edge in positioned.edges {
            guard let sourceNode = positioned.nodes.first(where: { $0.id == edge.sourceId }),
                  let targetNode = positioned.nodes.first(where: { $0.id == edge.targetId }) else {
                continue
            }

            let startPoint = edge.points.first!
            let endPoint = edge.points.last!

            // Start point should be within source node bounds (with tolerance for edge clipping)
            let sourceBounds = sourceNode.bounds.insetBy(dx: -5, dy: -5)
            XCTAssertTrue(sourceBounds.contains(startPoint) ||
                          abs(startPoint.x - sourceNode.position.x) <= sourceNode.size.width/2 + 5,
                "\(edge.sourceId)->\(edge.targetId) start should be at source node")

            // End point should be within target node bounds (with tolerance for edge clipping)
            let targetBounds = targetNode.bounds.insetBy(dx: -5, dy: -5)
            XCTAssertTrue(targetBounds.contains(endPoint) ||
                          abs(endPoint.x - targetNode.position.x) <= targetNode.size.width/2 + 5,
                "\(edge.sourceId)->\(edge.targetId) end should be at target node")
        }
    }
}
