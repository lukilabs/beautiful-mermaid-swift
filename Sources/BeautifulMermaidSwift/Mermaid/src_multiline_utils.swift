// Ported from original/src/multiline-utils.ts
import Foundation
import ElkSwift

open class original_src_multiline_utils {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    private struct StyledSegment {
        var text: String
        var bold: Bool
        var italic: Bool
        var underline: Bool
        var strikethrough: Bool
    }

    public static func normalizeBrTags(_ label: String) -> String {
        let unquoted: String
        if label.hasPrefix("\"") && label.hasSuffix("\"") && label.count >= 2 {
            unquoted = String(label.dropFirst().dropLast())
        } else {
            unquoted = label
        }

        var result = unquoted
        result = regexReplace(result, pattern: #"<br\s*/?>"#, template: "\n", options: [.caseInsensitive])
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        result = regexReplace(result, pattern: #"</?(?:sub|sup|small|mark)\s*>"#, template: "", options: [.caseInsensitive])

        // Markdown formatting -> HTML tags (order matters)
        result = regexReplace(result, pattern: #"\*\*(.+?)\*\*"#, template: "<b>$1</b>")
        result = regexReplace(result, pattern: #"\*([^\s*](?:[^*]*[^\s*])?)\*"#, template: "<i>$1</i>")
        result = regexReplace(result, pattern: #"~~(.+?)~~"#, template: "<s>$1</s>")

        return result
    }

    public static func stripFormattingTags(_ text: String) -> String {
        regexReplace(
            text,
            pattern: #"</?(?:b|strong|i|em|u|s|del)\s*>"#,
            template: "",
            options: [.caseInsensitive]
        )
    }

    public static func escapeXml(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    public static func renderMultilineText(
        _ text: String,
        cx: Double,
        cy: Double,
        fontSize: Double,
        attrs: String,
        baselineShift: Double = 0.35
    ) -> String {
        let lines = text.components(separatedBy: "\n")
        if lines.count == 1 {
            let dy = fontSize * baselineShift
            return "<text x=\"\(cx)\" y=\"\(cy)\" \(attrs) dy=\"\(dy)\">\(renderLineContent(text))</text>"
        }

        let lineHeight = fontSize * original_src_text_metrics.LINE_HEIGHT_RATIO
        let firstDy = -Double(lines.count - 1) / 2.0 * lineHeight + fontSize * baselineShift

        var tspans: [String] = []
        for (idx, line) in lines.enumerated() {
            let dy = idx == 0 ? firstDy : lineHeight
            tspans.append("<tspan x=\"\(cx)\" dy=\"\(dy)\">\(renderLineContent(line))</tspan>")
        }

        return "<text x=\"\(cx)\" y=\"\(cy)\" \(attrs)>\(tspans.joined())</text>"
    }

    public static func renderMultilineTextWithBackground(
        _ text: String,
        cx: Double,
        cy: Double,
        textWidth: Double,
        textHeight: Double,
        fontSize: Double,
        padding: Double,
        textAttrs: String,
        bgAttrs: String
    ) -> String {
        let bgWidth = textWidth + padding * 2
        let bgHeight = textHeight + padding * 2

        let rect = "<rect x=\"\(cx - bgWidth / 2)\" y=\"\(cy - bgHeight / 2)\" width=\"\(bgWidth)\" height=\"\(bgHeight)\" \(bgAttrs) />"
        let textEl = renderMultilineText(text, cx: cx, cy: cy, fontSize: fontSize, attrs: textAttrs)
        return "\(rect)\n\(textEl)"
    }

    private static func renderLineContent(_ line: String) -> String {
        if !hasFormatTags(line) {
            return escapeXml(line)
        }

        let segments = parseInlineFormatting(line)
        if segments.isEmpty {
            return ""
        }

        let allPlain = segments.allSatisfy { !$0.bold && !$0.italic && !$0.underline && !$0.strikethrough }
        if allPlain {
            return segments.map { escapeXml($0.text) }.joined()
        }

        return segments.map { seg in
            let escaped = escapeXml(seg.text)
            if !seg.bold && !seg.italic && !seg.underline && !seg.strikethrough {
                return escaped
            }

            var attrs: [String] = []
            if seg.bold {
                attrs.append("font-weight=\"bold\"")
            }
            if seg.italic {
                attrs.append("font-style=\"italic\"")
            }
            var deco: [String] = []
            if seg.underline {
                deco.append("underline")
            }
            if seg.strikethrough {
                deco.append("line-through")
            }
            if !deco.isEmpty {
                attrs.append("text-decoration=\"\(deco.joined(separator: " "))\"")
            }

            return "<tspan \(attrs.joined(separator: " "))>\(escaped)</tspan>"
        }.joined()
    }

    private static func hasFormatTags(_ line: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: #"</?(?:b|strong|i|em|u|s|del)\s*>"#,
            options: [.caseInsensitive]
        ) else {
            return false
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.firstMatch(in: line, options: [], range: range) != nil
    }

    private static func parseInlineFormatting(_ line: String) -> [StyledSegment] {
        guard let regex = try? NSRegularExpression(
            pattern: #"<(\/)?(?:(b|strong)|(i|em)|(u)|(s|del))\s*>"#,
            options: [.caseInsensitive]
        ) else {
            return [StyledSegment(text: line, bold: false, italic: false, underline: false, strikethrough: false)]
        }

        var segments: [StyledSegment] = []
        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false
        var lastUtf16Index = 0

        let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, options: [], range: fullRange)

        for match in matches {
            if match.range.location > lastUtf16Index {
                let start = String.Index(utf16Offset: lastUtf16Index, in: line)
                let end = String.Index(utf16Offset: match.range.location, in: line)
                if start <= end {
                let text = String(line[start..<end])
                segments.append(
                    StyledSegment(text: text, bold: bold, italic: italic, underline: underline, strikethrough: strikethrough)
                )
                }
            }

            let isClosing = rangeText(line, match.range(at: 1)) != nil
            if rangeText(line, match.range(at: 2)) != nil {
                bold = !isClosing
            } else if rangeText(line, match.range(at: 3)) != nil {
                italic = !isClosing
            } else if rangeText(line, match.range(at: 4)) != nil {
                underline = !isClosing
            } else if rangeText(line, match.range(at: 5)) != nil {
                strikethrough = !isClosing
            }

            lastUtf16Index = match.range.location + match.range.length
        }

        if lastUtf16Index < (line as NSString).length {
            let start = String.Index(utf16Offset: lastUtf16Index, in: line)
            let text = String(line[start...])
            segments.append(
                StyledSegment(text: text, bold: bold, italic: italic, underline: underline, strikethrough: strikethrough)
            )
        }

        return segments
    }

    private static func rangeText(_ source: String, _ range: NSRange) -> String? {
        guard range.location != NSNotFound,
              let r = Range(range, in: source)
        else {
            return nil
        }
        return String(source[r])
    }

    private static func regexReplace(
        _ source: String,
        pattern: String,
        template: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return source
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.stringByReplacingMatches(in: source, options: [], range: range, withTemplate: template)
    }
}
