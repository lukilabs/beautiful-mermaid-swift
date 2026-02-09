// SPDX-License-Identifier: MIT
//
//  MermaidImageRenderer.swift
//  BeautifulMermaid
//
//  Renders Mermaid diagrams to images
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Renders Mermaid diagrams to images
public class MermaidImageRenderer {

    /// Theme for rendering
    public var theme: DiagramTheme

    /// Layout configuration
    public var layoutConfig: LayoutConfig

    /// Image scale (2.0 = retina)
    public var scale: CGFloat = 2.0

    private let parser = MermaidParser()
    private let layout: GraphLayout

    public init(theme: DiagramTheme = .default, config: LayoutConfig = LayoutConfig()) {
        self.theme = theme
        self.layoutConfig = config
        self.layout = GraphLayout(config: config)
    }

    /// Render a Mermaid diagram to an image
    public func renderImage(from source: String) throws -> BMImage? {
        // Check diagram type and route to appropriate renderer
        let diagramType = detectDiagramType(source)

        switch diagramType {
        case .sequence:
            return try renderSequenceImage(from: source)
        case .classDiagram:
            return try renderClassImage(from: source)
        case .erDiagram:
            return try renderErImage(from: source)
        case .flowchart, .stateDiagram:
            // State diagrams use the same rendering pipeline as flowcharts
            let graph = try parser.parse(source)
            // Use parsed graph's direction (from source) by default
            var config = layoutConfig
            config.direction = graph.direction
            let positioned = try layout.layout(graph, config: config)
            return renderImage(from: positioned)
        }
    }

    /// Diagram type enumeration
    private enum DiagramType {
        case flowchart
        case stateDiagram
        case sequence
        case classDiagram
        case erDiagram
    }

