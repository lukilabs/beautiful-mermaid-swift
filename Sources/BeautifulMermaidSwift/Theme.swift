import Foundation
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct DiagramTheme: @unchecked Sendable, Equatable {
    public var background: BMColor
    public var foreground: BMColor
    public var line: BMColor?
    public var accent: BMColor?
    public var muted: BMColor?
    public var surface: BMColor?
    public var border: BMColor?
    public var font: BMFont
    public var lineWidth: CGFloat
    public var cornerRadius: CGFloat

    /// When `true`, the diagram background is not filled — useful for overlay/compositing
    public var transparent: Bool

    public static func == (lhs: DiagramTheme, rhs: DiagramTheme) -> Bool {
        lhs.background.bmColorEquals(rhs.background) &&
        lhs.foreground.bmColorEquals(rhs.foreground) &&
        _optionalColorEquals(lhs.line, rhs.line) &&
        _optionalColorEquals(lhs.accent, rhs.accent) &&
        _optionalColorEquals(lhs.muted, rhs.muted) &&
        _optionalColorEquals(lhs.surface, rhs.surface) &&
        _optionalColorEquals(lhs.border, rhs.border) &&
        lhs.font == rhs.font &&
        lhs.lineWidth == rhs.lineWidth &&
        lhs.cornerRadius == rhs.cornerRadius &&
        lhs.transparent == rhs.transparent
    }

    private static func _optionalColorEquals(_ a: BMColor?, _ b: BMColor?) -> Bool {
        switch (a, b) {
        case (.none, .none): return true
        case let (.some(a), .some(b)): return a.bmColorEquals(b)
        default: return false
        }
    }

    /// Creates a new diagram theme.
    ///
    /// Only `background` and `foreground` are required. All other colors are derived
    /// automatically by blending foreground into background at fixed ratios (see ``ColorMix``).
    /// Supply explicit overrides only when you need non-default palette values.
    ///
    /// - Parameters:
    ///   - background: Canvas background color.
    ///   - foreground: Primary text and label color.
    ///   - line: Edge/line color. Defaults to a 50% blend of foreground into background.
    ///   - accent: Arrow-head and highlight color. Defaults to foreground.
    ///   - muted: Secondary text color (edge labels). Defaults to a 40% blend.
    ///   - surface: Node fill color. Defaults to a 3% blend.
    ///   - border: Node stroke color. Defaults to a 20% blend.
    ///   - font: Font used for all labels. Defaults to the system font at 14 pt.
    ///   - lineWidth: Stroke width for edges and borders. Defaults to 1.5.
    ///   - cornerRadius: Corner radius for rounded node shapes. Defaults to 8.
    ///   - transparent: When `true`, renderers skip the background fill — useful for compositing.
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
        cornerRadius: CGFloat = 8,
        transparent: Bool = false
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
        self.transparent = transparent
    }

    /// Create a copy with transparent background (no fill)
    public func withTransparent(_ transparent: Bool = true) -> DiagramTheme {
        var copy = self
        copy.transparent = transparent
        return copy
    }

    // MARK: - Derived Colors

    public func effectiveLine() -> BMColor { line ?? background.mixed(with: foreground, amount: ColorMix.line) }
    public func effectiveAccent() -> BMColor { accent ?? foreground }
    public func effectiveMuted() -> BMColor { muted ?? background.mixed(with: foreground, amount: ColorMix.textMuted) }
    public func effectiveSurface() -> BMColor { surface ?? background.mixed(with: foreground, amount: ColorMix.nodeFill) }
    public func effectiveBorder() -> BMColor { border ?? background.mixed(with: foreground, amount: ColorMix.nodeStroke) }

    public func effectiveTextSecondary() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.textSec)
    }

    public func effectiveTextFaint() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.textFaint)
    }

    public func effectiveArrow() -> BMColor {
        accent ?? background.mixed(with: foreground, amount: ColorMix.arrow)
    }

    public func effectiveInnerStroke() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.innerStroke)
    }

    public func subgraphBackgroundColor() -> BMColor {
        background
    }

    public func subgraphHeaderColor() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.groupHeader)
    }

    public func keyBadgeColor() -> BMColor {
        background.mixed(with: foreground, amount: ColorMix.keyBadge)
    }

    // MARK: - Per-Element Colors

    public func edgeColor(for style: EdgeStyle) -> BMColor {
        if let hex = style.color { return BMColor(hex: hex) }
        return effectiveLine()
    }

    public func nodeFillColor(for inlineStyles: [String: String]) -> BMColor {
        if let fillHex = inlineStyles["fill"] { return BMColor(hex: fillHex) }
        return effectiveSurface()
    }

    public func nodeStrokeColor(for inlineStyles: [String: String]) -> BMColor {
        if let strokeHex = inlineStyles["stroke"] { return BMColor(hex: strokeHex) }
        return effectiveBorder()
    }

    public func nodeTextColor(for inlineStyles: [String: String]) -> BMColor {
        if let colorHex = inlineStyles["color"] { return BMColor(hex: colorHex) }
        return foreground
    }

    public func nodeFillColor(for node: MermaidNode) -> BMColor {
        nodeFillColor(for: node.inlineStyles)
    }

    public func nodeStrokeColor(for node: MermaidNode) -> BMColor {
        nodeStrokeColor(for: node.inlineStyles)
    }

    public func nodeTextColor(for node: MermaidNode) -> BMColor {
        nodeTextColor(for: node.inlineStyles)
    }
}

