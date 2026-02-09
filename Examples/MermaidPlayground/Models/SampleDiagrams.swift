//
//  SampleDiagrams.swift
//  MermaidPlayground
//
//  Sample Mermaid diagrams for testing
//

import Foundation

/// Collection of sample diagrams
public struct SampleDiagrams {

    // MARK: - Flowcharts

    public static let flowchart = """
    graph TD
        A[Start] --> B{Is it working?}
        B -->|Yes| C[Great!]
        B -->|No| D[Debug]
        D --> B
        C --> E[Ship it!]
    """

    public static let flowchartComplex = """
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

    public static let infrastructure = """
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

    public static let flowchartShapes = """
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

    public static let flowchartStyles = """
    graph TD
        A[Normal] --> B[Styled]
        B --> C[Highlighted]

        classDef important fill:#f96,stroke:#333,stroke-width:2px
        classDef highlighted fill:#9cf,stroke:#06c

        class B important
        class C highlighted
    """

    // MARK: - State Diagrams

    public static let stateDiagram = """
    stateDiagram-v2
        [*] --> Idle
        Idle --> Processing : Start
        Processing --> Completed : Success
        Processing --> Failed : Error
        Failed --> Idle : Retry
        Completed --> [*]
    """

    public static let stateDiagramNested = """
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

    // MARK: - Sequence Diagrams

    public static let sequenceDiagram = """
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

    public static let sequenceDiagramAuth = """
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

    // MARK: - Class Diagrams

    public static let classDiagram = """
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

    public static let classDiagramRelations = """
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

    // MARK: - ER Diagrams