    /// Detect the diagram type from source
    private func detectDiagramType(_ source: String) -> DiagramType {
        let lines = source.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            if trimmed.isEmpty || trimmed.hasPrefix("%%") { continue }
            if trimmed.hasPrefix("sequencediagram") {
                return .sequence
            }
            if trimmed.hasPrefix("classdiagram") {
                return .classDiagram
            }
            if trimmed.hasPrefix("erdiagram") {
                return .erDiagram
            }
            if trimmed.hasPrefix("statediagram") {
                return .stateDiagram
            }
            // Default to flowchart
            return .flowchart
        }
        return .flowchart
    }

    /// Render a sequence diagram to an image
    private func renderSequenceImage(from source: String) throws -> BMImage? {
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Find start index
        var startIndex = 0
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("sequenceDiagram") {
                startIndex = index + 1
                break
            }
        }

        let seqParser = SequenceParser()
        let diagram = seqParser.parseSequence(lines, startIndex: startIndex)

        let seqLayout = SequenceLayout()
        let positioned = seqLayout.layoutSequence(diagram, config: layoutConfig)

        let seqRenderer = SequenceRenderer(theme: theme)
        return seqRenderer.renderToImage(positioned, scale: scale)
    }

    /// Render a class diagram to an image
    private func renderClassImage(from source: String) throws -> BMImage? {
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Find start index after "classDiagram"
        var startIndex = 0
        for (index, line) in lines.enumerated() {
            if line.lowercased().hasPrefix("classdiagram") {
                startIndex = index + 1
                break
            }
        }

        let classParser = ClassParser()
        let parsed = try classParser.parseClassDiagram(lines, startIndex: startIndex)

        let positioned = try ClassLayout.layout(parsed)

        let classRenderer = ClassDiagramRenderer(theme: theme)
        return classRenderer.renderToImage(positioned, scale: scale)
    }

    /// Render an ER diagram to an image
    private func renderErImage(from source: String) throws -> BMImage? {
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Find start index after "erDiagram"
        var startIndex = 0
        for (index, line) in lines.enumerated() {
            if line.lowercased().hasPrefix("erdiagram") {
                startIndex = index + 1
                break
            }
        }

        let erParser = ERParser()
        let parsed = try erParser.parseErDiagram(lines, startIndex: startIndex)

        let positioned = try ErLayout.layout(parsed)

        let erRenderer = ERDiagramRenderer(theme: theme)
        return erRenderer.renderToImage(positioned, scale: scale)
    }

    /// Render a positioned graph to an image
    public func renderImage(from graph: PositionedGraph) -> BMImage? {
        let renderer = DiagramRenderer(theme: theme)
        return renderer.renderToImage(graph, scale: scale)
    }

    /// Render with custom size (diagram will be scaled to fit)
    public func renderImage(from source: String, size: CGSize) throws -> BMImage? {
        let graph = try parser.parse(source)

        var config = layoutConfig
        config.direction = graph.direction

        let positioned = try layout.layout(graph, config: config)

        return renderImage(from: positioned, size: size)
    }

    /// Render a positioned graph to an image with custom size
    public func renderImage(from graph: PositionedGraph, size: CGSize) -> BMImage? {
        let renderer = DiagramRenderer(theme: theme)

        // Calculate scale to fit
        let scaleX = size.width / graph.bounds.width
        let scaleY = size.height / graph.bounds.height
        let fitScale = min(scaleX, scaleY)

        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        let imageRenderer = UIGraphicsImageRenderer(size: size, format: format)

        return imageRenderer.image { rendererContext in
            let context = rendererContext.cgContext

            // Fill background
            context.setFillColor(theme.background.cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            // Center and scale
            let scaledWidth = graph.bounds.width * fitScale
            let scaledHeight = graph.bounds.height * fitScale
            let offsetX = (size.width - scaledWidth) / 2
            let offsetY = (size.height - scaledHeight) / 2

            context.translateBy(x: offsetX, y: offsetY)
            context.scaleBy(x: fitScale, y: fitScale)
            context.translateBy(x: -graph.bounds.minX, y: -graph.bounds.minY)

            renderer.render(graph, in: context, bounds: graph.bounds)
        }
        #elseif canImport(AppKit)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        // Fill background
        context.setFillColor(theme.background.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Flip for AppKit
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        // Center and scale
        let scaledWidth = graph.bounds.width * fitScale
        let scaledHeight = graph.bounds.height * fitScale
        let offsetX = (size.width - scaledWidth) / 2
        let offsetY = (size.height - scaledHeight) / 2

        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: fitScale, y: fitScale)
        context.translateBy(x: -graph.bounds.minX, y: -graph.bounds.minY)

        renderer.render(graph, in: context, bounds: graph.bounds)

        image.unlockFocus()
        return image
        #endif
    }

    #if canImport(UIKit)
    /// Render to PNG data
    public func renderPNG(from source: String) throws -> Data? {
        guard let image = try renderImage(from: source) else { return nil }
        return image.pngData()
    }

    /// Render to JPEG data
    public func renderJPEG(from source: String, quality: CGFloat = 0.9) throws -> Data? {
        guard let image = try renderImage(from: source) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }
    #elseif canImport(AppKit)
    /// Render to PNG data
    public func renderPNG(from source: String) throws -> Data? {
        guard let image = try renderImage(from: source),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Render to JPEG data
    public func renderJPEG(from source: String, quality: CGFloat = 0.9) throws -> Data? {
        guard let image = try renderImage(from: source),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
    #endif
}

// MARK: - Convenience API

extension MermaidImageRenderer {
    /// Quick render with default settings
    public static func render(
        _ source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) throws -> BMImage? {
        let renderer = MermaidImageRenderer(theme: theme)
        renderer.scale = scale
        return try renderer.renderImage(from: source)
    }

    /// Quick render with custom size
    public static func render(
        _ source: String,
        size: CGSize,
        theme: DiagramTheme = .default
    ) throws -> BMImage? {
        let renderer = MermaidImageRenderer(theme: theme)
        return try renderer.renderImage(from: source, size: size)
    }
}