extension DiagramTheme {
    public static let zincLight = DiagramTheme(background: BMColor(hex: "#FFFFFF"), foreground: BMColor(hex: "#27272A"))
    public static let zincDark = DiagramTheme(background: BMColor(hex: "#18181B"), foreground: BMColor(hex: "#FAFAFA"))
    public static let tokyoNight = DiagramTheme(
        background: BMColor(hex: "#1a1b26"),
        foreground: BMColor(hex: "#a9b1d6"),
        line: BMColor(hex: "#3d59a1"),
        accent: BMColor(hex: "#7aa2f7"),
        muted: BMColor(hex: "#565f89")
    )
    public static let tokyoNightStorm = DiagramTheme(
        background: BMColor(hex: "#24283b"),
        foreground: BMColor(hex: "#a9b1d6"),
        line: BMColor(hex: "#3d59a1"),
        accent: BMColor(hex: "#7aa2f7"),
        muted: BMColor(hex: "#565f89")
    )
    public static let tokyoNightLight = DiagramTheme(
        background: BMColor(hex: "#d5d6db"),
        foreground: BMColor(hex: "#343b58"),
        line: BMColor(hex: "#34548a"),
        accent: BMColor(hex: "#34548a"),
        muted: BMColor(hex: "#9699a3")
    )
    public static let catppuccinMocha = DiagramTheme(
        background: BMColor(hex: "#1e1e2e"),
        foreground: BMColor(hex: "#cdd6f4"),
        line: BMColor(hex: "#585b70"),
        accent: BMColor(hex: "#cba6f7"),
        muted: BMColor(hex: "#6c7086")
    )
    public static let catppuccinLatte = DiagramTheme(
        background: BMColor(hex: "#eff1f5"),
        foreground: BMColor(hex: "#4c4f69"),
        line: BMColor(hex: "#9ca0b0"),
        accent: BMColor(hex: "#8839ef"),
        muted: BMColor(hex: "#9ca0b0")
    )
    public static let nord = DiagramTheme(
        background: BMColor(hex: "#2e3440"),
        foreground: BMColor(hex: "#d8dee9"),
        line: BMColor(hex: "#4c566a"),
        accent: BMColor(hex: "#88c0d0"),
        muted: BMColor(hex: "#616e88")
    )
    public static let nordLight = DiagramTheme(
        background: BMColor(hex: "#eceff4"),
        foreground: BMColor(hex: "#2e3440"),
        line: BMColor(hex: "#aab1c0"),
        accent: BMColor(hex: "#5e81ac"),
        muted: BMColor(hex: "#7b88a1")
    )
    public static let dracula = DiagramTheme(
        background: BMColor(hex: "#282a36"),
        foreground: BMColor(hex: "#f8f8f2"),
        line: BMColor(hex: "#6272a4"),
        accent: BMColor(hex: "#bd93f9"),
        muted: BMColor(hex: "#6272a4")
    )
    public static let githubLight = DiagramTheme(
        background: BMColor(hex: "#ffffff"),
        foreground: BMColor(hex: "#1f2328"),
        line: BMColor(hex: "#d1d9e0"),
        accent: BMColor(hex: "#0969da"),
        muted: BMColor(hex: "#59636e")
    )
    public static let githubDark = DiagramTheme(
        background: BMColor(hex: "#0d1117"),
        foreground: BMColor(hex: "#e6edf3"),
        line: BMColor(hex: "#3d444d"),
        accent: BMColor(hex: "#4493f8"),
        muted: BMColor(hex: "#9198a1")
    )
    public static let solarizedLight = DiagramTheme(
        background: BMColor(hex: "#fdf6e3"),
        foreground: BMColor(hex: "#657b83"),
        line: BMColor(hex: "#93a1a1"),
        accent: BMColor(hex: "#268bd2"),
        muted: BMColor(hex: "#93a1a1")
    )
    public static let solarizedDark = DiagramTheme(
        background: BMColor(hex: "#002b36"),
        foreground: BMColor(hex: "#839496"),
        line: BMColor(hex: "#586e75"),
        accent: BMColor(hex: "#268bd2"),
        muted: BMColor(hex: "#586e75")
    )
    public static let oneDark = DiagramTheme(
        background: BMColor(hex: "#282c34"),
        foreground: BMColor(hex: "#abb2bf"),
        line: BMColor(hex: "#4b5263"),
        accent: BMColor(hex: "#c678dd"),
        muted: BMColor(hex: "#5c6370")
    )
    public static let gruvboxDark = DiagramTheme(
        background: BMColor(hex: "#282828"),
        foreground: BMColor(hex: "#ebdbb2"),
        line: BMColor(hex: "#665c54"),
        accent: BMColor(hex: "#83a598"),
        muted: BMColor(hex: "#665c54")
    )
    public static let gruvboxLight = DiagramTheme(
        background: BMColor(hex: "#fbf1c7"),
        foreground: BMColor(hex: "#3c3836"),
        line: BMColor(hex: "#a89984"),
        accent: BMColor(hex: "#458588"),
        muted: BMColor(hex: "#a89984")
    )

