// SPDX-License-Identifier: MIT
//
//  Direction.swift
//  BeautifulMermaid
//
//  Layout direction for diagram rendering
//

import Foundation

/// The direction of the diagram layout
public enum Direction: String, CaseIterable, Sendable {
    case topDown = "TD"
    case topToBottom = "TB"
    case bottomUp = "BU"
    case bottomToTop = "BT"
    case leftRight = "LR"
    case rightLeft = "RL"

    /// Normalized direction (TB/TD -> topDown, etc.)
    public var normalized: Direction {
        switch self {
        case .topDown, .topToBottom:
            return .topDown
        case .bottomUp, .bottomToTop:
            return .bottomUp
        case .leftRight:
            return .leftRight
        case .rightLeft:
            return .rightLeft
        }
    }

    /// Whether this is a horizontal layout
    public var isHorizontal: Bool {
        switch normalized {
        case .leftRight, .rightLeft:
            return true
        case .topDown, .bottomUp, .topToBottom, .bottomToTop:
            return false
        }
    }

    /// Whether this is a vertical layout
    public var isVertical: Bool {
        !isHorizontal
    }

    /// The angle in radians for edge arrows in this direction
    public var primaryAngle: CGFloat {
        switch normalized {
        case .topDown, .topToBottom:
            return .pi / 2  // Down
        case .bottomUp, .bottomToTop:
            return -.pi / 2  // Up
        case .leftRight:
            return 0  // Right
        case .rightLeft:
            return .pi  // Left
        }
    }

    /// Parse direction from Mermaid string
    public static func from(_ string: String) -> Direction? {
        let upper = string.uppercased().trimmingCharacters(in: .whitespaces)
        return Direction(rawValue: upper)
    }
}