    public static let erDiagram = """
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

    // MARK: - All Samples

    public static let allSamples: [(name: String, category: String, source: String)] = [
        ("Basic Flowchart", "Flowchart", flowchart),
        ("Complex Flowchart", "Flowchart", flowchartComplex),
        ("Infrastructure", "Flowchart", infrastructure),
        ("All Shapes", "Flowchart", flowchartShapes),
        ("Styled Flowchart", "Flowchart", flowchartStyles),
        ("State Machine", "State", stateDiagram),
        ("Nested States", "State", stateDiagramNested),
        ("Basic Sequence", "Sequence", sequenceDiagram),
        ("Auth Flow", "Sequence", sequenceDiagramAuth),
        ("Class Hierarchy", "Class", classDiagram),
        ("Class Relations", "Class", classDiagramRelations),
        ("ER Diagram", "ER", erDiagram)
    ]

    /// Get samples by category
    public static func samples(for category: String) -> [(name: String, source: String)] {
        allSamples.filter { $0.category == category }.map { ($0.name, $0.source) }
    }

    /// All categories
    public static let categories = ["Flowchart", "State", "Sequence", "Class", "ER"]
}

// MARK: - Test Diagrams from Verification Suite

/// A single test diagram entry
public struct TestDiagram: Codable, Identifiable {
    public let id: String
    public let category: String
    public let name: String
    public let source: String
}

/// Container for all test diagrams (matches verification/shared/test-diagrams.json)
public struct TestDiagramsFile: Codable {
    public let version: String
    public let description: String
    public let diagrams: [TestDiagram]
}

/// Provides access to test diagrams from the verification suite
public struct TestDiagrams {

    /// All loaded test diagrams
    public static var all: [TestDiagram] = loadDiagrams()

    /// Get all unique categories
    public static var categories: [String] {
        Array(Set(all.map { $0.category })).sorted()
    }

    /// Get diagrams by category
    public static func diagrams(for category: String) -> [TestDiagram] {
        all.filter { $0.category == category }
    }

    /// Find diagram by ID
    public static func diagram(withId id: String) -> TestDiagram? {
        all.first { $0.id == id }
    }

    // MARK: - Loading

    private static func loadDiagrams() -> [TestDiagram] {
        // Try to load from bundle first
        if let bundleURL = Bundle.main.url(forResource: "test-diagrams", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let file = try? JSONDecoder().decode(TestDiagramsFile.self, from: data) {
            return file.diagrams
        }

        // Fallback: return embedded diagrams
        return embeddedDiagrams
    }

    /// Embedded subset of diagrams as fallback when JSON file isn't in bundle
    private static let embeddedDiagrams: [TestDiagram] = [
        TestDiagram(id: "flow-1-simple", category: "flowchart", name: "Simple Flow",
                    source: "graph TD\n  A[Start] --> B[Process] --> C[End]"),
        TestDiagram(id: "flow-2-original-shapes", category: "flowchart", name: "Original Node Shapes",
                    source: "graph LR\n  A[Rectangle] --> B(Rounded)\n  B --> C{Diamond}\n  C --> D([Stadium])\n  D --> E((Circle))"),
        TestDiagram(id: "flow-5-all-12-shapes", category: "flowchart", name: "All 12 Flowchart Shapes",
                    source: "graph LR\n  A[Rectangle] --> B(Rounded)\n  B --> C{Diamond}\n  C --> D([Stadium])\n  D --> E((Circle))\n  E --> F[[Subroutine]]\n  F --> G(((Double Circle)))\n  G --> H{{Hexagon}}\n  H --> I[(Database)]\n  I --> J>Flag]\n  J --> K[/Trapezoid\\]\n  K --> L[\\Inverse Trap/]"),
        TestDiagram(id: "flow-6-edge-styles", category: "flowchart", name: "All Edge Styles",
                    source: "graph TD\n  A[Source] -->|solid| B[Target 1]\n  A -.->|dotted| C[Target 2]\n  A ==>|thick| D[Target 3]"),
        TestDiagram(id: "flow-8-bidirectional", category: "flowchart", name: "Bidirectional Arrows",
                    source: "graph LR\n  A[Client] <-->|sync| B[Server]\n  B <-.->|heartbeat| C[Monitor]\n  C <==>|data| D[Storage]"),
        TestDiagram(id: "flow-13-subgraphs", category: "flowchart", name: "Subgraphs",
                    source: "graph TD\n  subgraph Frontend\n    A[React App] --> B[State Manager]\n  end\n  subgraph Backend\n    C[API Server] --> D[Database]\n  end\n  B --> C"),
        TestDiagram(id: "flow-14-nested-subgraphs", category: "flowchart", name: "Nested Subgraphs",
                    source: "graph TD\n  subgraph Cloud\n    subgraph us-east [US East Region]\n      A[Web Server] --> B[App Server]\n    end\n    subgraph us-west [US West Region]\n      C[Web Server] --> D[App Server]\n    end\n  end\n  E[Load Balancer] --> A\n  E --> C"),
        TestDiagram(id: "flow-18-cicd-pipeline", category: "flowchart", name: "CI/CD Pipeline",
                    source: "graph TD\n  subgraph ci [CI Pipeline]\n    A[Push Code] --> B{Tests Pass?}\n    B -->|Yes| C[Build Image]\n    B -->|No| D[Fix & Retry]\n    D -.-> A\n  end\n  C --> E([Deploy Staging])\n  E --> F{QA Approved?}\n  F -->|Yes| G((Production))\n  F -->|No| D"),
        TestDiagram(id: "flow-19-system-architecture", category: "flowchart", name: "System Architecture",
                    source: "graph LR\n  subgraph clients [Client Layer]\n    A([Web App]) --> B[API Gateway]\n    C([Mobile App]) --> B\n  end\n  subgraph services [Service Layer]\n    B --> D[Auth Service]\n    B --> E[User Service]\n    B --> F[Order Service]\n  end\n  subgraph data [Data Layer]\n    D --> G[(Auth DB)]\n    E --> H[(User DB)]\n    F --> I[(Order DB)]\n    F --> J([Message Queue])\n  end"),
        TestDiagram(id: "flow-19b-services-first", category: "flowchart", name: "System Architecture (Services First)",
                    source: "graph LR\n  subgraph services [Service Layer]\n    B[API Gateway] --> D[Auth Service]\n    B --> E[User Service]\n    B --> F[Order Service]\n  end\n  subgraph clients [Client Layer]\n    A([Web App]) --> B\n    C([Mobile App]) --> B\n  end\n  subgraph data [Data Layer]\n    D --> G[(Auth DB)]\n    E --> H[(User DB)]\n    F --> I[(Order DB)]\n    F --> J([Message Queue])\n  end"),
        TestDiagram(id: "flow-20-decision-tree", category: "flowchart", name: "Decision Tree",
                    source: "graph TD\n  A{Is it raining?} -->|Yes| B{Have umbrella?}\n  A -->|No| C([Go outside])\n  B -->|Yes| D([Go with umbrella])\n  B -->|No| E{Is it heavy?}\n  E -->|Yes| F([Stay inside])\n  E -->|No| G([Run for it])"),
        TestDiagram(id: "flow-22-self-loop", category: "flowchart", name: "Self-Loop Edge",
                    source: "graph TD\n  A[Retry Node] --> A"),
        TestDiagram(id: "state-1-basic", category: "state", name: "Basic State Diagram",
                    source: "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Active : start\n  Active --> Idle : cancel\n  Active --> Done : complete\n  Done --> [*]"),
        TestDiagram(id: "state-2-composite", category: "state", name: "Composite States",
                    source: "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Processing : submit\n  state Processing {\n    parse --> validate\n    validate --> execute\n  }\n  Processing --> Complete : done\n  Processing --> Error : fail\n  Error --> Idle : retry\n  Complete --> [*]"),
        TestDiagram(id: "state-3-connection-lifecycle", category: "state", name: "Connection Lifecycle",
                    source: "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"),
        TestDiagram(id: "seq-1-basic", category: "sequence", name: "Basic Messages",
                    source: "sequenceDiagram\n  Alice->>Bob: Hello Bob!\n  Bob-->>Alice: Hi Alice!"),
        TestDiagram(id: "seq-5-activations", category: "sequence", name: "Activation Boxes",
                    source: "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>+S: Request\n  S->>+S: Process\n  S->>-S: Done\n  S-->>-C: Response"),
        TestDiagram(id: "seq-7-loop", category: "sequence", name: "Loop Block",
                    source: "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>S: Connect\n  loop Every 30s\n    C->>S: Heartbeat\n    S-->>C: Ack\n  end\n  C->>S: Disconnect"),
        TestDiagram(id: "seq-13-oauth", category: "sequence", name: "OAuth 2.0 Flow",
                    source: "sequenceDiagram\n  actor U as User\n  participant App as Client App\n  participant Auth as Auth Server\n  participant API as Resource API\n  U->>App: Click Login\n  App->>Auth: Authorization request\n  Auth->>U: Login page\n  U->>Auth: Credentials\n  Auth-->>App: Authorization code\n  App->>Auth: Exchange code for token\n  Auth-->>App: Access token\n  App->>API: Request + token\n  API-->>App: Protected resource\n  App-->>U: Display data"),
        TestDiagram(id: "class-1-basic", category: "class", name: "Basic Class",
                    source: "classDiagram\n  class Animal {\n    +String name\n    +int age\n    +eat() void\n    +sleep() void\n  }"),
        TestDiagram(id: "class-6-inheritance", category: "class", name: "Inheritance",
                    source: "classDiagram\n  class Animal {\n    +String name\n    +eat() void\n  }\n  class Dog {\n    +String breed\n    +bark() void\n  }\n  class Cat {\n    +bool isIndoor\n    +meow() void\n  }\n  Animal <|-- Dog\n  Animal <|-- Cat"),
        TestDiagram(id: "class-12-all-relationships", category: "class", name: "All 6 Relationship Types",
                    source: "classDiagram\n  A <|-- B : inheritance\n  C *-- D : composition\n  E o-- F : aggregation\n  G --> H : association\n  I ..> J : dependency\n  K ..|> L : realization"),
        TestDiagram(id: "class-15-mvc", category: "class", name: "MVC Architecture",
                    source: "classDiagram\n  class Model {\n    -data Map\n    +getData() Map\n    +setData(key, val) void\n    +notify() void\n  }\n  class View {\n    -model Model\n    +render() void\n    +update() void\n  }\n  class Controller {\n    -model Model\n    -view View\n    +handleInput(event) void\n    +updateModel(data) void\n  }\n  Controller --> Model : updates\n  Controller --> View : refreshes\n  View --> Model : reads\n  Model ..> View : notifies"),
        TestDiagram(id: "er-1-basic", category: "er", name: "Basic Relationship",
                    source: "erDiagram\n  CUSTOMER ||--o{ ORDER : places"),
        TestDiagram(id: "er-8-all-cardinality", category: "er", name: "All Cardinality Types",
                    source: "erDiagram\n  A ||--|| B : one-to-one\n  C ||--o{ D : one-to-many\n  E |o--|{ F : opt-to-many\n  G }|--o{ H : many-to-many"),
        TestDiagram(id: "er-12-ecommerce", category: "er", name: "E-Commerce Schema",
                    source: "erDiagram\n  CUSTOMER {\n    int id PK\n    string name\n    string email UK\n  }\n  ORDER {\n    int id PK\n    date created\n    int customer_id FK\n  }\n  PRODUCT {\n    int id PK\n    string name\n    float price\n  }\n  LINE_ITEM {\n    int id PK\n    int order_id FK\n    int product_id FK\n    int quantity\n  }\n  CUSTOMER ||--o{ ORDER : places\n  ORDER ||--|{ LINE_ITEM : contains\n  PRODUCT ||--o{ LINE_ITEM : includes")
    ]
}
