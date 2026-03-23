// Ported from original/src/er/types.ts
import Foundation
import ElkSwift

public typealias Entity = ErEntity
public typealias Attribute = ErAttribute
public typealias Relationship = ErRelationship
public typealias PositionedEntity = PositionedErEntity
public typealias PositionedRelationship = PositionedErRelationship

open class original_src_er_types {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    public static func makeAttribute(
        type: String,
        name: String,
        keys: [String] = [],
        comment: String? = nil
    ) -> ErAttribute {
        ErAttribute(type: type, name: name, keys: keys, comment: comment)
    }

    public static func makeEntity(
        id: String,
        label: String,
        attributes: [ErAttribute] = []
    ) -> ErEntity {
        ErEntity(id: id, label: label, attributes: attributes)
    }

    public static func makeRelationship(
        entity1: String,
        entity2: String,
        cardinality1: Cardinality,
        cardinality2: Cardinality,
        label: String,
        identifying: Bool
    ) -> ErRelationship {
        ErRelationship(
            entity1: entity1,
            entity2: entity2,
            cardinality1: cardinality1,
            cardinality2: cardinality2,
            label: label,
            identifying: identifying
        )
    }

    public static func makeDiagram(
        entities: [ErEntity] = [],
        relationships: [ErRelationship] = []
    ) -> ErDiagram {
        ErDiagram(entities: entities, relationships: relationships)
    }

    // Export inventory from TypeScript source:
    // - export interface ErDiagram
    // - export interface ErEntity
    // - export interface ErAttribute
    // - export type Cardinality
    // - export interface ErRelationship
    // - export interface PositionedErDiagram
    // - export interface PositionedErEntity
    // - export interface PositionedErRelationship
}
