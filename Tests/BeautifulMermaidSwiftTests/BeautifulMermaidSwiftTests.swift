import XCTest
@testable import BeautifulMermaid

final class BeautifulMermaidSwiftTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(MermaidRenderer.version.isEmpty)
    }

    func testFlowSvgContainsNodes() throws {
        let svg = try renderMermaidSVG(
            """
            graph TD
              A[Start] --> B[End]
            """,
            RenderOptions()
        )
        XCTAssertTrue(svg.contains("class=\"node\""), "Expected flow SVG to include rendered nodes")
    }

    func testRenderImageForSimpleFlowIsNonNil() throws {
        let image = try MermaidRenderer.renderImage(
            source: """
            graph TD
              A[Start] --> B[End]
            """
        )
        XCTAssertNotNil(image, "Expected MermaidRenderer.renderImage to return a rasterizable image")
    }

    /// Reproduces crash in flow-15 (subgraph with direction override).
    func testFlow15SubgraphDirectionCrash() throws {
        let source = """
        graph TD
          subgraph pipeline [Processing Pipeline]
            direction LR
            A[Input] --> B[Parse] --> C[Transform] --> D[Output]
          end
          E[Source] --> A
          D --> F[Sink]
        """
        let svg = try renderMermaidSVG(source, RenderOptions())
        XCTAssertFalse(svg.isEmpty)
    }

    /// Reproduces LongEdgeJoiner crash on state-2-composite.
    func testState2CompositeCrash() throws {
        let source = """
        stateDiagram-v2
          [*] --> Idle
          Idle --> Processing : submit
          state Processing {
            parse --> validate
            validate --> execute
          }
          Processing --> Complete : done
          Processing --> Error : fail
          Error --> Idle : retry
          Complete --> [*]
        """
        let svg = try renderMermaidSVG(source, RenderOptions())
        XCTAssertFalse(svg.isEmpty)
    }

    func testFlow6EdgeStyles() throws {
        let source = "graph TD\n  A[Source] -->|solid| B[Target 1]\n  A -.->|dotted| C[Target 2]\n  A ==>|thick| D[Target 3]"
        let svg = try renderMermaidSVG(source, RenderOptions())
        XCTAssertFalse(svg.isEmpty)
    }

    func testFlow8BidirectionalEdgeLabels() throws {
        let source = "graph LR\n  A[Client] <-->|sync| B[Server]\n  B <-.->|heartbeat| C[Monitor]\n  C <==>|data| D[Storage]"
        let svg = try renderMermaidSVG(source, RenderOptions())
        XCTAssertFalse(svg.isEmpty)
    }

    func testSimpleTDNodeOrder() throws {
        let source = "graph TD\n  A[Start] --> B[End]"
        let pos = try MermaidRenderer.layout(source)
        let nodes = pos.flowchartNodes!
        let nodeA = nodes.first { $0.id == "A" }!
        let nodeB = nodes.first { $0.id == "B" }!
        XCTAssertLessThan(nodeA.y, nodeB.y, "In graph TD, source A should be above target B (lower y)")
    }

    func testSimpleBTNodeOrder() throws {
        let source = "graph BT\n  A[Foundation] --> B[Layer 2] --> C[Top]"
        let pos = try MermaidRenderer.layout(source)
        let nodes = pos.flowchartNodes!
        let nodeA = nodes.first { $0.id == "A" }!
        let nodeC = nodes.first { $0.id == "C" }!
        XCTAssertGreaterThan(nodeA.y, nodeC.y, "In graph BT, source A should be below target C (higher y)")
    }

    func testFlow14NestedSubgraphDebug() throws {
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
        let pos = try MermaidRenderer.layout(source)
        let nodes = pos.flowchartNodes!
        let edges = pos.flowchartEdges!
        let groups = pos.flowchartGroups!
        print("=== FLOW-14 DEBUG ===")
        print("  graphSize: \(pos.width) x \(pos.height)")
        for n in nodes { print("  Node \(n.id)(\(n.label)): x=\(n.x) y=\(n.y) w=\(n.width) h=\(n.height)") }
        for e in edges { print("  Edge \(e.source)->\(e.target) pts=\(e.points.map { "(\(Int($0.x)),\(Int($0.y)))" })") }
        func printGroups(_ gs: [_PositionedGroupPayload], indent: String = "  ") {
            for g in gs {
                print("\(indent)Group \(g.id)(\(g.label)): x=\(g.x) y=\(g.y) w=\(g.width) h=\(g.height)")
                printGroups(g.children, indent: indent + "  ")
            }
        }
        printGroups(groups)
    }

    func testFlow6PortOrderDebug() throws {
        // Test as graph TD (has GraphTransformer rotation)
        let sourceTD = "graph TD\n  A[Source] -->|solid| B[Target 1]\n  A -.->|dotted| C[Target 2]\n  A ==>|thick| D[Target 3]"
        let posTD = try MermaidRenderer.layout(sourceTD)
        let nodesTD = posTD.flowchartNodes!
        let edgesTD = posTD.flowchartEdges!
        print("=== FLOW-6 TD ===")
        for n in nodesTD { print("  Node \(n.label): x=\(n.x) y=\(n.y) w=\(n.width) h=\(n.height)") }
        for e in edgesTD {
            let lp = e.labelPosition.map { "(\($0.x),\($0.y))" } ?? "nil"
            print("  Edge \(e.source)->\(e.target) label=\(e.label ?? "nil") labelPos=\(lp) pts=\(e.points.map { "(\(Int($0.x)),\(Int($0.y)))" })")
        }

        // Test as graph LR (no rotation)
        let sourceLR = "graph LR\n  A[Source] -->|solid| B[Target 1]\n  A -.->|dotted| C[Target 2]\n  A ==>|thick| D[Target 3]"
        let posLR = try MermaidRenderer.layout(sourceLR)
        let nodesLR = posLR.flowchartNodes!
        let edgesLR = posLR.flowchartEdges!
        print("=== FLOW-6 LR ===")
        for n in nodesLR { print("  Node \(n.label): x=\(n.x) y=\(n.y)") }
        for e in edgesLR {
            let lp = e.labelPosition.map { "(\($0.x),\($0.y))" } ?? "nil"
            print("  Edge \(e.source)->\(e.target) label=\(e.label ?? "nil") labelPos=\(lp) pts=\(e.points.map { "(\(Int($0.x)),\(Int($0.y)))" })")
        }
    }
}
