//
//  SourceEditor.swift
//  MermaidPlayground
//
//  Mermaid source text editor with debounced updates
//

import SwiftUI
import BeautifulMermaid

struct SourceEditor: View {
    @Bindable var config: PlaygroundConfiguration

    @SwiftUI.State private var localSource: String = ""
    @SwiftUI.State private var debounceTask: Task<Void, Never>?

    var body: some View {
        TextEditor(text: $localSource)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color(config.theme.background))
            .foregroundColor(Color(config.theme.foreground))
            #if os(iOS)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            #endif
            .padding(EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                localSource = config.source
            }
            .onChange(of: localSource) { _, newValue in
                debounceSourceUpdate(newValue)
            }
            .onChange(of: config.source) { _, newValue in
                // External update (e.g., diagram selection)
                if localSource != newValue {
                    localSource = newValue
                }
            }
    }

    private func debounceSourceUpdate(_ newValue: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled {
                await MainActor.run {
                    config.source = newValue
                }
            }
        }
    }
}

#Preview {
    SourceEditor(config: PlaygroundConfiguration.shared)
        .frame(height: 300)
        .padding()
}
