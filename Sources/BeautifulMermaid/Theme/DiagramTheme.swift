// SPDX-License-Identifier: MIT
//
//  DiagramTheme.swift
//  BeautifulMermaid
//
//  Theme configuration for diagram rendering
//

import Foundation
import CoreGraphics

/// Theme configuration for diagram rendering
public struct DiagramTheme: Sendable {
    /// Background color
    public var background: BMColor

    /// Primary foreground/text color
    public var foreground: BMColor

    /// Line/edge color (defaults to foreground with alpha)
    public var line: BMColor?

    /// Accent color for arrows, highlights
    public var accent: BMColor?

    /// Muted color for secondary elements
    public var muted: BMColor?

    /// Surface color for node fills
    public var surface: BMColor?

    /// Border color for node strokes
    public var border: BMColor?

    /// Font for labels
    public var font: BMFont

    /// Line width for edges
    public var lineWidth: CGFloat

    /// Node corner radius (where applicable)
    public var cornerRadius: CGFloat

    public init(
        background: BMColor,
        foreground: BMColor,
        line: BMColor? = nil,
        accent: BMColor? = nil,
        muted: BMColor? = nil,
        surface: BMColor? = nil,
        border: BMColor? = nil,
        font: BMFont = BMFont.systemFont(ofSize: 14),
        lineWidth: CGFloat = 1.5,
        cornerRadius: CGFloat = 8
    ) {
        self.background = background
        self.foreground = foreground
        self.line = line
        self.accent = accent
        self.muted = muted
        self.surface = surface
        self.border = border
        self.font = font
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
    }

    // MARK: - Derived Colors

    /// Effective line color - 30% blend of foreground into background
    public func effectiveLine() -> BMColor {
        line ?? background.mixed(with: foreground, amount: ColorMix.line)
    }

    /// Effective accent color
    public func effectiveAccent() -> BMColor {
        accent ?? foreground
    }

    /// Effective muted color (edge labels) - 40% blend
    public func effectiveMuted() -> BMColor {
        muted ?? background.mixed(with: foreground, amount: ColorMix.textMuted)
    }

    /// Effective surface color (node fills) - 3% blend
    public func effectiveSurface() -> BMColor {
        surface ?? background.mixed(with: foreground, amount: ColorMix.nodeFill)
    }

    /// Effective border color (node strokes) - 20% blend
    public func effectiveBorder() -> BMColor {
        border ?? background.mixed(with: foreground, amount: ColorMix.nodeStroke)
    }

    /// Secondary text color (for group headers) - 60% blend
    public func effectiveTextSecondary() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.textSec)
    }

    /// Faint text color (de-emphasized elements) - 25% blend
    public func effectiveTextFaint() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.textFaint)
    }

    /// Arrow head fill color - uses accent or 50% blend
    public func effectiveArrow() -> BMColor {
        accent ?? background.mixed(with: foreground, amount: ColorMix.arrow)
    }

    /// Inner stroke color (dividers within shapes) - 12% blend
    public func effectiveInnerStroke() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.innerStroke)
    }

    // MARK: - Color for Specific Elements

    /// Color for edge lines
    public func edgeColor(for style: EdgeStyle) -> BMColor {
        if let colorHex = style.color {
            return BMColor(hex: colorHex)
        }
        return effectiveLine()
    }

    /// Color for node fill
    public func nodeFillColor(for node: MermaidNode) -> BMColor {
        // Check for inline style
        if let fillHex = node.inlineStyles["fill"] {
            return BMColor(hex: fillHex)
        }
        return effectiveSurface()
    }

    /// Color for node stroke
    public func nodeStrokeColor(for node: MermaidNode) -> BMColor {
        if let strokeHex = node.inlineStyles["stroke"] {
            return BMColor(hex: strokeHex)
        }
        return effectiveBorder()
    }

    /// Color for node text
    public func nodeTextColor(for node: MermaidNode) -> BMColor {
        if let colorHex = node.inlineStyles["color"] {
            return BMColor(hex: colorHex)
        }
        return foreground
    }

    /// Color for subgraph background - pure background (matches TypeScript --_group-fill: var(--bg))
    public func subgraphBackgroundColor() -> BMColor {
        background
    }

    /// Color for subgraph header - 5% blend
    public func subgraphHeaderColor() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.groupHeader)
    }

    /// Color for key badges (PK/FK/UK in ER diagrams) - 10% blend
    public func keyBadgeColor() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.keyBadge)
    }
}

// MARK: - Theme Modifications

extension DiagramTheme {
    /// Create a copy with modified background
    public func withBackground(_ color: BMColor) -> DiagramTheme {
        var copy = self
        copy.background = color
        return copy
    }

    /// Create a copy with modified foreground
    public func withForeground(_ color: BMColor) -> DiagramTheme {
        var copy = self
        copy.foreground = color
        return copy
    }

    /// Create a copy with modified accent
    public func withAccent(_ color: BMColor) -> DiagramTheme {
        var copy = self
        copy.accent = color
        return copy
    }

    /// Create a copy with modified font
    public func withFont(_ font: BMFont) -> DiagramTheme {
        var copy = self
        copy.font = font
        return copy
    }

    /// Create a copy with modified line width
    public func withLineWidth(_ width: CGFloat) -> DiagramTheme {
        var copy = self
        copy.lineWidth = width
        return copy
    }
}
