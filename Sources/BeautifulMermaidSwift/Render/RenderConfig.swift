import Foundation
import CoreGraphics

public struct RenderConfig: Sendable {

    public static let shared = RenderConfig()

    // MARK: - Node Padding

    public var nodePaddingHorizontal: CGFloat = 20
    public var nodePaddingVertical: CGFloat = 10
    public var nodePaddingDiamondExtra: CGFloat = 24

    public var nodePadding: CGSize {
        CGSize(width: nodePaddingHorizontal, height: nodePaddingVertical)
    }

    // MARK: - Font Sizes

    public var fontSizeNodeLabel: CGFloat = 13
    public var fontSizeEdgeLabel: CGFloat = 11
    public var fontSizeGroupHeader: CGFloat = 12

    // MARK: - Font Weights

    public var fontWeightNodeLabel: Int = 500
    public var fontWeightEdgeLabel: Int = 400
    public var fontWeightGroupHeader: Int = 600

    // MARK: - Stroke Widths

    public var strokeWidthOuterBox: CGFloat = 1.0
    public var strokeWidthInnerBox: CGFloat = 0.75
    public var strokeWidthConnector: CGFloat = 1.0

    // MARK: - Arrow Head

    public var arrowHeadWidth: CGFloat = 8.0
    public var arrowHeadHeight: CGFloat = 5.0

    // MARK: - Spacing

    public var groupHeaderContentPad: CGFloat = 12.0
    public var subgraphPadding: CGFloat = 24
    public var nodeSpacing: CGFloat = 28
    public var layerSpacing: CGFloat = 48
    public var graphPadding: CGFloat = 40

    // MARK: - Text Rendering

    public var textBaselineShiftEm: CGFloat = 0.35

    // MARK: - Minimum Sizes

    public var minimumNodeWidth: CGFloat = 60
    public var minimumNodeHeight: CGFloat = 36
    public var statePseudostateSize: CGFloat = 28

    // MARK: - Shape-specific

    public var cylinderEllipseRadius: CGFloat = 7
    public var subroutineInset: CGFloat = 8
    public var asymmetricIndent: CGFloat = 12
    public var doubleCircleGap: CGFloat = 5

    // MARK: - Edge Labels

    public var edgeLabelPadding: CGFloat = 8
    public var edgeLabelCornerRadius: CGFloat = 2
    public var edgeLabelBorderWidth: CGFloat = 1.0

    // MARK: - Sequence Diagram Constants

    public var sequenceLoopH: CGFloat = 20
    public var sequenceTabHeight: CGFloat = 18
    public var sequenceFoldSize: CGFloat = 6

    // MARK: - Class Diagram Constants

    public var classPadding: CGFloat = 40
    public var classBoxPadX: CGFloat = 8
    public var classHeaderBaseHeight: CGFloat = 32
    public var classAnnotationHeight: CGFloat = 16
    public var classMemberRowHeight: CGFloat = 20
    public var classSectionPadY: CGFloat = 8
    public var classEmptySectionHeight: CGFloat = 8
    public var classMinWidth: CGFloat = 120
    public var classMemberFontSize: CGFloat = 11
    public var classMemberFontWeight: Int = 400
    public var classNodeSpacing: CGFloat = 40
    public var classLayerSpacing: CGFloat = 60

    // MARK: - ER Diagram Constants

    public var erPadding: CGFloat = 40
    public var erBoxPadX: CGFloat = 14
    public var erHeaderHeight: CGFloat = 34
    public var erRowHeight: CGFloat = 22
    public var erMinWidth: CGFloat = 140
    public var erAttrFontSize: CGFloat = 11

    // MARK: - Initialization

    public init() {}

    // MARK: - Font Helpers

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

    public func nodeLabelFont(family: String? = nil) -> BMFont {
        if let family = family {
            return BMFont(name: family, size: fontSizeNodeLabel) ?? BMFont.systemFont(ofSize: fontSizeNodeLabel, weight: fontWeight(from: fontWeightNodeLabel))
        }
        return BMFont.systemFont(ofSize: fontSizeNodeLabel, weight: fontWeight(from: fontWeightNodeLabel))
    }

    public func edgeLabelFont(family: String? = nil) -> BMFont {
        if let family = family {
            return BMFont(name: family, size: fontSizeEdgeLabel) ?? BMFont.systemFont(ofSize: fontSizeEdgeLabel, weight: fontWeight(from: fontWeightEdgeLabel))
        }
        return BMFont.systemFont(ofSize: fontSizeEdgeLabel, weight: fontWeight(from: fontWeightEdgeLabel))
    }

    public func groupHeaderFont(family: String? = nil) -> BMFont {
        if let family = family {
            return BMFont(name: family, size: fontSizeGroupHeader) ?? BMFont.systemFont(ofSize: fontSizeGroupHeader, weight: fontWeight(from: fontWeightGroupHeader))
        }
        return BMFont.systemFont(ofSize: fontSizeGroupHeader, weight: fontWeight(from: fontWeightGroupHeader))
    }

    public func estimateTextWidth(_ text: String, fontSize: CGFloat, fontWeight: Int) -> CGFloat {
        return original_src_text_metrics.measureTextWidth(text, fontSize: Double(fontSize), fontWeight: fontWeight)
    }

    public func estimateMonoTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        return CGFloat(text.count) * fontSize * 0.6
    }
}
