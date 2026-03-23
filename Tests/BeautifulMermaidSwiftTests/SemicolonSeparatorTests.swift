import XCTest
@testable import BeautifulMermaid

final class SemicolonSeparatorTests: XCTestCase {

    // MARK: - Semicolon-separated diagrams render without error

    func testFlowchartWithSemicolonSeparator() throws {
        let svg = try renderMermaidSVG("graph LR; A --> B")
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
        XCTAssertFalse(svg.contains("Syntax error"), "Should not contain syntax error")
    }

    func testFlowchartTDWithMultipleSemicolons() throws {
        let svg = try renderMermaidSVG("graph TD; A --> B; B --> C")
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
    }

    func testSequenceDiagramWithSemicolon() throws {
        let svg = try renderMermaidSVG("sequenceDiagram; Alice ->> Bob: hi")
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
    }

    func testErDiagramWithSemicolon() throws {
        let svg = try renderMermaidSVG("erDiagram; CUSTOMER ||--o{ ORDER : places")
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
    }

    // MARK: - Newline-separated diagrams still work (regression check)

    func testFlowchartWithNewlines() throws {
        let svg = try renderMermaidSVG("""
            graph LR
                A --> B
                B --> C
            """)
        XCTAssertTrue(svg.contains("<svg"), "Newline-separated diagram should still work")
    }

    func testSequenceDiagramWithNewlines() throws {
        let svg = try renderMermaidSVG("""
            sequenceDiagram
                Alice ->> Bob: hello
            """)
        XCTAssertTrue(svg.contains("<svg"), "Newline-separated sequence diagram should still work")
    }
}
