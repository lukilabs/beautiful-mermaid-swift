// SPDX-License-Identifier: MIT
//
//  Types.swift
//  BeautifulMermaid
//
//  Core data models for Mermaid diagrams
//

import Foundation
import CoreGraphics

// MARK: - Diagram Types

/// The type of Mermaid diagram
public enum DiagramType: String, CaseIterable, Sendable {
    case flowchart
    case stateDiagram
    case sequenceDiagram
    case classDiagram
    case erDiagram

    /// Keywords that identify this diagram type
    public var keywords: [String] {
        switch self {
        case .flowchart:
            return ["graph", "flowchart"]
        case .stateDiagram:
            return ["stateDiagram", "stateDiagram-v2"]
        case .sequenceDiagram:
            return ["sequenceDiagram"]
        case .classDiagram:
            return ["classDiagram", "classDiagram-v2"]
        case .erDiagram:
            return ["erDiagram"]
        }
    }
}

// MARK: - Node

/// A node in a Mermaid diagram
public struct MermaidNode: Identifiable, Sendable {
    public let id: String
    public var label: String
    public var shape: NodeShape
    public var styleClass: String?
    public var inlineStyles: [String: String]

    // Layout properties (set during layout phase)
    public var position: CGPoint = .zero
    public var size: CGSize = .zero

    public init(
        id: String,
        label: String,
        shape: NodeShape = .rectangle,
        styleClass: String? = nil,
        inlineStyles: [String: String] = [:]
    ) {
        self.id = id
        self.label = label
        self.shape = shape
        self.styleClass = styleClass
        self.inlineStyles = inlineStyles
    }

    /// The bounding rect of this node after layout
    public var bounds: CGRect {
        CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

// MARK: - Edge

/// An edge (connection) between nodes
public struct MermaidEdge: Identifiable, Sendable {
    public let id: String
    public let sourceId: String
    public let targetId: String
    public var label: String?
    public var style: EdgeStyle

    /// Whether to render an arrowhead at the start (source end) of the edge
    public var hasArrowStart: Bool
    /// Whether to render an arrowhead at the end (target end) of the edge
    public var hasArrowEnd: Bool

    // Layout properties (set during layout phase)
    public var points: [CGPoint] = []
    public var labelPosition: CGPoint = .zero
    public var sourceAngle: CGFloat = 0
    public var targetAngle: CGFloat = 0

    public init(
        id: String = UUID().uuidString,
        sourceId: String,
        targetId: String,
        label: String? = nil,
        style: EdgeStyle = .solidArrow,
        hasArrowStart: Bool = false,
        hasArrowEnd: Bool = true
    ) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.label = label
        self.style = style
        self.hasArrowStart = hasArrowStart
        self.hasArrowEnd = hasArrowEnd
    }
}

// MARK: - Subgraph

/// A subgraph/group container in a flowchart
public struct Subgraph: Identifiable, Sendable {
    public let id: String
    public var label: String
    public var nodeIds: [String]
    public var children: [Subgraph]  // Nested subgraphs
    public var direction: Direction?  // Optional direction override

    // Layout properties
    public var bounds: CGRect = .zero
    public var headerHeight: CGFloat = 30

    public init(
        id: String,
        label: String,
        nodeIds: [String] = [],
        children: [Subgraph] = [],
        direction: Direction? = nil
    ) {
        self.id = id
        self.label = label
        self.nodeIds = nodeIds
        self.children = children
        self.direction = direction
    }

    /// The Y position where content starts (below the header)
    /// Use this instead of bounds.minY when checking if nodes are above the subgraph content
    public var contentTop: CGFloat {
        bounds.minY + headerHeight
    }

    /// Recursively collect all node IDs in this subgraph and its children
    public func allNodeIds() -> Set<String> {
        var result = Set(nodeIds)
        for child in children {
            result.formUnion(child.allNodeIds())
        }
        return result
    }

    /// Recursively collect all subgraph IDs (including self and nested children)
    public func allSubgraphIds() -> Set<String> {
        var result: Set<String> = [id]
        for child in children {
            result.formUnion(child.allSubgraphIds())
        }
        return result
    }
}

// MARK: - Style Class

/// A style class definition (classDef)
public struct StyleClass: Sendable {
    public let name: String
    public var properties: [String: String]

