//
//  PreviewView.swift
//  MermaidPlayground
//
//  Preview view for rendered diagrams with zoom support
//

import SwiftUI
import BeautifulMermaid

struct PreviewView: View {
    @Bindable var config: PlaygroundConfiguration

    @SwiftUI.State private var parseError: Error?
    @SwiftUI.State private var diagramBounds: CGRect = .zero
    @SwiftUI.State private var zoomScale: CGFloat = 1.0
    @SwiftUI.State private var lastZoomScale: CGFloat = 1.0
    @SwiftUI.State private var hasSetInitialZoom: Bool = false
    @SwiftUI.State private var lastSourceHash: Int = 0

    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 4.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(config.theme.background)
                    .ignoresSafeArea()

                // Zoomable content
                let layoutConfig = buildLayoutConfig()
                let baseSize = calculateContentSize(
                    diagramBounds: diagramBounds,
                    viewSize: geometry.size
                )

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    MermaidViewRepresentable(
                        source: config.source,
                        theme: config.theme,
                        layoutConfig: layoutConfig,
                        parseError: $parseError,
                        diagramBounds: $diagramBounds
                    )
                    .frame(width: baseSize.width, height: baseSize.height)
                    .scaleEffect(zoomScale, anchor: .center)
                    .frame(
                        width: max(baseSize.width * zoomScale, geometry.size.width),
                        height: max(baseSize.height * zoomScale, geometry.size.height)
                    )
                }
                .defaultScrollAnchor(.center)
                .scrollBounceBehavior(.basedOnSize)
                #if targetEnvironment(macCatalyst)
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastZoomScale * value
                            zoomScale = min(max(newScale, minZoom), maxZoom)
                        }
                        .onEnded { _ in
                            lastZoomScale = zoomScale
                        }
                )
                #else
                .highPriorityGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastZoomScale * value
                            zoomScale = min(max(newScale, minZoom), maxZoom)
                        }
                        .onEnded { _ in
                            lastZoomScale = zoomScale
                        }
                )
                #endif
                .onChange(of: diagramBounds) { _, newBounds in
                    let sourceHash = config.source.hashValue
                    // Reset zoom to fit when source changes or first load
                    if !hasSetInitialZoom || sourceHash != lastSourceHash {
                        let fitScale = calculateFitScale(diagramBounds: newBounds, viewSize: geometry.size)
                        zoomScale = fitScale
                        lastZoomScale = fitScale
                        hasSetInitialZoom = true
                        lastSourceHash = sourceHash
                    }
                }

                // Error overlay
                if let error = parseError {
                    VStack {
                        Text("Parse Error")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.body)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(config.theme.background).opacity(0.9))
                    )
                }
            }
        }
    }

    private func buildLayoutConfig() -> LayoutConfig {
        var layoutConfig = LayoutConfig()
        layoutConfig.nodePadding = CGSize(
            width: config.nodePadding,
            height: config.nodePadding * 0.625
        )
        layoutConfig.edgeSeparation = config.edgeSpacing
        layoutConfig.rankSeparation = config.rankSeparation
        layoutConfig.font = BMFont.systemFont(ofSize: config.fontSize)
        layoutConfig.direction = config.direction
        return layoutConfig
    }

    private func calculateContentSize(diagramBounds: CGRect, viewSize: CGSize) -> CGSize {
        let padding: CGFloat = 40
        let minWidth = max(viewSize.width, 100)
        let minHeight = max(viewSize.height, 100)

        let contentWidth = max(diagramBounds.width + padding * 2, minWidth)
        let contentHeight = max(diagramBounds.height + padding * 2, minHeight)

        return CGSize(width: contentWidth, height: contentHeight)
    }

    private func calculateFitScale(diagramBounds: CGRect, viewSize: CGSize) -> CGFloat {
        guard diagramBounds.width > 0 && diagramBounds.height > 0 else {
            return 1.0
        }

        let padding: CGFloat = 40
        let availableWidth = viewSize.width - padding * 2
        let availableHeight = viewSize.height - padding * 2

        let scaleX = availableWidth / diagramBounds.width
        let scaleY = availableHeight / diagramBounds.height

        // Fit to view (use the smaller scale to ensure diagram fits)
        let fitScale = min(scaleX, scaleY)

        // Clamp to allowed zoom range
        return min(max(fitScale, minZoom), maxZoom)
    }
}

#Preview {
    PreviewView(config: PlaygroundConfiguration.shared)
}
