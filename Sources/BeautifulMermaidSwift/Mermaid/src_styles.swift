// Ported from original/src/styles.ts
import Foundation
import ElkSwift

open class original_src_styles {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    public struct FontSizes: Sendable {
        public var nodeLabel: Double
        public var edgeLabel: Double
        public var groupHeader: Double

        public init(nodeLabel: Double, edgeLabel: Double, groupHeader: Double) {
            self.nodeLabel = nodeLabel
            self.edgeLabel = edgeLabel
            self.groupHeader = groupHeader
        }
    }

    public struct FontWeights: Sendable {
        public var nodeLabel: Int
        public var edgeLabel: Int
        public var groupHeader: Int

        public init(nodeLabel: Int, edgeLabel: Int, groupHeader: Int) {
            self.nodeLabel = nodeLabel
            self.edgeLabel = edgeLabel
            self.groupHeader = groupHeader
        }
    }

    public struct NodePadding: Sendable {
        public var horizontal: Double
        public var vertical: Double
        public var diamondExtra: Double

        public init(horizontal: Double, vertical: Double, diamondExtra: Double) {
            self.horizontal = horizontal
            self.vertical = vertical
            self.diamondExtra = diamondExtra
        }
    }

    public struct StrokeWidths: Sendable {
        public var outerBox: Double
        public var innerBox: Double
        public var connector: Double

        public init(outerBox: Double, innerBox: Double, connector: Double) {
            self.outerBox = outerBox
            self.innerBox = innerBox
            self.connector = connector
        }
    }

    public struct ArrowHead: Sendable {
        public var width: Double
        public var height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    public static let MONO_FONT = "'JetBrains Mono'"
    public static let MONO_FONT_STACK = "\(MONO_FONT), 'SF Mono', 'Fira Code', ui-monospace, monospace"

    public static let FONT_SIZES = FontSizes(nodeLabel: 13, edgeLabel: 11, groupHeader: 12)
    public static let FONT_WEIGHTS = FontWeights(nodeLabel: 500, edgeLabel: 400, groupHeader: 600)

    public static let GROUP_HEADER_CONTENT_PAD: Double = 12
    public static let NODE_PADDING = NodePadding(horizontal: 20, vertical: 10, diamondExtra: 24)
    public static let STROKE_WIDTHS = StrokeWidths(outerBox: 1, innerBox: 0.75, connector: 1)

    public static let TEXT_BASELINE_SHIFT = "0.35em"
    public static let ARROW_HEAD = ArrowHead(width: 8, height: 5)

    public static func estimateTextWidth(_ text: String, _ fontSize: Double, _ fontWeight: Int) -> Double {
        original_src_text_metrics.measureTextWidth(text, fontSize: fontSize, fontWeight: fontWeight)
    }

    public static func estimateMonoTextWidth(_ text: String, _ fontSize: Double) -> Double {
        Double(text.count) * fontSize * 0.6
    }
}
