//
//  FeatureTests.swift
//  BeautifulMermaidTests
//
//  Comprehensive tests for all diagram features matching SampleDiagrams.swift
//

import XCTest
@testable import BeautifulMermaid

final class FeatureTests: XCTestCase {

    // MARK: - Flowchart: Basic

    func testFlowchartBasic() throws {
        let source = """
        graph TD
            A[Start] --> B{Is it working?}
            B -->|Yes| C[Great!]
            B -->|No| D[Debug]
            D --> B
            C --> E[Ship it!]
        """

        let graph = try MermaidParser.parse(source)

        // Verify structure
        XCTAssertEqual(graph.type, .flowchart)
        XCTAssertEqual(graph.direction, .topDown)
        XCTAssertEqual(graph.nodes.count, 5, "Should have 5 nodes: A, B, C, D, E")
        XCTAssertEqual(graph.edges.count, 5, "Should have 5 edges")

        // Verify node shapes
        XCTAssertEqual(graph.nodes["A"]?.shape, .rectangle)
        XCTAssertEqual(graph.nodes["B"]?.shape, .diamond)
        XCTAssertEqual(graph.nodes["C"]?.shape, .rectangle)
        XCTAssertEqual(graph.nodes["D"]?.shape, .rectangle)
        XCTAssertEqual(graph.nodes["E"]?.shape, .rectangle)

        // Verify labels
        XCTAssertEqual(graph.nodes["A"]?.label, "Start")
        XCTAssertEqual(graph.nodes["B"]?.label, "Is it working?")
        XCTAssertEqual(graph.nodes["E"]?.label, "Ship it!")

        // Verify edge labels
        let yesEdge = graph.edges.first { $0.label == "Yes" }
        let noEdge = graph.edges.first { $0.label == "No" }
        XCTAssertNotNil(yesEdge, "Should have edge with 'Yes' label")
        XCTAssertNotNil(noEdge, "Should have edge with 'No' label")
        XCTAssertEqual(yesEdge?.sourceId, "B")
        XCTAssertEqual(yesEdge?.targetId, "C")
        XCTAssertEqual(noEdge?.sourceId, "B")
        XCTAssertEqual(noEdge?.targetId, "D")

        // Verify cycle edge (D --> B)
        let cycleEdge = graph.edges.first { $0.sourceId == "D" && $0.targetId == "B" }
        XCTAssertNotNil(cycleEdge, "Should have cycle edge D -> B")
    }

    // MARK: - Flowchart: Complex

    func testFlowchartComplex() throws {
        let source = """
        graph TD
            A[Client] --> B[Load Balancer]
            B --> C[Server 1]
            B --> D[Server 2]
            B --> E[Server 3]

            subgraph Servers[Server Cluster]
                C --> F[(Database)]
                D --> F
                E --> F
            end

            F --> G[Cache]
            G --> C
            G --> D
            G --> E
        """

        let graph = try MermaidParser.parse(source)

        // Verify nodes
        XCTAssertEqual(graph.nodes.count, 7, "Should have 7 nodes: A, B, C, D, E, F, G")

        // Verify database shape
        XCTAssertEqual(graph.nodes["F"]?.shape, .cylinder, "Database should be cylinder shape")
        XCTAssertEqual(graph.nodes["F"]?.label, "Database")

        // Verify fan-out from Load Balancer
        let lbEdges = graph.edges.filter { $0.sourceId == "B" }
        XCTAssertEqual(lbEdges.count, 3, "Load Balancer should have 3 outgoing edges")

        // Verify fan-in to Database
        let dbEdges = graph.edges.filter { $0.targetId == "F" }
        XCTAssertEqual(dbEdges.count, 3, "Database should have 3 incoming edges")

        // Verify subgraph
        XCTAssertEqual(graph.subgraphs.count, 1)
        XCTAssertEqual(graph.subgraphs[0].label, "Server Cluster")
        XCTAssertTrue(graph.subgraphs[0].nodeIds.contains("C"))
        XCTAssertTrue(graph.subgraphs[0].nodeIds.contains("D"))
        XCTAssertTrue(graph.subgraphs[0].nodeIds.contains("E"))
        XCTAssertTrue(graph.subgraphs[0].nodeIds.contains("F"))
    }