    public init(name: String, properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }

    /// Common style properties
    public var fill: String? { properties["fill"] }
    public var stroke: String? { properties["stroke"] }
    public var strokeWidth: String? { properties["stroke-width"] }
    public var color: String? { properties["color"] }
    public var fontWeight: String? { properties["font-weight"] }
}

// MARK: - Mermaid Graph

/// The complete parsed representation of a Mermaid diagram
public struct MermaidGraph: Sendable {
    public var type: DiagramType
    public var direction: Direction
    public var nodes: [String: MermaidNode]
    public var edges: [MermaidEdge]
    public var subgraphs: [Subgraph]
    public var styleClasses: [String: StyleClass]
    public var classAssignments: [String: String]  // nodeId -> className (matching TypeScript)
    public var nodeStyles: [String: [String: String]]  // nodeId -> style props (matching TypeScript)
    public var title: String?

    // Node order (for deterministic rendering)
    public var nodeOrder: [String]

    public init(
        type: DiagramType = .flowchart,
        direction: Direction = .topDown,
        nodes: [String: MermaidNode] = [:],
        edges: [MermaidEdge] = [],
        subgraphs: [Subgraph] = [],
        styleClasses: [String: StyleClass] = [:],
        classAssignments: [String: String] = [:],
        nodeStyles: [String: [String: String]] = [:],
        title: String? = nil,
        nodeOrder: [String] = []
    ) {
        self.type = type
        self.direction = direction
        self.nodes = nodes
        self.edges = edges
        self.subgraphs = subgraphs
        self.styleClasses = styleClasses
        self.classAssignments = classAssignments
        self.nodeStyles = nodeStyles
        self.title = title
        self.nodeOrder = nodeOrder
    }

    /// Get nodes in order
    public var orderedNodes: [MermaidNode] {
        nodeOrder.compactMap { nodes[$0] }
    }

    /// Add a node to the graph
    public mutating func addNode(_ node: MermaidNode) {
        if nodes[node.id] == nil {
            nodeOrder.append(node.id)
        }
        nodes[node.id] = node
    }

    /// Add an edge to the graph
    public mutating func addEdge(_ edge: MermaidEdge) {
        edges.append(edge)
    }

    /// Remove a node from the graph
    public mutating func removeNode(_ id: String) {
        nodes.removeValue(forKey: id)
        nodeOrder.removeAll { $0 == id }
    }
}

// MARK: - Positioned Graph (Layout Output)

/// A graph with all positions computed
public struct PositionedGraph: Sendable {
    public var nodes: [MermaidNode]
    public var edges: [MermaidEdge]
    public var subgraphs: [Subgraph]
    public var bounds: CGRect
    public var direction: Direction

    public init(
        nodes: [MermaidNode],
        edges: [MermaidEdge],
        subgraphs: [Subgraph],
        bounds: CGRect,
        direction: Direction
    ) {
        self.nodes = nodes
        self.edges = edges
        self.subgraphs = subgraphs
        self.bounds = bounds
        self.direction = direction
    }
}

// MARK: - Legacy Sequence Diagram Types (for backwards compatibility)

/// A participant in a sequence diagram (legacy type)
public struct Participant: Identifiable, Sendable {
    public let id: String
    public var label: String
    public var alias: String?
    public var isActor: Bool

    // Layout
    public var xPosition: CGFloat = 0
    public var columnWidth: CGFloat = 100

    public init(id: String, label: String, alias: String? = nil, isActor: Bool = false) {
        self.id = id
        self.label = label
        self.alias = alias
        self.isActor = isActor
    }
}

// Note: New sequence diagram types are in SequenceTypes.swift

// MARK: - Class Diagram Types

/// A class in a class diagram
public struct ClassDefinition: Identifiable, Sendable {
    public let id: String
    public var name: String
    public var stereotype: String?
    public var attributes: [ClassMember]
    public var methods: [ClassMember]

    // Layout
    public var position: CGPoint = .zero
    public var size: CGSize = .zero

