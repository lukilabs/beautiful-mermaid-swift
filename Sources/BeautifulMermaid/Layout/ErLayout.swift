// SPDX-License-Identifier: MIT
//
//  ErLayout.swift
//  BeautifulMermaid
//
//  ER diagram layout engine using SwiftDagre.
//  EXACT PORT of original/src/er/layout.ts
//

import Foundation
import CoreGraphics
import SwiftDagre

// MARK: - ER Diagram Layout

/// ER diagram layout engine
/// Port of: original/src/er/layout.ts
public struct ErLayout {

    // MARK: - Helper Types

    private struct EntitySize {
        let width: CGFloat
        let height: CGFloat
    }

    // MARK: - Layout Function

    /// Layout a parsed ER diagram using SwiftDagre.
    /// Returns positioned entity boxes and relationship paths.
    ///
    /// Port of: layoutErDiagram() lines 39-163
    public static func layout(_ diagram: ErDiagram) throws -> PositionedErDiagram {
        let config = RenderConfig.shared

        // Empty diagram check (lines 43-45)
        if diagram.entities.isEmpty {
            return PositionedErDiagram(width: 0, height: 0, entities: [], relationships: [])
        }

        // 1. Calculate box dimensions for each entity (lines 47-67)
        var entitySizes: [String: EntitySize] = [:]

        for entity in diagram.entities {
            // Header width from entity label (line 52)
            let headerTextW = config.estimateTextWidth(entity.label, fontSize: config.fontSizeNodeLabel, fontWeight: config.fontWeightNodeLabel)

            // Max attribute row width: "type  name  PK,FK" (lines 54-61)
            var maxAttrW: CGFloat = 0
            for attr in entity.attributes {
                let keysStr = attr.keys.isEmpty ? "" : "  \(attr.keys.joined(separator: ","))"
                let attrText = "\(attr.type)  \(attr.name)\(keysStr)"
                let w = config.estimateMonoTextWidth(attrText, fontSize: config.erAttrFontSize)
                maxAttrW = max(maxAttrW, w)
            }

            // Final dimensions (lines 63-64)
            let width = max(config.erMinWidth, headerTextW + config.erBoxPadX * 2, maxAttrW + config.erBoxPadX * 2)
            let height = config.erHeaderHeight + CGFloat(max(entity.attributes.count, 1)) * config.erRowHeight

            entitySizes[entity.id] = EntitySize(width: width, height: height)
        }

        // 2. Build dagre graph (lines 69-95)
        // TypeScript: new dagre.graphlib.Graph({ directed: true }) — no multigraph
        // This means parallel edges overwrite each other, matching TypeScript behavior
        let g = SwiftDagre.Graph<SwiftDagre.DagreNodeLabel, SwiftDagre.DagreEdgeLabel>(
            options: SwiftDagre.GraphOptions(directed: true, multigraph: false, compound: false)
        )
        let layoutOptions = SwiftDagre.LayoutOptions()
        layoutOptions.rankdir = .leftRight      // LR for ER diagrams
        layoutOptions.acyclicer = .greedy       // break cycles before ranking
        layoutOptions.nodesep = 50              // ER.nodeSpacing
        layoutOptions.ranksep = 70              // ER.layerSpacing
        layoutOptions.marginx = Double(config.erPadding)
        layoutOptions.marginy = Double(config.erPadding)
        g.setGraph(layoutOptions)

        // Add nodes (lines 81-84)
        for entity in diagram.entities {
            let size = entitySizes[entity.id]!
            let nodeLabel = SwiftDagre.DagreNodeLabel(width: Double(size.width), height: Double(size.height))
            g.setNode(entity.id, label: nodeLabel)
        }

        // Add edges (lines 86-95)
        // TypeScript doesn't use named edges (no multigraph), so multiple relationships between
        // same pair of entities will overwrite each other — matching TypeScript behavior
        for rel in diagram.relationships {
            let edgeLabel = SwiftDagre.DagreEdgeLabel()
            edgeLabel.minlen = 1
            edgeLabel.width = Double(config.estimateTextWidth(rel.label, fontSize: config.fontSizeEdgeLabel, fontWeight: config.fontWeightEdgeLabel) + 8)
            edgeLabel.height = Double(config.fontSizeEdgeLabel + 6)
            edgeLabel.labelpos = .center
            try g.setEdge(rel.entity1, rel.entity2, label: edgeLabel)
        }

        // 3. Run dagre layout (lines 97-104)
        try SwiftDagre.layout(g, options: layoutOptions)

        // 4. Extract positioned entities (lines 106-124)
        let positionedEntities: [PositionedErEntity] = diagram.entities.map { entity in
            let dagreNode = g.node(entity.id)!
            let topLeft = centerToTopLeft(cx: CGFloat(dagreNode.x), cy: CGFloat(dagreNode.y),
                                          width: CGFloat(dagreNode.width), height: CGFloat(dagreNode.height))

            return PositionedErEntity(
                id: entity.id,
                label: entity.label,
                attributes: entity.attributes,
                x: topLeft.x,
                y: topLeft.y,
                width: CGFloat(dagreNode.width),
                height: CGFloat(dagreNode.height),
                headerHeight: config.erHeaderHeight,
                rowHeight: config.erRowHeight
            )
        }

        // 5. Extract relationship paths (lines 126-155)
        // TypeScript iterates original relationships and looks up edges by (entity1, entity2)
        let positionedRelationships: [PositionedErRelationship] = diagram.relationships.compactMap { rel in
            guard let dagreEdge = g.edge(rel.entity1, rel.entity2) else { return nil }

            let rawPoints = dagreEdge.points.map { CGPoint(x: $0.x, y: $0.y) }
            // LR layout → horizontal-first bends (verticalFirst: false) (line 132)
            let orthoPoints = snapToOrthogonal(rawPoints, verticalFirst: false)

            // Clip endpoints (lines 134-144)
            let srcNode = g.node(rel.entity1)
            let tgtNode = g.node(rel.entity2)
            let points = clipEndpointsToNodes(
                orthoPoints,
                sourceNode: srcNode.map { NodeRect(cx: CGFloat($0.x), cy: CGFloat($0.y), hw: CGFloat($0.width/2), hh: CGFloat($0.height/2)) },
                targetNode: tgtNode.map { NodeRect(cx: CGFloat($0.x), cy: CGFloat($0.y), hw: CGFloat($0.width/2), hh: CGFloat($0.height/2)) }
            )

            return PositionedErRelationship(
                entity1: rel.entity1,
                entity2: rel.entity2,
                cardinality1: rel.cardinality1,
                cardinality2: rel.cardinality2,
                label: rel.label,
                identifying: rel.identifying,
                points: points
            )
        }

        return PositionedErDiagram(
            width: CGFloat(layoutOptions.width),
            height: CGFloat(layoutOptions.height),
            entities: positionedEntities,
            relationships: positionedRelationships
        )
    }
}