    // MARK: - Flowchart: Infrastructure (Nested Subgraphs)

    func testFlowchartInfrastructure() throws {
        let source = """
        graph TD
            LB([Load Balancer])

            LB --> WS1
            LB --> WS2

            subgraph Cloud
                subgraph USEast[US East Region]
                    WS1[Web Server] --> AS1[App Server]
                end

                subgraph USWest[US West Region]
                    WS2[Web Server] --> AS2[App Server]
                end
            end
        """

        let graph = try MermaidParser.parse(source)

        // Verify Load Balancer is stadium shape
        XCTAssertEqual(graph.nodes["LB"]?.shape, .stadium)
        XCTAssertEqual(graph.nodes["LB"]?.label, "Load Balancer")

        // Verify nodes
        XCTAssertNotNil(graph.nodes["WS1"])
        XCTAssertNotNil(graph.nodes["WS2"])
        XCTAssertNotNil(graph.nodes["AS1"])
        XCTAssertNotNil(graph.nodes["AS2"])

        // Verify nested subgraph structure
        XCTAssertEqual(graph.subgraphs.count, 1, "Should have 1 top-level subgraph (Cloud)")
        let cloudSubgraph = graph.subgraphs[0]
        XCTAssertEqual(cloudSubgraph.id, "Cloud")
        XCTAssertEqual(cloudSubgraph.children.count, 2, "Cloud should have 2 child subgraphs")

        // Verify nested subgraph labels
        let childLabels = Set(cloudSubgraph.children.map { $0.label })
        XCTAssertTrue(childLabels.contains("US East Region"))
        XCTAssertTrue(childLabels.contains("US West Region"))

        // Verify nodes are in correct nested subgraphs
        let usEast = cloudSubgraph.children.first { $0.label == "US East Region" }
        let usWest = cloudSubgraph.children.first { $0.label == "US West Region" }

        XCTAssertTrue(usEast?.nodeIds.contains("WS1") == true)
        XCTAssertTrue(usEast?.nodeIds.contains("AS1") == true)
        XCTAssertTrue(usWest?.nodeIds.contains("WS2") == true)
        XCTAssertTrue(usWest?.nodeIds.contains("AS2") == true)
    }

    // MARK: - Flowchart: All Shapes

    func testFlowchartAllShapes() throws {
        let source = """
        graph LR
            A[Rectangle]
            B(Rounded)
            C([Stadium])
            D((Circle))
            E{Diamond}
            F{{Hexagon}}
            G[(Database)]
            H[[Subroutine]]

            A --> B --> C --> D
            E --> F --> G --> H
        """

        let graph = try MermaidParser.parse(source)

        // Verify all shapes
        XCTAssertEqual(graph.nodes["A"]?.shape, .rectangle, "A should be rectangle")
        XCTAssertEqual(graph.nodes["B"]?.shape, .rounded, "B should be rounded")
        XCTAssertEqual(graph.nodes["C"]?.shape, .stadium, "C should be stadium")
        XCTAssertEqual(graph.nodes["D"]?.shape, .circle, "D should be circle")
        XCTAssertEqual(graph.nodes["E"]?.shape, .diamond, "E should be diamond")
        XCTAssertEqual(graph.nodes["F"]?.shape, .hexagon, "F should be hexagon")
        XCTAssertEqual(graph.nodes["G"]?.shape, .cylinder, "G should be cylinder/database")
        XCTAssertEqual(graph.nodes["H"]?.shape, .subroutine, "H should be subroutine")

        // Verify labels match shape names
        XCTAssertEqual(graph.nodes["A"]?.label, "Rectangle")
        XCTAssertEqual(graph.nodes["D"]?.label, "Circle")
        XCTAssertEqual(graph.nodes["F"]?.label, "Hexagon")

        // Verify LR direction
        XCTAssertEqual(graph.direction, .leftRight)
    }

