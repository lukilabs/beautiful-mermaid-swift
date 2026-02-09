// SPDX-License-Identifier: MIT
//
//  ErTypes.swift
//  BeautifulMermaid
//
//  EXACT PORT of original/src/er/types.ts
//  Models the parsed representation of a Mermaid ER diagram.
//

import Foundation

// MARK: - Parsed ER Diagram Types

/// Parsed ER diagram — logical structure from mermaid text
/// Port of: original/src/er/types.ts lines 8-14
public struct ErDiagram: Codable, Sendable {
    /// All entity definitions
    public var entities: [ErEntity]
    /// Relationships between entities
    public var relationships: [ErRelationship]

    public init(
        entities: [ErEntity] = [],
        relationships: [ErRelationship] = []
    ) {
        self.entities = entities
        self.relationships = relationships
    }
}

/// An entity in the ER diagram
/// Port of: original/src/er/types.ts lines 16-22
public struct ErEntity: Codable, Sendable {
    public let id: String
    /// Display name (same as id unless aliased)
    public var label: String
    /// Entity attributes (columns)
    public var attributes: [ErAttribute]

    public init(id: String, label: String, attributes: [ErAttribute] = []) {
        self.id = id
        self.label = label
        self.attributes = attributes
    }
}

/// An attribute (column) of an entity
/// Port of: original/src/er/types.ts lines 24-33
public struct ErAttribute: Codable, Sendable {
    /// Data type (string, int, varchar, etc.)
    public var type: String
    /// Attribute name
    public var name: String
    /// Key constraints: PK, FK, UK
    public var keys: [String]
    /// Optional comment
    public var comment: String?

    public init(type: String, name: String, keys: [String] = [], comment: String? = nil) {
        self.type = type
        self.name = name
        self.keys = keys
        self.comment = comment
    }
}

/// Cardinality notation (crow's foot)
/// Port of: original/src/er/types.ts lines 35-42
/// Values: "one", "zero-one", "many", "zero-many"
public enum ErCardinality: String, Codable, Sendable {
    case one = "one"          // ||  exactly one
    case zeroOne = "zero-one" // |o  zero or one
    case many = "many"        // }|  one or more
    case zeroMany = "zero-many" // o{  zero or more
}

/// A relationship between entities
/// Port of: original/src/er/types.ts lines 44-55
public struct ErRelationship: Codable, Sendable {
    public let entity1: String
    public let entity2: String
    /// Cardinality at entity1's end: "one", "zero-one", "many", "zero-many"
    public var cardinality1: String
    /// Cardinality at entity2's end
    public var cardinality2: String
    /// Relationship verb/label (e.g., "places", "contains")
    public var label: String
    /// Whether the relationship is identifying (solid line) or non-identifying (dashed)
    public var identifying: Bool

    public init(
        entity1: String,
        entity2: String,
        cardinality1: String,
        cardinality2: String,
        label: String,
        identifying: Bool
    ) {
        self.entity1 = entity1
        self.entity2 = entity2
        self.cardinality1 = cardinality1
        self.cardinality2 = cardinality2
        self.label = label
        self.identifying = identifying
    }
}

// MARK: - Positioned ER Diagram Types (for layout output)
// Port of: original/src/er/types.ts lines 61-91

/// Positioned ER diagram — ready for SVG rendering
public struct PositionedErDiagram: Codable, Sendable {
    public var width: CGFloat
    public var height: CGFloat
    public var entities: [PositionedErEntity]
    public var relationships: [PositionedErRelationship]

    public init(width: CGFloat, height: CGFloat, entities: [PositionedErEntity], relationships: [PositionedErRelationship]) {
        self.width = width
        self.height = height
        self.entities = entities
        self.relationships = relationships
    }

    /// Bounds of the diagram
    public var bounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }
}

/// Positioned entity with layout coordinates
public struct PositionedErEntity: Codable, Sendable {
    public let id: String
    public var label: String
    public var attributes: [ErAttribute]
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    /// Height of the header row
    public var headerHeight: CGFloat
    /// Height per attribute row
    public var rowHeight: CGFloat

    public init(
        id: String,
        label: String,
        attributes: [ErAttribute],
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        headerHeight: CGFloat,
        rowHeight: CGFloat
    ) {
        self.id = id
        self.label = label
        self.attributes = attributes
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.headerHeight = headerHeight
        self.rowHeight = rowHeight
    }
}

/// Positioned relationship with path points
public struct PositionedErRelationship: Codable, Sendable {
    public let entity1: String
    public let entity2: String
    public var cardinality1: String
    public var cardinality2: String
    public var label: String
    public var identifying: Bool
    /// Path points from entity1 to entity2
    public var points: [CGPoint]

    public init(
        entity1: String,
        entity2: String,
        cardinality1: String,
        cardinality2: String,
        label: String,
        identifying: Bool,
        points: [CGPoint]
    ) {
        self.entity1 = entity1
        self.entity2 = entity2
        self.cardinality1 = cardinality1
        self.cardinality2 = cardinality2
        self.label = label
        self.identifying = identifying
        self.points = points
    }
}
