// Ported from original/src/ascii/converter.ts
import Foundation
import ElkSwift

open class original_src_ascii_converter {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    // MARK: - Shared ASCII model types (used by grid/pathfinder/index shims)

    public struct GridCoord: Hashable, Sendable {
        public var x: Int
        public var y: Int

        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public struct DrawingCoord: Hashable, Sendable {
        public var x: Int
        public var y: Int

        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public struct Direction: Hashable, Sendable {
        public var x: Int
        public var y: Int

        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public struct AsciiStyleClass: Sendable {
        public var name: String
        public var styles: [String: String]

        public init(name: String, styles: [String: String]) {
            self.name = name
            self.styles = styles
        }
    }

    public static let EMPTY_STYLE = AsciiStyleClass(name: "", styles: [:])

    public enum CharRole: Sendable {
        case none
    }

    public struct EdgeBundle: Sendable {
        public init() {}
    }

    public final class AsciiNode: @unchecked Sendable {
        public var name: String
        public var displayLabel: String
        public var shape: String
        public var index: Int
        public var gridCoord: GridCoord?
        public var drawingCoord: DrawingCoord?
        public var drawing: [[Character]]?
        public var drawn: Bool
        public var styleClassName: String
        public var styleClass: AsciiStyleClass

        public init(
            name: String,
            displayLabel: String,
            shape: String,
            index: Int
        ) {
            self.name = name
            self.displayLabel = displayLabel
            self.shape = shape
            self.index = index
            gridCoord = nil
            drawingCoord = nil
            drawing = nil
            drawn = false
            styleClassName = ""
            styleClass = original_src_ascii_converter.EMPTY_STYLE
        }
    }

    public final class AsciiEdge: @unchecked Sendable {
        public var from: AsciiNode
        public var to: AsciiNode
        public var text: String
        public var path: [GridCoord]
        public var labelLine: [GridCoord]
        public var startDir: Direction
        public var endDir: Direction
        public var style: String?
        public var hasArrowStart: Bool
        public var hasArrowEnd: Bool
        public var bundle: EdgeBundle?

        public init(
            from: AsciiNode,
            to: AsciiNode,
            text: String,
            style: String?,
            hasArrowStart: Bool,
            hasArrowEnd: Bool
        ) {
            self.from = from
            self.to = to
            self.text = text
            path = []
            labelLine = []
            startDir = Direction(x: 0, y: 0)
            endDir = Direction(x: 0, y: 0)
            self.style = style
            self.hasArrowStart = hasArrowStart
            self.hasArrowEnd = hasArrowEnd
            bundle = nil
        }
    }

    public final class AsciiSubgraph: @unchecked Sendable {
        public var name: String
        public var nodes: [AsciiNode]
        public weak var parent: AsciiSubgraph?
        public var children: [AsciiSubgraph]
        public var minX: Int
        public var minY: Int
        public var maxX: Int
        public var maxY: Int
        public var direction: String?

        public init(name: String, parent: AsciiSubgraph?, direction: String?) {
            self.name = name
            nodes = []
            self.parent = parent
            children = []
            minX = 0
            minY = 0
            maxX = 0
            maxY = 0
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

    public final class AsciiGraph: @unchecked Sendable {
        public var nodes: [AsciiNode]
        public var edges: [AsciiEdge]
        public var canvas: [[Character]]
        public var roleCanvas: [[CharRole]]
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
            subgraphs: [AsciiSubgraph],
            config: AsciiConfig
        ) {
            self.nodes = nodes
            self.edges = edges
            canvas = []
            roleCanvas = []
            grid = [:]
            columnWidth = [:]
            rowHeight = [:]
            self.subgraphs = subgraphs
            self.config = config
            offsetX = 0
            offsetY = 0
            bundles = []
        }
    }

    // MARK: - Mermaid parser-input shims

    public struct MermaidNodeInput: Sendable {
        public var label: String
        public var shape: String

        public init(label: String, shape: String) {
            self.label = label
            self.shape = shape
        }
    }

    public struct MermaidEdgeInput: Sendable {
        public var source: String
        public var target: String
        public var label: String?
        public var style: String?
        public var hasArrowStart: Bool
        public var hasArrowEnd: Bool

        public init(
            source: String,
            target: String,
            label: String? = nil,
            style: String? = nil,
            hasArrowStart: Bool = false,
            hasArrowEnd: Bool = true
        ) {
            self.source = source
            self.target = target
            self.label = label
            self.style = style
            self.hasArrowStart = hasArrowStart
            self.hasArrowEnd = hasArrowEnd
        }
    }

    public final class MermaidSubgraphInput: @unchecked Sendable {
        public var label: String
        public var nodeIds: [String]
        public var children: [MermaidSubgraphInput]
        public var direction: String?

        public init(
            label: String,
            nodeIds: [String],
            children: [MermaidSubgraphInput] = [],
            direction: String? = nil
        ) {
            self.label = label
            self.nodeIds = nodeIds
            self.children = children
            self.direction = direction
        }
    }

    public struct MermaidGraphInput: Sendable {
        // Ordered to preserve insertion semantics from the TS Map.
        public var nodes: [(id: String, node: MermaidNodeInput)]
        public var edges: [MermaidEdgeInput]
        public var subgraphs: [MermaidSubgraphInput]
        public var classAssignments: [(nodeId: String, className: String)]
        public var classDefs: [String: [String: String]]

        public init(
            nodes: [(id: String, node: MermaidNodeInput)],
            edges: [MermaidEdgeInput],
            subgraphs: [MermaidSubgraphInput] = [],
            classAssignments: [(nodeId: String, className: String)] = [],
            classDefs: [String: [String: String]] = [:]
        ) {
            self.nodes = nodes
            self.edges = edges
            self.subgraphs = subgraphs
            self.classAssignments = classAssignments
            self.classDefs = classDefs
        }
    }

    // MARK: - TS parity utilities

    public static func gridCoordEquals(_ lhs: GridCoord, _ rhs: GridCoord) -> Bool {
        lhs == rhs
    }

    public static func gridKey(_ c: GridCoord) -> String {
        "\(c.x),\(c.y)"
    }

    // MARK: - converter.ts API

    /// Faithful port of converter.ts high-level mapping semantics.
    public static func convertToAsciiGraph(
        _ parsed: MermaidGraphInput,
        _ config: AsciiConfig
    ) -> AsciiGraph {
        var nodeMap: [String: AsciiNode] = [:]
        var index = 0
        for (id, mNode) in parsed.nodes {
            let asciiNode = AsciiNode(
                name: id,
                displayLabel: mNode.label,
                shape: mNode.shape,
                index: index
            )
            nodeMap[id] = asciiNode
            index += 1
        }

        let nodes = parsed.nodes.compactMap { nodeMap[$0.id] }

        var edges: [AsciiEdge] = []
        for mEdge in parsed.edges {
            guard let from = nodeMap[mEdge.source], let to = nodeMap[mEdge.target] else {
                continue
            }
            edges.append(
                AsciiEdge(
                    from: from,
                    to: to,
                    text: mEdge.label ?? "",
                    style: mEdge.style,
                    hasArrowStart: mEdge.hasArrowStart,
                    hasArrowEnd: mEdge.hasArrowEnd
                )
            )
        }

        var subgraphs: [AsciiSubgraph] = []
        for mSg in parsed.subgraphs {
            _ = convertSubgraph(mSg, parent: nil, nodeMap: nodeMap, allSubgraphs: &subgraphs)
        }

        deduplicateSubgraphNodes(parsed.subgraphs, asciiSubgraphs: subgraphs)

        for assignment in parsed.classAssignments {
            guard let node = nodeMap[assignment.nodeId],
                  let classDef = parsed.classDefs[assignment.className]
            else {
                continue
            }
            node.styleClassName = assignment.className
            node.styleClass = AsciiStyleClass(name: assignment.className, styles: classDef)
        }

        return AsciiGraph(nodes: nodes, edges: edges, subgraphs: subgraphs, config: config)
    }

    private static func convertSubgraph(
        _ mSg: MermaidSubgraphInput,
        parent: AsciiSubgraph?,
        nodeMap: [String: AsciiNode],
        allSubgraphs: inout [AsciiSubgraph]
    ) -> AsciiSubgraph {
        let normalizedDirection: String?
        if let dir = mSg.direction {
            normalizedDirection = (dir == "LR" || dir == "RL") ? "LR" : "TD"
        } else {
            normalizedDirection = nil
        }

        let sg = AsciiSubgraph(name: mSg.label, parent: parent, direction: normalizedDirection)
        for nodeId in mSg.nodeIds {
            if let node = nodeMap[nodeId] {
                sg.nodes.append(node)
            }
        }
        allSubgraphs.append(sg)

        for childMSg in mSg.children {
            let child = convertSubgraph(childMSg, parent: sg, nodeMap: nodeMap, allSubgraphs: &allSubgraphs)
            sg.children.append(child)
            for childNode in child.nodes where !sg.nodes.contains(where: { $0 === childNode }) {
                sg.nodes.append(childNode)
            }
        }

        return sg
    }

    private static func deduplicateSubgraphNodes(
        _ mermaidSubgraphs: [MermaidSubgraphInput],
        asciiSubgraphs: [AsciiSubgraph]
    ) {
        var sgMap: [ObjectIdentifier: AsciiSubgraph] = [:]
        buildSgMap(mermaidSubgraphs, asciiSubgraphs: asciiSubgraphs, result: &sgMap)

        var nodeOwner: [String: AsciiSubgraph] = [:]
        func claimNodes(_ mSg: MermaidSubgraphInput) {
            guard let asciiSg = sgMap[ObjectIdentifier(mSg)] else {
                return
            }
            for child in mSg.children {
                claimNodes(child)
            }
            for nodeId in mSg.nodeIds where nodeOwner[nodeId] == nil {
                nodeOwner[nodeId] = asciiSg
            }
        }
        for mSg in mermaidSubgraphs {
            claimNodes(mSg)
        }

        for asciiSg in asciiSubgraphs {
            asciiSg.nodes = asciiSg.nodes.filter { node in
                guard let owner = nodeOwner[node.name] else {
                    return true
                }
                return isAncestorOrSelf(candidate: asciiSg, target: owner)
            }
        }
    }

    private static func isAncestorOrSelf(candidate: AsciiSubgraph, target: AsciiSubgraph) -> Bool {
        var current: AsciiSubgraph? = target
        while let c = current {
            if c === candidate {
                return true
            }
            current = c.parent
        }
        return false
    }

    private static func buildSgMap(
        _ mSgs: [MermaidSubgraphInput],
        asciiSubgraphs: [AsciiSubgraph],
        result: inout [ObjectIdentifier: AsciiSubgraph]
    ) {
        var flatMermaid: [MermaidSubgraphInput] = []
        func flatten(_ sgs: [MermaidSubgraphInput]) {
            for sg in sgs {
                flatMermaid.append(sg)
                flatten(sg.children)
            }
        }
        flatten(mSgs)

        for idx in 0..<min(flatMermaid.count, asciiSubgraphs.count) {
            result[ObjectIdentifier(flatMermaid[idx])] = asciiSubgraphs[idx]
        }
    }
}
