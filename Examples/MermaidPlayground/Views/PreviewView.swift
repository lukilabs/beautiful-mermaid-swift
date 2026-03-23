//
//  PreviewView.swift
//  MermaidPlayground
//
//  Preview view for rendered diagrams with zoom support
//

import SwiftUI
import BeautifulMermaid

@available(iOS 17.0, macOS 14.0, macCatalyst 17.0, *)
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

                // zoomScale is the actual diagram scale: 1.0 = natural size.
                // The MermaidView frame matches the zoomed diagram size so it
                // re-renders at native resolution (crisp at any zoom level).
                let scaledWidth = max(diagramBounds.width * zoomScale, 1)
                let scaledHeight = max(diagramBounds.height * zoomScale, 1)

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack {
                        // Scroll content sized to at least the viewport
                        Color.clear
                            .frame(
                                width: max(scaledWidth, geometry.size.width),
                                height: max(scaledHeight, geometry.size.height)
                            )

                        // MermaidView at exact zoomed diagram size, centered
                        MermaidViewRepresentable(
                            source: config.source,
                            theme: config.theme,
                            parseError: $parseError,
                            diagramBounds: $diagramBounds
                        )
                        .frame(width: scaledWidth, height: scaledHeight)
                    }
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

                #if targetEnvironment(macCatalyst)
                // Zoom controls
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Spacer()
                        HStack(spacing: 2) {
                            Button {
                                let newScale = max(zoomScale / 1.25, minZoom)
                                zoomScale = newScale
                                lastZoomScale = newScale
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 28, height: 28)
                            }

                            Divider()
                                .frame(height: 18)

                            Text("\(Int(round(zoomScale * 100)))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .frame(width: 44)

                            Divider()
                                .frame(height: 18)

                            Button {
                                let newScale = min(zoomScale * 1.25, maxZoom)
                                zoomScale = newScale
                                lastZoomScale = newScale
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 28, height: 28)
                            }

                            Divider()
                                .frame(height: 18)

                            Button {
                                let fitScale = calculateFitScale(
                                    diagramBounds: diagramBounds,
                                    viewSize: geometry.size
                                )
                                zoomScale = fitScale
                                lastZoomScale = fitScale
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundColor(Color(config.theme.foreground))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(config.theme.background).opacity(0.85))
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        )
                        .padding(12)
                    }
                }
                #endif
            }
        }
    }

    /// Calculate the zoom scale that fits the diagram within the view
    private func calculateFitScale(diagramBounds: CGRect, viewSize: CGSize) -> CGFloat {
        guard diagramBounds.width > 0 && diagramBounds.height > 0 else {
            return 1.0
        }

        let scaleX = viewSize.width / diagramBounds.width
        let scaleY = viewSize.height / diagramBounds.height

        // Fit to view, clamped to zoom range
        return min(max(min(scaleX, scaleY), minZoom), maxZoom)
    }
}
