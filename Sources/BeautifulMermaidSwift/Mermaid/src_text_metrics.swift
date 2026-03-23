// Ported from original/src/text-metrics.ts
import Foundation
import ElkSwift

open class original_src_text_metrics {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    private static let NARROW_CHARS: Set<Character> = Set("iltfjI1!|.,:;'".map { $0 })
    private static let WIDE_CHARS: Set<Character> = Set("WMwm@%".map { $0 })
    private static let VERY_WIDE_CHARS: Set<Character> = Set("WM".map { $0 })
    private static let SEMI_NARROW_PUNCT: Set<Character> = Set("()[]{}\\/-\"`".map { $0 })
    private static let EMOJI_REGEX: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(pattern: #"[\p{Emoji_Presentation}\p{Extended_Pictographic}]"#) else {
            assertionFailure("Invalid emoji regex")
            return NSRegularExpression()
        }
        return regex
    }()

    public static let LINE_HEIGHT_RATIO: Double = 1.3

    public struct MultilineMetrics: Sendable {
        public var width: Double
        public var height: Double
        public var lines: [String]
        public var lineHeight: Double

        public init(width: Double, height: Double, lines: [String], lineHeight: Double) {
            self.width = width
            self.height = height
            self.lines = lines
            self.lineHeight = lineHeight
        }
    }

    private static func isCombiningMark(_ code: UInt32) -> Bool {
        (code >= 0x0300 && code <= 0x036F)
            || (code >= 0x1AB0 && code <= 0x1AFF)
            || (code >= 0x1DC0 && code <= 0x1DFF)
            || (code >= 0x20D0 && code <= 0x20FF)
            || (code >= 0xFE20 && code <= 0xFE2F)
    }

    private static func isFullwidth(_ code: UInt32) -> Bool {
        (code >= 0x1100 && code <= 0x115F)
            || (code >= 0x2E80 && code <= 0x2EFF)
            || (code >= 0x2F00 && code <= 0x2FDF)
            || (code >= 0x3000 && code <= 0x303F)
            || (code >= 0x3040 && code <= 0x309F)
            || (code >= 0x30A0 && code <= 0x30FF)
            || (code >= 0x3100 && code <= 0x312F)
            || (code >= 0x3130 && code <= 0x318F)
            || (code >= 0x3190 && code <= 0x31FF)
            || (code >= 0x3200 && code <= 0x33FF)
            || (code >= 0x3400 && code <= 0x4DBF)
            || (code >= 0x4E00 && code <= 0x9FFF)
            || (code >= 0xAC00 && code <= 0xD7AF)
            || (code >= 0xF900 && code <= 0xFAFF)
            || (code >= 0xFF00 && code <= 0xFF60)
            || (code >= 0xFFE0 && code <= 0xFFE6)
            || code >= 0x20000
    }

    private static func isEmoji(_ char: Character) -> Bool {
        let text = String(char)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return EMOJI_REGEX.firstMatch(in: text, options: [], range: range) != nil
    }

    public static func getCharWidth(_ char: Character) -> Double {
        guard let scalar = char.unicodeScalars.first else {
            return 0
        }
        let code = scalar.value

        if isCombiningMark(code) {
            return 0
        }
        if isFullwidth(code) || isEmoji(char) {
            return 2.0
        }
        if char == " " {
            return 0.3
        }
        if VERY_WIDE_CHARS.contains(char) {
            return 1.5
        }
        if WIDE_CHARS.contains(char) {
            return 1.2
        }
        if NARROW_CHARS.contains(char) {
            return 0.4
        }
        if SEMI_NARROW_PUNCT.contains(char) {
            return 0.5
        }
        if char == "r" {
            return 0.8
        }
        if code >= 65, code <= 90 {
            return 1.2
        }
        if code >= 48, code <= 57 {
            return 1.0
        }
        return 1.0
    }

    public static func measureTextWidth(_ text: String, fontSize: Double, fontWeight: Int) -> Double {
        let baseRatio: Double
        if fontWeight >= 600 {
            baseRatio = 0.60
        } else if fontWeight >= 500 {
            baseRatio = 0.57
        } else {
            baseRatio = 0.54
        }

        let totalWidth = text.reduce(0.0) { $0 + getCharWidth($1) }
        let minPadding = fontSize * 0.15
        return totalWidth * fontSize * baseRatio + minPadding
    }

    public static func measureMultilineText(
        _ text: String,
        fontSize: Double,
        fontWeight: Int
    ) -> MultilineMetrics {
        let lines = text.components(separatedBy: "\n")
        let lineHeight = fontSize * LINE_HEIGHT_RATIO

        var maxWidth = 0.0
        for line in lines {
            let plain = stripFormattingTags(line)
            let w = measureTextWidth(plain, fontSize: fontSize, fontWeight: fontWeight)
            if w > maxWidth {
                maxWidth = w
            }
        }

        return MultilineMetrics(
            width: maxWidth,
            height: Double(lines.count) * lineHeight,
            lines: lines,
            lineHeight: lineHeight
        )
    }

    private static func stripFormattingTags(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"</?(?:b|strong|i|em|u|s|del)\s*>"#, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
}
