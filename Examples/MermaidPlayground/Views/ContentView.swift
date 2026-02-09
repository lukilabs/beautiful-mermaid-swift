//
//  ContentView.swift
//  MermaidPlayground
//
//  Root view with NavigationSplitView for sidebar/detail layout
//

import SwiftUI
import BeautifulMermaid

struct ContentView: View {
    @SwiftUI.State private var config = PlaygroundConfiguration.shared
    @SwiftUI.State private var columnVisibility: NavigationSplitViewVisibility = .all
    @SwiftUI.State private var showingControls = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            #if os(iOS)
            if horizontalSizeClass == .compact {
                // iPhone: Show preview with sheet for controls
                compactLayout
            } else {
                // iPad: Use NavigationSplitView
                regularLayout
            }
            #else
            // macOS: Use NavigationSplitView
            regularLayout
            #endif
        }
    }

    // MARK: - Compact Layout (iPhone)

    #if os(iOS)
    private var compactLayout: some View {
        PreviewView(config: config)
            .overlay(alignment: .topTrailing) {
                Button {
                    showingControls = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(config.theme.foreground))
                        .padding(12)
                        .background(
                            Circle()
                                .fill(Color(config.theme.background).opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                }
                .padding()
            }
            .sheet(isPresented: $showingControls) {
                NavigationStack {
                    SidebarView(config: config)
                        .navigationTitle("Controls")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(Color(config.theme.background), for: .navigationBar)
                        .toolbarColorScheme(config.theme.background.isLight ? .light : .dark, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingControls = false
                                }
                            }
                        }
                }
                .presentationDetents([.height(80), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
    }
    #endif

    // MARK: - Regular Layout (iPad/macOS)

    private var regularLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(config: config)
                .navigationTitle("Controls")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color(config.theme.background), for: .navigationBar)
                .toolbarColorScheme(config.theme.background.isLight ? .light : .dark, for: .navigationBar)
                #endif
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 320, ideal: 400, max: 500)
                #endif
        } detail: {
            PreviewView(config: config)
                .navigationTitle("Preview")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color(config.theme.background), for: .navigationBar)
                .toolbarColorScheme(config.theme.background.isLight ? .light : .dark, for: .navigationBar)
                #endif
        }
        .navigationSplitViewStyle(.balanced)
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
    }
}

// MARK: - Color Light/Dark Detection

extension BMColor {
    /// Returns true if this is a "light" color (luminance > 0.5)
    var isLight: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #if canImport(UIKit)
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
        guard let rgb = usingColorSpace(.sRGB) else { return true }
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif

        // Calculate perceived luminance
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.5
    }
}

#Preview {
    ContentView()
}
