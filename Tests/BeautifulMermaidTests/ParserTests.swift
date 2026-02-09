//
//  ParserTests.swift
//  BeautifulMermaidTests
//
//  Tests for Mermaid diagram parsing
//

import XCTest
@testable import BeautifulMermaid

final class ParserTests: XCTestCase {

    // MARK: - Flowchart Parser Tests

    func testBasicFlowchart() throws {
        let source = """
        graph TD
            A[Start] --> B[End]
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .flowchart)
        XCTAssertEqual(graph.direction, .topDown)
        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 1)

        XCTAssertNotNil(graph.nodes["A"])
        XCTAssertEqual(graph.nodes["A"]?.label, "Start")
        XCTAssertEqual(graph.nodes["A"]?.shape, .rectangle)

        XCTAssertNotNil(graph.nodes["B"])
        XCTAssertEqual(graph.nodes["B"]?.label, "End")
    }

    func testFlowchartWithMultipleNodes() throws {
        let source = """
        graph LR
            A[Start] --> B{Decision}
            B -->|Yes| C[Action]
            B -->|No| D[End]
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.direction, .leftRight)
        XCTAssertEqual(graph.nodes.count, 4)
        XCTAssertEqual(graph.edges.count, 3)

        XCTAssertEqual(graph.nodes["B"]?.shape, .diamond)
    }

    func testFlowchartShapes() throws {
        let source = """
        graph TD
            A[Rectangle]
            B(Rounded)
            C([Stadium])
            D((Circle))
            E{Diamond}
            F{{Hexagon}}
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.nodes["A"]?.shape, .rectangle)
        XCTAssertEqual(graph.nodes["B"]?.shape, .rounded)
        XCTAssertEqual(graph.nodes["C"]?.shape, .stadium)
        XCTAssertEqual(graph.nodes["D"]?.shape, .circle)
        XCTAssertEqual(graph.nodes["E"]?.shape, .diamond)
        XCTAssertEqual(graph.nodes["F"]?.shape, .hexagon)
    }

    func testFlowchartWithSubgraph() throws {
        let source = """
        graph TD
            subgraph Group1[My Group]
                A[Node A]
                B[Node B]
            end
            A --> B
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.subgraphs.count, 1)
        XCTAssertEqual(graph.subgraphs[0].label, "My Group")
        XCTAssertTrue(graph.subgraphs[0].nodeIds.contains("A"))
        XCTAssertTrue(graph.subgraphs[0].nodeIds.contains("B"))
    }

    func testFlowchartWithStyles() throws {
        let source = """
        graph TD
            A[Styled] --> B[Plain]
            classDef important fill:#f00,stroke:#333
            class A important
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertNotNil(graph.styleClasses["important"])
        XCTAssertEqual(graph.styleClasses["important"]?.fill, "#f00")
        XCTAssertEqual(graph.nodes["A"]?.styleClass, "important")
    }

    func testEdgeStyles() throws {
        let source = """
        graph TD
            A --> B
            B --- C
            C -.-> D
            D ==> E
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.edges.count, 4)
        XCTAssertEqual(graph.edges[0].style.targetArrow, .arrow)
        XCTAssertEqual(graph.edges[1].style.targetArrow, .none)
        XCTAssertEqual(graph.edges[2].style.lineStyle, .dotted)
        XCTAssertEqual(graph.edges[3].style.lineStyle, .thick)
    }

    func testEdgeLabels() throws {
        let source = """
        graph TD
            A -->|Label| B
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.edges[0].label, "Label")
    }

    func testChainedEdges() throws {
        let source = """
        graph TD
            A[Start] --> B[Process] --> C[End]
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.nodes.count, 3, "Should have 3 nodes")
        XCTAssertEqual(graph.edges.count, 2, "Should have 2 edges")

        XCTAssertNotNil(graph.nodes["A"])
        XCTAssertNotNil(graph.nodes["B"])
        XCTAssertNotNil(graph.nodes["C"])

        XCTAssertEqual(graph.nodes["A"]?.label, "Start")
        XCTAssertEqual(graph.nodes["B"]?.label, "Process")
        XCTAssertEqual(graph.nodes["C"]?.label, "End")

        // Check edges connect correctly
        let edge1 = graph.edges.first { $0.sourceId == "A" && $0.targetId == "B" }
        let edge2 = graph.edges.first { $0.sourceId == "B" && $0.targetId == "C" }

        XCTAssertNotNil(edge1, "Should have edge A -> B")
        XCTAssertNotNil(edge2, "Should have edge B -> C")
    }

    func testChainedEdgesWithLabels() throws {
        let source = """
        graph TD
            A -->|first| B -->|second| C
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertEqual(graph.edges.count, 2)

        let edge1 = graph.edges.first { $0.sourceId == "A" }
        let edge2 = graph.edges.first { $0.sourceId == "B" }

        XCTAssertEqual(edge1?.label, "first")
        XCTAssertEqual(edge2?.label, "second")
    }

    func testLongChainedEdges() throws {
        let source = """
        graph LR
            A --> B --> C --> D --> E
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.nodes.count, 5)
        XCTAssertEqual(graph.edges.count, 4)
    }

    // MARK: - Self-Loop Tests

    func testSelfLoop() throws {
        let source = """
        graph TD
            A[Node] --> A
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.nodes.count, 1)
        XCTAssertEqual(graph.edges.count, 1)

        let edge = graph.edges[0]
        XCTAssertEqual(edge.sourceId, "A")
        XCTAssertEqual(edge.targetId, "A", "Self-loop should have same source and target")
    }

    func testSelfLoopWithLabel() throws {
        let source = """
        graph TD
            A[Retry] -->|again| A
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.nodes.count, 1)
        XCTAssertEqual(graph.edges.count, 1)

        let edge = graph.edges[0]
        XCTAssertEqual(edge.sourceId, "A")
        XCTAssertEqual(edge.targetId, "A")
        XCTAssertEqual(edge.label, "again", "Self-loop label should be preserved")
    }

    func testMultipleSelfLoops() throws {
        let source = """
        graph TD
            A[Start] --> B[Validate]
            B -->|invalid| B
            B -->|valid| C[Process]
            C -->|retry| C
            C --> D[End]
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.nodes.count, 4)
        XCTAssertEqual(graph.edges.count, 5)

        // Check self-loop edges
        let selfLoopB = graph.edges.first { $0.sourceId == "B" && $0.targetId == "B" }
        let selfLoopC = graph.edges.first { $0.sourceId == "C" && $0.targetId == "C" }

        XCTAssertNotNil(selfLoopB, "Should have self-loop on B")
        XCTAssertNotNil(selfLoopC, "Should have self-loop on C")
        XCTAssertEqual(selfLoopB?.label, "invalid")
        XCTAssertEqual(selfLoopC?.label, "retry")
    }

    // MARK: - State Diagram Tests

    func testStateDiagram() throws {
        let source = """
        stateDiagram-v2
            [*] --> Active
            Active --> Inactive
            Inactive --> [*]
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .stateDiagram)
        XCTAssertTrue(graph.nodes.count >= 2)
    }

    // MARK: - Sequence Diagram Tests

    func testSequenceDiagram() throws {
        let source = """
        sequenceDiagram
            participant A as Alice
            participant B as Bob
            A->>B: Hello
            B-->>A: Hi there
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .sequenceDiagram)
        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.nodes["A"]?.label, "Alice")
        XCTAssertEqual(graph.edges.count, 2)
    }

    // MARK: - Class Diagram Tests

    func testClassDiagram() throws {
        let source = """
        classDiagram
            class Animal {
                +name: String
                +age: Int
                +makeSound()
            }
            class Dog
            Animal <|-- Dog
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .classDiagram)
        XCTAssertNotNil(graph.nodes["Animal"])
        XCTAssertNotNil(graph.nodes["Dog"])
    }

    // MARK: - ER Diagram Tests

    func testERDiagram() throws {
        let source = """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            ORDER ||--|{ LINE-ITEM : contains
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .erDiagram)
        XCTAssertTrue(graph.nodes.count >= 2)
    }

    // MARK: - Direction Tests

    func testDirections() throws {
        for (dirString, expected) in [("TD", Direction.topDown), ("TB", Direction.topToBottom),
                                       ("LR", Direction.leftRight), ("RL", Direction.rightLeft),
                                       ("BT", Direction.bottomToTop)] {
            let source = "graph \(dirString)\n    A --> B"
            let graph = try MermaidParser.parse(source)
            XCTAssertEqual(graph.direction.normalized, expected.normalized, "Failed for direction \(dirString)")
        }
    }

    // MARK: - Error Handling Tests

    func testEmptyInput() {
        XCTAssertThrowsError(try MermaidParser.parse(""))
    }

    func testUnknownDiagramType() {
        XCTAssertThrowsError(try MermaidParser.parse("unknownDiagram\n    A --> B"))
    }
}
