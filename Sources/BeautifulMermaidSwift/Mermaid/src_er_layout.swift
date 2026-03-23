// Ported from original/src/er/layout.ts
import Foundation
import ElkSwift

private enum ER {
    static let padding: Double = 40
    static let boxPadX: Double = 14
    static let headerHeight: Double = 34
    static let rowHeight: Double = 22
    static let minWidth: Double = 140
    static let attrFontSize: Double = 11
    static let attrFontWeight: Int = 400
    static let nodeSpacing: Double = 70
    static let layerSpacing: Double = 90
}

private typealias EntitySizeMap = [String: (width: Double, height: Double)]

private struct _ElkLabel {
    var text: String
    var width: Double
    var height: Double
    var x: Double?
    var y: Double?
}

private struct _ElkPoint {
    var x: Double
    var y: Double
}

private struct _ElkSection {
    var startPoint: _ElkPoint
    var endPoint: _ElkPoint
    var bendPoints: [_ElkPoint]?
}

private struct _ElkEdge {
    var id: String
    var sources: [String]
    var targets: [String]
    var labels: [_ElkLabel]?
    var sections: [_ElkSection]?
}

private struct _ElkNode {
    var id: String
    var width: Double?
    var height: Double?
    var x: Double?
    var y: Double?
    var layoutOptions: [String: String]?
    var children: [_ElkNode]?
    var edges: [_ElkEdge]?
}

