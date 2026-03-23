import XCTest
@testable import BeautifulMermaid

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Exports example images and ASCII art for README documentation
/// Run with: swift test --filter ExampleImageExporter
final class ExampleImageExporter: XCTestCase {

    struct ExampleDiagram {
        let name: String
        let code: String
    }

    static let examples: [ExampleDiagram] = [
        ExampleDiagram(
            name: "flowchart",
            code: """
            graph TD
                subgraph ci [CI Pipeline]
                    A[Push Code] --> B{Tests Pass?}
                    B -->|Yes| C[Build Image]
                    B -->|No| D[Fix & Retry]
                    D -.-> A
                end
                C --> E([Deploy Staging])
                E --> F{QA Approved?}
                F -->|Yes| G((Production))
                F -->|No| D
            """
        ),
        ExampleDiagram(
            name: "state",
            code: """
            stateDiagram-v2
                [*] --> Closed
                Closed --> Connecting : connect
                Connecting --> Connected : success
                Connecting --> Closed : timeout
                Connected --> Disconnecting : close
                Connected --> Reconnecting : error
                Reconnecting --> Connected : success
                Reconnecting --> Closed : max_retries
                Disconnecting --> Closed : done
                Closed --> [*]
            """
        ),
        ExampleDiagram(
            name: "sequence",
            code: """
            sequenceDiagram
                actor U as User
                participant App as Client App
                participant Auth as Auth Server
                participant API as Resource API
                U->>App: Click Login
                App->>Auth: Authorization request
                Auth->>U: Login page
                U->>Auth: Credentials
                Auth-->>App: Authorization code
                App->>Auth: Exchange code for token
                Auth-->>App: Access token
                App->>API: Request + token
                API-->>App: Protected resource
                App-->>U: Display data
            """
        ),
        ExampleDiagram(
            name: "class",
            code: """
            classDiagram
                class Animal {
                    <<abstract>>
                    +String name
                    +int age
                    +eat() void
                    +sleep() void
                }
                class Mammal {
                    +bool warmBlooded
                    +nurse() void
                }
                class Bird {
                    +bool canFly
                    +layEggs() void
                }
                class Dog {
                    +String breed
                    +bark() void
                }
                class Cat {
                    +bool isIndoor
                    +purr() void
                }
                class Parrot {
                    +String vocabulary
                    +speak() void
                }
                Animal <|-- Mammal
                Animal <|-- Bird
                Mammal <|-- Dog
                Mammal <|-- Cat
                Bird <|-- Parrot
            """
        ),
        ExampleDiagram(
            name: "er",
            code: """
            erDiagram
                CUSTOMER {
                    int id PK
                    string name
                    string email UK
                }
                ORDER {
                    int id PK
                    date created
                    int customer_id FK
                }
                PRODUCT {
                    int id PK
                    string name
                    float price
                }
                LINE_ITEM {
                    int id PK
                    int order_id FK
                    int product_id FK
                    int quantity
                }
                CUSTOMER ||--o{ ORDER : places
                ORDER ||--|{ LINE_ITEM : contains
                PRODUCT ||--o{ LINE_ITEM : includes
            """
        ),
        ExampleDiagram(
            name: "xychart",
            code: """
            xychart-beta
                title "Sales Revenue"
                x-axis [jan, feb, mar, apr, may, jun]
                y-axis "Revenue (in $)" 4000 --> 11000
                bar [5000, 6000, 7500, 8200, 9800, 10500]
                line [5000, 6000, 7500, 8200, 9800, 10500]
            """
        )
    ]

    static let themes: [(name: String, theme: DiagramTheme)] = [
        ("light", .zincLight),
        ("dark", .githubDark)
    ]

    func testExportExampleImages() throws {
        let outputDir: String
        if let envDir = ProcessInfo.processInfo.environment["EXAMPLE_OUTPUT_DIR"] {
            outputDir = envDir
        } else {
            let testFile = #file
            let testsDir = (testFile as NSString).deletingLastPathComponent
            let projectRoot = ((testsDir as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
            outputDir = (projectRoot as NSString).appendingPathComponent("assets/examples")
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        print("Exporting example images to: \(outputDir)")

        var exportCount = 0

        for example in Self.examples {
            // Export PNGs
            for (themeName, theme) in Self.themes {
                guard let image = try MermaidRenderer.renderImage(source: example.code, theme: theme, scale: 2.0) else {
                    XCTFail("Failed to render \(example.name) with \(themeName) theme")
                    continue
                }

                let filename = "\(example.name)-\(themeName).png"
                let outputPath = (outputDir as NSString).appendingPathComponent(filename)

                #if os(macOS)
                // Flip the image vertically (CGContext renders bottom-up)
                let flipped = NSImage(size: image.size)
                flipped.lockFocus()
                let ctx = NSGraphicsContext.current!.cgContext
                ctx.translateBy(x: 0, y: image.size.height)
                ctx.scaleBy(x: 1, y: -1)
                image.draw(in: NSRect(origin: .zero, size: image.size))
                flipped.unlockFocus()

                guard let tiffData = flipped.tiffRepresentation,
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

            // Export ASCII art
            let ascii = try MermaidRenderer.renderASCII(source: example.code, theme: .zincDark)
            let asciiFilename = "\(example.name)-ascii.txt"
            let asciiPath = (outputDir as NSString).appendingPathComponent(asciiFilename)
            try ascii.write(toFile: asciiPath, atomically: true, encoding: .utf8)
            print("  Exported: \(asciiFilename)")
            exportCount += 1
        }

        print("Done! Exported \(exportCount) example assets.")
    }
}
