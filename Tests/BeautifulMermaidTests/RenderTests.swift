//
//  RenderTests.swift
//  BeautifulMermaidTests
//
//  Tests for rendering
//

import XCTest
@testable import BeautifulMermaid

final class RenderTests: XCTestCase {

    func testImageRender() throws {
        let source = """
        graph TD
            A[Start] --> B[End]
        """

        let image = try MermaidRenderer.renderImage(source: source)

        XCTAssertNotNil(image, "Should produce an image")

        #if canImport(UIKit)
        XCTAssertGreaterThan(image!.size.width, 0)
        XCTAssertGreaterThan(image!.size.height, 0)
        #elseif canImport(AppKit)
        XCTAssertGreaterThan(image!.size.width, 0)
        XCTAssertGreaterThan(image!.size.height, 0)
        #endif
    }

    func testImageRenderWithSize() throws {
        let source = """
        graph TD
            A --> B
        """

        let size = CGSize(width: 400, height: 300)
        let image = try MermaidRenderer.renderImage(source: source, size: size)

        XCTAssertNotNil(image)

        #if canImport(UIKit)
        XCTAssertEqual(image!.size.width, size.width, accuracy: 1.0)
        XCTAssertEqual(image!.size.height, size.height, accuracy: 1.0)
        #elseif canImport(AppKit)
        XCTAssertEqual(image!.size.width, size.width, accuracy: 1.0)
        XCTAssertEqual(image!.size.height, size.height, accuracy: 1.0)
        #endif
    }

    func testDifferentThemes() throws {
        let source = """
        graph TD
            A --> B
        """

        // Test that different themes produce images
        let themes: [DiagramTheme] = [
            .tokyoNight,
            .catppuccinMocha,
            .nord,
            .githubLight
        ]

        for theme in themes {
            let image = try MermaidRenderer.renderImage(source: source, theme: theme)
            XCTAssertNotNil(image, "Theme should produce an image")
        }
    }

    func testRenderAllDiagramTypes() throws {
        let diagrams = [
            ("Flowchart", "graph TD\n    A --> B"),
            ("State", "stateDiagram-v2\n    [*] --> Active"),
            ("Sequence", "sequenceDiagram\n    A->>B: Hello"),
            ("Class", "classDiagram\n    class Animal"),
            ("ER", "erDiagram\n    CUSTOMER ||--o{ ORDER : places")
        ]

        for (name, source) in diagrams {
            do {
                let image = try MermaidRenderer.renderImage(source: source)
                XCTAssertNotNil(image, "\(name) diagram should render")
            } catch {
                XCTFail("\(name) diagram failed: \(error)")
            }
        }
    }

    func testStringExtensions() throws {
        let source = """
        graph TD
            A --> B
        """

        // Test parseMermaid
        let graph = try source.parseMermaid()
        XCTAssertEqual(graph.type, .flowchart)

        // Test renderMermaidImage
        let image = try source.renderMermaidImage()
        XCTAssertNotNil(image)
    }

    func testCylinderAndFlagShapes() throws {
        let source = """
        graph TD
            A[(Database)]
            B>Flag Shape]
            C[Normal]
            A --> B --> C
        """

        // Use explicit size to ensure diagram fits
        let renderer = MermaidImageRenderer(theme: .default)
        let image = try renderer.renderImage(from: source, size: CGSize(width: 400, height: 500))
        XCTAssertNotNil(image, "Should render cylinder and flag shapes")
    }
}
