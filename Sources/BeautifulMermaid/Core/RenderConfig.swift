// SPDX-License-Identifier: MIT
//
//  RenderConfig.swift
//  BeautifulMermaid
//
//  Configuration object for rendering constants
//  Ported from beautiful-mermaid TypeScript styles.ts
//

import Foundation
import CoreGraphics

/// Configuration for rendering mermaid diagrams
/// All values match the original beautiful-mermaid TypeScript implementation
public struct RenderConfig: Sendable {

    // MARK: - Singleton

    /// Shared default configuration
    public static var shared = RenderConfig()

    // MARK: - Node Padding

    /// Horizontal padding inside rectangles/rounded/stadium
    public var nodePaddingHorizontal: CGFloat = 16

    /// Vertical padding inside rectangles/rounded/stadium
    public var nodePaddingVertical: CGFloat = 10

    /// Extra padding for diamond shapes (they need more space due to rotation)
    public var nodePaddingDiamondExtra: CGFloat = 24

    /// Convenience accessor for node padding as CGSize
    public var nodePadding: CGSize {
        CGSize(width: nodePaddingHorizontal, height: nodePaddingVertical)
    }

    // MARK: - Font Sizes

    /// Node label text size in points
    public var fontSizeNodeLabel: CGFloat = 13

    /// Edge label text size in points
    public var fontSizeEdgeLabel: CGFloat = 11

    /// Subgraph header text size in points
    public var fontSizeGroupHeader: CGFloat = 12

    // MARK: - Font Weights

    /// Font weight for node labels (500 = medium)
    public var fontWeightNodeLabel: Int = 500

    /// Font weight for edge labels (400 = regular)
    public var fontWeightEdgeLabel: Int = 400

    /// Font weight for group headers (600 = semibold)
    public var fontWeightGroupHeader: Int = 600

    // MARK: - Stroke Widths

    /// Stroke width for outer box (subgraph borders)
    public var strokeWidthOuterBox: CGFloat = 1.0

    /// Stroke width for inner box (node borders)
    public var strokeWidthInnerBox: CGFloat = 0.75

    /// Stroke width for connectors (edges)
    public var strokeWidthConnector: CGFloat = 0.75

    // MARK: - Arrow Head

    /// Arrow head width in points
    public var arrowHeadWidth: CGFloat = 8.0

    /// Arrow head height in points
    public var arrowHeadHeight: CGFloat = 4.8

    // MARK: - Spacing

    /// Vertical gap between subgraph header band and content area
    public var groupHeaderContentPad: CGFloat = 8.0

    /// Padding inside subgraph boxes (around the content)
    public var subgraphPadding: CGFloat = 24

    /// Default node spacing (horizontal gap between nodes in same rank)
    public var nodeSpacing: CGFloat = 24

    /// Default layer/rank spacing (vertical gap between ranks)
    public var layerSpacing: CGFloat = 40

    /// Default margin/padding around the entire graph
    public var graphPadding: CGFloat = 40

    // MARK: - Text Rendering

    /// Vertical shift for text baseline centering (in em units)
    /// Using 0.35em places the optical center of text at the y coordinate
    public var textBaselineShiftEm: CGFloat = 0.35

    // MARK: - Minimum Sizes

    /// Minimum node width for aesthetics
    public var minimumNodeWidth: CGFloat = 60

    /// Minimum node height for aesthetics
    public var minimumNodeHeight: CGFloat = 36

    /// Fixed size for state diagram pseudostates (start/end)
    public var statePseudostateSize: CGFloat = 28

    // MARK: - Shape-specific

    /// Cylinder ellipse vertical radius for the cap
    public var cylinderEllipseRadius: CGFloat = 7

    /// Subroutine vertical line inset from edge
    public var subroutineInset: CGFloat = 8

    /// Asymmetric shape left indent
    public var asymmetricIndent: CGFloat = 12

    /// Double circle gap between rings
    public var doubleCircleGap: CGFloat = 5

    // MARK: - Edge Labels

    /// Padding inside edge label background pill
    public var edgeLabelPadding: CGFloat = 8

    /// Corner radius for edge label background
    public var edgeLabelCornerRadius: CGFloat = 4

    /// Stroke width for edge label background border
    public var edgeLabelBorderWidth: CGFloat = 0.5

    // MARK: - Sequence Diagram Constants (matching TypeScript)

    /// Self-message loop height
    public var sequenceLoopH: CGFloat = 20

    /// Block tab height (for alt/loop labels)
    public var sequenceTabHeight: CGFloat = 18

    /// Note corner fold size
    public var sequenceFoldSize: CGFloat = 6

    // MARK: - Class Diagram Constants (CLS.* from TypeScript)

    /// Class diagram padding
    public var classPadding: CGFloat = 40

    /// Horizontal padding inside class boxes
    public var classBoxPadX: CGFloat = 8

    /// Base height for class header (name section)
    public var classHeaderBaseHeight: CGFloat = 32

    /// Height for annotation row (<<interface>>, etc.)
    public var classAnnotationHeight: CGFloat = 16

    /// Height per member row
    public var classMemberRowHeight: CGFloat = 20

    /// Vertical padding for sections (attributes, methods)
    public var classSectionPadY: CGFloat = 8

