//
//  MermaidViewRepresentable.swift
//  MermaidPlayground
//
//  SwiftUI wrapper for MermaidView (cross-platform)
//

import SwiftUI
import BeautifulMermaid

#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit

struct MermaidViewRepresentable: UIViewRepresentable {
    let source: String
    let theme: DiagramTheme

    @Binding var parseError: Error?
    @Binding var diagramBounds: CGRect

    func makeUIView(context: Context) -> MermaidView {
        let view = MermaidView()
        view.theme = theme
        view.source = source
        return view
    }

    func updateUIView(_ view: MermaidView, context: Context) {
        // Update theme
        if view.theme.background.hexString != theme.background.hexString ||
           view.theme.foreground.hexString != theme.foreground.hexString {
            view.theme = theme
        }

        // Update source (triggers re-render)
        if view.source != source {
            view.source = source
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

    @Binding var parseError: Error?
    @Binding var diagramBounds: CGRect

    func makeNSView(context: Context) -> MermaidView {
        let view = MermaidView()
        view.theme = theme
        view.source = source
        return view
    }

    func updateNSView(_ view: MermaidView, context: Context) {
        // Update theme
        if view.theme.background.hexString != theme.background.hexString ||
           view.theme.foreground.hexString != theme.foreground.hexString {
            view.theme = theme
        }

        // Update source (triggers re-render)
        if view.source != source {
            view.source = source
        }

        // Report back the parse error and diagram bounds
        DispatchQueue.main.async {
            self.parseError = view.parseError
            self.diagramBounds = view.diagramBounds
        }
    }
}

#endif
