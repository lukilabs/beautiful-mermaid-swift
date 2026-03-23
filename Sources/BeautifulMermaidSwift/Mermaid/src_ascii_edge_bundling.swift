// Ported from original/src/ascii/edge-bundling.ts
import Foundation
import ElkSwift

private func nodeBundleKey(_ node: AsciiNode) -> String {
    "\(node.name)#\(node.index)"
}

private func nodeEquals(_ a: AsciiNode, _ b: AsciiNode) -> Bool {
    a.name == b.name && a.index == b.index
}

private func edgeEquals(_ a: AsciiEdge, _ b: AsciiEdge) -> Bool {
    nodeEquals(a.from, b.from) &&
        nodeEquals(a.to, b.to) &&
        a.text == b.text &&
        a.style == b.style &&
        a.hasArrowStart == b.hasArrowStart &&
        a.hasArrowEnd == b.hasArrowEnd
}

private func subgraphEquals(_ a: AsciiSubgraph?, _ b: AsciiSubgraph?) -> Bool {
    switch (a, b) {
    case (nil, nil):
        return true
    case let (lhs?, rhs?):
        return lhs.name == rhs.name && lhs.parent == rhs.parent
    default:
        return false
    }
}

private func canBundle(_ edgeIndices: [Int], _ graph: AsciiGraph) -> Bool {
    if edgeIndices.count < 2 {
        return false
    }

    let firstEdge = graph.edges[edgeIndices[0]]
    let firstStyle = firstEdge.style
    let firstFromSg = getNodeSubgraph(graph, firstEdge.from)
    let firstToSg = getNodeSubgraph(graph, firstEdge.to)

    for idx in edgeIndices {
        let edge = graph.edges[idx]

        if edge.style != firstStyle {
            return false
        }
        if !edge.text.isEmpty {
            return false
        }

        let fromSg = getNodeSubgraph(graph, edge.from)
        let toSg = getNodeSubgraph(graph, edge.to)

        if !subgraphEquals(fromSg, firstFromSg) || !subgraphEquals(toSg, firstToSg) {
            return false
        }
        if !subgraphEquals(fromSg, toSg) {
            return false
        }
    }

    return true
}

private func edgeIndices(for bundle: EdgeBundle, in graph: AsciiGraph) -> [Int] {
    var used = Set<Int>()
    var indices: [Int] = []

    for bundleEdge in bundle.edges {
        if let match = graph.edges.indices.first(where: { idx in
            !used.contains(idx) && edgeEquals(graph.edges[idx], bundleEdge)
        }) {
            indices.append(match)
            used.insert(match)
        }
    }

    return indices
}

public func analyzeEdgeBundles(_ graph: inout AsciiGraph) -> [EdgeBundle] {
    if graph.config.graphDirection != "TD" {
        return []
    }

    var bundles: [EdgeBundle] = []
    var bundledEdges = Set<Int>()

    var edgesByTarget: [String: [Int]] = [:]
    for idx in graph.edges.indices {
        let edge = graph.edges[idx]
        if nodeEquals(edge.from, edge.to) {
            continue
        }
        edgesByTarget[nodeBundleKey(edge.to), default: []].append(idx)
    }

    for (_, indices) in edgesByTarget {
        if indices.count < 2 || !canBundle(indices, graph) {
            continue
        }
        if indices.contains(where: { bundledEdges.contains($0) }) {
            continue
        }

        let target = graph.edges[indices[0]].to
        var bundle = EdgeBundle(
            type: "fan-in",
            edges: indices.map { graph.edges[$0] },
            sharedNode: target,
            otherNodes: indices.map { graph.edges[$0].from },
            junctionPoint: nil,
            sharedPath: [],
            junctionDir: Middle,
            sharedNodeDir: Middle
        )

        for idx in indices {
            graph.edges[idx].bundle = bundle
            bundledEdges.insert(idx)
        }

        bundle.edges = indices.map { graph.edges[$0] }
        bundles.append(bundle)
    }

    var edgesBySource: [String: [Int]] = [:]
    for idx in graph.edges.indices {
        let edge = graph.edges[idx]
        if nodeEquals(edge.from, edge.to) || bundledEdges.contains(idx) {
            continue
        }
        edgesBySource[nodeBundleKey(edge.from), default: []].append(idx)
    }

    for (_, indices) in edgesBySource {
        if indices.count < 2 || !canBundle(indices, graph) {
            continue
        }

        let source = graph.edges[indices[0]].from
        var bundle = EdgeBundle(
            type: "fan-out",
            edges: indices.map { graph.edges[$0] },
            sharedNode: source,
            otherNodes: indices.map { graph.edges[$0].to },
            junctionPoint: nil,
            sharedPath: [],
            junctionDir: Middle,
            sharedNodeDir: Middle
        )

        for idx in indices {
            graph.edges[idx].bundle = bundle
            bundledEdges.insert(idx)
        }

        bundle.edges = indices.map { graph.edges[$0] }
        bundles.append(bundle)
    }

    return bundles
}