private func _buildErElkGraph(
    _ diagram: ErDiagram,
    _ options: RenderOptions
) -> (elkGraph: _ElkNode, entitySizes: EntitySizeMap) {
    _ = options
    var entitySizes: EntitySizeMap = [:]

    for entity in diagram.entities {
        let headerTextWidth = original_src_styles.estimateTextWidth(
            entity.label,
            original_src_styles.FONT_SIZES.nodeLabel,
            original_src_styles.FONT_WEIGHTS.nodeLabel
        )

        var maxAttrWidth = 0.0
        for attr in entity.attributes {
            let keyPart = attr.keys.isEmpty ? "" : "  " + attr.keys.joined(separator: ",")
            let attrText = "\(attr.type)  \(attr.name)\(keyPart)"
            let width = original_src_styles.estimateMonoTextWidth(attrText, ER.attrFontSize)
            maxAttrWidth = max(maxAttrWidth, width)
        }

        let width = max(ER.minWidth, headerTextWidth + ER.boxPadX * 2, maxAttrWidth + ER.boxPadX * 2)
        let height = ER.headerHeight + Double(max(entity.attributes.count, 1)) * ER.rowHeight
        entitySizes[entity.id] = (width, height)
    }

    var children: [_ElkNode] = []
    for entity in diagram.entities {
        let size = entitySizes[entity.id] ?? (ER.minWidth, ER.headerHeight + ER.rowHeight)
        children.append(
            _ElkNode(
                id: entity.id,
                width: size.width,
                height: size.height,
                x: nil,
                y: nil,
                layoutOptions: nil,
                children: nil,
                edges: nil
            )
        )
    }

    var edges: [_ElkEdge] = []
    for (idx, rel) in diagram.relationships.enumerated() {
        var edge = _ElkEdge(
            id: "e\(idx)",
            sources: [rel.entity1],
            targets: [rel.entity2],
            labels: nil,
            sections: nil
        )
        if !rel.label.isEmpty {
            let metrics = original_src_text_metrics.measureMultilineText(
                rel.label,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            edge.labels = [
                _ElkLabel(
                    text: rel.label,
                    width: metrics.width + 8,
                    height: metrics.height + 6,
                    x: nil,
                    y: nil
                ),
            ]
        }
        edges.append(edge)
    }

    let elkGraph = _ElkNode(
        id: "root",
        width: nil,
        height: nil,
        x: nil,
        y: nil,
        layoutOptions: [
            "elk.algorithm": "layered",
            "elk.direction": "RIGHT",
            "elk.spacing.nodeNode": String(ER.nodeSpacing),
            "elk.layered.spacing.nodeNodeBetweenLayers": String(ER.layerSpacing),
            "elk.padding": "[top=\(ER.padding),left=\(ER.padding),bottom=\(ER.padding),right=\(ER.padding)]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.edgeLabels.placement": "CENTER",
        ],
        children: children,
        edges: edges
    )

    return (elkGraph, entitySizes)
}

private func _extractErLayout(
    _ result: _ElkNode,
    _ diagram: ErDiagram,
    _ entitySizes: EntitySizeMap
) -> PositionedErDiagram {
    let entityLookup = Dictionary(uniqueKeysWithValues: diagram.entities.map { ($0.id, $0) })

    var positionedEntities: [PositionedErEntity] = []
    for child in result.children ?? [] {
        guard let entity = entityLookup[child.id] else {
            continue
        }
        let fallback = entitySizes[entity.id] ?? (ER.minWidth, ER.headerHeight + ER.rowHeight)
        positionedEntities.append(
            PositionedErEntity(
                id: entity.id,
                label: entity.label,
                attributes: entity.attributes,
                x: child.x ?? 0,
                y: child.y ?? 0,
                width: child.width ?? fallback.width,
                height: child.height ?? fallback.height,
                headerHeight: ER.headerHeight,
                rowHeight: ER.rowHeight
            )
        )
    }

    var relationships: [PositionedErRelationship] = []
    let resultEdges = result.edges ?? []
    for (idx, elkEdge) in resultEdges.enumerated() {
        guard idx < diagram.relationships.count else {
            continue
        }
        let rel = diagram.relationships[idx]
        var points: [ErPoint] = []
        if let section = elkEdge.sections?.first {
            points.append(ErPoint(x: section.startPoint.x, y: section.startPoint.y))
            for bp in section.bendPoints ?? [] {
                points.append(ErPoint(x: bp.x, y: bp.y))
            }
            points.append(ErPoint(x: section.endPoint.x, y: section.endPoint.y))
        }
        relationships.append(
            PositionedErRelationship(
                entity1: rel.entity1,
                entity2: rel.entity2,
                cardinality1: rel.cardinality1,
                cardinality2: rel.cardinality2,
                label: rel.label,
                identifying: rel.identifying,
                points: points
            )
        )
    }

    return PositionedErDiagram(
        width: result.width ?? 600,
        height: result.height ?? 400,
        entities: positionedEntities,
        relationships: relationships
    )
}

private func _anyToDouble(_ value: Any?) -> Double? {
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    if let f = value as? Float { return Double(f) }
    if let n = value as? NSNumber { return n.doubleValue }
    return nil
}

private func _decodeElkPoint(_ any: Any?) -> _ElkPoint? {
    guard let point = any as? [String: Any],
          let x = _anyToDouble(point["x"]),
          let y = _anyToDouble(point["y"])
    else {
        return nil
    }
    return _ElkPoint(x: x, y: y)
}

private func _encodeElkPoint(_ point: _ElkPoint) -> [String: Any] {
    ["x": point.x, "y": point.y]
}

private func _decodeElkLabel(_ any: Any?) -> _ElkLabel? {
    guard let label = any as? [String: Any],
          let text = label["text"] as? String,
          let width = _anyToDouble(label["width"]),
          let height = _anyToDouble(label["height"])
    else {
        return nil
    }

    return _ElkLabel(
        text: text,
        width: width,
        height: height,
        x: _anyToDouble(label["x"]),
        y: _anyToDouble(label["y"])
    )
}

private func _encodeElkLabel(_ label: _ElkLabel) -> [String: Any] {
    var out: [String: Any] = [
        "text": label.text,
        "width": label.width,
        "height": label.height,
    ]
    if let x = label.x { out["x"] = x }
    if let y = label.y { out["y"] = y }
    return out
}

private func _decodeElkSection(_ any: Any?) -> _ElkSection? {
    guard let section = any as? [String: Any],
          let startPoint = _decodeElkPoint(section["startPoint"]),
          let endPoint = _decodeElkPoint(section["endPoint"])
    else {
        return nil
    }

    let bendPoints = (section["bendPoints"] as? [Any])?.compactMap { _decodeElkPoint($0) }
    return _ElkSection(startPoint: startPoint, endPoint: endPoint, bendPoints: bendPoints)
}

private func _encodeElkSection(_ section: _ElkSection) -> [String: Any] {
    var out: [String: Any] = [
        "startPoint": _encodeElkPoint(section.startPoint),
        "endPoint": _encodeElkPoint(section.endPoint),
    ]
    if let bendPoints = section.bendPoints {
        out["bendPoints"] = bendPoints.map(_encodeElkPoint)
    }
    return out
}

private func _decodeElkEdge(_ any: Any?) -> _ElkEdge? {
    guard let edge = any as? [String: Any],
          let id = edge["id"] as? String,
          let sources = edge["sources"] as? [String],
          let targets = edge["targets"] as? [String]
    else {
        return nil
    }

    let labels = (edge["labels"] as? [Any])?.compactMap { _decodeElkLabel($0) }
    let sections = (edge["sections"] as? [Any])?.compactMap { _decodeElkSection($0) }
    return _ElkEdge(id: id, sources: sources, targets: targets, labels: labels, sections: sections)
}

private func _encodeElkEdge(_ edge: _ElkEdge) -> [String: Any] {
    var out: [String: Any] = [
        "id": edge.id,
        "sources": edge.sources,
        "targets": edge.targets,
    ]
    if let labels = edge.labels {
        out["labels"] = labels.map(_encodeElkLabel)
    }
    if let sections = edge.sections {
        out["sections"] = sections.map(_encodeElkSection)
    }
    return out
}

private func _decodeElkNode(_ any: Any?) -> _ElkNode? {
    guard let node = any as? [String: Any],
          let id = node["id"] as? String
    else {
        return nil
    }

    let children = (node["children"] as? [Any])?.compactMap { _decodeElkNode($0) }
    let edges = (node["edges"] as? [Any])?.compactMap { _decodeElkEdge($0) }

    return _ElkNode(
        id: id,
        width: _anyToDouble(node["width"]),
        height: _anyToDouble(node["height"]),
        x: _anyToDouble(node["x"]),
        y: _anyToDouble(node["y"]),
        layoutOptions: node["layoutOptions"] as? [String: String],
        children: children,
        edges: edges
    )
}

private func _encodeElkNode(_ node: _ElkNode) -> ElkNode {
    var out: ElkNode = ["id": node.id]
    if let width = node.width { out["width"] = width }
    if let height = node.height { out["height"] = height }
    if let x = node.x { out["x"] = x }
    if let y = node.y { out["y"] = y }
    if let layoutOptions = node.layoutOptions { out["layoutOptions"] = layoutOptions }
    if let children = node.children { out["children"] = children.map(_encodeElkNode) }
    if let edges = node.edges { out["edges"] = edges.map(_encodeElkEdge) }
    return out
}

private func _elkLayoutSync(_ graph: _ElkNode) throws -> _ElkNode {
    let laidOut = try elkLayoutSync(_encodeElkNode(graph))
    return _decodeElkNode(laidOut) ?? graph
}

public func layoutErDiagramSync(
    _ diagram: ErDiagram,
    options: RenderOptions = RenderOptions()
) throws -> PositionedErDiagram {
    try _layoutErDiagramSyncEntry(diagram, options: options)
}

private func _layoutErDiagramSyncEntry(
    _ diagram: ErDiagram,
    options: RenderOptions
) throws -> PositionedErDiagram {
    if diagram.entities.isEmpty {
        return PositionedErDiagram(width: 0, height: 0, entities: [], relationships: [])
    }

    let built = _buildErElkGraph(diagram, options)
    let result = try _elkLayoutSync(built.elkGraph)
    return _extractErLayout(result, diagram, built.entitySizes)
}

open class original_src_er_layout {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    // Export inventory from TypeScript source:
    // - export function layoutErDiagramSync
    public static func layoutErDiagramSync(
        _ diagram: ErDiagram,
        options: RenderOptions = RenderOptions()
    ) throws -> PositionedErDiagram {
        try _layoutErDiagramSyncEntry(diagram, options: options)
    }
}
