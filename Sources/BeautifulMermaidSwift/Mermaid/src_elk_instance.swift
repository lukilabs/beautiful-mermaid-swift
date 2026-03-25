// Ported from original/src/elk-instance.ts
import Foundation
import ElkSwift

public typealias ElkNode = [String: Any]

private enum _ElkInstanceAdapterError: Error, LocalizedError {
    case invalidGraphShape
    case elkUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidGraphShape:
            return "ELK graph must contain a string 'id' field."
        case .elkUnavailable(let message):
            return "ELK layout unavailable: \(message)"
        }
    }
}

private enum _ElkBridgeRuntime {
    private static let lock = NSLock()
    private static var sharedInstance: ELK?

    static func shared() throws -> ELK {
        lock.lock()
        defer { lock.unlock() }
        if let sharedInstance {
            return sharedInstance
        }
        do {
            let created = try ELK()
            sharedInstance = created
            return created
        } catch {
            throw _ElkInstanceAdapterError.elkUnavailable(error.localizedDescription)
        }
    }
}

private enum _ElkDirection {
    case down
    case up
    case right
    case left
}

private struct _ElkPadding {
    var top: Double
    var left: Double
    var bottom: Double
    var right: Double
}

private struct _ElkLaidOutNode {
    var id: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

private func _validateElkGraph(_ graph: ElkNode) throws {
    guard let id = graph["id"] as? String, !id.isEmpty else {
        throw _ElkInstanceAdapterError.invalidGraphShape
    }
}

private func _toDouble(_ value: Any?, default fallback: Double = 0) -> Double {
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    if let s = value as? String, let d = Double(s) { return d }
    return fallback
}

private func _parseDirection(_ graph: ElkNode) -> _ElkDirection {
    guard
        let layoutOptions = graph["layoutOptions"] as? [String: Any],
        let directionRaw = layoutOptions["elk.direction"] as? String
    else {
        return .down
    }

    switch directionRaw.uppercased() {
    case "UP": return .up
    case "RIGHT": return .right
    case "LEFT": return .left
    default: return .down
    }
}

private func _parsePadding(_ graph: ElkNode) -> _ElkPadding {
    guard
        let layoutOptions = graph["layoutOptions"] as? [String: Any],
        let paddingRaw = layoutOptions["elk.padding"] as? String
    else {
        return _ElkPadding(top: 40, left: 40, bottom: 40, right: 40)
    }

    let pattern = #"(top|left|bottom|right)\s*=\s*([-+]?[0-9]*\.?[0-9]+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return _ElkPadding(top: 40, left: 40, bottom: 40, right: 40)
    }

    var out = _ElkPadding(top: 40, left: 40, bottom: 40, right: 40)
    let ns = paddingRaw as NSString
    let matches = regex.matches(in: paddingRaw, range: NSRange(location: 0, length: ns.length))
    for m in matches {
        if m.numberOfRanges < 3 { continue }
        let key = ns.substring(with: m.range(at: 1)).lowercased()
        let value = Double(ns.substring(with: m.range(at: 2))) ?? 40
        switch key {
        case "top": out.top = value
        case "left": out.left = value
        case "bottom": out.bottom = value
        case "right": out.right = value
        default: break
        }
    }
    return out
}

private func _parseSpacing(_ graph: ElkNode) -> (nodeSpacing: Double, layerSpacing: Double) {
    guard let layoutOptions = graph["layoutOptions"] as? [String: Any] else {
        return (28, 48)
    }
    let nodeSpacing = _toDouble(layoutOptions["elk.spacing.nodeNode"], default: 28)
    let layerSpacing = _toDouble(layoutOptions["elk.layered.spacing.nodeNodeBetweenLayers"], default: 48)
    return (nodeSpacing, layerSpacing)
}

private func _extractNodeDimensions(_ node: ElkNode) -> (id: String, width: Double, height: Double)? {
    guard let id = node["id"] as? String, !id.isEmpty else { return nil }
    let width = max(1, _toDouble(node["width"], default: 60))
    let height = max(1, _toDouble(node["height"], default: 36))
    return (id, width, height)
}

