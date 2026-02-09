// SPDX-License-Identifier: MIT
//
//  SequenceTypes.swift
//  BeautifulMermaid
//
//  Data types specific to sequence diagrams
//

import Foundation
import CoreGraphics

// MARK: - Parsed Representation

/// A parsed sequence diagram
public struct SequenceDiagram: Sendable {
    public var actors: [SequenceActor]
    public var messages: [SequenceMessage]
    public var blocks: [SequenceBlock]
    public var notes: [SequenceNote]

    public init(
        actors: [SequenceActor] = [],
        messages: [SequenceMessage] = [],
        blocks: [SequenceBlock] = [],
        notes: [SequenceNote] = []
    ) {
        self.actors = actors
        self.messages = messages
        self.blocks = blocks
        self.notes = notes
    }
}

/// An actor (participant) in a sequence diagram
public struct SequenceActor: Identifiable, Sendable {
    public let id: String
    public var label: String
    public var type: ActorType

    public init(id: String, label: String, type: ActorType = .participant) {
        self.id = id
        self.label = label
        self.type = type
    }
}

/// Type of actor in a sequence diagram
public enum ActorType: String, Sendable {
    case participant  // Rectangle box
    case actor        // Stick figure
}

/// A message between actors in a sequence diagram
public struct SequenceMessage: Sendable {
    public let from: String
    public let to: String
    public var label: String
    public var lineStyle: SequenceLineStyle
    public var arrowHead: SequenceArrowHead
    public var activate: Bool      // + marker - activate target
    public var deactivate: Bool    // - marker - deactivate source

    public init(
        from: String,
        to: String,
        label: String = "",
        lineStyle: SequenceLineStyle = .solid,
        arrowHead: SequenceArrowHead = .filled,
        activate: Bool = false,
        deactivate: Bool = false
    ) {
        self.from = from
        self.to = to
        self.label = label
        self.lineStyle = lineStyle
        self.arrowHead = arrowHead
        self.activate = activate
        self.deactivate = deactivate
    }

    /// Whether this is a self-message (from == to)
    public var isSelfMessage: Bool {
        from == to
    }
}

/// Line style for sequence messages
public enum SequenceLineStyle: Sendable {
    case solid   // -
    case dashed  // --
}

/// Arrow head style for sequence messages
public enum SequenceArrowHead: Sendable {
    case filled  // >> (filled triangle)
    case open    // )  (open arrow)
    case cross   // x  (cross mark)
    case none    // >  (simple line, no head)
}

/// A block structure (loop, alt, opt, etc.) in a sequence diagram
public struct SequenceBlock: Sendable {
    public var type: SequenceBlockType
    public var label: String
    public var startIndex: Int      // First message index
    public var endIndex: Int        // Last message index
    public var dividers: [SequenceBlockDivider]  // else/and sections

    public init(
        type: SequenceBlockType,
        label: String,
        startIndex: Int,
        endIndex: Int,
        dividers: [SequenceBlockDivider] = []
    ) {
        self.type = type
        self.label = label
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.dividers = dividers
    }
}

/// Type of block in a sequence diagram
public enum SequenceBlockType: String, Sendable {
    case loop
    case alt
    case opt
    case par
    case critical
    case `break`
    case rect
}

/// A divider within a block (else in alt, and in par)
public struct SequenceBlockDivider: Sendable {
    public var afterIndex: Int  // Message index after which this divider appears
    public var label: String

    public init(afterIndex: Int, label: String) {
        self.afterIndex = afterIndex
        self.label = label
    }
}

/// A note in a sequence diagram
public struct SequenceNote: Sendable {
    public var actorIds: [String]
    public var text: String
    public var position: SequenceNotePosition
    public var afterIndex: Int  // Message index after which this note appears (-1 for before first)

    public init(
        actorIds: [String],
        text: String,
        position: SequenceNotePosition,
        afterIndex: Int = -1
    ) {
        self.actorIds = actorIds
        self.text = text
        self.position = position
        self.afterIndex = afterIndex
    }
}

/// Position of a note relative to actor(s)
public enum SequenceNotePosition: Sendable {
    case left   // Note left of actor
    case right  // Note right of actor
    case over   // Note over actor(s)
}

// MARK: - Positioned Representation (Layout Output)

/// A fully positioned sequence diagram ready for rendering
public struct PositionedSequenceDiagram: Sendable {
    public var width: CGFloat
    public var height: CGFloat
    public var actors: [PositionedActor]
    public var lifelines: [SequenceLifeline]
    public var messages: [PositionedSequenceMessage]
    public var activations: [SequenceActivation]
    public var blocks: [PositionedSequenceBlock]
    public var notes: [PositionedSequenceNote]

    public init(
        width: CGFloat = 0,
        height: CGFloat = 0,
        actors: [PositionedActor] = [],
        lifelines: [SequenceLifeline] = [],
        messages: [PositionedSequenceMessage] = [],
        activations: [SequenceActivation] = [],
        blocks: [PositionedSequenceBlock] = [],
        notes: [PositionedSequenceNote] = []
    ) {
        self.width = width
        self.height = height
        self.actors = actors
        self.lifelines = lifelines
        self.messages = messages
        self.activations = activations
        self.blocks = blocks
        self.notes = notes
    }