public func calculateJunctionPoint(_ graph: AsciiGraph, _ bundle: EdgeBundle) -> GridCoord {
    let dir = graph.config.graphDirection
    let sharedCoord = bundle.sharedNode.gridCoord ?? GridCoord(x: 0, y: 0)
    let otherCoords = bundle.otherNodes.compactMap(\.gridCoord)

    if bundle.type == "fan-in" {
        let minX = otherCoords.map(\.x).min() ?? sharedCoord.x
        let maxX = otherCoords.map(\.x).max() ?? sharedCoord.x
        let minY = otherCoords.map(\.y).min() ?? sharedCoord.y
        let maxY = otherCoords.map(\.y).max() ?? sharedCoord.y
        _ = minY
        _ = maxY

        if dir == "TD" {
            let junctionY = sharedCoord.y - 1
            let centerX = ((minX + maxX) / 2) + 1
            _ = centerX
            let junctionX = sharedCoord.x + 1
            return GridCoord(x: junctionX, y: junctionY)
        } else {
            let junctionX = sharedCoord.x - 1
            let junctionY = sharedCoord.y + 1
            return GridCoord(x: junctionX, y: junctionY)
        }
    }

    let minX = otherCoords.map(\.x).min() ?? sharedCoord.x
    let maxX = otherCoords.map(\.x).max() ?? sharedCoord.x
    let minY = otherCoords.map(\.y).min() ?? sharedCoord.y
    let maxY = otherCoords.map(\.y).max() ?? sharedCoord.y
    _ = minX
    _ = maxX
    _ = minY
    _ = maxY

    if dir == "TD" {
        let junctionY = sharedCoord.y + 3
        let junctionX = sharedCoord.x + 1
        return GridCoord(x: junctionX, y: junctionY)
    } else {
        let junctionX = sharedCoord.x + 3
        let junctionY = sharedCoord.y + 1
        return GridCoord(x: junctionX, y: junctionY)
    }
}

public func routeBundledEdges(_ graph: inout AsciiGraph, _ bundle: inout EdgeBundle) {
    let dir = graph.config.graphDirection
    bundle.junctionPoint = calculateJunctionPoint(graph, bundle)
    let junction = bundle.junctionPoint ?? GridCoord(x: 0, y: 0)

    let mappedIndices = edgeIndices(for: bundle, in: graph)

    if bundle.type == "fan-in" {
        bundle.junctionDir = dir == "TD" ? Up : Left
        bundle.sharedNodeDir = dir == "TD" ? Down : Right

        let targetCoord = bundle.sharedNode.gridCoord ?? GridCoord(x: 0, y: 0)
        let targetEntry = dir == "TD"
            ? GridCoord(x: targetCoord.x + 1, y: targetCoord.y)
            : GridCoord(x: targetCoord.x, y: targetCoord.y + 1)

        let sharedPath = getPath(graph.grid, junction, targetEntry)
        bundle.sharedPath = sharedPath.map(mergePath) ?? [junction, targetEntry]

        for i in bundle.edges.indices {
            var edge = bundle.edges[i]
            let sourceCoord = edge.from.gridCoord ?? GridCoord(x: 0, y: 0)
            let sourceExit = dir == "TD"
                ? GridCoord(x: sourceCoord.x + 1, y: sourceCoord.y + 2)
                : GridCoord(x: sourceCoord.x + 2, y: sourceCoord.y + 1)

            let pathToJunction = getPath(graph.grid, sourceExit, junction)
            edge.pathToJunction = pathToJunction.map(mergePath) ?? [sourceExit, junction]

            edge.startDir = dir == "TD" ? Down : Right
            edge.endDir = dir == "TD" ? Up : Left
            edge.path = (edge.pathToJunction ?? [sourceExit, junction]) + bundle.sharedPath.dropFirst()
            edge.bundle = bundle

            bundle.edges[i] = edge
            if i < mappedIndices.count {
                graph.edges[mappedIndices[i]] = edge
            }
        }
    } else {
        bundle.junctionDir = dir == "TD" ? Down : Right
        bundle.sharedNodeDir = dir == "TD" ? Up : Left

        let sourceCoord = bundle.sharedNode.gridCoord ?? GridCoord(x: 0, y: 0)
        let sourceExit = dir == "TD"
            ? GridCoord(x: sourceCoord.x + 1, y: sourceCoord.y + 2)
            : GridCoord(x: sourceCoord.x + 2, y: sourceCoord.y + 1)

        let sharedPath = getPath(graph.grid, sourceExit, junction)
        bundle.sharedPath = sharedPath.map(mergePath) ?? [sourceExit, junction]

        for i in bundle.edges.indices {
            var edge = bundle.edges[i]
            let targetCoord = edge.to.gridCoord ?? GridCoord(x: 0, y: 0)
            let targetEntry = dir == "TD"
                ? GridCoord(x: targetCoord.x + 1, y: targetCoord.y)
                : GridCoord(x: targetCoord.x, y: targetCoord.y + 1)

            let pathToJunction = getPath(graph.grid, junction, targetEntry)
            edge.pathToJunction = pathToJunction.map(mergePath) ?? [junction, targetEntry]

            edge.startDir = dir == "TD" ? Down : Right
            edge.endDir = dir == "TD" ? Up : Left
            edge.path = bundle.sharedPath + (edge.pathToJunction ?? [junction, targetEntry]).dropFirst()
            edge.bundle = bundle

            bundle.edges[i] = edge
            if i < mappedIndices.count {
                graph.edges[mappedIndices[i]] = edge
            }
        }
    }
}

public func processBundles(_ graph: inout AsciiGraph) {
    for i in graph.bundles.indices {
        var bundle = graph.bundles[i]
        routeBundledEdges(&graph, &bundle)
        graph.bundles[i] = bundle
    }
}

open class original_src_ascii_edge_bundling {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version
}
