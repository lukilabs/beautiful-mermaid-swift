// Ported from original/src/class/layout.ts
import Foundation
import ElkSwift

public enum CLS {
    public static let padding: Double = 40
    public static let boxPadX: Double = 8
    public static let headerBaseHeight: Double = 32
    public static let annotationHeight: Double = 16
    public static let memberRowHeight: Double = 20
    public static let sectionPadY: Double = 8
    public static let emptySectionHeight: Double = 8
    public static let minWidth: Double = 120
    public static let memberFontSize: Double = 11
    public static let memberFontWeight: Double = 400
    public static let nodeSpacing: Double = 40
    public static let layerSpacing: Double = 60
}

private typealias ClassSizeMap = [String: (width: Double, height: Double, headerHeight: Double, attrHeight: Double, methodHeight: Double)]

private func _asDouble(_ value: Any?) -> Double? {
    if let v = value as? Double { return v }
    if let v = value as? Int { return Double(v) }
    if let v = value as? Float { return Double(v) }
    if let v = value as? NSNumber { return v.doubleValue }
    return nil
}

private func _asString(_ value: Any?) -> String? {
    value as? String
}

private func _asDict(_ value: Any?) -> [String: Any]? {
    value as? [String: Any]
}

private func _asDictArray(_ value: Any?) -> [[String: Any]] {
    if let direct = value as? [[String: Any]] {
        return direct
    }
    if let anyArray = value as? [Any] {
        return anyArray.compactMap { $0 as? [String: Any] }
    }
    return []
}

