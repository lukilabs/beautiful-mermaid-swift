//
//  MermaidViewRepresentable.swift
//  MermaidPlayground
//
//  SwiftUI wrapper for MermaidView (cross-platform)
//

import SwiftUI
import BeautifulMermaid

#if canImport(UIKit)
import UIKit

struct MermaidViewRepresentable: UIViewRepresentable {
    let source: String
    let theme: DiagramTheme
    let layoutConfig: LayoutConfig

    @Binding var parseError: Error?
    @Binding var diagramBounds: CGRect

    func makeUIView(context: Context) -> MermaidView {
        let view = MermaidView()
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        return view
    }

    func updateUIView(_ view: MermaidView, context: Context) {
        // Check if layout config changed (especially direction)
        let configChanged = view.layoutConfig.direction != layoutConfig.direction ||
                           view.layoutConfig.rankSeparation != layoutConfig.rankSeparation ||
                           view.layoutConfig.nodeSeparation != layoutConfig.nodeSeparation

        // Update theme
        if view.theme.background.hexString != theme.background.hexString ||
           view.theme.foreground.hexString != theme.foreground.hexString {
            view.theme = theme
        }

        // Update layout config if changed
        if configChanged {
            view.layoutConfig = layoutConfig
        }

        // Update source (triggers re-render) or force re-render if config changed
        if view.source != source {
            view.source = source
        } else if configChanged {
            // Force re-render by re-setting the source
            let currentSource = view.source
            view.source = ""
            view.source = currentSource
        }

        // Report back the parse error and diagram bounds
        DispatchQueue.main.async {
            self.parseError = view.parseError
            self.diagramBounds = view.diagramBounds
        }
    }
}

#elseif canImport(AppKit)
import AppKit

struct MermaidViewRepresentable: NSViewRepresentable {
    let source: String
    let theme: DiagramTheme
    let layoutConfig: LayoutConfig

    @Binding var parseError: Error?
    @Binding var diagramBounds: CGRect

    func makeNSView(context: Context) -> MermaidView {
        let view = MermaidView()
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        return view
    }

    func updateNSView(_ view: MermaidView, context: Context) {
        // Check if layout config changed (especially direction)
        let configChanged = view.layoutConfig.direction != layoutConfig.direction ||
                           view.layoutConfig.rankSeparation != layoutConfig.rankSeparation ||
                           view.layoutConfig.nodeSeparation != layoutConfig.nodeSeparation

        // Update theme
        if view.theme.background.hexString != theme.background.hexString ||
           view.theme.foreground.hexString != theme.foreground.hexString {
            view.theme = theme
        }

        // Update layout config if changed
        if configChanged {
            view.layoutConfig = layoutConfig
        }

        // Update source (triggers re-render) or force re-render if config changed
        if view.source != source {
            view.source = source
        } else if configChanged {
            // Force re-render by re-setting the source
            let currentSource = view.source
            view.source = ""
            view.source = currentSource
        }

        // Report back the parse error and diagram bounds
        DispatchQueue.main.async {
            self.parseError = view.parseError
            self.diagramBounds = view.diagramBounds
        }
    }
}

#endif