private func _layoutChildren(
    children: inout [ElkNode],
    edges: [ElkNode],
    direction: _ElkDirection,
    padding: _ElkPadding,
    nodeSpacing: Double,
    layerSpacing: Double
) -> (width: Double, height: Double, laidOutById: [String: _ElkLaidOutNode]) {
    if children.isEmpty {
        return (padding.left + padding.right, padding.top + padding.bottom, [:])
    }

    let nodeInfo = children.compactMap { _extractNodeDimensions($0) }
    let ids = nodeInfo.map { $0.id }
    let idSet = Set(ids)
    let idToIndex = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { _, last in last })

    var predecessors = Array(repeating: [Int](), count: nodeInfo.count)
    var indegree = Array(repeating: 0, count: nodeInfo.count)
    var adjacency = Array(repeating: [Int](), count: nodeInfo.count)

    for edge in edges {
        guard
            let sources = edge["sources"] as? [String],
            let targets = edge["targets"] as? [String],
            let sourceId = sources.first,
            let targetId = targets.first,
            idSet.contains(sourceId),
            idSet.contains(targetId),
            let s = idToIndex[sourceId],
            let t = idToIndex[targetId]
        else {
            continue
        }
        adjacency[s].append(t)
        predecessors[t].append(s)
        indegree[t] += 1
    }

    var layer = Array(repeating: 0, count: nodeInfo.count)
    var queue: [Int] = []
    var head = 0
    for i in 0..<indegree.count where indegree[i] == 0 {
        queue.append(i)
    }

    while head < queue.count {
        let u = queue[head]
        head += 1
        for v in adjacency[u] {
            layer[v] = max(layer[v], layer[u] + 1)
            indegree[v] -= 1
            if indegree[v] == 0 {
                queue.append(v)
            }
        }
    }

    if head < nodeInfo.count {
        for idx in 0..<nodeInfo.count where !queue.contains(idx) {
            let predMax = predecessors[idx].map { layer[$0] }.max() ?? 0
            layer[idx] = predMax + 1
        }
    }

    var layers: [Int: [Int]] = [:]
    for idx in 0..<nodeInfo.count {
        layers[layer[idx], default: []].append(idx)
    }
    let sortedLayerKeys = layers.keys.sorted()

    var laidOut: [String: _ElkLaidOutNode] = [:]
    var maxRight = 0.0
    var maxBottom = 0.0

    switch direction {
    case .down, .up:
        var layerY = padding.top
        for key in sortedLayerKeys {
            guard let layerNodes = layers[key] else { continue }
            var xCursor = padding.left
            var maxLayerHeight = 0.0

            for idx in layerNodes {
                let info = nodeInfo[idx]
                let x = xCursor
                let y = layerY
                laidOut[info.id] = _ElkLaidOutNode(id: info.id, x: x, y: y, width: info.width, height: info.height)

                xCursor += info.width + nodeSpacing
                maxLayerHeight = max(maxLayerHeight, info.height)
                maxRight = max(maxRight, x + info.width)
                maxBottom = max(maxBottom, y + info.height)
            }

            layerY += maxLayerHeight + layerSpacing
        }

    case .right, .left:
        var layerX = padding.left
        for key in sortedLayerKeys {
            guard let layerNodes = layers[key] else { continue }
            var yCursor = padding.top
            var maxLayerWidth = 0.0

            for idx in layerNodes {
                let info = nodeInfo[idx]
                let x = layerX
                let y = yCursor
                laidOut[info.id] = _ElkLaidOutNode(id: info.id, x: x, y: y, width: info.width, height: info.height)

                yCursor += info.height + nodeSpacing
                maxLayerWidth = max(maxLayerWidth, info.width)
                maxRight = max(maxRight, x + info.width)
                maxBottom = max(maxBottom, y + info.height)
            }

            layerX += maxLayerWidth + layerSpacing
        }
    }

    let totalWidth = max(padding.left + padding.right, maxRight + padding.right)
    let totalHeight = max(padding.top + padding.bottom, maxBottom + padding.bottom)

    if direction == .up {
        for (id, n) in laidOut {
            let mirroredY = totalHeight - padding.bottom - n.height - (n.y - padding.top)
            laidOut[id]?.y = mirroredY
        }
    } else if direction == .left {
        for (id, n) in laidOut {
            let mirroredX = totalWidth - padding.right - n.width - (n.x - padding.left)
            laidOut[id]?.x = mirroredX
        }
    }

    for i in children.indices {
        guard let id = children[i]["id"] as? String, let n = laidOut[id] else { continue }
        children[i]["x"] = n.x
        children[i]["y"] = n.y
    }

    return (totalWidth, totalHeight, laidOut)
}

