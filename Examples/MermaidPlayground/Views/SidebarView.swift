//
//  SidebarView.swift
//  MermaidPlayground
//
//  Controls panel with diagram selector, theme picker, direction control,
//  export button, and source editor
//

import SwiftUI
import BeautifulMermaid
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var config: PlaygroundConfiguration

    @SwiftUI.State private var selectedDiagramName: String = "Select Test Diagram..."
    @SwiftUI.State private var showExportError = false
    @SwiftUI.State private var exportErrorMessage = ""
    @SwiftUI.State private var exportedFileURL: URL?
    @SwiftUI.State private var showingExporter = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Test Diagrams Section
                    sectionHeader("Test Diagrams")
                    testDiagramPicker
                        .padding(.top, -10)

                    // Theme Section
                    sectionHeader("Theme")
                    ThemePicker(config: config)
                        .padding(.top, -10)

                    // Direction Section
                    sectionHeader("Direction")
                    directionPicker
                        .padding(.top, -10)

                    // Export Button (no header needed)
                    exportButton

                    // Source Section
                    sectionHeader("Source")
                    SourceEditor(config: config)
                        .frame(minHeight: max(200, geometry.size.height - 400))
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(config.theme.effectiveLine()).opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, -10)
                }
                .padding(16)
            }
        }
        .background(Color(config.theme.background))
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportedFileURL.map { PNGDocument(url: $0) },
            contentType: .png,
            defaultFilename: "mermaid-diagram.png"
        ) { result in
            // Clean up temp file after export
            if let url = exportedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            exportedFileURL = nil
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color(config.theme.foreground))
    }

    // MARK: - Test Diagram Picker

    private var testDiagramPicker: some View {
        Menu {
            ForEach(["flowchart", "state", "sequence", "class", "er"], id: \.self) { category in
                let diagrams = TestDiagrams.diagrams(for: category)
                if !diagrams.isEmpty {
                    Menu(category.capitalized) {
                        ForEach(diagrams) { diagram in
                            Button {
                                selectedDiagramName = diagram.name
                                config.source = diagram.source
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(diagram.name)
                                    Text(diagram.id)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedDiagramName)
                    .foregroundColor(Color(config.theme.effectiveAccent()))
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(Color(config.theme.effectiveAccent()))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Direction Picker

    private var directionPicker: some View {
        Picker("Direction", selection: $config.direction) {
            Text("TB").tag(Direction.topDown)
            Text("LR").tag(Direction.leftRight)
            Text("BT").tag(Direction.bottomUp)
            Text("RL").tag(Direction.rightLeft)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            exportPNG()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export PNG")
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(config.theme.effectiveLine()), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(config.theme.foreground))
    }

    // MARK: - Export Logic

    private func exportPNG() {
        // Build layout config from playground configuration
        var layoutConfig = LayoutConfig()
        layoutConfig.nodePadding = CGSize(width: config.nodePadding, height: config.nodePadding * 0.625)
        layoutConfig.edgeSeparation = config.edgeSpacing
        layoutConfig.rankSeparation = config.rankSeparation
        layoutConfig.font = BMFont.systemFont(ofSize: config.fontSize)
        layoutConfig.direction = config.direction

        do {
            // Create renderer with current theme
            let renderer = MermaidImageRenderer(theme: config.theme)
            renderer.scale = 2.0  // High resolution export
            renderer.layoutConfig = layoutConfig

            // Render the image
            guard let image = try renderer.renderImage(from: config.source) else {
                showError("Failed to render diagram")
                return
            }

            // Convert to PNG data
            #if canImport(UIKit)
            guard let pngData = image.pngData() else {
                showError("Failed to create PNG data")
                return
            }
            #elseif canImport(AppKit)
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                showError("Failed to create PNG data")
                return
            }
            #endif

            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "mermaid-diagram-\(Int(Date().timeIntervalSince1970)).png"
            let tempURL = tempDir.appendingPathComponent(fileName)

            try pngData.write(to: tempURL)

            // Show file exporter
            exportedFileURL = tempURL
            showingExporter = true

        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        exportErrorMessage = message
        showExportError = true
    }
}

// MARK: - PNG Document for FileExporter

struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        // Not used for export
        url = URL(fileURLWithPath: "")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SidebarView(config: PlaygroundConfiguration.shared)
        .frame(width: 380, height: 700)
}