    /// Bounds of the diagram
    public var bounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }
}

/// A positioned actor box
public struct PositionedActor: Sendable {
    public var id: String
    public var label: String
    public var type: ActorType
    public var bounds: CGRect      // Box at top
    public var bottomBounds: CGRect // Box at bottom (optional, for diagrams that repeat)
    public var centerX: CGFloat    // Lifeline center X position

    public init(
        id: String,
        label: String,
        type: ActorType,
        bounds: CGRect,
        bottomBounds: CGRect = .zero,
        centerX: CGFloat
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.bounds = bounds
        self.bottomBounds = bottomBounds
        self.centerX = centerX
    }
}

/// A lifeline (vertical dashed line from actor)
public struct SequenceLifeline: Sendable {
    public var actorId: String
    public var x: CGFloat
    public var startY: CGFloat
    public var endY: CGFloat

    public init(actorId: String, x: CGFloat, startY: CGFloat, endY: CGFloat) {
        self.actorId = actorId
        self.x = x
        self.startY = startY
        self.endY = endY
    }
}

/// A positioned message with arrow path
public struct PositionedSequenceMessage: Sendable {
    public var from: String
    public var to: String
    public var label: String
    public var lineStyle: SequenceLineStyle
    public var arrowHead: SequenceArrowHead
    public var points: [CGPoint]       // Path points (2 for normal, 4 for self-message)
    public var labelPosition: CGPoint
    public var arrowAngle: CGFloat     // Angle for arrow head

    public init(
        from: String,
        to: String,
        label: String,
        lineStyle: SequenceLineStyle,
        arrowHead: SequenceArrowHead,
        points: [CGPoint],
        labelPosition: CGPoint,
        arrowAngle: CGFloat
    ) {
        self.from = from
        self.to = to
        self.label = label
        self.lineStyle = lineStyle
        self.arrowHead = arrowHead
        self.points = points
        self.labelPosition = labelPosition
        self.arrowAngle = arrowAngle
    }

    public var isSelfMessage: Bool {
        from == to
    }
}

/// An activation box on a lifeline
public struct SequenceActivation: Sendable {
    public var actorId: String
    public var bounds: CGRect
    public var depth: Int  // For nested activations

    public init(actorId: String, bounds: CGRect, depth: Int = 0) {
        self.actorId = actorId
        self.bounds = bounds
        self.depth = depth
    }
}

/// A positioned block (loop, alt, etc.)
public struct PositionedSequenceBlock: Sendable {
    public var type: SequenceBlockType
    public var label: String
    public var bounds: CGRect
    public var dividers: [PositionedBlockDivider]

    public init(
        type: SequenceBlockType,
        label: String,
        bounds: CGRect,
        dividers: [PositionedBlockDivider] = []
    ) {
        self.type = type
        self.label = label
        self.bounds = bounds
        self.dividers = dividers
    }
}

/// A positioned divider line within a block
public struct PositionedBlockDivider: Sendable {
    public var y: CGFloat
    public var label: String

    public init(y: CGFloat, label: String) {
        self.y = y
        self.label = label
    }
}

/// A positioned note
public struct PositionedSequenceNote: Sendable {
    public var text: String
    public var bounds: CGRect
    public var position: SequenceNotePosition

    public init(text: String, bounds: CGRect, position: SequenceNotePosition) {
        self.text = text
        self.bounds = bounds
        self.position = position
    }
}

// MARK: - Layout Constants

/// Constants for sequence diagram layout (matching TypeScript)
public struct SequenceConstants {
    /// Padding around the entire diagram
    public static let padding: CGFloat = 30

    /// Horizontal gap between actors
    public static let actorGap: CGFloat = 140

    /// Minimum actor box width
    public static let actorMinWidth: CGFloat = 80

    /// Actor box height
    public static let actorHeight: CGFloat = 40

    /// Gap between actor box and first message
    public static let headerGap: CGFloat = 20

    /// Vertical space per message row
    public static let messageRowHeight: CGFloat = 40

    /// Extra height for self-messages
    public static let selfMessageHeight: CGFloat = 30

    /// Width of activation boxes
    public static let activationWidth: CGFloat = 10

    /// Horizontal offset for nested activations
    public static let activationOffset: CGFloat = 4

    /// Horizontal padding inside blocks
    public static let blockPadX: CGFloat = 10

    /// Top padding in blocks (includes label)
    public static let blockPadTop: CGFloat = 40

    /// Bottom padding in blocks
    public static let blockPadBottom: CGFloat = 8

    /// Extra space for block header
    public static let blockHeaderExtra: CGFloat = 28

    /// Extra space for dividers (else/and)
    public static let dividerExtra: CGFloat = 24

    /// Note box width
    public static let noteWidth: CGFloat = 120

    /// Note box padding
    public static let notePadding: CGFloat = 8

    /// Horizontal extent of self-message loop
    public static let selfMessageWidth: CGFloat = 30

    /// Padding for actor labels
    public static let actorPadding: CGFloat = 16

    /// Gap between note and actor lifeline
    public static let noteGap: CGFloat = 10
}
