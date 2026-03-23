import Foundation
import CoreGraphics

// MARK: - Edge Style Parsing

enum EdgeStyleParser {
    static func parse(from styleString: String, hasArrowStart: Bool, hasArrowEnd: Bool) -> EdgeStyle {
        var lineStyle: LineStyle = .solid
        var sourceArrow: ArrowHead = hasArrowStart ? .arrow : .none
        var targetArrow: ArrowHead = hasArrowEnd ? .arrow : .none

        switch styleString.lowercased() {
        case "dotted":
            lineStyle = .dotted
        case "dashed":
            lineStyle = .dashed
        case "thick":
            lineStyle = .thick
        default:
            lineStyle = .solid
        }

        return EdgeStyle(lineStyle: lineStyle, sourceArrow: sourceArrow, targetArrow: targetArrow)
    }
}

// MARK: - Render Relationship Type Constants

enum RenderRelType: String {
    case inheritance
    case composition
    case aggregation
    case association
    case dependency
    case realization
}
