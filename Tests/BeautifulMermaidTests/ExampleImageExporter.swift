import XCTest
@testable import BeautifulMermaid

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Exports example images for README documentation
/// Run with: swift test --filter ExampleImageExporter
final class ExampleImageExporter: XCTestCase {

    struct ExampleDiagram {
        let name: String
        let description: String
        let code: String
    }

    static let examples: [ExampleDiagram] = [
        ExampleDiagram(
            name: "flowchart",
            description: "Flowcharts",
            code: """
            graph TD
                A[Start] --> B{Decision}
                B -->|Yes| C[Do Something]
                B -->|No| D[Do Something Else]
                C --> E[End]
                D --> E
            """
        ),
        ExampleDiagram(
            name: "state",
            description: "State Diagrams",
            code: """
            stateDiagram-v2
                [*] --> Idle
                Idle --> Processing: start
                Processing --> Complete: finish
                Processing --> Error: fail
                Error --> Idle: reset
                Complete --> [*]
            """
        ),
        ExampleDiagram(
            name: "sequence",
            description: "Sequence Diagrams",
            code: """
            sequenceDiagram
                participant Client
                participant Server
                participant Database
                Client->>Server: Request
                Server->>Database: Query
                Database-->>Server: Results
                Server-->>Client: Response
            """
        ),
        ExampleDiagram(
            name: "class",
            description: "Class Diagrams",
            code: """
            classDiagram
                Animal <|-- Duck
                Animal <|-- Fish
                Animal : +String name
                Animal : +makeSound()
                Duck : +swim()
                Fish : +swim()
            """
        ),
        ExampleDiagram(
            name: "er",
            description: "ER Diagrams",
            code: """
            erDiagram
                CUSTOMER ||--o{ ORDER : places
                ORDER ||--|{ LINE_ITEM : contains
                PRODUCT ||--o{ LINE_ITEM : includes
            """
        )
    ]

    /// Theme configurations for light/dark mode
    static let themes: [(name: String, theme: DiagramTheme)] = [
        ("light", .zincLight),
        ("dark", .githubDark)
    ]

    func testExportExampleImages() throws {
        // Get output directory from environment or use default
        let outputDir: String
        if let envDir = ProcessInfo.processInfo.environment["EXAMPLE_OUTPUT_DIR"] {
            outputDir = envDir
        } else {
            // Default to project root's assets folder
            let testFile = #file
            let testsDir = (testFile as NSString).deletingLastPathComponent
            let projectRoot = ((testsDir as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
            outputDir = (projectRoot as NSString).appendingPathComponent("assets/examples")
        }

        // Create output directory
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        print("Exporting example images to: \(outputDir)")

        var exportCount = 0

        for example in Self.examples {
            for (themeName, theme) in Self.themes {
                guard let image = try MermaidRenderer.renderImage(source: example.code, theme: theme, scale: 2.0) else {
                    XCTFail("Failed to render \(example.name) with \(themeName) theme")
                    continue
                }

                let filename = "\(example.name)-\(themeName).png"
                let outputPath = (outputDir as NSString).appendingPathComponent(filename)

                #if os(macOS)
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    XCTFail("Failed to convert \(example.name) to PNG")
                    continue
                }
                try pngData.write(to: URL(fileURLWithPath: outputPath))
                #else
                guard let pngData = image.pngData() else {
                    XCTFail("Failed to convert \(example.name) to PNG")
                    continue
                }
                try pngData.write(to: URL(fileURLWithPath: outputPath))
                #endif

                print("  Exported: \(filename)")
                exportCount += 1
            }
        }

        print("Done! Exported \(exportCount) example images.")
    }
}
