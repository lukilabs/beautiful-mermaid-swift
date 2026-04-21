import SwiftUI
import CoreGraphics

/// A value-type model that manages the Mermaid diagram pipeline (parse -> layout -> render).
///
/// Mutating `source`, `theme`, or `layoutConfig` re-runs the pipeline synchronously and refreshes
/// `preparedDiagram`, `diagramBounds`, and `parseError`. Hold it in `@State` to drive a
/// ``MermaidDiagramView``.
///
/// Usage:
/// ```swift
/// @State private var diagram = MermaidDiagram(source: "graph TD; A-->B")
///
/// var body: some View {
///     MermaidDiagramView(diagram)
///         .frame(height: 300)
/// }
/// ```
public struct MermaidDiagram {

    public var source: String {
        didSet { if source != oldValue { prepare() } }
    }

    public var theme: DiagramTheme {
        didSet { if theme != oldValue { prepare() } }
    }

    public var layoutConfig: LayoutConfig {
        didSet { if layoutConfig != oldValue { prepare() } }
    }

    public private(set) var parseError: Error?
    public private(set) var diagramBounds: CGRect = .zero
    public private(set) var preparedDiagram: PreparedDiagram?

    public init(
        source: String = "",
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        prepare()
    }

    private mutating func prepare() {
        parseError = nil
        preparedDiagram = nil
        diagramBounds = .zero

        guard !source.isEmpty else { return }

        do {
            let graph = try MermaidParser.parse(source)
            let layout = GraphLayout(config: layoutConfig)
            let positioned = try layout.layout(graph)
            let renderer = DiagramRenderer(theme: theme)

            let bounds = CGRect(x: 0, y: 0, width: max(1, positioned.width), height: max(1, positioned.height))
            preparedDiagram = PreparedDiagram(bounds: bounds) { context, renderBounds in
                renderer.render(positioned, in: context, bounds: renderBounds)
            }
            diagramBounds = bounds
        } catch {
            parseError = error
        }
    }
}

// MARK: - MermaidDiagramView convenience init for the value-type model

#if canImport(UIKit)
import UIKit

@available(iOS 16.0, macCatalyst 16.0, visionOS 1.0, *)
extension MermaidDiagramView {
    /// Create a diagram view driven by a ``MermaidDiagram`` value.
    public init(_ diagram: MermaidDiagram) {
        self.init(
            source: diagram.source,
            theme: diagram.theme,
            layoutConfig: diagram.layoutConfig
        )
    }
}

#elseif canImport(AppKit)
import AppKit

@available(macOS 13.0, *)
extension MermaidDiagramView {
    /// Create a diagram view driven by a ``MermaidDiagram`` value.
    public init(_ diagram: MermaidDiagram) {
        self.init(
            source: diagram.source,
            theme: diagram.theme,
            layoutConfig: diagram.layoutConfig
        )
    }
}

#endif
