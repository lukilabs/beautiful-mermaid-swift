import Foundation
import CoreGraphics

public enum DiagramType: String, CaseIterable, Sendable {
    case flowchart
    case stateDiagram
    case sequenceDiagram
    case classDiagram
    case erDiagram
    case xyChart
}

/// The parsed graph model for flowcharts and state diagrams.
public typealias ParsedGraphModel = original_src_types.MermaidGraph

/// Type-safe diagram payload. Use pattern matching to access the parsed model.
public enum DiagramPayload: Sendable {
    case flowchart(ParsedGraphModel)
    case stateDiagram(ParsedGraphModel)
    case sequenceDiagram(SequenceDiagram)
    case classDiagram(ClassDiagram)
    case erDiagram(ErDiagram)
    case xyChart(XYChart)
}

public struct MermaidGraph: @unchecked Sendable {
    public var type: DiagramType
    public var payload: Any?

    /// Type-safe access to the parsed diagram model.
    /// Use pattern matching to access the typed data:
    /// ```swift
    /// let graph = try MermaidRenderer.parse(source)
    /// switch graph.typedPayload {
    /// case .flowchart(let model): // ...
    /// case .sequenceDiagram(let seq): // ...
    /// }
    /// ```
    public var typedPayload: DiagramPayload? {
        switch type {
        case .flowchart:
            return (payload as? ParsedGraphModel).map { .flowchart($0) }
        case .stateDiagram:
            return (payload as? ParsedGraphModel).map { .stateDiagram($0) }
        case .sequenceDiagram:
            return (payload as? SequenceDiagram).map { .sequenceDiagram($0) }
        case .classDiagram:
            return (payload as? ClassDiagram).map { .classDiagram($0) }
        case .erDiagram:
            return (payload as? ErDiagram).map { .erDiagram($0) }
        case .xyChart:
            return (payload as? XYChart).map { .xyChart($0) }
        }
    }

    public init(type: DiagramType = .flowchart, payload: Any? = nil) {
        self.type = type
        self.payload = payload
    }
}

// MARK: - Public type aliases (drop underscore prefix)

/// A positioned node in a flowchart or state diagram.
public typealias PositionedNode = _PositionedNodePayload
/// A positioned edge in a flowchart or state diagram.
public typealias PositionedEdge = _PositionedEdgePayload
/// A positioned group (subgraph) in a flowchart or state diagram.
public typealias PositionedGroup = _PositionedGroupPayload
/// A positioned point (x, y coordinate).
public typealias PositionedPoint = _PositionedPointPayload

/// Type-safe positioned diagram content. Use pattern matching to access layout results.
public enum PositionedContent: Sendable {
    case flowchart(
        nodes: [PositionedNode],
        edges: [PositionedEdge],
        groups: [PositionedGroup]
    )
    case stateDiagram(
        nodes: [PositionedNode],
        edges: [PositionedEdge],
        groups: [PositionedGroup]
    )
    case sequenceDiagram(
        actors: [PositionedSequenceActor],
        messages: [PositionedSequenceMessage],
        blocks: [PositionedSequenceBlock],
        lifelines: [SequenceLifeline],
        activations: [SequenceActivation],
        notes: [PositionedSequenceNote]
    )
    case classDiagram(
        classes: [PositionedClassNode],
        relationships: [PositionedClassRelationship]
    )
    case erDiagram(
        entities: [PositionedErEntity],
        relationships: [PositionedErRelationship]
    )
    case xyChart(PositionedXYChart)
}

public struct PositionedGraph: Sendable {
    public var diagram: MermaidGraph
    public var width: Double
    public var height: Double
    /// Type-safe positioned content. Use pattern matching to access layout results:
    /// ```swift
    /// let graph = try MermaidRenderer.layout(source)
    /// switch graph.content {
    /// case .flowchart(let nodes, let edges, let groups):
    ///     // use nodes, edges, groups directly
    /// case .sequenceDiagram(let actors, let messages, ...):
    ///     // ...
    /// }
    /// ```
    public var content: PositionedContent

    public init(diagram: MermaidGraph, width: Double = 0, height: Double = 0, content: PositionedContent) {
        self.diagram = diagram
        self.width = width
        self.height = height
        self.content = content
    }

    /// Convenience initializer that creates an empty positioned graph based on the diagram type.
    public init(diagram: MermaidGraph, width: Double = 0, height: Double = 0) {
        self.diagram = diagram
        self.width = width
        self.height = height
        switch diagram.type {
        case .flowchart:
            self.content = .flowchart(nodes: [], edges: [], groups: [])
        case .stateDiagram:
            self.content = .stateDiagram(nodes: [], edges: [], groups: [])
        case .sequenceDiagram:
            self.content = .sequenceDiagram(actors: [], messages: [], blocks: [], lifelines: [], activations: [], notes: [])
        case .classDiagram:
            self.content = .classDiagram(classes: [], relationships: [])
        case .erDiagram:
            self.content = .erDiagram(entities: [], relationships: [])
        case .xyChart:
            self.content = .xyChart(.empty)
        }
    }

