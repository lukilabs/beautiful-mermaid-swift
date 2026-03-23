// Ported from original/src/ascii/ansi.ts
import Foundation
import ElkSwift
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum MIX {
    public static let line = 50.0
    public static let arrow = 85.0
    public static let nodeStroke = 20.0
}

private let DEFAULT_ASCII_THEME_ANSI = AsciiTheme(
    fg: "#27272a",
    border: "#a1a1aa",
    line: "#71717a",
    arrow: "#52525b",
    corner: "#71717a",
    junction: "#a1a1aa"
)

private struct RGB {
    let r: Int
    let g: Int
    let b: Int
}

private func parseHex(_ hex: String) -> RGB {
    let h = hex.replacingOccurrences(of: "#", with: "")
    if h.count == 3 {
        let chars = Array(h)
        return RGB(
            r: Int(String(repeating: String(chars[0]), count: 2), radix: 16) ?? 0,
            g: Int(String(repeating: String(chars[1]), count: 2), radix: 16) ?? 0,
            b: Int(String(repeating: String(chars[2]), count: 2), radix: 16) ?? 0
        )
    }
    if h.count >= 6 {
        let r = Int(h.prefix(2), radix: 16) ?? 0
        let g = Int(h.dropFirst(2).prefix(2), radix: 16) ?? 0
        let b = Int(h.dropFirst(4).prefix(2), radix: 16) ?? 0
        return RGB(r: r, g: g, b: b)
    }
    return RGB(r: 0, g: 0, b: 0)
}

private func mixColors(_ fg: String, _ bg: String, _ pct: Double) -> String {
    let f = parseHex(fg)
    let b = parseHex(bg)
    func mix(_ a: Int, _ z: Int) -> Int {
        Int(round(Double(a) * (pct / 100.0) + Double(z) * (1.0 - pct / 100.0)))
    }
    let r = max(0, min(255, mix(f.r, b.r)))
    let g = max(0, min(255, mix(f.g, b.g)))
    let bl = max(0, min(255, mix(f.b, b.b)))
    return String(format: "#%02x%02x%02x", r, g, bl)
}

public func diagramColorsToAsciiTheme(_ colors: DiagramColors) -> AsciiTheme {
    let line = colors.line ?? mixColors(colors.fg, colors.bg, MIX.line)
    let border = colors.border ?? mixColors(colors.fg, colors.bg, MIX.nodeStroke)
    return AsciiTheme(
        fg: colors.fg,
        border: border,
        line: line,
        arrow: colors.accent ?? mixColors(colors.fg, colors.bg, MIX.arrow),
        corner: line,
        junction: border
    )
}

public func detectColorMode() -> ColorMode {
    #if canImport(Darwin) || canImport(Glibc)
    let tty = isatty(STDOUT_FILENO) == 1
    if !tty {
        return .none
    }
    #endif

    let env = ProcessInfo.processInfo.environment
    let colorTerm = (env["COLORTERM"] ?? "").lowercased()
    let term = (env["TERM"] ?? "").lowercased()

    if colorTerm == "truecolor" || colorTerm == "24bit" {
        return .truecolor
    }
    if term.contains("256color") || term.contains("256") {
        return .ansi256
    }
    if !term.isEmpty && term != "dumb" {
        return .ansi16
    }

    return .none
}

private let ESC = "\u{001B}["
private let RESET = "\u{001B}[0m"

private func truecolorFg(_ hex: String) -> String {
    let rgb = parseHex(hex)
    return "\(ESC)38;2;\(rgb.r);\(rgb.g);\(rgb.b)m"
}

private func rgbTo256(_ r: Int, _ g: Int, _ b: Int) -> Int {
    let avg = Double(r + g + b) / 3.0
    let maxDiff = max(abs(Double(r) - avg), max(abs(Double(g) - avg), abs(Double(b) - avg)))

    if maxDiff < 10.0 {
        let gray = Int(round((avg / 255.0) * 23.0))
        return 232 + min(23, max(0, gray))
    }

    func toIndex(_ v: Int) -> Int {
        if v < 48 { return 0 }
        if v < 115 { return 1 }
        return min(5, Int(floor(Double(v - 35) / 40.0)))
    }

    let ri = toIndex(r)
    let gi = toIndex(g)
    let bi = toIndex(b)
    return 16 + (36 * ri) + (6 * gi) + bi
}

private func ansi256Fg(_ hex: String) -> String {
    let rgb = parseHex(hex)
    return "\(ESC)38;5;\(rgbTo256(rgb.r, rgb.g, rgb.b))m"
}