private func buildClassElkGraph(
    _ diagram: ClassDiagram,
    _ options: RenderOptions
) -> (elkGraph: ElkNode, classSizes: ClassSizeMap) {
    _ = options

    var classSizes: ClassSizeMap = [:]

    for cls in diagram.classes {
        let headerHeight = (cls.annotation != nil)
            ? CLS.headerBaseHeight + CLS.annotationHeight
            : CLS.headerBaseHeight

        let attrHeight = !cls.attributes.isEmpty
            ? Double(cls.attributes.count) * CLS.memberRowHeight + CLS.sectionPadY
            : CLS.emptySectionHeight

        let methodHeight = !cls.methods.isEmpty
            ? Double(cls.methods.count) * CLS.memberRowHeight + CLS.sectionPadY
            : CLS.emptySectionHeight

        let headerTextW = original_src_styles.estimateTextWidth(
            cls.label,
            original_src_styles.FONT_SIZES.nodeLabel,
            original_src_styles.FONT_WEIGHTS.nodeLabel
        )
        let maxAttrW = maxMemberWidth(cls.attributes)
        let maxMethodW = maxMemberWidth(cls.methods)

        let width = max(
            CLS.minWidth,
            headerTextW + CLS.boxPadX * 2,
            maxAttrW + CLS.boxPadX * 2,
            maxMethodW + CLS.boxPadX * 2
        )
        let height = headerHeight + attrHeight + methodHeight

        classSizes[cls.id] = (
            width: width,
            height: height,
            headerHeight: headerHeight,
            attrHeight: attrHeight,
            methodHeight: methodHeight
        )
    }

    var children: [[String: Any]] = []
    for cls in diagram.classes {
        guard let size = classSizes[cls.id] else { continue }
        children.append([
            "id": cls.id,
            "width": size.width,
            "height": size.height,
        ])
    }

    var edges: [[String: Any]] = []
    for (i, rel) in diagram.relationships.enumerated() {
        var edge: [String: Any] = [
            "id": "e\(i)",
            "sources": [rel.from],
            "targets": [rel.to],
        ]

        if let label = rel.label, !label.isEmpty {
            let metrics = original_src_text_metrics.measureMultilineText(
                label,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            edge["labels"] = [[
                "text": label,
                "width": metrics.width + 8,
                "height": metrics.height + 6,
            ]]
        }

        edges.append(edge)
    }

    let elkGraph: ElkNode = [
        "id": "root",
        "layoutOptions": [
            "elk.algorithm": "layered",
            "elk.direction": "DOWN",
            "elk.spacing.nodeNode": String(CLS.nodeSpacing),
            "elk.layered.spacing.nodeNodeBetweenLayers": String(CLS.layerSpacing),
            "elk.padding": "[top=\(CLS.padding),left=\(CLS.padding),bottom=\(CLS.padding),right=\(CLS.padding)]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.edgeLabels.placement": "CENTER",
            "elk.layered.edgeLabels.sideSelection": "ALWAYS_DOWN",
        ],
        "children": children,
        "edges": edges,
    ]

    return (elkGraph, classSizes)
}

private func extractClassLayout(
    _ result: ElkNode,
    _ diagram: ClassDiagram,
    _ classSizes: ClassSizeMap
) -> PositionedClassDiagram {
    let classLookup = Dictionary(uniqueKeysWithValues: diagram.classes.map { ($0.id, $0) })

    var positionedClasses: [PositionedClassNode] = []
    for child in _asDictArray(result["children"]) {
        guard let id = _asString(child["id"]), let cls = classLookup[id], let size = classSizes[id] else {
            continue
        }

        positionedClasses.append(
            PositionedClassNode(
                id: cls.id,
                label: cls.label,
                annotation: cls.annotation,
                attributes: cls.attributes,
                methods: cls.methods,
                x: _asDouble(child["x"]) ?? 0,
                y: _asDouble(child["y"]) ?? 0,
                width: _asDouble(child["width"]) ?? size.width,
                height: _asDouble(child["height"]) ?? size.height,
                headerHeight: size.headerHeight,
                attrHeight: size.attrHeight,
                methodHeight: size.methodHeight
            )
        )
    }

    var relationships: [PositionedClassRelationship] = []
    let resultEdges = _asDictArray(result["edges"])
    for (i, elkEdge) in resultEdges.enumerated() {
        guard i < diagram.relationships.count else { continue }
        let rel = diagram.relationships[i]

        var points: [ClassPoint] = []
        if let section = _asDictArray(elkEdge["sections"]).first {
            if let start = _asDict(section["startPoint"]),
               let sx = _asDouble(start["x"]),
               let sy = _asDouble(start["y"]) {
                points.append(ClassPoint(x: sx, y: sy))
            }

            for bp in _asDictArray(section["bendPoints"]) {
                if let bx = _asDouble(bp["x"]), let by = _asDouble(bp["y"]) {
                    points.append(ClassPoint(x: bx, y: by))
                }
            }

            if let end = _asDict(section["endPoint"]),
               let ex = _asDouble(end["x"]),
               let ey = _asDouble(end["y"]) {
                points.append(ClassPoint(x: ex, y: ey))
            }
        }

        var labelPosition: ClassPoint?
        if let label = _asDictArray(elkEdge["labels"]).first,
           let lx = _asDouble(label["x"]),
           let ly = _asDouble(label["y"]) {
            labelPosition = ClassPoint(
                x: lx + (_asDouble(label["width"]) ?? 0) / 2,
                y: ly + (_asDouble(label["height"]) ?? 0) / 2
            )
        }

        relationships.append(
            PositionedClassRelationship(
                from: rel.from,
                to: rel.to,
                type: rel.type,
                markerAt: rel.markerAt,
                label: rel.label,
                fromCardinality: rel.fromCardinality,
                toCardinality: rel.toCardinality,
                points: points,
                labelPosition: labelPosition
            )
        )
    }

    return PositionedClassDiagram(
        width: _asDouble(result["width"]) ?? 600,
        height: _asDouble(result["height"]) ?? 400,
        classes: positionedClasses,
        relationships: relationships
    )
}

public func layoutClassDiagramSync(
    _ diagram: ClassDiagram,
    options: RenderOptions = RenderOptions()
) throws -> PositionedClassDiagram {
    try _layoutClassDiagramSyncEntry(diagram, options: options)
}

private func _layoutClassDiagramSyncEntry(
    _ diagram: ClassDiagram,
    options: RenderOptions
) throws -> PositionedClassDiagram {
    if diagram.classes.isEmpty {
        return PositionedClassDiagram(width: 0, height: 0, classes: [], relationships: [])
    }

    let built = buildClassElkGraph(diagram, options)
    let result = try elkLayoutSync(built.elkGraph)
    return extractClassLayout(result, diagram, built.classSizes)
}

private func maxMemberWidth(_ members: [ClassMember]) -> Double {
    if members.isEmpty {
        return 0
    }
    var maxW = 0.0
    for member in members {
        let text = memberToString(member)
        let w = original_src_styles.estimateMonoTextWidth(text, CLS.memberFontSize)
        if w > maxW {
            maxW = w
        }
    }
    return maxW
}

public func memberToString(_ m: ClassMember) -> String {
    _memberToStringEntry(m)
}

private func _memberToStringEntry(_ m: ClassMember) -> String {
    let vis = m.visibility.isEmpty ? "" : "\(m.visibility) "
    let name = m.isMethod ? "\(m.name)(\(m.params ?? ""))" : m.name
    let type = m.type.map { ": \($0)" } ?? ""
    return "\(vis)\(name)\(type)"
}

open class original_src_class_layout {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    public static func layoutClassDiagramSync(
        _ diagram: ClassDiagram,
        options: RenderOptions = RenderOptions()
    ) throws -> PositionedClassDiagram {
        try _layoutClassDiagramSyncEntry(diagram, options: options)
    }

    public static func memberToString(_ member: ClassMember) -> String {
        _memberToStringEntry(member)
    }
}