    public static let `default` = zincLight

    public static let allThemes: [(name: String, theme: DiagramTheme)] = [
        ("Zinc Light", zincLight),
        ("Zinc Dark", zincDark),
        ("Tokyo Night", tokyoNight),
        ("Tokyo Night Storm", tokyoNightStorm),
        ("Tokyo Night Light", tokyoNightLight),
        ("Catppuccin Mocha", catppuccinMocha),
        ("Catppuccin Latte", catppuccinLatte),
        ("Nord", nord),
        ("Nord Light", nordLight),
        ("Dracula", dracula),
        ("GitHub Light", githubLight),
        ("GitHub Dark", githubDark),
        ("Solarized Light", solarizedLight),
        ("Solarized Dark", solarizedDark),
        ("One Dark", oneDark),
        ("Gruvbox Dark", gruvboxDark),
        ("Gruvbox Light", gruvboxLight)
    ]

    public static func theme(named name: String) -> DiagramTheme? {
        let normalized = name.lowercased().replacingOccurrences(of: " ", with: "-")
        return allThemes.first {
            $0.name.lowercased().replacingOccurrences(of: " ", with: "-") == normalized
        }?.theme
    }

    // MARK: - Shiki / VS Code Theme Import

    /// A VS Code / Shiki theme definition that can be converted to a ``DiagramTheme``.
    ///
    /// Mirrors the `ShikiThemeLike` structure from the TypeScript library.
    /// Provide `colors` (VS Code workbench color keys like `"editor.background"`)
    /// and optionally `tokenColors` for syntax-scope-based accent extraction.
    public struct ShikiTheme: Sendable {
        public var type: String?
        public var colors: [String: String]
        public var tokenColors: [TokenColor]

        public struct TokenColor: Sendable {
            public var scope: [String]
            public var foreground: String?

            public init(scope: [String], foreground: String? = nil) {
                self.scope = scope
                self.foreground = foreground
            }
        }

        public init(
            type: String? = nil,
            colors: [String: String] = [:],
            tokenColors: [TokenColor] = []
        ) {
            self.type = type
            self.colors = colors
            self.tokenColors = tokenColors
        }
    }

    /// Create a ``DiagramTheme`` from a VS Code / Shiki theme.
    ///
    /// Maps VS Code workbench color keys to diagram colors:
    /// - `editor.background` → background
    /// - `editor.foreground` → foreground
    /// - `editorLineNumber.foreground` → line
    /// - `focusBorder` or `keyword` token → accent
    /// - `comment` token or `editorLineNumber.foreground` → muted
    /// - `editor.selectionBackground` → surface
    /// - `editorWidget.border` → border
    public static func fromShikiTheme(_ theme: ShikiTheme) -> DiagramTheme {
        let shikiInput = original_src_theme.ShikiThemeLike(
            type: theme.type,
            colors: theme.colors,
            tokenColors: theme.tokenColors.map {
                original_src_theme.ShikiTokenColor(scope: $0.scope, foreground: $0.foreground)
            }
        )
        let colors = original_src_theme.fromShikiTheme(shikiInput)
        return DiagramTheme(
            background: BMColor(hex: colors.bg),
            foreground: BMColor(hex: colors.fg),
            line: colors.line.map { BMColor(hex: $0) },
            accent: colors.accent.map { BMColor(hex: $0) },
            muted: colors.muted.map { BMColor(hex: $0) },
            surface: colors.surface.map { BMColor(hex: $0) },
            border: colors.border.map { BMColor(hex: $0) }
        )
    }
}
