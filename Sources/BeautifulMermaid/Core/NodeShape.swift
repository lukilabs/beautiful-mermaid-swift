// SPDX-License-Identifier: MIT
//
//  NodeShape.swift
//  BeautifulMermaid
//
//  Node shape definitions for Mermaid diagrams
//

import Foundation
import CoreGraphics

/// All supported node shapes in Mermaid diagrams
public enum NodeShape: String, CaseIterable, Sendable {
    // Basic shapes
    case rectangle           // [text]
    case rounded             // (text)
    case stadium             // ([text])
    case circle              // ((text))
    case doublecircle        // (((text))) — concentric circles

    // Diamond/decision
    case diamond             // {text}
    case rhombus             // Alias for diamond

    // Hexagon variants
    case hexagon             // {{text}}

    // Parallelogram variants
    case parallelogram       // [/text/]
    case parallelogramAlt    // [\text\]

    // Trapezoid variants
    case trapezoid           // [/text\]
    case trapezoidAlt        // [\text/]

    // Cylinder (database)
    case cylinder            // [(text)]

    // Subroutine (double border)
    case subroutine          // [[text]]

    // Asymmetric (flag)
    case asymmetric          // >text]

    // State diagram special nodes
    case stateStart          // [*] at start
    case stateEnd            // [*] at end
    case stateFork           // Fork/join bar
    case stateChoice         // Choice diamond (smaller)
    case stateNote           // Note box

    // Class diagram
    case classBox            // Class with compartments

    // ER diagram
    case entity              // Entity rectangle

    // Special
    case invisible           // No visible shape

    /// Default padding for this shape type
    public var defaultPadding: CGSize {
        switch self {
        case .circle, .stateStart, .stateEnd:
            return CGSize(width: 8, height: 8)
        case .diamond, .rhombus, .stateChoice:
            return CGSize(width: 24, height: 16)
        case .hexagon:
            return CGSize(width: 20, height: 12)
        case .cylinder:
            return CGSize(width: 12, height: 20)
        case .stateFork:
            return CGSize(width: 4, height: 4)
        case .invisible:
            return .zero
        default:
            return CGSize(width: 16, height: 12)
        }
    }

    /// Whether this shape has a fixed aspect ratio
    public var hasFixedAspect: Bool {
        switch self {
        case .circle, .stateStart, .stateEnd, .stateChoice:
            return true
        default:
            return false
        }
    }

    /// The minimum size for this shape
    public var minimumSize: CGSize {
        switch self {
        case .stateStart, .stateEnd:
            return CGSize(width: 20, height: 20)
        case .stateChoice:
            return CGSize(width: 24, height: 24)
        case .stateFork:
            return CGSize(width: 60, height: 8)
        case .circle:
            return CGSize(width: 40, height: 40)
        default:
            return CGSize(width: 40, height: 30)
        }
    }
}

// MARK: - Shape Detection from Mermaid Syntax

extension NodeShape {
    /// Detect shape from Mermaid node definition syntax
    /// Returns the shape and the extracted label text
    public static func detect(from syntax: String) -> (shape: NodeShape, label: String)? {
        let trimmed = syntax.trimmingCharacters(in: .whitespaces)

        // Order matters - check longer patterns first
        // Using manual pattern matching for reliability

        // Stadium: ([text])
        if trimmed.hasPrefix("([") && trimmed.hasSuffix("])") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            if start < end {
                return (.stadium, String(trimmed[start..<end]))
            }
        }

        // Circle: ((text))
        if trimmed.hasPrefix("((") && trimmed.hasSuffix("))") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            if start < end {
                return (.circle, String(trimmed[start..<end]))
            }
        }

        // Cylinder: [(text)]
        if trimmed.hasPrefix("[(") && trimmed.hasSuffix(")]") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            if start < end {
                return (.cylinder, String(trimmed[start..<end]))
            }
        }

        // Subroutine: [[text]]
        if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            if start < end {
                return (.subroutine, String(trimmed[start..<end]))
            }
        }

        // Hexagon: {{text}}
        if trimmed.hasPrefix("{{") && trimmed.hasSuffix("}}") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            if start < end {
                return (.hexagon, String(trimmed[start..<end]))
            }
        }

        // Trapezoid: [/text\]
        if trimmed.hasPrefix("[/") && trimmed.hasSuffix("\\]") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            if start < end {
                return (.trapezoid, String(trimmed[start..<end]))
            }
        }

        // Trapezoid alt: [\text/]
        if trimmed.hasPrefix("[\\") && trimmed.hasSuffix("/]") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            if start < end {
                return (.trapezoidAlt, String(trimmed[start..<end]))
            }
        }

        // Parallelogram: [/text/]
        if trimmed.hasPrefix("[/") && trimmed.hasSuffix("/]") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            if start < end {
                return (.parallelogram, String(trimmed[start..<end]))
            }
        }

        // Parallelogram alt: [\text\]
        if trimmed.hasPrefix("[\\") && trimmed.hasSuffix("\\]") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            if start < end {
                return (.parallelogramAlt, String(trimmed[start..<end]))
            }
        }

        // Asymmetric: >text]
        if trimmed.hasPrefix(">") && trimmed.hasSuffix("]") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 1)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -1)
            if start < end {
                return (.asymmetric, String(trimmed[start..<end]))
            }
        }

        // Diamond: {text}
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") && !trimmed.hasPrefix("{{") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 1)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -1)
            if start < end {
                return (.diamond, String(trimmed[start..<end]))
            }
        }

        // Rounded: (text)
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") && !trimmed.hasPrefix("((") && !trimmed.hasPrefix("([") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 1)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -1)
            if start < end {
                return (.rounded, String(trimmed[start..<end]))
            }
        }

        // Rectangle: [text] (default)
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") && !trimmed.hasPrefix("[[") && !trimmed.hasPrefix("[(") && !trimmed.hasPrefix("[/") && !trimmed.hasPrefix("[\\") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 1)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -1)
            if start < end {
                let content = String(trimmed[start..<end])
                // Check for state start/end marker
                if content == "*" {
                    return (.stateStart, "")
                }
                return (.rectangle, content)
            }
        }

        return nil
    }
}
