//
//  ThemeTests.swift
//  BeautifulMermaidTests
//
//  Tests for theme system
//

import XCTest
@testable import BeautifulMermaid

final class ThemeTests: XCTestCase {

    func testDefaultTheme() {
        let theme = DiagramTheme.default

        XCTAssertNotNil(theme.background)
        XCTAssertNotNil(theme.foreground)
    }

    func testBuiltInThemes() {
        // Test that all built-in themes are valid
        for (name, theme) in DiagramTheme.allThemes {
            XCTAssertNotNil(theme.background, "Theme \(name) should have background")
            XCTAssertNotNil(theme.foreground, "Theme \(name) should have foreground")
        }

        XCTAssertGreaterThanOrEqual(DiagramTheme.allThemes.count, 15, "Should have at least 15 themes")
    }

    func testEffectiveColors() {
        let theme = DiagramTheme.tokyoNight

        // Effective colors should never be nil
        XCTAssertNotNil(theme.effectiveLine())
        XCTAssertNotNil(theme.effectiveAccent())
        XCTAssertNotNil(theme.effectiveMuted())
        XCTAssertNotNil(theme.effectiveSurface())
        XCTAssertNotNil(theme.effectiveBorder())
    }

    func testThemeModifications() {
        let original = DiagramTheme.tokyoNight
        let modified = original.withLineWidth(3.0)

        XCTAssertEqual(modified.lineWidth, 3.0)
        XCTAssertEqual(modified.background.hexString, original.background.hexString)
    }

    func testColorFromHex() {
        let color = BMColor(hex: "#FF0000")

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        #if canImport(UIKit)
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        if let rgbColor = color.usingColorSpace(.deviceRGB) {
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        #endif

        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func testColorMixing() {
        let black = BMColor(hex: "#000000")
        let white = BMColor(hex: "#FFFFFF")

        let gray = black.mixed(with: white, amount: 0.5)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        #if canImport(UIKit)
        gray.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        if let rgbColor = gray.usingColorSpace(.deviceRGB) {
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        #endif

        // Should be close to 50% gray
        XCTAssertEqual(r, 0.5, accuracy: 0.01)
        XCTAssertEqual(g, 0.5, accuracy: 0.01)
        XCTAssertEqual(b, 0.5, accuracy: 0.01)
    }

    func testNodeColors() {
        let theme = DiagramTheme.tokyoNight

        // Node with no style
        let plainNode = MermaidNode(id: "plain", label: "Plain")
        XCTAssertEqual(theme.nodeFillColor(for: plainNode).hexString,
                      theme.effectiveSurface().hexString)

        // Node with inline style
        var styledNode = MermaidNode(id: "styled", label: "Styled")
        styledNode.inlineStyles["fill"] = "#FF0000"
        XCTAssertEqual(theme.nodeFillColor(for: styledNode).hexString, "#FF0000")
    }
}
