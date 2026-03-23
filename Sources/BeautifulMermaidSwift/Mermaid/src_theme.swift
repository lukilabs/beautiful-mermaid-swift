// Ported from original/src/theme.ts
import Foundation
import ElkSwift

open class original_src_theme {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version

    public struct DiagramColors: Sendable {
        public var bg: String
        public var fg: String
        public var line: String?
        public var accent: String?
        public var muted: String?
        public var surface: String?
        public var border: String?

        public init(
            bg: String,
            fg: String,
            line: String? = nil,
            accent: String? = nil,
            muted: String? = nil,
            surface: String? = nil,
            border: String? = nil
        ) {
            self.bg = bg
            self.fg = fg
            self.line = line
            self.accent = accent
            self.muted = muted
            self.surface = surface
            self.border = border
        }
    }

    public struct Defaults: Sendable {
        public let bg: String
        public let fg: String

        public init(bg: String, fg: String) {
            self.bg = bg
            self.fg = fg
        }
    }

    public struct Mix: Sendable {
        public let text: Int
        public let textSec: Int
        public let textMuted: Int
        public let textFaint: Int
        public let line: Int
        public let arrow: Int
        public let nodeFill: Int
        public let nodeStroke: Int
        public let groupHeader: Int
        public let innerStroke: Int
        public let keyBadge: Int

        public init(
            text: Int,
            textSec: Int,
            textMuted: Int,
            textFaint: Int,
            line: Int,
            arrow: Int,
            nodeFill: Int,
            nodeStroke: Int,
            groupHeader: Int,
            innerStroke: Int,
            keyBadge: Int
        ) {
            self.text = text
            self.textSec = textSec
            self.textMuted = textMuted
            self.textFaint = textFaint
            self.line = line
            self.arrow = arrow
            self.nodeFill = nodeFill
            self.nodeStroke = nodeStroke
            self.groupHeader = groupHeader
            self.innerStroke = innerStroke
            self.keyBadge = keyBadge
        }
    }