    // MARK: - Flowchart: Styles

    func testFlowchartStyles() throws {
        let source = """
        graph TD
            A[Normal] --> B[Styled]
            B --> C[Highlighted]

            classDef important fill:#f96,stroke:#333,stroke-width:2px
            classDef highlighted fill:#9cf,stroke:#06c

            class B important
            class C highlighted
        """

        let graph = try MermaidParser.parse(source)

        // Verify classDef definitions
        XCTAssertNotNil(graph.styleClasses["important"])
        XCTAssertNotNil(graph.styleClasses["highlighted"])

        // Verify important class properties
        XCTAssertEqual(graph.styleClasses["important"]?.fill, "#f96")
        XCTAssertEqual(graph.styleClasses["important"]?.stroke, "#333")
        XCTAssertEqual(graph.styleClasses["important"]?.strokeWidth, "2px")

        // Verify highlighted class properties
        XCTAssertEqual(graph.styleClasses["highlighted"]?.fill, "#9cf")
        XCTAssertEqual(graph.styleClasses["highlighted"]?.stroke, "#06c")

        // Verify class assignments
        XCTAssertNil(graph.nodes["A"]?.styleClass, "A should have no style class")
        XCTAssertEqual(graph.nodes["B"]?.styleClass, "important")
        XCTAssertEqual(graph.nodes["C"]?.styleClass, "highlighted")
    }

    // MARK: - State Diagram: Basic

    func testStateDiagramBasic() throws {
        let source = """
        stateDiagram-v2
            [*] --> Idle
            Idle --> Processing : Start
            Processing --> Completed : Success
            Processing --> Failed : Error
            Failed --> Idle : Retry
            Completed --> [*]
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .stateDiagram)

        // Verify states exist
        XCTAssertNotNil(graph.nodes["Idle"])
        XCTAssertNotNil(graph.nodes["Processing"])
        XCTAssertNotNil(graph.nodes["Completed"])
        XCTAssertNotNil(graph.nodes["Failed"])

        // Verify transitions with labels
        let startTransition = graph.edges.first { $0.label == "Start" }
        XCTAssertNotNil(startTransition)
        XCTAssertEqual(startTransition?.sourceId, "Idle")
        XCTAssertEqual(startTransition?.targetId, "Processing")

        let successTransition = graph.edges.first { $0.label == "Success" }
        XCTAssertNotNil(successTransition)
        XCTAssertEqual(successTransition?.sourceId, "Processing")
        XCTAssertEqual(successTransition?.targetId, "Completed")

        let retryTransition = graph.edges.first { $0.label == "Retry" }
        XCTAssertNotNil(retryTransition)
        XCTAssertEqual(retryTransition?.sourceId, "Failed")
        XCTAssertEqual(retryTransition?.targetId, "Idle")
    }

    // MARK: - State Diagram: Nested

    func testStateDiagramNested() throws {
        let source = """
        stateDiagram-v2
            [*] --> Active

            state Active {
                [*] --> Running
                Running --> Paused : Pause
                Paused --> Running : Resume
                Running --> [*] : Stop
            }

            Active --> Finished : Complete
            Finished --> [*]
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .stateDiagram)

        // Verify main states
        XCTAssertNotNil(graph.nodes["Active"])
        XCTAssertNotNil(graph.nodes["Finished"])

        // Verify nested states exist
        XCTAssertNotNil(graph.nodes["Running"])
        XCTAssertNotNil(graph.nodes["Paused"])

        // Verify nested transitions
        let pauseTransition = graph.edges.first { $0.label == "Pause" }
        XCTAssertNotNil(pauseTransition)
        XCTAssertEqual(pauseTransition?.sourceId, "Running")
        XCTAssertEqual(pauseTransition?.targetId, "Paused")

