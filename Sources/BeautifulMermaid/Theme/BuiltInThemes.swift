// SPDX-License-Identifier: MIT
//
//  BuiltInThemes.swift
//  BeautifulMermaid
//
//  Pre-defined themes for diagram rendering
//  Ported from beautiful-mermaid TypeScript theme.ts
//

import Foundation

extension DiagramTheme {

    // MARK: - Dark Themes

    /// Zinc Dark theme (default dark)
    public static let zincDark = DiagramTheme(
        background: BMColor(hex: "#18181B"),
        foreground: BMColor(hex: "#FAFAFA")
    )

    /// Tokyo Night theme (dark)
    public static let tokyoNight = DiagramTheme(
        background: BMColor(hex: "#1a1b26"),
        foreground: BMColor(hex: "#a9b1d6"),
        line: BMColor(hex: "#3d59a1"),
        accent: BMColor(hex: "#7aa2f7"),
        muted: BMColor(hex: "#565f89")
    )

    /// Tokyo Night Storm theme (dark)
    public static let tokyoNightStorm = DiagramTheme(
        background: BMColor(hex: "#24283b"),
        foreground: BMColor(hex: "#a9b1d6"),
        line: BMColor(hex: "#3d59a1"),
        accent: BMColor(hex: "#7aa2f7"),
        muted: BMColor(hex: "#565f89")
    )

    /// Tokyo Night Light theme
    public static let tokyoNightLight = DiagramTheme(
        background: BMColor(hex: "#d5d6db"),
        foreground: BMColor(hex: "#343b58"),
        line: BMColor(hex: "#34548a"),
        accent: BMColor(hex: "#34548a"),
        muted: BMColor(hex: "#9699a3")
    )

    /// Catppuccin Mocha theme (dark)
    public static let catppuccinMocha = DiagramTheme(
        background: BMColor(hex: "#1e1e2e"),
        foreground: BMColor(hex: "#cdd6f4"),
        line: BMColor(hex: "#585b70"),
        accent: BMColor(hex: "#cba6f7"),
        muted: BMColor(hex: "#6c7086")
    )

    /// Catppuccin Latte theme (light)
    public static let catppuccinLatte = DiagramTheme(
        background: BMColor(hex: "#eff1f5"),
        foreground: BMColor(hex: "#4c4f69"),
        line: BMColor(hex: "#9ca0b0"),
        accent: BMColor(hex: "#8839ef"),
        muted: BMColor(hex: "#9ca0b0")
    )

    /// Nord theme (dark)
    public static let nord = DiagramTheme(
        background: BMColor(hex: "#2e3440"),
        foreground: BMColor(hex: "#d8dee9"),
        line: BMColor(hex: "#4c566a"),
        accent: BMColor(hex: "#88c0d0"),
        muted: BMColor(hex: "#616e88")
    )

    /// Nord Light theme
    public static let nordLight = DiagramTheme(
        background: BMColor(hex: "#eceff4"),
        foreground: BMColor(hex: "#2e3440"),
        line: BMColor(hex: "#aab1c0"),
        accent: BMColor(hex: "#5e81ac"),
        muted: BMColor(hex: "#7b88a1")
    )

    /// Dracula theme (dark)
    public static let dracula = DiagramTheme(
        background: BMColor(hex: "#282a36"),
        foreground: BMColor(hex: "#f8f8f2"),
        line: BMColor(hex: "#6272a4"),
        accent: BMColor(hex: "#bd93f9"),
        muted: BMColor(hex: "#6272a4")
    )

    /// GitHub Light theme
    public static let githubLight = DiagramTheme(
        background: BMColor(hex: "#ffffff"),
        foreground: BMColor(hex: "#1f2328"),
        line: BMColor(hex: "#d1d9e0"),
        accent: BMColor(hex: "#0969da"),
        muted: BMColor(hex: "#59636e")
    )

    /// GitHub Dark theme
    public static let githubDark = DiagramTheme(
        background: BMColor(hex: "#0d1117"),
        foreground: BMColor(hex: "#e6edf3"),
        line: BMColor(hex: "#3d444d"),
        accent: BMColor(hex: "#4493f8"),
        muted: BMColor(hex: "#9198a1")
    )

    /// Solarized Light theme
    public static let solarizedLight = DiagramTheme(
        background: BMColor(hex: "#fdf6e3"),
        foreground: BMColor(hex: "#657b83"),
        line: BMColor(hex: "#93a1a1"),
        accent: BMColor(hex: "#268bd2"),
        muted: BMColor(hex: "#93a1a1")
    )

    /// Solarized Dark theme
    public static let solarizedDark = DiagramTheme(
        background: BMColor(hex: "#002b36"),
        foreground: BMColor(hex: "#839496"),
        line: BMColor(hex: "#586e75"),
        accent: BMColor(hex: "#268bd2"),
        muted: BMColor(hex: "#586e75")
    )

    /// One Dark theme
    public static let oneDark = DiagramTheme(
        background: BMColor(hex: "#282c34"),
        foreground: BMColor(hex: "#abb2bf"),
        line: BMColor(hex: "#4b5263"),
        accent: BMColor(hex: "#c678dd"),
        muted: BMColor(hex: "#5c6370")
    )

    // MARK: - Additional Themes (not in original but useful)

    /// Gruvbox Dark theme
    public static let gruvboxDark = DiagramTheme(
        background: BMColor(hex: "#282828"),
        foreground: BMColor(hex: "#ebdbb2"),
        line: BMColor(hex: "#665c54"),
        accent: BMColor(hex: "#83a598"),
        muted: BMColor(hex: "#665c54")
    )

    /// Gruvbox Light theme
    public static let gruvboxLight = DiagramTheme(
        background: BMColor(hex: "#fbf1c7"),
        foreground: BMColor(hex: "#3c3836"),
        line: BMColor(hex: "#a89984"),
        accent: BMColor(hex: "#458588"),
        muted: BMColor(hex: "#a89984")
    )

    // MARK: - Default Theme

    /// Zinc Light theme (matches TypeScript DEFAULTS)
    /// This is the default mono theme with white background and dark foreground
    public static let zincLight = DiagramTheme(
        background: BMColor(hex: "#FFFFFF"),
        foreground: BMColor(hex: "#27272A")
    )

    /// Default theme (Zinc Light - matches TypeScript defaults)
    public static let `default` = zincLight

    // MARK: - Theme Registry

    /// All available built-in themes matching the original TypeScript implementation
    public static let allThemes: [(name: String, theme: DiagramTheme)] = [
        // Original themes from theme.ts
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
        // Additional themes
        ("Gruvbox Dark", gruvboxDark),
        ("Gruvbox Light", gruvboxLight),
    ]

    /// Get a theme by name (case-insensitive, supports kebab-case)
    public static func theme(named name: String) -> DiagramTheme? {
        let normalized = name.lowercased().replacingOccurrences(of: " ", with: "-")
        return allThemes.first { (themeName, _) in
            themeName.lowercased().replacingOccurrences(of: " ", with: "-") == normalized
        }?.theme
    }
}
