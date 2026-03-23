// Ported from original/src/class/types.ts
import Foundation
import ElkSwift

public typealias ClassDiagramModel = ClassDiagram
public typealias ClassNodeModel = ClassNode
public typealias ClassMemberModel = ClassMember
public typealias ClassRelationshipModel = ClassRelationship
public typealias ClassNamespaceModel = ClassNamespace
public typealias PositionedClassDiagramModel = PositionedClassDiagram
public typealias PositionedClassNodeModel = PositionedClassNode
public typealias PositionedClassRelationshipModel = PositionedClassRelationship
public typealias ClassRelationshipType = RelationshipType

open class original_src_class_types {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    public static func makeMember(
        visibility: String = "",
        name: String,
        type: String? = nil,
        isStatic: Bool = false,
        isAbstract: Bool = false,
        isMethod: Bool = false,
        params: String? = nil
    ) -> ClassMember {
        ClassMember(
            visibility: visibility,
            name: name,
            type: type,
            isStatic: isStatic,
            isAbstract: isAbstract,
            isMethod: isMethod,
            params: params
        )
    }

    public static func makeNode(
        id: String,
        label: String,
        attributes: [ClassMember] = [],
        methods: [ClassMember] = [],
        annotation: String? = nil
    ) -> ClassNode {
        ClassNode(id: id, label: label, attributes: attributes, methods: methods, annotation: annotation)
    }

    public static func makeRelationship(
        from: String,
        to: String,
        type: RelationshipType,
        markerAt: String,
        label: String? = nil,
        fromCardinality: String? = nil,
        toCardinality: String? = nil
    ) -> ClassRelationship {
        ClassRelationship(
            from: from,
            to: to,
            type: type,
            markerAt: markerAt,
            label: label,
            fromCardinality: fromCardinality,
            toCardinality: toCardinality
        )
    }

    public static func toAsciiDiagram(_ diagram: ClassDiagram) -> AsciiClassDiagram {
        AsciiClassDiagram(
            classes: diagram.classes.map { node in
                AsciiClassNode(
                    id: node.id,
                    label: node.label,
                    annotation: node.annotation,
                    attributes: node.attributes.map {
                        AsciiClassMember(
                            visibility: $0.visibility.isEmpty ? nil : $0.visibility,
                            name: $0.isMethod ? "\($0.name)(\($0.params ?? ""))" : $0.name,
                            type: $0.type
                        )
                    },
                    methods: node.methods.map {
                        AsciiClassMember(
                            visibility: $0.visibility.isEmpty ? nil : $0.visibility,
                            name: $0.isMethod ? "\($0.name)(\($0.params ?? ""))" : $0.name,
                            type: $0.type
                        )
                    }
                )
            },
            relationships: diagram.relationships.compactMap { rel in
                guard let relType = AsciiClassRelationshipType(rawValue: rel.type.lowercased()) else {
                    return nil
                }
                return AsciiClassRelationship(
                    from: rel.from,
                    to: rel.to,
                    type: relType,
                    markerAt: rel.markerAt,
                    label: rel.label
                )
            }
        )
    }

    // Export inventory from TypeScript source:
    // - export interface ClassDiagram
    // - export interface ClassNode
    // - export interface ClassMember
    // - export type RelationshipType
    // - export interface ClassRelationship
    // - export interface ClassNamespace
    // - export interface PositionedClassDiagram
    // - export interface PositionedClassNode
    // - export interface PositionedClassRelationship
}
