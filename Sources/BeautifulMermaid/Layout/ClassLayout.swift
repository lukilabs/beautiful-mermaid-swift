// SPDX-License-Identifier: MIT
//
//  ClassLayout.swift
//  BeautifulMermaid
//
//  Class diagram layout engine using SwiftDagre.
//  EXACT PORT of original/src/class/layout.ts
//

import Foundation
import CoreGraphics
import SwiftDagre

// MARK: - Class Diagram Layout

/// Class diagram layout engine
/// Port of: original/src/class/layout.ts
public struct ClassLayout {

    // MARK: - Helper Types

    private struct ClassSize {
        let width: CGFloat
        let height: CGFloat
        let headerHeight: CGFloat
        let attrHeight: CGFloat
        let methodHeight: CGFloat
    }

    // MARK: - Layout Function

    /// Layout a parsed class diagram using SwiftDagre.
    /// Returns positioned class nodes and relationship paths.
    ///
    /// Port of: layoutClassDiagram() lines 55-198
    public static func layout(_ diagram: ClassDiagram) throws -> PositionedClassDiagram {
        let config = RenderConfig.shared

        // Empty diagram check (line 59-61)
        if diagram.classes.isEmpty {
            return PositionedClassDiagram(width: 0, height: 0, classes: [], relationships: [])
        }

        // 1. Calculate box dimensions for each class (lines 63-88)
        var classSizes: [String: ClassSize] = [:]

        for cls in diagram.classes {
            // Header height (lines 67-69)
            let headerHeight = cls.annotation != nil
                ? config.classHeaderBaseHeight + config.classAnnotationHeight
                : config.classHeaderBaseHeight

            // Attributes section height (lines 71-73)
            let attrHeight = cls.attributes.isEmpty
                ? config.classEmptySectionHeight
                : CGFloat(cls.attributes.count) * config.classMemberRowHeight + config.classSectionPadY

            // Methods section height (lines 75-77)
            let methodHeight = cls.methods.isEmpty
                ? config.classEmptySectionHeight
                : CGFloat(cls.methods.count) * config.classMemberRowHeight + config.classSectionPadY

            // Width: max of header text, widest attribute, widest method (lines 79-83)
            let headerTextW = config.estimateTextWidth(cls.label, fontSize: config.fontSizeNodeLabel, fontWeight: config.fontWeightNodeLabel)
            let maxAttrW = maxMemberWidth(cls.attributes, config: config)
            let maxMethodW = maxMemberWidth(cls.methods, config: config)
            let width = max(config.classMinWidth,
                           headerTextW + config.classBoxPadX * 2,
                           maxAttrW + config.classBoxPadX * 2,
                           maxMethodW + config.classBoxPadX * 2)

            let height = headerHeight + attrHeight + methodHeight

            classSizes[cls.id] = ClassSize(width: width, height: height,
                                           headerHeight: headerHeight, attrHeight: attrHeight, methodHeight: methodHeight)
        }

        // 2. Build dagre graph (lines 90-118)
        // TypeScript: new dagre.graphlib.Graph({ directed: true }) — no multigraph
        // This means parallel edges overwrite each other, matching TypeScript behavior
        let g = SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>(
            options: SwiftDagre.GraphOptions(directed: true, multigraph: false, compound: false)
        )
        let layoutOptions = SwiftDagre.LayoutOptions()
        layoutOptions.rankdir = .topBottom      // TB for class diagrams
        layoutOptions.acyclicer = .greedy       // break cycles before ranking
        layoutOptions.nodesep = Double(config.classNodeSpacing)
        layoutOptions.ranksep = Double(config.classLayerSpacing)
        layoutOptions.marginx = Double(config.classPadding)
        layoutOptions.marginy = Double(config.classPadding)
        g.setGraph(layoutOptions)

        // Add nodes (lines 102-105)
        for cls in diagram.classes {
            let size = classSizes[cls.id]!
            let nodeLabel = SwiftDagre.DagreNodeLabel(width: Double(size.width), height: Double(size.height))
            g.setNode(cls.id, label: nodeLabel)
        }

        // Add edges with label dimensions (lines 107-118)
        // TypeScript doesn't use named edges (no multigraph), so multiple edges between
        // same pair of classes will overwrite each other — matching TypeScript behavior
        for rel in diagram.relationships {
            let edgeLabel = SwiftDagre.DagreEdgeLabel()
            edgeLabel.minlen = 1
            if let label = rel.label {
                edgeLabel.width = Double(config.estimateTextWidth(label, fontSize: config.fontSizeEdgeLabel, fontWeight: config.fontWeightEdgeLabel) + 8)
                edgeLabel.height = Double(config.fontSizeEdgeLabel + 6)
                edgeLabel.labelpos = .center
            }
            try g.setEdge(rel.from, rel.to, label: edgeLabel)
        }

        // 3. Run dagre layout (lines 120-127)
        try SwiftDagre.layout(g, options: layoutOptions)

        // 4. Extract positioned classes (lines 129-151)
        let positionedClasses: [PositionedClassNode] = diagram.classes.map { cls in
            let dagreNode = g.node(cls.id)!
            let size = classSizes[cls.id]!
            let topLeft = centerToTopLeft(cx: CGFloat(dagreNode.x), cy: CGFloat(dagreNode.y),
                                          width: CGFloat(dagreNode.width), height: CGFloat(dagreNode.height))

            return PositionedClassNode(
                id: cls.id,
                label: cls.label,
                annotation: cls.annotation,
                attributes: cls.attributes,
                methods: cls.methods,
                x: topLeft.x,
                y: topLeft.y,
                width: CGFloat(dagreNode.width),
                height: CGFloat(dagreNode.height),
                headerHeight: size.headerHeight,
                attrHeight: size.attrHeight,
                methodHeight: size.methodHeight
            )
        }

        // 5. Extract relationship paths and label positions (lines 153-190)
        // TypeScript iterates original relationships and looks up edges by (from, to)
        let positionedRelationships: [PositionedClassRelationship] = diagram.relationships.compactMap { rel in
            guard let dagreEdge = g.edge(rel.from, rel.to) else { return nil }

            let rawPoints = dagreEdge.points.map { CGPoint(x: $0.x, y: $0.y) }
            // TB layout → vertical-first bends (line 159)
            let orthoPoints = snapToOrthogonal(rawPoints, verticalFirst: true)

            // Clip endpoints (lines 161-171)
            let srcNode = g.node(rel.from)
            let tgtNode = g.node(rel.to)
            let points = clipEndpointsToNodes(
                orthoPoints,
                sourceNode: srcNode.map { NodeRect(cx: CGFloat($0.x), cy: CGFloat($0.y), hw: CGFloat($0.width/2), hh: CGFloat($0.height/2)) },
                targetNode: tgtNode.map { NodeRect(cx: CGFloat($0.x), cy: CGFloat($0.y), hw: CGFloat($0.width/2), hh: CGFloat($0.height/2)) }
            )

            // Label position (lines 174-177)
            let labelPosition: CGPoint? = (dagreEdge.x != 0 || dagreEdge.y != 0)
                ? CGPoint(x: dagreEdge.x, y: dagreEdge.y)
                : nil

            return PositionedClassRelationship(
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
        }

        return PositionedClassDiagram(
            width: CGFloat(layoutOptions.width),
            height: CGFloat(layoutOptions.height),
            classes: positionedClasses,
            relationships: positionedRelationships
        )
    }

    // MARK: - Helper Functions

    /// Calculate max width of class members (uses mono metrics)
    /// Port of: maxMemberWidth() lines 200-211
    private static func maxMemberWidth(_ members: [ClassDiagramMember], config: RenderConfig) -> CGFloat {
        guard !members.isEmpty else { return 0 }
        var maxW: CGFloat = 0
        for m in members {
            let text = memberToString(m)
            // Members render in monospace (line 207)
            let w = config.estimateMonoTextWidth(text, fontSize: config.classMemberFontSize)
            maxW = max(maxW, w)
        }
        return maxW
    }

    /// Convert a class member to its display string
    /// Port of: memberToString() lines 213-218
    public static func memberToString(_ m: ClassDiagramMember) -> String {
        let vis = m.visibility.isEmpty ? "" : "\(m.visibility) "
        let type = m.type.map { ": \($0)" } ?? ""
        return "\(vis)\(m.name)\(type)"
    }
}
