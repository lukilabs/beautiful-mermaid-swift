// Ported from original/src/types.ts
import Foundation
import ElkSwift

open class original_src_types {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    public enum Direction: String, Sendable {
        case TD
        case TB
        case LR
        case BT
        case RL
    }

    public enum NodeShape: String, Sendable {
        case rectangle
        case rounded
        case diamond
        case stadium
        case circle
        case subroutine
        case doublecircle
        case hexagon
        case cylinder
        case asymmetric
        case trapezoid
        case trapezoidAlt = "trapezoid-alt"
        case stateStart = "state-start"
        case stateEnd = "state-end"
    }

    public enum EdgeStyle: String, Sendable {
        case solid
        case dotted
        case thick
    }

    public struct Point: Hashable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct MermaidNode: Sendable {
        public var id: String
        public var label: String
        public var shape: NodeShape

        public init(id: String, label: String, shape: NodeShape) {
            self.id = id
            self.label = label
            self.shape = shape
        }
    }

    public struct MermaidEdge: Sendable {
        public var source: String
        public var target: String
        public var label: String?
        public var style: EdgeStyle
        public var hasArrowStart: Bool
        public var hasArrowEnd: Bool
        public var inlineStyle: [String: String]?

        public init(
            source: String,
            target: String,
            label: String? = nil,
            style: EdgeStyle,
            hasArrowStart: Bool,
            hasArrowEnd: Bool,
            inlineStyle: [String: String]? = nil
        ) {
            self.source = source
            self.target = target
            self.label = label
            self.style = style
            self.hasArrowStart = hasArrowStart
            self.hasArrowEnd = hasArrowEnd
            self.inlineStyle = inlineStyle
        }
    }

    public final class MermaidSubgraph: @unchecked Sendable {
        public var id: String
        public var label: String
        public var nodeIds: [String]
        public var children: [MermaidSubgraph]
        public var direction: Direction?

        public init(
            id: String,
            label: String,
            nodeIds: [String],
            children: [MermaidSubgraph] = [],
            direction: Direction? = nil
        ) {
            self.id = id
            self.label = label
            self.nodeIds = nodeIds
            self.children = children
            self.direction = direction
        }
    }

    public struct MermaidGraph: Sendable {
        public var direction: Direction
        // Ordered node list to preserve TS Map insertion order.
        public var nodesInOrder: [(id: String, node: MermaidNode)]
        public var edges: [MermaidEdge]
        public var subgraphs: [MermaidSubgraph]
        public var classDefs: [String: [String: String]]
        public var classAssignments: [String: String]
        public var nodeStyles: [String: [String: String]]
        /// Maps edge indices (or -1 for 'default') to inline styles from `linkStyle` directives
        public var linkStyles: [Int: [String: String]]

        public init(
            direction: Direction,
            nodesInOrder: [(id: String, node: MermaidNode)],
            edges: [MermaidEdge],
            subgraphs: [MermaidSubgraph] = [],
            classDefs: [String: [String: String]] = [:],
            classAssignments: [String: String] = [:],
            nodeStyles: [String: [String: String]] = [:],
            linkStyles: [Int: [String: String]] = [:]
        ) {
            self.direction = direction
            self.nodesInOrder = nodesInOrder
            self.edges = edges
            self.subgraphs = subgraphs
            self.classDefs = classDefs
            self.classAssignments = classAssignments
            self.nodeStyles = nodeStyles
            self.linkStyles = linkStyles
        }

        public var nodesById: [String: MermaidNode] {
            var map: [String: MermaidNode] = [:]
            for entry in nodesInOrder {
                map[entry.id] = entry.node
            }
            return map
        }
    }

    public struct PositionedNode: Sendable {
        public var id: String
        public var label: String
        public var shape: NodeShape
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
        public var inlineStyle: [String: String]?

        public init(
            id: String,
            label: String,
            shape: NodeShape,
            x: Double,
            y: Double,
            width: Double,
            height: Double,
            inlineStyle: [String: String]? = nil
        ) {
            self.id = id
            self.label = label
            self.shape = shape
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            self.inlineStyle = inlineStyle
        }
    }

    public struct PositionedEdge: Sendable {
        public var source: String
        public var target: String
        public var label: String?
        public var style: EdgeStyle
        public var hasArrowStart: Bool
        public var hasArrowEnd: Bool
        public var points: [Point]
        public var labelPosition: Point?
        public var inlineStyle: [String: String]?

        public init(
            source: String,
            target: String,
            label: String? = nil,
            style: EdgeStyle,
            hasArrowStart: Bool,
            hasArrowEnd: Bool,
            points: [Point],
            labelPosition: Point? = nil,
            inlineStyle: [String: String]? = nil
        ) {
            self.source = source
            self.target = target
            self.label = label
            self.style = style
            self.hasArrowStart = hasArrowStart
            self.hasArrowEnd = hasArrowEnd
            self.points = points
            self.labelPosition = labelPosition
            self.inlineStyle = inlineStyle
        }
    }

    public struct RenderOptions: Sendable {
        public var bg: String?
        public var fg: String?
        public var line: String?
        public var accent: String?
        public var muted: String?
        public var surface: String?
        public var border: String?
        public var font: String?
        public var padding: Double?
        public var nodeSpacing: Double?
        public var layerSpacing: Double?
        public var componentSpacing: Double?
        public var transparent: Bool?

        public init(
            bg: String? = nil,
            fg: String? = nil,
            line: String? = nil,
            accent: String? = nil,
            muted: String? = nil,
            surface: String? = nil,
            border: String? = nil,
            font: String? = nil,
            padding: Double? = nil,
            nodeSpacing: Double? = nil,
            layerSpacing: Double? = nil,
            componentSpacing: Double? = nil,
            transparent: Bool? = nil
        ) {
            self.bg = bg
            self.fg = fg
            self.line = line
            self.accent = accent
            self.muted = muted
            self.surface = surface
            self.border = border
            self.font = font
            self.padding = padding
            self.nodeSpacing = nodeSpacing
            self.layerSpacing = layerSpacing
            self.componentSpacing = componentSpacing
            self.transparent = transparent
        }
    }
}