    public init(
        id: String,
        name: String,
        stereotype: String? = nil,
        attributes: [ClassMember] = [],
        methods: [ClassMember] = []
    ) {
        self.id = id
        self.name = name
        self.stereotype = stereotype
        self.attributes = attributes
        self.methods = methods
    }
}

/// A member (attribute or method) of a class
public struct ClassMember: Sendable {
    public var visibility: ClassVisibility
    public var name: String
    public var type: String?
    public var parameters: String?  // For methods
    public var isStatic: Bool
    public var isAbstract: Bool

    public init(
        visibility: ClassVisibility = .public,
        name: String,
        type: String? = nil,
        parameters: String? = nil,
        isStatic: Bool = false,
        isAbstract: Bool = false
    ) {
        self.visibility = visibility
        self.name = name
        self.type = type
        self.parameters = parameters
        self.isStatic = isStatic
        self.isAbstract = isAbstract
    }
}

/// Visibility modifiers for class members
public enum ClassVisibility: String, Sendable {
    case `public` = "+"
    case `private` = "-"
    case protected = "#"
    case packagePrivate = "~"
}

/// Relationship types in class diagrams
public enum ClassRelationType: Sendable {
    case inheritance     // --|>
    case composition     // --*
    case aggregation     // --o
    case association     // -->
    case dependency      // ..>
    case realization     // ..|>
    case link            // --
}

// MARK: - ER Diagram Types

/// An entity in an ER diagram
public struct Entity: Identifiable, Sendable {
    public let id: String
    public var name: String
    public var attributes: [EntityAttribute]

    // Layout
    public var position: CGPoint = .zero
    public var size: CGSize = .zero

    public init(id: String, name: String, attributes: [EntityAttribute] = []) {
        self.id = id
        self.name = name
        self.attributes = attributes
    }
}

/// An attribute of an entity
public struct EntityAttribute: Sendable {
    public var name: String
    public var type: String
    public var isPrimaryKey: Bool
    public var isForeignKey: Bool

    public init(name: String, type: String, isPrimaryKey: Bool = false, isForeignKey: Bool = false) {
        self.name = name
        self.type = type
        self.isPrimaryKey = isPrimaryKey
        self.isForeignKey = isForeignKey
    }
}

/// Cardinality in ER relationships
public enum Cardinality: String, Sendable {
    case zeroOrOne = "|o"
    case exactlyOne = "||"
    case zeroOrMore = "}o"
    case oneOrMore = "}|"
}

/// A relationship between entities
public struct EntityRelationship: Sendable {
    public let entity1: String
    public let entity2: String
    public var cardinality1: Cardinality
    public var cardinality2: Cardinality
    public var label: String?

    public init(
        entity1: String,
        entity2: String,
        cardinality1: Cardinality,
        cardinality2: Cardinality,
        label: String? = nil
    ) {
        self.entity1 = entity1
        self.entity2 = entity2
        self.cardinality1 = cardinality1
        self.cardinality2 = cardinality2
        self.label = label
    }
}

// MARK: - State Diagram Types

/// A state in a state diagram
public struct State: Identifiable, Sendable {
    public let id: String
    public var label: String
    public var description: String?
    public var isStart: Bool
    public var isEnd: Bool
    public var isFork: Bool
    public var isChoice: Bool
    public var childStates: [State]

    // Layout
    public var position: CGPoint = .zero
    public var size: CGSize = .zero

    public init(
        id: String,
        label: String,
        description: String? = nil,
        isStart: Bool = false,
        isEnd: Bool = false,
        isFork: Bool = false,
        isChoice: Bool = false,
        childStates: [State] = []
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.isStart = isStart
        self.isEnd = isEnd
        self.isFork = isFork
        self.isChoice = isChoice
        self.childStates = childStates
    }
}

/// A transition between states
public struct StateTransition: Sendable {
    public let fromId: String
    public let toId: String
    public var label: String?
    public var guardCondition: String?
    public var action: String?

    public init(fromId: String, toId: String, label: String? = nil, guardCondition: String? = nil, action: String? = nil) {
        self.fromId = fromId
        self.toId = toId
        self.label = label
        self.guardCondition = guardCondition
        self.action = action
    }
}
