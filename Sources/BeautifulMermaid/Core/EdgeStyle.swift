// SPDX-License-Identifier: MIT
//
//  EdgeStyle.swift
//  BeautifulMermaid
//
//  Edge/arrow style definitions for Mermaid diagrams
//

import Foundation
import CoreGraphics

/// Line style for edges
public enum LineStyle: String, CaseIterable, Sendable {
    case solid
    case dotted
    case dashed
    case thick

    /// The dash pattern for CoreGraphics
    public var dashPattern: [CGFloat]? {
        switch self {
        case .solid, .thick:
            return nil
        case .dotted:
            return [2, 4]
        case .dashed:
            return [8, 4]
        }
    }

    /// Line width multiplier
    public var widthMultiplier: CGFloat {
        switch self {
        case .thick:
            return 2.0
        default:
            return 1.0
        }
    }
}

/// Arrow head style
public enum ArrowHead: String, CaseIterable, Sendable {
    case none
    case arrow       // Standard arrow >
    case open        // Open arrow (no fill)
    case circle      // Circle marker o
    case cross       // X marker
    case diamond     // Diamond marker (inheritance)

    /// Size of the arrow head relative to line width
    public var sizeMultiplier: CGFloat {
        switch self {
        case .none:
            return 0
        case .circle, .cross:
            return 4
        case .arrow, .open:
            return 6
        case .diamond:
            return 8
        }
    }
}

/// Complete edge style definition
public struct EdgeStyle: Sendable {
    public var lineStyle: LineStyle
    public var sourceArrow: ArrowHead
    public var targetArrow: ArrowHead
    public var color: String?  // Optional color override (hex)

    public init(
        lineStyle: LineStyle = .solid,
        sourceArrow: ArrowHead = .none,
        targetArrow: ArrowHead = .arrow,
        color: String? = nil
    ) {
        self.lineStyle = lineStyle
        self.sourceArrow = sourceArrow
        self.targetArrow = targetArrow
        self.color = color
    }

    // Common presets
    public static let solidArrow = EdgeStyle(lineStyle: .solid, targetArrow: .arrow)
    public static let solidLine = EdgeStyle(lineStyle: .solid, targetArrow: .none)
    public static let dottedArrow = EdgeStyle(lineStyle: .dotted, targetArrow: .arrow)
    public static let dashedArrow = EdgeStyle(lineStyle: .dashed, targetArrow: .arrow)
    public static let thickArrow = EdgeStyle(lineStyle: .thick, targetArrow: .arrow)
    public static let bidirectional = EdgeStyle(lineStyle: .solid, sourceArrow: .arrow, targetArrow: .arrow)
}

// MARK: - Edge Detection from Mermaid Syntax

extension EdgeStyle {
    /// Parse edge style from Mermaid arrow syntax
    /// Returns the style and any label text
    public static func parse(from arrow: String) -> (style: EdgeStyle, label: String?) {
        var style = EdgeStyle()
        var label: String? = nil

        // Check for label: -->|label| or -- label -->
        if let pipeRange = arrow.range(of: "|"),
           let endPipeRange = arrow.range(of: "|", range: arrow.index(after: pipeRange.lowerBound)..<arrow.endIndex) {
            let labelStart = arrow.index(after: pipeRange.lowerBound)
            let labelEnd = endPipeRange.lowerBound
            label = String(arrow[labelStart..<labelEnd]).trimmingCharacters(in: .whitespaces)
        }

        // Determine arrow type (order matters - check longer patterns first)

        // Bidirectional: <-->
        if arrow.contains("<-->") {
            style.lineStyle = .solid
            style.sourceArrow = .arrow
            style.targetArrow = .arrow
        }
        // Thick line: ==>
        else if arrow.contains("==>") {
            style.lineStyle = .thick
            style.targetArrow = .arrow
        }
        // Thick line no arrow: ===
        else if arrow.contains("===") {
            style.lineStyle = .thick
            style.targetArrow = .none
        }
        // Dotted with arrow: -.->
        else if arrow.contains("-.->") {
            style.lineStyle = .dotted
            style.targetArrow = .arrow
        }
        // Dotted no arrow: -.-
        else if arrow.contains("-.-") {
            style.lineStyle = .dotted
            style.targetArrow = .none
        }
        // Dashed with arrow (long): ---->
        else if arrow.contains("---->") {
            style.lineStyle = .dashed
            style.targetArrow = .arrow
        }
        // Normal arrow: -->
        else if arrow.contains("-->") {
            style.lineStyle = .solid
            style.targetArrow = .arrow
        }
        // Open arrow: --o
        else if arrow.contains("--o") {
            style.lineStyle = .solid
            style.targetArrow = .circle
        }
        // Reverse arrow: <--
        else if arrow.contains("<--") {
            style.lineStyle = .solid
            style.sourceArrow = .arrow
            style.targetArrow = .none
        }
        // No arrow: ---
        else if arrow.contains("---") {
            style.lineStyle = .solid
            style.targetArrow = .none
        }

        return (style, label)
    }
}