        let resumeTransition = graph.edges.first { $0.label == "Resume" }
        XCTAssertNotNil(resumeTransition)
        XCTAssertEqual(resumeTransition?.sourceId, "Paused")
        XCTAssertEqual(resumeTransition?.targetId, "Running")
    }

    // MARK: - Sequence Diagram: Basic

    func testSequenceDiagramBasic() throws {
        let source = """
        sequenceDiagram
            participant A as Alice
            participant B as Bob
            participant C as Charlie

            A->>B: Hello Bob!
            B-->>A: Hi Alice!
            A->>C: Hey Charlie
            C->>B: Bob, did you hear?
            B-->>C: Yes, I did!
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .sequenceDiagram)

        // Verify participants
        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertEqual(graph.nodes["A"]?.label, "Alice")
        XCTAssertEqual(graph.nodes["B"]?.label, "Bob")
        XCTAssertEqual(graph.nodes["C"]?.label, "Charlie")

        // Verify messages
        XCTAssertEqual(graph.edges.count, 5)

        let firstMessage = graph.edges.first { $0.label == "Hello Bob!" }
        XCTAssertNotNil(firstMessage)
        XCTAssertEqual(firstMessage?.sourceId, "A")
        XCTAssertEqual(firstMessage?.targetId, "B")

        // Verify dashed reply
        let reply = graph.edges.first { $0.label == "Hi Alice!" }
        XCTAssertNotNil(reply)
        XCTAssertEqual(reply?.sourceId, "B")
        XCTAssertEqual(reply?.targetId, "A")
        XCTAssertEqual(reply?.style.lineStyle, .dotted)
    }

    // MARK: - Sequence Diagram: Auth Flow

    func testSequenceDiagramAuthFlow() throws {
        let source = """
        sequenceDiagram
            participant U as User
            participant C as Client
            participant S as Server
            participant D as Database

            U->>C: Login Request
            C->>S: POST /auth
            S->>D: Query User
            D-->>S: User Data
            S-->>C: JWT Token
            C-->>U: Login Success
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .sequenceDiagram)

        // Verify participants
        XCTAssertEqual(graph.nodes.count, 4)
        XCTAssertEqual(graph.nodes["U"]?.label, "User")
        XCTAssertEqual(graph.nodes["C"]?.label, "Client")
        XCTAssertEqual(graph.nodes["S"]?.label, "Server")
        XCTAssertEqual(graph.nodes["D"]?.label, "Database")

        // Verify messages
        XCTAssertEqual(graph.edges.count, 6)

        // Verify flow order through messages
        let loginRequest = graph.edges.first { $0.label == "Login Request" }
        let postAuth = graph.edges.first { $0.label == "POST /auth" }
        let queryUser = graph.edges.first { $0.label == "Query User" }
        let userData = graph.edges.first { $0.label == "User Data" }
        let jwtToken = graph.edges.first { $0.label == "JWT Token" }
        let loginSuccess = graph.edges.first { $0.label == "Login Success" }

        XCTAssertNotNil(loginRequest)
        XCTAssertNotNil(postAuth)
        XCTAssertNotNil(queryUser)
        XCTAssertNotNil(userData)
        XCTAssertNotNil(jwtToken)
        XCTAssertNotNil(loginSuccess)

        // Verify request/response patterns
        XCTAssertEqual(loginRequest?.style.lineStyle, .solid)
        XCTAssertEqual(userData?.style.lineStyle, .dotted)
        XCTAssertEqual(jwtToken?.style.lineStyle, .dotted)
    }

    // MARK: - Class Diagram: Hierarchy

    func testClassDiagramHierarchy() throws {
        let source = """
        classDiagram
            class Animal {
                +String name
                +int age
                +makeSound()
            }

            class Dog {
                +String breed
                +bark()
            }

            class Cat {
                +int lives
                +meow()
            }

            Animal <|-- Dog
            Animal <|-- Cat
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .classDiagram)

        // Verify classes exist
        XCTAssertNotNil(graph.nodes["Animal"])
        XCTAssertNotNil(graph.nodes["Dog"])
        XCTAssertNotNil(graph.nodes["Cat"])

        // Verify inheritance relationships
        XCTAssertEqual(graph.edges.count, 2)

        let dogInheritance = graph.edges.first {
            ($0.sourceId == "Animal" && $0.targetId == "Dog") ||
            ($0.sourceId == "Dog" && $0.targetId == "Animal")
        }
        XCTAssertNotNil(dogInheritance, "Should have Dog inherits from Animal")

        let catInheritance = graph.edges.first {
            ($0.sourceId == "Animal" && $0.targetId == "Cat") ||
            ($0.sourceId == "Cat" && $0.targetId == "Animal")
        }
        XCTAssertNotNil(catInheritance, "Should have Cat inherits from Animal")
    }

    // MARK: - Class Diagram: Relations with Cardinality

    func testClassDiagramRelations() throws {
        let source = """
        classDiagram
            class Order {
                +int orderId
                +Date orderDate
                +calculateTotal()
            }

            class Customer {
                +String name
                +String email
            }

            class Product {
                +String name
                +float price
            }

            class LineItem {
                +int quantity
            }

            Customer "1" --> "*" Order : places
            Order "1" --> "*" LineItem : contains
            LineItem "*" --> "1" Product : refers to
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .classDiagram)

        // Verify all classes
        XCTAssertNotNil(graph.nodes["Order"])
        XCTAssertNotNil(graph.nodes["Customer"])
        XCTAssertNotNil(graph.nodes["Product"])
        XCTAssertNotNil(graph.nodes["LineItem"])

        // Verify relationships
        XCTAssertEqual(graph.edges.count, 3)

        // Verify labeled relationships
        // Note: Swift ClassParser combines multiplicity with label (e.g., "1..* places")
        let placesEdge = graph.edges.first { $0.label?.contains("places") == true }
        let containsEdge = graph.edges.first { $0.label?.contains("contains") == true }
        let refersToEdge = graph.edges.first { $0.label?.contains("refers to") == true }

        XCTAssertNotNil(placesEdge)
        XCTAssertNotNil(containsEdge)
        XCTAssertNotNil(refersToEdge)
    }

    // MARK: - ER Diagram

    func testERDiagram() throws {
        let source = """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            ORDER ||--|{ LINE-ITEM : contains
            PRODUCT ||--o{ LINE-ITEM : includes
            CUSTOMER {
                string name
                string email
            }
            ORDER {
                int orderNumber
                date orderDate
            }
        """

        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .erDiagram)

        // Verify entities
        XCTAssertNotNil(graph.nodes["CUSTOMER"])
        XCTAssertNotNil(graph.nodes["ORDER"])
        XCTAssertNotNil(graph.nodes["LINE-ITEM"])
        XCTAssertNotNil(graph.nodes["PRODUCT"])

        // Verify relationships
        XCTAssertGreaterThanOrEqual(graph.edges.count, 3)

        // Verify labeled relationships
        // Note: Swift parser may combine cardinality with label
        let placesEdge = graph.edges.first { $0.label?.contains("places") == true }
        let containsEdge = graph.edges.first { $0.label?.contains("contains") == true }
        let includesEdge = graph.edges.first { $0.label?.contains("includes") == true }

        XCTAssertNotNil(placesEdge)
        XCTAssertNotNil(containsEdge)
        XCTAssertNotNil(includesEdge)
    }

    // MARK: - Edge Styles

    func testAllEdgeStyles() throws {
        let source = """
        graph TD
            A --> B
            B --- C
            C -.-> D
            D -.- E
            E ==> F
            F === G
        """

        let graph = try MermaidParser.parse(source)

        // Solid arrow
        let solidArrow = graph.edges.first { $0.sourceId == "A" }
        XCTAssertEqual(solidArrow?.style.lineStyle, .solid)
        XCTAssertEqual(solidArrow?.style.targetArrow, .arrow)

        // Solid line (no arrow)
        let solidLine = graph.edges.first { $0.sourceId == "B" }
        XCTAssertEqual(solidLine?.style.lineStyle, .solid)
        XCTAssertEqual(solidLine?.style.targetArrow, ArrowHead.none)

        // Dotted arrow
        let dottedArrow = graph.edges.first { $0.sourceId == "C" }
        XCTAssertEqual(dottedArrow?.style.lineStyle, .dotted)
        XCTAssertEqual(dottedArrow?.style.targetArrow, .arrow)

        // Dotted line (no arrow)
        let dottedLine = graph.edges.first { $0.sourceId == "D" }
        XCTAssertEqual(dottedLine?.style.lineStyle, .dotted)
        XCTAssertEqual(dottedLine?.style.targetArrow, ArrowHead.none)

        // Thick arrow
        let thickArrow = graph.edges.first { $0.sourceId == "E" }
        XCTAssertEqual(thickArrow?.style.lineStyle, .thick)
        XCTAssertEqual(thickArrow?.style.targetArrow, .arrow)

        // Thick line (no arrow)
        let thickLine = graph.edges.first { $0.sourceId == "F" }
        XCTAssertEqual(thickLine?.style.lineStyle, .thick)
        XCTAssertEqual(thickLine?.style.targetArrow, ArrowHead.none)
    }

    // MARK: - Direction Variants

    func testAllDirections() throws {
        let directions: [(String, Direction)] = [
            ("TD", .topDown),
            ("TB", .topToBottom),
            ("BT", .bottomToTop),
            ("LR", .leftRight),
            ("RL", .rightLeft)
        ]

        for (dirStr, expectedDir) in directions {
            let source = "graph \(dirStr)\n    A --> B"
            let graph = try MermaidParser.parse(source)
            XCTAssertEqual(
                graph.direction.normalized,
                expectedDir.normalized,
                "Direction \(dirStr) should parse correctly"
            )
        }
    }

    // MARK: - Parallel Links (Ampersand Syntax)

    func testParallelLinks() throws {
        let source = """
        graph TD
            A & B --> C & D
        """

        let graph = try MermaidParser.parse(source)

        // Should create 4 edges: A->C, A->D, B->C, B->D
        XCTAssertEqual(graph.edges.count, 4, "Should have 4 edges from cartesian product")

        // Verify all combinations exist
        let hasAtoC = graph.edges.contains { $0.sourceId == "A" && $0.targetId == "C" }
        let hasAtoD = graph.edges.contains { $0.sourceId == "A" && $0.targetId == "D" }
        let hasBtoC = graph.edges.contains { $0.sourceId == "B" && $0.targetId == "C" }
        let hasBtoD = graph.edges.contains { $0.sourceId == "B" && $0.targetId == "D" }

        XCTAssertTrue(hasAtoC, "Should have edge A -> C")
        XCTAssertTrue(hasAtoD, "Should have edge A -> D")
        XCTAssertTrue(hasBtoC, "Should have edge B -> C")
        XCTAssertTrue(hasBtoD, "Should have edge B -> D")
    }

    // MARK: - Layout Tests for Features

    func testFlowchartLayoutRendering() throws {
        let source = """
        graph TD
            A[Start] --> B{Is it working?}
            B -->|Yes| C[Great!]
            B -->|No| D[Debug]
            D --> B
            C --> E[Ship it!]
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        // Verify all nodes have positions
        XCTAssertEqual(positioned.nodes.count, 5)
        for node in positioned.nodes {
            XCTAssertGreaterThan(node.size.width, 0, "Node \(node.id) should have width")
            XCTAssertGreaterThan(node.size.height, 0, "Node \(node.id) should have height")
        }

        // Verify all edges have points
        XCTAssertEqual(positioned.edges.count, 5)
        for edge in positioned.edges {
            XCTAssertGreaterThanOrEqual(edge.points.count, 2,
                "Edge \(edge.sourceId)->\(edge.targetId) should have at least 2 points")
        }

        // Verify TD layout: A should be above B
        let nodeA = positioned.nodes.first { $0.id == "A" }!
        let nodeB = positioned.nodes.first { $0.id == "B" }!
        XCTAssertLessThan(nodeA.position.y, nodeB.position.y, "A should be above B in TD layout")
    }

    func testNestedSubgraphLayoutRendering() throws {
        let source = """
        graph TD
            LB([Load Balancer])

            LB --> WS1
            LB --> WS2

            subgraph Cloud
                subgraph USEast[US East Region]
                    WS1[Web Server] --> AS1[App Server]
                end

                subgraph USWest[US West Region]
                    WS2[Web Server] --> AS2[App Server]
                end
            end
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        // Verify subgraph structure in positioned graph
        XCTAssertEqual(positioned.subgraphs.count, 1, "Should have 1 top-level subgraph")
        let cloud = positioned.subgraphs[0]
        XCTAssertEqual(cloud.children.count, 2, "Cloud should have 2 nested subgraphs")

        // Verify subgraph bounds are valid
        XCTAssertGreaterThan(cloud.bounds.width, 0, "Cloud should have width")
        XCTAssertGreaterThan(cloud.bounds.height, 0, "Cloud should have height")

        for child in cloud.children {
            XCTAssertGreaterThan(child.bounds.width, 0, "\(child.label) should have width")
            XCTAssertGreaterThan(child.bounds.height, 0, "\(child.label) should have height")
        }

        // Verify Load Balancer is above the Cloud subgraph's content area
        // (contentTop is bounds.minY + headerHeight, representing where actual content starts)
        let lb = positioned.nodes.first { $0.id == "LB" }!
        XCTAssertLessThan(lb.position.y, cloud.contentTop,
            "Load Balancer should be above Cloud subgraph content")
    }

    func testSubgraphDirectionOverride() throws {
        // Tests TODO 6: Subgraph direction overrides
        // The main graph is TD but the subgraph uses direction LR
        let source = """
        graph TD
          subgraph pipeline [Processing Pipeline]
            direction LR
            A[Input] --> B[Parse] --> C[Transform] --> D[Output]
          end
          E[Source] --> A
          D --> F[Sink]
        """

        let graph = try MermaidParser.parse(source)

        // Verify the subgraph has a direction override
        XCTAssertEqual(graph.subgraphs.count, 1)
        let pipeline = graph.subgraphs[0]
        XCTAssertEqual(pipeline.label, "Processing Pipeline")
        XCTAssertEqual(pipeline.direction, .leftRight, "Subgraph should have LR direction override")
        XCTAssertEqual(graph.direction, .topDown, "Main graph should be TD")

        // Layout the graph
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        // Get the nodes inside the subgraph
        let nodeA = positioned.nodes.first { $0.id == "A" }!
        let nodeB = positioned.nodes.first { $0.id == "B" }!
        let nodeC = positioned.nodes.first { $0.id == "C" }!
        let nodeD = positioned.nodes.first { $0.id == "D" }!
        let nodeE = positioned.nodes.first { $0.id == "E" }!
        let nodeF = positioned.nodes.first { $0.id == "F" }!

        // Verify the subgraph nodes are laid out horizontally (LR)
        // A should be left of B, B left of C, C left of D
        XCTAssertLessThan(nodeA.position.x, nodeB.position.x,
            "A should be left of B in LR subgraph")
        XCTAssertLessThan(nodeB.position.x, nodeC.position.x,
            "B should be left of C in LR subgraph")
        XCTAssertLessThan(nodeC.position.x, nodeD.position.x,
            "C should be left of D in LR subgraph")

        // The nodes should be roughly at the same Y position (horizontal line)
        let yTolerance: CGFloat = 10.0
        XCTAssertEqual(nodeA.position.y, nodeB.position.y, accuracy: yTolerance,
            "A and B should be at similar Y in LR layout")
        XCTAssertEqual(nodeB.position.y, nodeC.position.y, accuracy: yTolerance,
            "B and C should be at similar Y in LR layout")
        XCTAssertEqual(nodeC.position.y, nodeD.position.y, accuracy: yTolerance,
            "C and D should be at similar Y in LR layout")

        // Verify the external nodes (E and F) follow TD layout
        // E (Source) should be above the pipeline
        // F (Sink) should be below the pipeline
        XCTAssertLessThan(nodeE.position.y, nodeA.position.y,
            "E (Source) should be above the pipeline nodes")
        XCTAssertGreaterThan(nodeF.position.y, nodeD.position.y,
            "F (Sink) should be below the pipeline nodes")

        // Verify the subgraph has bounds
        let pipelineSubgraph = positioned.subgraphs.first { $0.id == "pipeline" }!
        XCTAssertGreaterThan(pipelineSubgraph.bounds.width, 0, "Pipeline should have width")
        XCTAssertGreaterThan(pipelineSubgraph.bounds.height, 0, "Pipeline should have height")

        print("Subgraph Direction Override test:")
        print("  Nodes A, B, C, D Y positions: \(nodeA.position.y), \(nodeB.position.y), \(nodeC.position.y), \(nodeD.position.y)")
        print("  Nodes A, B, C, D X positions: \(nodeA.position.x), \(nodeB.position.x), \(nodeC.position.x), \(nodeD.position.x)")
        print("  Node E (Source) Y: \(nodeE.position.y)")
        print("  Node F (Sink) Y: \(nodeF.position.y)")
        print("  Pipeline bounds: \(pipelineSubgraph.bounds)")
    }

    func testAllShapesLayoutRendering() throws {
        let source = """
        graph LR
            A[Rectangle]
            B(Rounded)
            C([Stadium])
            D((Circle))
            E{Diamond}
            F{{Hexagon}}
            G[(Database)]
            H[[Subroutine]]

            A --> B --> C --> D
            E --> F --> G --> H
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        // Verify all shapes have valid sizes
        for node in positioned.nodes {
            XCTAssertGreaterThan(node.size.width, 0, "\(node.id) should have width")
            XCTAssertGreaterThan(node.size.height, 0, "\(node.id) should have height")

            // Verify circle and stadium have appropriate aspect ratios
            if node.shape == .circle {
                let aspectRatio = node.size.width / node.size.height
                XCTAssertEqual(aspectRatio, 1.0, accuracy: 0.1,
                    "Circle should have 1:1 aspect ratio")
            }
        }

        // Verify LR layout: X positions increase left to right
        let nodeA = positioned.nodes.first { $0.id == "A" }!
        let nodeD = positioned.nodes.first { $0.id == "D" }!
        XCTAssertLessThan(nodeA.position.x, nodeD.position.x, "A should be left of D in LR layout")
    }

    // MARK: - Rendering Tests

    func testImageRendering() throws {
        let source = """
        graph TD
            A[Start] --> B[End]
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        let renderer = DiagramRenderer(theme: .default)
        let image = renderer.renderToImage(positioned, scale: 2.0)

        XCTAssertNotNil(image, "Should render to image")
        XCTAssertGreaterThan(image?.size.width ?? 0, 0, "Image should have width")
        XCTAssertGreaterThan(image?.size.height ?? 0, 0, "Image should have height")
    }

    func testThemedRendering() throws {
        let source = """
        graph TD
            A[Start] --> B[End]
        """

        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        // Test with different themes
        let themes: [DiagramTheme] = [.default, .zincDark, .nord]

        for theme in themes {
            let renderer = DiagramRenderer(theme: theme)
            let image = renderer.renderToImage(positioned, scale: 1.0)
            XCTAssertNotNil(image, "Should render with \(theme) theme")
        }
    }
}
