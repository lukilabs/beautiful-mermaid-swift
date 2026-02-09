// SPDX-License-Identifier: MIT
//
//  ClassTypes.swift
//  BeautifulMermaid
//
//  EXACT PORT of original/src/class/types.ts
//  Models the parsed representation of a Mermaid class diagram.
//

import Foundation

// MARK: - Parsed Class Diagram Types

/// Parsed class diagram — logical structure from mermaid text
/// Port of: original/src/class/types.ts lines 8-16
public struct ClassDiagram: Codable, Sendable {
    /// All class definitions
    public var classes: [ClassNode]
    /// Relationships between classes
    public var relationships: [ClassRelationship]
    /// Optional namespace groupings
    public var namespaces: [ClassNamespace]

    public init(
        classes: [ClassNode] = [],
        relationships: [ClassRelationship] = [],
        namespaces: [ClassNamespace] = []
    ) {
        self.classes = classes
        self.relationships = relationships
        self.namespaces = namespaces
    }
}

/// A class node in the diagram
/// Port of: original/src/class/types.ts lines 18-27
public struct ClassNode: Codable, Sendable {
    public let id: String
    public var label: String
    /// Annotation like <<interface>>, <<abstract>>, <<service>>, <<enumeration>>
    public var annotation: String?
    /// Class attributes (fields/properties)
    public var attributes: [ClassDiagramMember]
    /// Class methods (functions)
    public var methods: [ClassDiagramMember]

    public init(
        id: String,
        label: String,
        annotation: String? = nil,
        attributes: [ClassDiagramMember] = [],
        methods: [ClassDiagramMember] = []
    ) {
        self.id = id
        self.label = label
        self.annotation = annotation
        self.attributes = attributes
        self.methods = methods
    }
}

/// A member (attribute or method) of a class in the class diagram
/// Port of: original/src/class/types.ts lines 29-40
/// Note: Named ClassDiagramMember to avoid conflict with existing ClassMember in Types.swift
public struct ClassDiagramMember: Codable, Sendable {
    /// Visibility: + public, - private, # protected, ~ package
    public var visibility: String  // '+' | '-' | '#' | '~' | ''
    /// Member name
    public var name: String
    /// Type annotation (e.g., "String", "int", "void")
    public var type: String?
    /// Whether the member is static (underlined in UML)
    public var isStatic: Bool
    /// Whether the member is abstract (italic in UML)
    public var isAbstract: Bool

    public init(
        visibility: String = "",
        name: String,
        type: String? = nil,
        isStatic: Bool = false,
        isAbstract: Bool = false
    ) {
        self.visibility = visibility
        self.name = name
        self.type = type
        self.isStatic = isStatic
        self.isAbstract = isAbstract
    }
}

/// Relationship types following UML conventions
/// Port of: original/src/class/types.ts lines 42-49
public enum ClassRelationshipType: String, Codable, Sendable {
    case inheritance   // A <|-- B   (solid line, hollow triangle)
    case composition   // A *-- B    (solid line, filled diamond)
    case aggregation   // A o-- B    (solid line, hollow diamond)
    case association   // A --> B    (solid line, open arrow)
    case dependency    // A ..> B    (dashed line, open arrow)
    case realization   // A ..|> B   (dashed line, hollow triangle)
}

/// A relationship between classes
/// Port of: original/src/class/types.ts lines 51-68
public struct ClassRelationship: Codable, Sendable {
    public let from: String
    public let to: String
    /// RelationshipType: inheritance, composition, aggregation, association, dependency, realization
    public var type: String
    /// Which end of the relationship line has the UML marker (triangle, diamond, arrow).
    /// Determined by the arrow syntax direction:
    ///   - Prefix markers like `<|--`, `*--`, `o--` → 'from' (marker on left/from side)
    ///   - Suffix markers like `..|>`, `-->`, `..>`, `--*`, `--o` → 'to' (marker on right/to side)
    public var markerAt: String  // 'from' | 'to'
    /// Label on the relationship line
    public var label: String?
    /// Cardinality at the "from" end (e.g., "1", "*", "0..1")
    public var fromCardinality: String?
    /// Cardinality at the "to" end
    public var toCardinality: String?

    public init(
        from: String,
        to: String,
        type: String,
        markerAt: String,
        label: String? = nil,
        fromCardinality: String? = nil,
        toCardinality: String? = nil
    ) {
        self.from = from
        self.to = to
        self.type = type
        self.markerAt = markerAt
        self.label = label
        self.fromCardinality = fromCardinality
        self.toCardinality = toCardinality
    }
}

/// A namespace grouping of classes
/// Port of: original/src/class/types.ts lines 70-73
public struct ClassNamespace: Codable, Sendable {
    public var name: String
    public var classIds: [String]

    public init(name: String, classIds: [String] = []) {
        self.name = name
        self.classIds = classIds
    }
}

// MARK: - Positioned Class Diagram Types (for layout output)
// Port of: original/src/class/types.ts lines 79-117

/// Positioned class diagram — ready for SVG rendering
public struct PositionedClassDiagram: Codable, Sendable {
    public var width: CGFloat
    public var height: CGFloat
    public var classes: [PositionedClassNode]
    public var relationships: [PositionedClassRelationship]

    public init(width: CGFloat, height: CGFloat, classes: [PositionedClassNode], relationships: [PositionedClassRelationship]) {
        self.width = width
        self.height = height
        self.classes = classes
        self.relationships = relationships
    }

    /// Bounds of the diagram
    public var bounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }
}

/// Positioned class node with layout coordinates
public struct PositionedClassNode: Codable, Sendable {
    public let id: String
    public var label: String
    public var annotation: String?
    public var attributes: [ClassDiagramMember]
    public var methods: [ClassDiagramMember]
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    /// Height of the header section (name + annotation)
    public var headerHeight: CGFloat
    /// Height of the attributes section
    public var attrHeight: CGFloat
    /// Height of the methods section
    public var methodHeight: CGFloat

    public init(
        id: String,
        label: String,
        annotation: String? = nil,
        attributes: [ClassDiagramMember],
        methods: [ClassDiagramMember],
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        headerHeight: CGFloat,
        attrHeight: CGFloat,
        methodHeight: CGFloat
    ) {
        self.id = id
        self.label = label
        self.annotation = annotation
        self.attributes = attributes
        self.methods = methods
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.headerHeight = headerHeight
        self.attrHeight = attrHeight
        self.methodHeight = methodHeight
    }
}

/// Positioned class relationship with path points
public struct PositionedClassRelationship: Codable, Sendable {
    public let from: String
    public let to: String
    public var type: String
    /// Which end of the line has the UML marker — propagated from ClassRelationship
    public var markerAt: String
    public var label: String?
    public var fromCardinality: String?
    public var toCardinality: String?
    /// Path points from source to target
    public var points: [CGPoint]
    /// Dagre-computed label center position (avoids overlaps between nearby edges)
    public var labelPosition: CGPoint?

    public init(
        from: String,
        to: String,
        type: String,
        markerAt: String,
        label: String? = nil,
        fromCardinality: String? = nil,
        toCardinality: String? = nil,
        points: [CGPoint],
        labelPosition: CGPoint? = nil
    ) {
        self.from = from
        self.to = to
        self.type = type
        self.markerAt = markerAt
        self.label = label
        self.fromCardinality = fromCardinality
        self.toCardinality = toCardinality
        self.points = points
        self.labelPosition = labelPosition
    }
}

