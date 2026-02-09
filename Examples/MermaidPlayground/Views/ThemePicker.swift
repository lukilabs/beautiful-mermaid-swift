//
//  ThemePicker.swift
//  MermaidPlayground
//
//  Theme selection UI with quick-access buttons and full menu
//

import SwiftUI
import BeautifulMermaid

struct ThemePicker: View {
    @Bindable var config: PlaygroundConfiguration

    /// Quick-access theme names (shown as separate buttons)
    private let quickAccessThemes = ["Zinc Light", "Dracula", "Solarized Light"]

    var body: some View {
        VStack(spacing: 8) {
            // Quick-access theme buttons
            HStack(spacing: 8) {
                ForEach(quickAccessThemes, id: \.self) { themeName in
                    if let theme = DiagramTheme.theme(named: themeName) {
                        QuickThemeButton(
                            themeName: themeName,
                            theme: theme,
                            isSelected: isThemeSelected(theme),
                            currentTheme: config.theme
                        ) {
                            config.theme = theme
                        }
                    }
                }
            }

            // More themes menu button
            Menu {
                ForEach(DiagramTheme.allThemes, id: \.name) { name, theme in
                    Button {
                        config.theme = theme
                    } label: {
                        HStack {
                            ThemeCircle(theme: theme, size: 24)
                            Text(name)
                            if isThemeSelected(theme) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("\(DiagramTheme.allThemes.count) Themes")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(config.theme.effectiveLine()).opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .foregroundColor(Color(config.theme.foreground))
        }
    }

    private func isThemeSelected(_ theme: DiagramTheme) -> Bool {
        theme.background.hexString == config.theme.background.hexString
    }

    private func shortThemeName(_ fullName: String) -> String {
        switch fullName {
        case "Zinc Light": return "Default"
        case "Solarized Light": return "Solarized"
        default: return fullName
        }
    }
}

struct QuickThemeButton: View {
    let themeName: String
    let theme: DiagramTheme
    let isSelected: Bool
    let currentTheme: DiagramTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ThemeCircle(theme: theme, size: 18)
                Text(shortThemeName)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(currentTheme.foreground).opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Color(currentTheme.effectiveLine()).opacity(isSelected ? 1.0 : 0.5),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(currentTheme.foreground))
    }

    private var shortThemeName: String {
        switch themeName {
        case "Zinc Light": return "Default"
        case "Solarized Light": return "Solarized"
        default: return themeName
        }
    }
}

struct ThemeCircle: View {
    let theme: DiagramTheme
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color(theme.background))
            .frame(width: size - 2, height: size - 2)
            .overlay(
                Circle()
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
            )
    }
}

#Preview {
    ThemePicker(config: PlaygroundConfiguration.shared)
        .padding()
}
