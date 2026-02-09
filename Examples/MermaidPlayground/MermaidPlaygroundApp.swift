//
//  MermaidPlaygroundApp.swift
//  MermaidPlayground
//
//  SwiftUI app entry point for iOS and macOS
//

import SwiftUI

@main
struct MermaidPlaygroundApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove default "New" menu item
            }
        }
        #endif
    }
}
