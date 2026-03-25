import Foundation
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public final class MermaidImageRenderer {
    public var theme: DiagramTheme
    public var layoutConfig: LayoutConfig
    public var scale: CGFloat = 2.0

    public init(theme: DiagramTheme = .default, config: LayoutConfig = LayoutConfig()) {
        self.theme = theme
        self.layoutConfig = config
    }

    /// Prepare a diagram for direct CGContext rendering.
    public func prepare(from source: String) throws -> PreparedDiagram? {
        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout(config: layoutConfig)
        let positioned = try layout.layout(graph)
        let renderer = DiagramRenderer(theme: theme)

        let bounds = CGRect(x: 0, y: 0, width: max(1, positioned.width), height: max(1, positioned.height))
        return PreparedDiagram(bounds: bounds) { context, renderBounds in
            renderer.render(positioned, in: context, bounds: renderBounds)
        }
    }

    /// Render a Mermaid diagram to an image using the CGContext pipeline.
    public func renderImage(from source: String, scale overrideScale: CGFloat? = nil) throws -> BMImage? {
        guard let prepared = try prepare(from: source) else { return nil }
        return _renderPrepared(prepared, scale: overrideScale ?? scale)
    }

    /// Render a positioned graph to an image.
    public func renderImage(from positioned: PositionedGraph, scale overrideScale: CGFloat? = nil) -> BMImage? {
        let renderer = DiagramRenderer(theme: theme)
        let bounds = CGRect(x: 0, y: 0, width: max(1, positioned.width), height: max(1, positioned.height))
        let prepared = PreparedDiagram(bounds: bounds) { context, renderBounds in
            renderer.render(positioned, in: context, bounds: renderBounds)
        }
        return _renderPrepared(prepared, scale: overrideScale ?? scale)
    }

    /// Render with custom output size (diagram will be aspect-fit scaled).
    public func renderImage(from source: String, size: CGSize) throws -> BMImage? {
        guard let prepared = try prepare(from: source) else { return nil }
        return _renderPreparedFitted(prepared, size: size)
    }

    /// Render via SVG path (fallback for cases where SVG string output is needed).
    public func renderSVG(from source: String) throws -> String {
        _ = _ElkBridge.version
        let options = RenderOptions(
            bg: _hex(theme.background),
            fg: _hex(theme.foreground),
            line: _hex(theme.effectiveLine()),
            accent: _hex(theme.effectiveAccent()),
            muted: _hex(theme.effectiveMuted()),
            surface: _hex(theme.effectiveSurface()),
            border: _hex(theme.effectiveBorder()),
            transparent: false
        )

        let svg = try renderMermaidSVG(source, options)
        let resolvedSvg = _resolveSvgCssVariables(svg)
        return _flattenKnownSvgTokens(resolvedSvg, theme: theme)
    }

    /// Render via SVG path to an image (legacy behavior).
    public func renderSVGImage(from source: String) throws -> BMImage? {
        let svg = try renderSVG(from: source)
        guard let data = svg.data(using: .utf8) else { return nil }
        #if targetEnvironment(macCatalyst)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #elseif canImport(UIKit)
        return UIImage(data: data)
        #else
        return nil
        #endif
    }

    #if targetEnvironment(macCatalyst) || canImport(UIKit)
    public func renderPNG(from source: String) throws -> Data? {
        guard let image = try renderImage(from: source) else { return nil }
        return image.pngData()
    }

    public func renderJPEG(from source: String, quality: CGFloat = 0.9) throws -> Data? {
        guard let image = try renderImage(from: source) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }
    #elseif canImport(AppKit)
    public func renderPNG(from source: String) throws -> Data? {
        guard let image = try renderImage(from: source),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    public func renderJPEG(from source: String, quality: CGFloat = 0.9) throws -> Data? {
        guard let image = try renderImage(from: source),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
    #endif

    // MARK: - Private

    private func _renderPrepared(_ prepared: PreparedDiagram, scale: CGFloat) -> BMImage? {
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return nil }

        let size = CGSize(width: diagBounds.width, height: diagBounds.height)

        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        let uiRenderer = UIGraphicsImageRenderer(size: size, format: format)
        return uiRenderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            if !theme.transparent {
                ctx.setFillColor(theme.background.cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
            prepared.render(ctx, diagBounds)
        }
        #elseif canImport(AppKit)
        let pixelSize = NSSize(width: diagBounds.width * scale, height: diagBounds.height * scale)
        let width = Int(pixelSize.width)
        let height = Int(pixelSize.height)
        guard width > 0, height > 0,
              let ctx = CGContext(
                  data: nil, width: width, height: height,
                  bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else { return nil }

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(CGRect(origin: .zero, size: pixelSize))
        }

        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)

        prepared.render(ctx, diagBounds)

        guard let cgImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: size)
        #endif
    }

    private func _renderPreparedFitted(_ prepared: PreparedDiagram, size: CGSize) -> BMImage? {
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return nil }

        let scaleX = size.width / diagBounds.width
        let scaleY = size.height / diagBounds.height
        let fitScale = min(scaleX, scaleY)

        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        let uiRenderer = UIGraphicsImageRenderer(size: size, format: format)
        return uiRenderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            if !theme.transparent {
                ctx.setFillColor(theme.background.cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
            }

            let scaledWidth = diagBounds.width * fitScale
            let scaledHeight = diagBounds.height * fitScale
            let offsetX = (size.width - scaledWidth) / 2
            let offsetY = (size.height - scaledHeight) / 2

            ctx.translateBy(x: offsetX, y: offsetY)
            ctx.scaleBy(x: fitScale, y: fitScale)
            ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
            prepared.render(ctx, diagBounds)
        }
        #elseif canImport(AppKit)
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0,
              let ctx = CGContext(
                  data: nil, width: width, height: height,
                  bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else { return nil }

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        let scaledWidth = diagBounds.width * fitScale
        let scaledHeight = diagBounds.height * fitScale
        let offsetX = (size.width - scaledWidth) / 2
        let offsetY = (size.height - scaledHeight) / 2

        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: fitScale, y: fitScale)
        ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)

        prepared.render(ctx, diagBounds)

        guard let cgImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: size)
        #endif
    }
}

// MARK: - Convenience API

extension MermaidImageRenderer {
    public static func render(
        _ source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) throws -> BMImage? {
        let renderer = MermaidImageRenderer(theme: theme)
        renderer.scale = scale
        return try renderer.renderImage(from: source)
    }

    public static func render(
        _ source: String,
        size: CGSize,
        theme: DiagramTheme = .default
    ) throws -> BMImage? {
        let renderer = MermaidImageRenderer(theme: theme)
        return try renderer.renderImage(from: source, size: size)
    }
}
