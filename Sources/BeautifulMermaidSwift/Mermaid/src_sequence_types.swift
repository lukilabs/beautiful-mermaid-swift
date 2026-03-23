// Ported from original/src/sequence/types.ts
import Foundation
import ElkSwift

public typealias Actor = SequenceActor
public typealias Message = SequenceMessage
public typealias Block = SequenceBlock
public typealias Note = SequenceNote
public typealias PositionedActor = PositionedSequenceActor
public typealias Lifeline = SequenceLifeline
public typealias PositionedMessage = PositionedSequenceMessage
public typealias Activation = SequenceActivation
public typealias PositionedBlock = PositionedSequenceBlock
public typealias PositionedNote = PositionedSequenceNote

open class original_src_sequence_types {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    public static func makeActor(id: String, label: String, type: String = "participant") -> SequenceActor {
        SequenceActor(id: id, label: label, type: type)
    }

    public static func makeMessage(
        from: String,
        to: String,
        label: String,
        lineStyle: String = "solid",
        arrowHead: String = "open",
        activate: Bool = false,
        deactivate: Bool = false
    ) -> SequenceMessage {
        SequenceMessage(
            from: from,
            to: to,
            label: label,
            lineStyle: lineStyle,
            arrowHead: arrowHead,
            activate: activate,
            deactivate: deactivate
        )
    }

    public static func makeDiagram(
        actors: [SequenceActor] = [],
        messages: [SequenceMessage] = [],
        blocks: [SequenceBlock] = [],
        notes: [SequenceNote] = []
    ) -> SequenceDiagram {
        SequenceDiagram(actors: actors, messages: messages, blocks: blocks, notes: notes)
    }

    // Export inventory from TypeScript source:
    // - export interface SequenceDiagram
    // - export interface Actor
    // - export interface Message
    // - export interface Block
    // - export interface Note
    // - export interface PositionedSequenceDiagram
    // - export interface PositionedActor
    // - export interface Lifeline
    // - export interface PositionedMessage
    // - export interface Activation
    // - export interface PositionedBlock
    // - export interface PositionedNote
}
