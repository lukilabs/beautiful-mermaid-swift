// SPDX-License-Identifier: MIT
//
//  BeautifulMermaid.swift
//  BeautifulMermaid
//
//  Public API for the BeautifulMermaid library
//

import Foundation
import CoreGraphics

/// Main entry point for rendering Mermaid diagrams
public struct MermaidRenderer {

    // MARK: - Image Rendering

    /// Render a Mermaid diagram to a native image
    /// - Parameters:
    ///   - source: Mermaid diagram source text
    ///   - theme: Theme for rendering (default: tokyoNight)
    ///   - scale: Image scale factor (default: 2.0 for retina)
    /// - Returns: Rendered image, or nil if parsing fails
    public static func renderImage(
        source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) throws -> BMImage? {
        let renderer = MermaidImageRenderer(theme: theme)
        renderer.scale = scale
        return try renderer.renderImage(from: source)
    }

    /// Render a Mermaid diagram to a native image with specific size
    /// - Parameters:
    ///   - source: Mermaid diagram source text
    ///   - size: Target image size (diagram will be scaled to fit)
    ///   - theme: Theme for rendering
    /// - Returns: Rendered image, or nil if parsing fails
    public static func renderImage(
        source: String,
        size: CGSize,
        theme: DiagramTheme = .default
    ) throws -> BMImage? {
        let renderer = MermaidImageRenderer(theme: theme)
        return try renderer.renderImage(from: source, size: size)
    }

    // MARK: - Parsing

    /// Parse a Mermaid diagram without rendering
    /// - Parameter source: Mermaid diagram source text
    /// - Returns: Parsed graph structure
    public static func parse(_ source: String) throws -> MermaidGraph {
        try MermaidParser.parse(source)
    }

    /// Parse and layout a Mermaid diagram
    /// - Parameters:
    ///   - source: Mermaid diagram source text
    ///   - config: Layout configuration
    /// - Returns: Positioned graph ready for rendering
    public static func layout(
        _ source: String,
        config: LayoutConfig = LayoutConfig()
    ) throws -> PositionedGraph {
        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout(config: config)
        return try layout.layout(graph)
    }

    // MARK: - Direct Context Rendering

    /// Render directly to a CGContext
    /// - Parameters:
    ///   - source: Mermaid diagram source text
    ///   - context: Target CoreGraphics context
    ///   - bounds: Drawing bounds
    ///   - theme: Theme for rendering
    public static func render(
        source: String,
        in context: CGContext,
        bounds: CGRect,
        theme: DiagramTheme = .default
    ) throws {
        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)

        let renderer = DiagramRenderer(theme: theme)
        renderer.render(positioned, in: context, bounds: bounds)
    }
}

// MARK: - Version Info

extension MermaidRenderer {
    /// Library version
    public static let version = "0.1.1"

    /// Supported Mermaid diagram types
    public static let supportedDiagramTypes: [DiagramType] = DiagramType.allCases
}

// MARK: - Convenience Extensions

extension String {
    /// Parse this string as a Mermaid diagram
    public func parseMermaid() throws -> MermaidGraph {
        try MermaidParser.parse(self)
    }

    /// Render this string as a Mermaid diagram to an image
    public func renderMermaidImage(
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) throws -> BMImage? {
        try MermaidRenderer.renderImage(source: self, theme: theme, scale: scale)
    }

}