private func ansi16Fg(_ hex: String) -> String {
    let rgb = parseHex(hex)
    let luma = 0.299 * Double(rgb.r) + 0.587 * Double(rgb.g) + 0.114 * Double(rgb.b)
    let bright = luma > 100 ? 0 : 60

    let code: Int
    if rgb.r > 180 && rgb.g < 100 && rgb.b < 100 {
        code = 31
    } else if rgb.g > 180 && rgb.r < 100 && rgb.b < 100 {
        code = 32
    } else if rgb.r > 150 && rgb.g > 150 && rgb.b < 100 {
        code = 33
    } else if rgb.b > 180 && rgb.r < 100 && rgb.g < 100 {
        code = 34
    } else if rgb.r > 150 && rgb.b > 150 && rgb.g < 100 {
        code = 35
    } else if rgb.g > 150 && rgb.b > 150 && rgb.r < 100 {
        code = 36
    } else if luma > 200 {
        code = 37
    } else if luma < 50 {
        code = 30
    } else {
        code = 37
    }

    return "\(ESC)\(code + bright)m"
}

private func escapeHtml(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

private func htmlSpan(_ hex: String, _ text: String) -> String {
    "<span style=\"color:\(hex)\">\(escapeHtml(text))</span>"
}

private func getRoleColor(_ role: CharRole, _ theme: AsciiTheme) -> String {
    switch role {
    case .text:
        return theme.fg
    case .border:
        return theme.border
    case .line:
        return theme.line
    case .arrow:
        return theme.arrow
    case .corner:
        return theme.corner ?? theme.line
    case .junction:
        return theme.junction ?? theme.border
    }
}

public func getAnsiColor(_ role: CharRole, _ theme: AsciiTheme, _ mode: ColorMode) -> String {
    if mode == .none {
        return ""
    }

    let hex = getRoleColor(role, theme)
    switch mode {
    case .truecolor:
        return truecolorFg(hex)
    case .ansi256:
        return ansi256Fg(hex)
    case .ansi16:
        return ansi16Fg(hex)
    case .none, .html:
        return ""
    }
}

public func getAnsiReset(_ mode: ColorMode) -> String {
    mode == .none ? "" : RESET
}

public func colorizeChar(
    _ char: String,
    _ role: CharRole?,
    _ theme: AsciiTheme,
    _ mode: ColorMode
) -> String {
    if mode == .none || char == " " {
        return char
    }
    guard let role = role else { return char }
    if mode == .html {
        return htmlSpan(getRoleColor(role, theme), char)
    }

    let colorCode = getAnsiColor(role, theme, mode)
    return "\(colorCode)\(char)\(RESET)"
}

private func colorizeLineHtml(_ chars: [String], _ roles: [CharRole?], _ theme: AsciiTheme) -> String {
    var result = ""
    var currentRole: CharRole? = nil
    var buffer = ""

    func flush() {
        guard !buffer.isEmpty else { return }
        if let currentRole {
            result += htmlSpan(getRoleColor(currentRole, theme), buffer)
        } else {
            result += escapeHtml(buffer)
        }
        buffer = ""
    }

    let count = min(chars.count, roles.count)
    for i in 0..<count {
        let char = chars[i]
        let role = roles[i]

        if char == " " {
            flush()
            currentRole = nil
            result += " "
            continue
        }

        if role == currentRole {
            buffer += char
            continue
        }

        flush()
        currentRole = role
        buffer = char
    }
    flush()

    if chars.count > count {
        result += chars[count...].joined()
    }

    return result
}

public func colorizeLine(
    _ chars: [String],
    _ roles: [CharRole?],
    _ theme: AsciiTheme,
    _ mode: ColorMode
) -> String {
    if mode == .none {
        return chars.joined()
    }

    if mode == .html {
        return colorizeLineHtml(chars, roles, theme)
    }

    var result = ""
    var currentRole: CharRole? = nil
    var buffer = ""

    func flush() {
        guard !buffer.isEmpty else { return }
        if let currentRole {
            result += getAnsiColor(currentRole, theme, mode) + buffer + RESET
        } else {
            result += buffer
        }
        buffer = ""
    }

    let count = min(chars.count, roles.count)
    for i in 0..<count {
        let char = chars[i]
        let role = roles[i]

        if char == " " {
            flush()
            currentRole = nil
            result += char
            continue
        }

        if role == currentRole {
            buffer += char
            continue
        }

        flush()
        currentRole = role
        buffer = char
    }

    flush()
    if chars.count > count {
        result += chars[count...].joined()
    }

    return result
}

public func colorizeText(_ text: String, _ hex: String, _ mode: ColorMode) -> String {
    if mode == .none { return text }
    if mode == .html { return htmlSpan(hex, text) }
    let colorCode: String
    switch mode {
    case .truecolor: colorCode = truecolorFg(hex)
    case .ansi256: colorCode = ansi256Fg(hex)
    case .ansi16: colorCode = ansi16Fg(hex)
    default: return text
    }
    return "\(colorCode)\(text)\(RESET)"
}

open class original_src_ascii_ansi {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version
    public static let DEFAULT_ASCII_THEME = DEFAULT_ASCII_THEME_ANSI
}