    public struct ThemeName: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.rawValue = value
        }

        public static let zincLight: ThemeName = "zinc-light"
        public static let zincDark: ThemeName = "zinc-dark"
        public static let tokyoNight: ThemeName = "tokyo-night"
        public static let tokyoNightStorm: ThemeName = "tokyo-night-storm"
        public static let tokyoNightLight: ThemeName = "tokyo-night-light"
        public static let catppuccinMocha: ThemeName = "catppuccin-mocha"
        public static let catppuccinLatte: ThemeName = "catppuccin-latte"
        public static let nord: ThemeName = "nord"
        public static let nordLight: ThemeName = "nord-light"
        public static let dracula: ThemeName = "dracula"
        public static let githubLight: ThemeName = "github-light"
        public static let githubDark: ThemeName = "github-dark"
        public static let solarizedLight: ThemeName = "solarized-light"
        public static let solarizedDark: ThemeName = "solarized-dark"
        public static let oneDark: ThemeName = "one-dark"
    }

    public struct ShikiTokenColor: Sendable {
        public var scope: [String]
        public var foreground: String?

        public init(scope: [String], foreground: String? = nil) {
            self.scope = scope
            self.foreground = foreground
        }
    }

    public struct ShikiThemeLike: Sendable {
        public var type: String?
        public var colors: [String: String]?
        public var tokenColors: [ShikiTokenColor]?

        public init(
            type: String? = nil,
            colors: [String: String]? = nil,
            tokenColors: [ShikiTokenColor]? = nil
        ) {
            self.type = type
            self.colors = colors
            self.tokenColors = tokenColors
        }
    }

    public static let DEFAULTS = Defaults(bg: "#FFFFFF", fg: "#27272A")

    public static let MIX = Mix(
        text: 100,
        textSec: 60,
        textMuted: 40,
        textFaint: 25,
        line: 50,
        arrow: 85,
        nodeFill: 3,
        nodeStroke: 20,
        groupHeader: 5,
        innerStroke: 12,
        keyBadge: 10
    )

    public static let THEMES: [String: DiagramColors] = [
        "zinc-light": DiagramColors(bg: "#FFFFFF", fg: "#27272A"),
        "zinc-dark": DiagramColors(bg: "#18181B", fg: "#FAFAFA"),
        "tokyo-night": DiagramColors(
            bg: "#1a1b26", fg: "#a9b1d6",
            line: "#3d59a1", accent: "#7aa2f7", muted: "#565f89"
        ),
        "tokyo-night-storm": DiagramColors(
            bg: "#24283b", fg: "#a9b1d6",
            line: "#3d59a1", accent: "#7aa2f7", muted: "#565f89"
        ),
        "tokyo-night-light": DiagramColors(
            bg: "#d5d6db", fg: "#343b58",
            line: "#34548a", accent: "#34548a", muted: "#9699a3"
        ),
        "catppuccin-mocha": DiagramColors(
            bg: "#1e1e2e", fg: "#cdd6f4",
            line: "#585b70", accent: "#cba6f7", muted: "#6c7086"
        ),
        "catppuccin-latte": DiagramColors(
            bg: "#eff1f5", fg: "#4c4f69",
            line: "#9ca0b0", accent: "#8839ef", muted: "#9ca0b0"
        ),
        "nord": DiagramColors(
            bg: "#2e3440", fg: "#d8dee9",
            line: "#4c566a", accent: "#88c0d0", muted: "#616e88"
        ),
        "nord-light": DiagramColors(
            bg: "#eceff4", fg: "#2e3440",
            line: "#aab1c0", accent: "#5e81ac", muted: "#7b88a1"
        ),
        "dracula": DiagramColors(
            bg: "#282a36", fg: "#f8f8f2",
            line: "#6272a4", accent: "#bd93f9", muted: "#6272a4"
        ),
        "github-light": DiagramColors(
            bg: "#ffffff", fg: "#1f2328",
            line: "#d1d9e0", accent: "#0969da", muted: "#59636e"
        ),
        "github-dark": DiagramColors(
            bg: "#0d1117", fg: "#e6edf3",
            line: "#3d444d", accent: "#4493f8", muted: "#9198a1"
        ),
        "solarized-light": DiagramColors(
            bg: "#fdf6e3", fg: "#657b83",
            line: "#93a1a1", accent: "#268bd2", muted: "#93a1a1"
        ),
        "solarized-dark": DiagramColors(
            bg: "#002b36", fg: "#839496",
            line: "#586e75", accent: "#268bd2", muted: "#586e75"
        ),
        "one-dark": DiagramColors(
            bg: "#282c34", fg: "#abb2bf",
            line: "#4b5263", accent: "#c678dd", muted: "#5c6370"
        ),
    ]

    public static let ThemeNameValues: [ThemeName] = [
        .zincLight,
        .zincDark,
        .tokyoNight,
        .tokyoNightStorm,
        .tokyoNightLight,
        .catppuccinMocha,
        .catppuccinLatte,
        .nord,
        .nordLight,
        .dracula,
        .githubLight,
        .githubDark,
        .solarizedLight,
        .solarizedDark,
        .oneDark,
    ]

    public static func fromShikiTheme(_ theme: ShikiThemeLike) -> DiagramColors {
        let colors = theme.colors ?? [:]
        let dark = theme.type == "dark"

        func tokenColor(_ scope: String) -> String? {
            theme.tokenColors?
                .first(where: { $0.scope.contains(scope) })?
                .foreground
        }

        return DiagramColors(
            bg: colors["editor.background"] ?? (dark ? "#1e1e1e" : "#ffffff"),
            fg: colors["editor.foreground"] ?? (dark ? "#d4d4d4" : "#333333"),
            line: colors["editorLineNumber.foreground"],
            accent: colors["focusBorder"] ?? tokenColor("keyword"),
            muted: tokenColor("comment") ?? colors["editorLineNumber.foreground"],
            surface: colors["editor.selectionBackground"],
            border: colors["editorWidget.border"]
        )
    }

    public static func buildStyleBlock(_ font: String, _ hasMonoFont: Bool) -> String {
        let encodedFont = font.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? font

        var fontImports: [String] = [
            "@import url('https://fonts.googleapis.com/css2?family=\(encodedFont):wght@400;500;600;700&amp;display=swap');"
        ]
        if hasMonoFont {
            fontImports.append(
                "@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500&amp;display=swap');"
            )
        }

        let derivedVars = """
            /* Derived from --bg and --fg (overridable via --line, --accent, etc.) */
            --_text:          var(--fg);
            --_text-sec:      var(--muted, color-mix(in srgb, var(--fg) \(MIX.textSec)%, var(--bg)));
            --_text-muted:    var(--muted, color-mix(in srgb, var(--fg) \(MIX.textMuted)%, var(--bg)));
            --_text-faint:    color-mix(in srgb, var(--fg) \(MIX.textFaint)%, var(--bg));
            --_line:          var(--line, color-mix(in srgb, var(--fg) \(MIX.line)%, var(--bg)));
            --_arrow:         var(--accent, color-mix(in srgb, var(--fg) \(MIX.arrow)%, var(--bg)));
            --_node-fill:     var(--surface, color-mix(in srgb, var(--fg) \(MIX.nodeFill)%, var(--bg)));
            --_node-stroke:   var(--border, color-mix(in srgb, var(--fg) \(MIX.nodeStroke)%, var(--bg)));
            --_group-fill:    var(--bg);
            --_group-hdr:     color-mix(in srgb, var(--fg) \(MIX.groupHeader)%, var(--bg));
            --_inner-stroke:  color-mix(in srgb, var(--fg) \(MIX.innerStroke)%, var(--bg));
            --_key-badge:     color-mix(in srgb, var(--fg) \(MIX.keyBadge)%, var(--bg));
        """

        var lines: [String] = [
            "<style>",
            "  \(fontImports.joined(separator: "\n  "))",
            "  text { font-family: '\(font)', system-ui, sans-serif; }",
        ]
        if hasMonoFont {
            lines.append("  .mono { font-family: 'JetBrains Mono', 'SF Mono', 'Fira Code', ui-monospace, monospace; }")
        }
        lines.append("  svg {\(derivedVars)")
        lines.append("  }")
        lines.append("</style>")
        return lines.joined(separator: "\n")
    }

    public static func svgOpenTag(
        _ width: Double,
        _ height: Double,
        _ colors: DiagramColors,
        _ transparent: Bool? = nil
    ) -> String {
        let styleVars = [
            "--bg:\(colors.bg)",
            "--fg:\(colors.fg)",
            colors.line.map { "--line:\($0)" } ?? "",
            colors.accent.map { "--accent:\($0)" } ?? "",
            colors.muted.map { "--muted:\($0)" } ?? "",
            colors.surface.map { "--surface:\($0)" } ?? "",
            colors.border.map { "--border:\($0)" } ?? "",
        ].filter { !$0.isEmpty }.joined(separator: ";")

        let bgStyle = (transparent ?? false) ? "" : ";background:var(--bg)"
        let widthStr = _formatNumber(width)
        let heightStr = _formatNumber(height)

        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(widthStr) \(heightStr)\" " +
            "width=\"\(widthStr)\" height=\"\(heightStr)\" style=\"\(styleVars)\(bgStyle)\">"
    }

    private static func _formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }
}
