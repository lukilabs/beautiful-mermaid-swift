import Foundation
import CoreGraphics
import ElkSwift
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Main entry point for rendering Mermaid diagrams.
/// API shape is kept compatible with the OSS BeautifulMermaid public surface.
public struct MermaidRenderer {

    /// Render a Mermaid diagram to a native image.
    public static func renderImage(
        source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) throws -> BMImage? {
        _ = ElkSwift.version
        let renderer = MermaidImageRenderer(theme: theme)
        renderer.scale = scale
        return try renderer.renderImage(from: source)
    }

    /// Render a Mermaid diagram to a native image with specific size.
    public static func renderImage(
        source: String,
        size: CGSize,
        theme: DiagramTheme = .default
    ) throws -> BMImage? {
        _ = ElkSwift.version
        let renderer = MermaidImageRenderer(theme: theme)
        return try renderer.renderImage(from: source, size: size)
    }

    /// Parse a Mermaid diagram without rendering.
    public static func parse(_ source: String) throws -> MermaidGraph {
        _ = ElkSwift.version
        return try MermaidParser.parse(source)
    }

    /// Parse and layout a Mermaid diagram.
    public static func layout(
        _ source: String,
        config: LayoutConfig = LayoutConfig()
    ) throws -> PositionedGraph {
        _ = ElkSwift.version
        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout(config: config)
        return try layout.layout(graph)
    }

    /// Render directly to a CGContext.
    public static func render(
        source: String,
        in context: CGContext,
        bounds: CGRect,
        theme: DiagramTheme = .default
    ) throws {
        _ = ElkSwift.version
        // Direct CGContext render path (parse -> layout -> renderer) avoids
        // native SVG rasterization artifacts on macOS.
        //
        // IMPORTANT: DiagramRenderer expects a top-left coordinate system
        // (y=0 at top). On macOS/AppKit, raw CGContexts have y=0 at bottom.
        // Callers must flip the context before calling this method:
        //   context.translateBy(x: 0, y: bounds.height)
        //   context.scaleBy(x: 1, y: -1)
        // MermaidImageRenderer._renderPrepared() does this automatically.
        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)
        DiagramRenderer(theme: theme).render(positioned, in: context, bounds: bounds)
    }
}

extension MermaidRenderer {
    public static let version = "0.1.1"
    public static let supportedDiagramTypes: [DiagramType] = DiagramType.allCases

    // MARK: - SVG Output

    /// Render a Mermaid diagram to an SVG string.
    public static func renderSVG(
        source: String,
        theme: DiagramTheme = .default
    ) throws -> String {
        _ = ElkSwift.version
        let renderer = MermaidImageRenderer(theme: theme)
        return try renderer.renderSVG(from: source)
    }

    // MARK: - ASCII Output

    /// Render a Mermaid diagram to an ASCII/Unicode string.
    public static func renderASCII(
        source: String,
        theme: DiagramTheme = .default
    ) throws -> String {
        _ = ElkSwift.version
        let colors: [String: String] = [
            "fg": theme.foreground.hexString,
            "border": (theme.border ?? theme.foreground).hexString,
            "line": (theme.line ?? theme.foreground).hexString,
            "arrow": (theme.line ?? theme.foreground).hexString,
        ]
        let asciiTheme = original_src_ascii_index.diagramColorsToAsciiTheme(colors)
        let options = original_src_ascii_index.AsciiRenderOptions(theme: asciiTheme)
        return try original_src_ascii_index.renderMermaidASCII(source, options: options)
    }

    // MARK: - Async Variants

    /// Render a Mermaid diagram to a native image asynchronously.
    public static func renderImageAsync(
        source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) async throws -> BMImage? {
        try await Task.detached {
            try renderImage(source: source, theme: theme, scale: scale)
        }.value
    }

    /// Render a Mermaid diagram to an SVG string asynchronously.
    public static func renderSVGAsync(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await Task.detached {
            try renderSVG(source: source, theme: theme)
        }.value
    }

    /// Render a Mermaid diagram to an ASCII/Unicode string asynchronously.
    public static func renderASCIIAsync(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await Task.detached {
            try renderASCII(source: source, theme: theme)
        }.value
    }

    /// Parse and layout a Mermaid diagram asynchronously.
    /// Returns a prepared diagram that can be rendered into a CGContext.
    public static func prepareAsync(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> PreparedDiagram {
        let renderer = MermaidImageRenderer(theme: theme)
        return try await Task.detached {
            try renderer.prepare(from: source)
        }.value!
    }
}

extension String {
    public func parseMermaid() throws -> MermaidGraph {
        try MermaidParser.parse(self)
    }

    public func renderMermaidImage(
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) throws -> BMImage? {
        try MermaidRenderer.renderImage(source: self, theme: theme, scale: scale)
    }

    public func renderMermaidSVG(
        theme: DiagramTheme = .default
    ) throws -> String {
        try MermaidRenderer.renderSVG(source: self, theme: theme)
    }

    public func renderMermaidASCII(
        theme: DiagramTheme = .default
    ) throws -> String {
        try MermaidRenderer.renderASCII(source: self, theme: theme)
    }
}