private func _point(_ x: Double, _ y: Double) -> ElkNode {
    ["x": x, "y": y]
}

private func _routeEdges(edges: inout [ElkNode], nodesById: [String: _ElkLaidOutNode]) {
    for idx in edges.indices {
        guard
            let sources = edges[idx]["sources"] as? [String],
            let targets = edges[idx]["targets"] as? [String],
            let sourceId = sources.first,
            let targetId = targets.first,
            let s = nodesById[sourceId],
            let t = nodesById[targetId]
        else {
            continue
        }

        let sCX = s.x + s.width / 2
        let sCY = s.y + s.height / 2
        let tCX = t.x + t.width / 2
        let tCY = t.y + t.height / 2
        let dx = tCX - sCX
        let dy = tCY - sCY

        let start: ElkNode
        let end: ElkNode
        let bends: [ElkNode]

        if abs(dx) >= abs(dy) {
            let startX = dx >= 0 ? s.x + s.width : s.x
            let endX = dx >= 0 ? t.x : t.x + t.width
            let startY = sCY
            let endY = tCY
            let midX = (startX + endX) / 2
            start = _point(startX, startY)
            end = _point(endX, endY)
            bends = [_point(midX, startY), _point(midX, endY)]
        } else {
            let startY = dy >= 0 ? s.y + s.height : s.y
            let endY = dy >= 0 ? t.y : t.y + t.height
            let startX = sCX
            let endX = tCX
            let midY = (startY + endY) / 2
            start = _point(startX, startY)
            end = _point(endX, endY)
            bends = [_point(startX, midY), _point(endX, midY)]
        }

        let sectionId: String
        if let edgeId = edges[idx]["id"] as? String {
            sectionId = "\(edgeId)s0"
        } else {
            sectionId = "s\(idx)"
        }

        edges[idx]["sections"] = [[
            "id": sectionId,
            "startPoint": start,
            "bendPoints": bends,
            "endPoint": end,
        ]]

        if var labels = edges[idx]["labels"] as? [ElkNode], !labels.isEmpty {
            var first = labels[0]
            let lw = _toDouble(first["width"], default: 0)
            let lh = _toDouble(first["height"], default: 0)
            first["x"] = ((
                _toDouble(start["x"], default: 0) + _toDouble(end["x"], default: 0)
            ) / 2) - (lw / 2)
            first["y"] = ((
                _toDouble(start["y"], default: 0) + _toDouble(end["y"], default: 0)
            ) / 2) - (lh / 2)
            labels[0] = first
            edges[idx]["labels"] = labels
        }
    }
}

private func _layoutRecursively(_ graph: ElkNode) throws -> ElkNode {
    var out = graph
    var children = (out["children"] as? [ElkNode]) ?? []

    // Layout nested compounds first.
    if !children.isEmpty {
        for i in children.indices {
            if children[i]["children"] is [ElkNode] {
                children[i] = try _layoutRecursively(children[i])
            }
        }
    }

    var edges = (out["edges"] as? [ElkNode]) ?? []
    let direction = _parseDirection(out)
    let padding = _parsePadding(out)
    let spacing = _parseSpacing(out)

    let laidOut = _layoutChildren(
        children: &children,
        edges: edges,
        direction: direction,
        padding: padding,
        nodeSpacing: spacing.nodeSpacing,
        layerSpacing: spacing.layerSpacing
    )

    _routeEdges(edges: &edges, nodesById: laidOut.laidOutById)

    out["children"] = children
    out["edges"] = edges
    out["width"] = laidOut.width
    out["height"] = laidOut.height
    return out
}

public func elkLayoutSync(_ graph: ElkNode) throws -> ElkNode {
    try original_src_elk_instance.elkLayoutSync(graph)
}

open class original_src_elk_instance {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export function elkLayoutSync
    public static func elkLayoutSync(_ graph: ElkNode) throws -> ElkNode {
        try _validateElkGraph(graph)
        let elk = try _ElkBridgeRuntime.shared()
        return try elk.layout(graph: graph)
    }
}