    // MARK: - Typed accessors (convenience)

    /// Flowchart/state diagram positioned nodes (nil for other diagram types).
    public var flowchartNodes: [PositionedNode]? {
        switch content {
        case .flowchart(let nodes, _, _), .stateDiagram(let nodes, _, _): return nodes
        default: return nil
        }
    }
    /// Flowchart/state diagram positioned edges (nil for other diagram types).
    public var flowchartEdges: [PositionedEdge]? {
        switch content {
        case .flowchart(_, let edges, _), .stateDiagram(_, let edges, _): return edges
        default: return nil
        }
    }
    /// Flowchart/state diagram positioned groups (nil for other diagram types).
    public var flowchartGroups: [PositionedGroup]? {
        switch content {
        case .flowchart(_, _, let groups), .stateDiagram(_, _, let groups): return groups
        default: return nil
        }
    }

    public var sequenceActors: [PositionedSequenceActor]? {
        switch content {
        case .sequenceDiagram(let actors, _, _, _, _, _): return actors
        default: return nil
        }
    }
    public var sequenceMessages: [PositionedSequenceMessage]? {
        switch content {
        case .sequenceDiagram(_, let messages, _, _, _, _): return messages
        default: return nil
        }
    }
    public var sequenceBlocks: [PositionedSequenceBlock]? {
        switch content {
        case .sequenceDiagram(_, _, let blocks, _, _, _): return blocks
        default: return nil
        }
    }
    public var seqLifelines: [SequenceLifeline] {
        switch content {
        case .sequenceDiagram(_, _, _, let lifelines, _, _): return lifelines
        default: return []
        }
    }
    public var seqActivations: [SequenceActivation] {
        switch content {
        case .sequenceDiagram(_, _, _, _, let activations, _): return activations
        default: return []
        }
    }
    public var seqNotes: [PositionedSequenceNote] {
        switch content {
        case .sequenceDiagram(_, _, _, _, _, let notes): return notes
        default: return []
        }
    }

    public var classNodes: [PositionedClassNode]? {
        switch content {
        case .classDiagram(let classes, _): return classes
        default: return nil
        }
    }
    public var classRelationships: [PositionedClassRelationship]? {
        switch content {
        case .classDiagram(_, let relationships): return relationships
        default: return nil
        }
    }

    public var erEntities: [PositionedErEntity]? {
        switch content {
        case .erDiagram(let entities, _): return entities
        default: return nil
        }
    }
    public var erRelationships: [PositionedErRelationship]? {
        switch content {
        case .erDiagram(_, let relationships): return relationships
        default: return nil
        }
    }

    public var xyChartData: PositionedXYChart? {
        switch content {
        case .xyChart(let chart): return chart
        default: return nil
        }
    }
}

public struct LayoutConfig: Sendable, Equatable {
    /// Padding around the diagram (default: 40, matches TS/ELK)
    public var padding: CGFloat
    /// Horizontal space between nodes in the same layer (default: 28)
    public var nodeSpacing: CGFloat
    /// Vertical space between layers (default: 48)
    public var layerSpacing: CGFloat
    /// Space between disconnected components (default: 20)
    public var componentSpacing: CGFloat

    public init(
        padding: CGFloat = 40,
        nodeSpacing: CGFloat = 28,
        layerSpacing: CGFloat = 48,
        componentSpacing: CGFloat = 20
    ) {
        self.padding = padding
        self.nodeSpacing = nodeSpacing
        self.layerSpacing = layerSpacing
        self.componentSpacing = componentSpacing
    }
}

public enum LineStyle: String, CaseIterable, Sendable {
    case solid
    case dotted
    case dashed
    case thick
}

public enum ArrowHead: String, CaseIterable, Sendable {
    case none
    case arrow
    case open
    case circle
    case cross
    case diamond
}

public struct EdgeStyle: Sendable, Equatable {
    public var lineStyle: LineStyle
    public var sourceArrow: ArrowHead
    public var targetArrow: ArrowHead
    public var color: String?
    /// Explicit stroke width from linkStyle directive (e.g. "2px" → 2.0)
    public var strokeWidth: CGFloat?

    public init(
        lineStyle: LineStyle = .solid,
        sourceArrow: ArrowHead = .none,
        targetArrow: ArrowHead = .arrow,
        color: String? = nil,
        strokeWidth: CGFloat? = nil
    ) {
        self.lineStyle = lineStyle
        self.sourceArrow = sourceArrow
        self.targetArrow = targetArrow
        self.color = color
        self.strokeWidth = strokeWidth
    }
}

public struct MermaidNode: Sendable {
    public var id: String
    public var inlineStyles: [String: String]
    public init(id: String, inlineStyles: [String: String] = [:]) {
        self.id = id
        self.inlineStyles = inlineStyles
    }
}

public enum BeautifulMermaidError: Error {
    case notYetImplemented(String)
}