    /// Height for empty sections
    public var classEmptySectionHeight: CGFloat = 8

    /// Minimum width for class boxes
    public var classMinWidth: CGFloat = 120

    /// Font size for class members
    public var classMemberFontSize: CGFloat = 11

    /// Font weight for class members
    public var classMemberFontWeight: Int = 400

    /// Node spacing for class diagrams
    public var classNodeSpacing: CGFloat = 40

    /// Layer spacing for class diagrams
    public var classLayerSpacing: CGFloat = 60

    // MARK: - ER Diagram Constants (ER.* from TypeScript)

    /// ER diagram padding
    public var erPadding: CGFloat = 40

    /// Horizontal padding inside entity boxes
    public var erBoxPadX: CGFloat = 12

    /// Entity header height
    public var erHeaderHeight: CGFloat = 32

    /// Row height for attributes
    public var erRowHeight: CGFloat = 22

    /// Minimum width for entity boxes
    public var erMinWidth: CGFloat = 140

    /// Font size for attributes
    public var erAttrFontSize: CGFloat = 11

    // MARK: - Initialization

    public init() {}

    // MARK: - Font Helpers

    /// Get UIFont/NSFont weight from integer weight value
    public func fontWeight(from weight: Int) -> BMFont.Weight {
        switch weight {
        case 100: return .ultraLight
        case 200: return .thin
        case 300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        case 900: return .black
        default: return .regular
        }
    }

    /// Create a font for node labels
    public func nodeLabelFont(family: String? = nil) -> BMFont {
        if let family = family {
            return BMFont(name: family, size: fontSizeNodeLabel) ?? BMFont.systemFont(ofSize: fontSizeNodeLabel, weight: fontWeight(from: fontWeightNodeLabel))
        }
        return BMFont.systemFont(ofSize: fontSizeNodeLabel, weight: fontWeight(from: fontWeightNodeLabel))
    }

    /// Create a font for edge labels
    public func edgeLabelFont(family: String? = nil) -> BMFont {
        if let family = family {
            return BMFont(name: family, size: fontSizeEdgeLabel) ?? BMFont.systemFont(ofSize: fontSizeEdgeLabel, weight: fontWeight(from: fontWeightEdgeLabel))
        }
        return BMFont.systemFont(ofSize: fontSizeEdgeLabel, weight: fontWeight(from: fontWeightEdgeLabel))
    }

    /// Create a font for group headers
    public func groupHeaderFont(family: String? = nil) -> BMFont {
        if let family = family {
            return BMFont(name: family, size: fontSizeGroupHeader) ?? BMFont.systemFont(ofSize: fontSizeGroupHeader, weight: fontWeight(from: fontWeightGroupHeader))
        }
        return BMFont.systemFont(ofSize: fontSizeGroupHeader, weight: fontWeight(from: fontWeightGroupHeader))
    }
}

// MARK: - Color Mixing Weights

/// Color mixing weights for derived CSS-like variables
/// When an optional color is not set, these percentages determine
/// how much foreground color is mixed into the background
public struct ColorMix: Sendable {
    /// Primary text: near-full fg (100%)
    public static let text: CGFloat = 1.0

    /// Secondary text (group headers): fg mixed at 60%
    public static let textSec: CGFloat = 0.60

    /// Muted text (edge labels, notes): fg mixed at 40%
    public static let textMuted: CGFloat = 0.40

    /// Faint text (de-emphasized): fg mixed at 25%
    public static let textFaint: CGFloat = 0.25

    /// Edge/connector lines: fg mixed at 30%
    public static let line: CGFloat = 0.30

    /// Arrow head fill: fg mixed at 50%
    public static let arrow: CGFloat = 0.50

    /// Node fill tint: fg mixed at 3%
    public static let nodeFill: CGFloat = 0.03

    /// Node/group stroke: fg mixed at 20%
    public static let nodeStroke: CGFloat = 0.20

    /// Group header band tint: fg mixed at 5%
    public static let groupHeader: CGFloat = 0.05

    /// Inner divider strokes: fg mixed at 12%
    public static let innerStroke: CGFloat = 0.12

    /// Key badge background opacity (ER diagrams): fg mixed at 10%
    public static let keyBadge: CGFloat = 0.10
}

// MARK: - Text Width Estimation

extension RenderConfig {
    /// Estimate text width using character-based approximation
    /// Matching original TypeScript: estimateTextWidth()
    ///
    /// Inter average character widths as fraction of fontSize, per weight:
    /// - weight >= 600: 0.58
    /// - weight >= 500: 0.55
    /// - weight < 500:  0.52
    public func estimateTextWidth(_ text: String, fontSize: CGFloat, fontWeight: Int) -> CGFloat {
        let widthRatio: CGFloat
        if fontWeight >= 600 {
            widthRatio = 0.58
        } else if fontWeight >= 500 {
            widthRatio = 0.55
        } else {
            widthRatio = 0.52
        }
        return CGFloat(text.count) * fontSize * widthRatio
    }

    /// Estimate text width for monospace fonts (uniform glyph width)
    /// Uses 0.6 of fontSize which matches JetBrains Mono / SF Mono / Fira Code
    public func estimateMonoTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        return CGFloat(text.count) * fontSize * 0.6
    }
}
