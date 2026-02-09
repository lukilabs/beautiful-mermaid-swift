//
//  PlaygroundConfiguration.swift
//  MermaidPlayground
//
//  Configuration state for the playground
//

import SwiftUI
import BeautifulMermaid

/// Singleton configuration for the playground
@Observable
public class PlaygroundConfiguration {
    public static let shared = PlaygroundConfiguration()

    // MARK: - Default Diagram

    private static let defaultDiagram = """
    graph TD
      A[Start] --> B[Process] --> C[End]
    """

    // MARK: - Diagram Source

    public var source: String = PlaygroundConfiguration.defaultDiagram

    // MARK: - Theme

    public var theme: DiagramTheme = .default

    // MARK: - Direction

    public var direction: Direction = .topDown

    // MARK: - Layout Settings

    public var nodePadding: CGFloat = 16

    public var edgeSpacing: CGFloat = 10

    public var rankSeparation: CGFloat = 50

    public var fontSize: CGFloat = 14

    // MARK: - Color Overrides

    public var backgroundOverride: Color?

    public var foregroundOverride: Color?

    public var accentOverride: Color?

    public var lineOverride: Color?

    // MARK: - Reset Methods

    public func resetColorOverrides() {
        backgroundOverride = nil
        foregroundOverride = nil
        accentOverride = nil
        lineOverride = nil
    }

    public func resetLayoutDefaults() {
        nodePadding = 16
        edgeSpacing = 10
        rankSeparation = 50
        fontSize = 14
    }

    private init() {}
}
