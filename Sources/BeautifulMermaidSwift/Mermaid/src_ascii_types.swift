// Ported from original/src/ascii/types.ts
import Foundation
import ElkSwift

open class original_src_ascii_types {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // MARK: - Namespaced type model (faithful to types.ts without global symbol clashes)

    public typealias AsciiNodeShape = String

    public struct GridCoord: Sendable, Hashable {
        public var x: Int
        public var y: Int

        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public struct DrawingCoord: Sendable, Hashable {
        public var x: Int
        public var y: Int

        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public struct Direction: Sendable, Hashable {
        public let x: Int
        public let y: Int

        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public static let Up = Direction(x: 1, y: 0)
    public static let Down = Direction(x: 1, y: 2)
    public static let Left = Direction(x: 0, y: 1)
    public static let Right = Direction(x: 2, y: 1)
    public static let UpperRight = Direction(x: 2, y: 0)
    public static let UpperLeft = Direction(x: 0, y: 0)
    public static let LowerRight = Direction(x: 2, y: 2)
    public static let LowerLeft = Direction(x: 0, y: 2)
    public static let Middle = Direction(x: 1, y: 1)

    public static let ALL_DIRECTIONS: [Direction] = [
        Up, Down, Left, Right, UpperRight, UpperLeft, LowerRight, LowerLeft, Middle,
    ]

    public typealias Canvas = [[Character]]

    public struct AsciiStyleClass: Sendable, Hashable {
        public var name: String
        public var styles: [String: String]

        public init(name: String, styles: [String: String]) {
            self.name = name
            self.styles = styles
        }
    }

    public enum AsciiEdgeStyle: String, Sendable {
        case solid
        case dotted
        case thick
    }

    public struct AsciiNode: Sendable {
        public var name: String
        public var displayLabel: String
        public var shape: AsciiNodeShape
        public var index: Int
        public var gridCoord: GridCoord?
        public var drawingCoord: DrawingCoord?
        public var drawing: Canvas?
        public var drawn: Bool
        public var styleClassName: String
        public var styleClass: AsciiStyleClass

        public init(
            name: String,
            displayLabel: String,
            shape: AsciiNodeShape,
            index: Int,
            gridCoord: GridCoord? = nil,
            drawingCoord: DrawingCoord? = nil,
            drawing: Canvas? = nil,
            drawn: Bool = false,
            styleClassName: String = "",
            styleClass: AsciiStyleClass = EMPTY_STYLE
        ) {
            self.name = name
            self.displayLabel = displayLabel
            self.shape = shape
            self.index = index
            self.gridCoord = gridCoord
            self.drawingCoord = drawingCoord
            self.drawing = drawing
            self.drawn = drawn
            self.styleClassName = styleClassName
            self.styleClass = styleClass
        }
    }

    public struct AsciiEdge: Sendable {
        public var from: AsciiNode
        public var to: AsciiNode
        public var text: String
        public var path: [GridCoord]
        public var labelLine: [GridCoord]
        public var startDir: Direction
        public var endDir: Direction
        public var style: AsciiEdgeStyle
        public var hasArrowStart: Bool
        public var hasArrowEnd: Bool
        public var bundle: EdgeBundle?
        public var pathToJunction: [GridCoord]?

        public init(
            from: AsciiNode,
            to: AsciiNode,
            text: String = "",
            path: [GridCoord] = [],
            labelLine: [GridCoord] = [],
            startDir: Direction = Right,
            endDir: Direction = Left,
            style: AsciiEdgeStyle = .solid,
            hasArrowStart: Bool = false,
            hasArrowEnd: Bool = true,
            bundle: EdgeBundle? = nil,
            pathToJunction: [GridCoord]? = nil
        ) {
            self.from = from
            self.to = to
            self.text = text
            self.path = path
            self.labelLine = labelLine
            self.startDir = startDir
            self.endDir = endDir
            self.style = style
            self.hasArrowStart = hasArrowStart
            self.hasArrowEnd = hasArrowEnd
            self.bundle = bundle
            self.pathToJunction = pathToJunction
        }
    }

    public struct AsciiSubgraph: Sendable {
        public var name: String
        public var nodes: [AsciiNode]
        public var parent: Int?
        public var children: [Int]
        public var minX: Int
        public var minY: Int
        public var maxX: Int
        public var maxY: Int
        public var direction: String?

        public init(
            name: String,
            nodes: [AsciiNode] = [],
            parent: Int? = nil,
            children: [Int] = [],
            minX: Int = 0,
            minY: Int = 0,
            maxX: Int = 0,
            maxY: Int = 0,
            direction: String? = nil
        ) {
            self.name = name
            self.nodes = nodes
            self.parent = parent
            self.children = children
            self.minX = minX
            self.minY = minY
            self.maxX = maxX
            self.maxY = maxY
            self.direction = direction
        }
    }

    public struct AsciiConfig: Sendable {
        public var useAscii: Bool
        public var paddingX: Int
        public var paddingY: Int
        public var boxBorderPadding: Int
        public var graphDirection: String

        public init(
            useAscii: Bool,
            paddingX: Int,
            paddingY: Int,
            boxBorderPadding: Int,
            graphDirection: String
        ) {
            self.useAscii = useAscii
            self.paddingX = paddingX
            self.paddingY = paddingY
            self.boxBorderPadding = boxBorderPadding
            self.graphDirection = graphDirection
        }
    }

    public struct AsciiGraph: Sendable {
        public var nodes: [AsciiNode]
        public var edges: [AsciiEdge]
        public var canvas: Canvas
        public var roleCanvas: RoleCanvas
        public var grid: [String: AsciiNode]
        public var columnWidth: [Int: Int]
        public var rowHeight: [Int: Int]
        public var subgraphs: [AsciiSubgraph]
        public var config: AsciiConfig
        public var offsetX: Int
        public var offsetY: Int
        public var bundles: [EdgeBundle]

        public init(
            nodes: [AsciiNode],
            edges: [AsciiEdge],
            canvas: Canvas,
            roleCanvas: RoleCanvas,
            grid: [String: AsciiNode],
            columnWidth: [Int: Int],
            rowHeight: [Int: Int],
            subgraphs: [AsciiSubgraph],
            config: AsciiConfig,
            offsetX: Int = 0,
            offsetY: Int = 0,
            bundles: [EdgeBundle] = []
        ) {
            self.nodes = nodes
            self.edges = edges
            self.canvas = canvas
            self.roleCanvas = roleCanvas
            self.grid = grid
            self.columnWidth = columnWidth
            self.rowHeight = rowHeight
            self.subgraphs = subgraphs
            self.config = config
            self.offsetX = offsetX
            self.offsetY = offsetY
            self.bundles = bundles
        }
    }

    public enum CharRole: String, Sendable {
        case text
        case border
        case line
        case arrow
        case corner
        case junction
    }

    public typealias RoleCanvas = [[CharRole?]]

    public struct AsciiTheme: Sendable, Hashable {
        public var fg: String
        public var border: String
        public var line: String
        public var arrow: String
        public var corner: String?
        public var junction: String?
        public var accent: String?
        public var bg: String?

        public init(
            fg: String,
            border: String,
            line: String,
            arrow: String,
            corner: String? = nil,
            junction: String? = nil,
            accent: String? = nil,
            bg: String? = nil
        ) {
            self.fg = fg
            self.border = border
            self.line = line
            self.arrow = arrow
            self.corner = corner
            self.junction = junction
            self.accent = accent
            self.bg = bg
        }
    }

    public enum ColorMode: String, Sendable {
        case none
        case ansi16
        case ansi256
        case truecolor
        case html
    }

    public struct EdgeBundle: Sendable {
        public var type: String
        public var edges: [AsciiEdge]
        public var sharedNode: AsciiNode
        public var otherNodes: [AsciiNode]
        public var junctionPoint: GridCoord?
        public var sharedPath: [GridCoord]
        public var junctionDir: Direction
        public var sharedNodeDir: Direction

        public init(
            type: String,
            edges: [AsciiEdge],
            sharedNode: AsciiNode,
            otherNodes: [AsciiNode],
            junctionPoint: GridCoord? = nil,
            sharedPath: [GridCoord] = [],
            junctionDir: Direction = Middle,
            sharedNodeDir: Direction = Middle
        ) {
            self.type = type
            self.edges = edges
            self.sharedNode = sharedNode
            self.otherNodes = otherNodes
            self.junctionPoint = junctionPoint
            self.sharedPath = sharedPath
            self.junctionDir = junctionDir
            self.sharedNodeDir = sharedNodeDir
        }
    }

    public static func gridCoordEquals(_ a: GridCoord, _ b: GridCoord) -> Bool {
        a.x == b.x && a.y == b.y
    }

    public static func drawingCoordEquals(_ a: DrawingCoord, _ b: DrawingCoord) -> Bool {
        a.x == b.x && a.y == b.y
    }

    public static func gridCoordDirection(_ c: GridCoord, _ dir: Direction) -> GridCoord {
        GridCoord(x: c.x + dir.x, y: c.y + dir.y)
    }

    public static func gridKey(_ c: GridCoord) -> String {
        "\(c.x),\(c.y)"
    }

    public static let EMPTY_STYLE = AsciiStyleClass(name: "", styles: [:])
}
