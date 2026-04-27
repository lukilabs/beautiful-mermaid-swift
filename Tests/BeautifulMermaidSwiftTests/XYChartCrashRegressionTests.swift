import XCTest
@testable import BeautifulMermaid

final class XYChartCrashRegressionTests: XCTestCase {

    func test_dataLongerThanCategories_doesNotCrash() throws {
        let variants = [
            // vertical (default)
            """
            xychart-beta
                title "Vertical mixed"
                x-axis [Jan, Feb, Mar]
                y-axis "Revenue" 0 --> 1000
                bar [100, 200, 300, 400, 500]
                line [150, 250, 350, 450, 550]
            """,
            // horizontal
            """
            xychart-beta horizontal
                title "Horizontal mixed"
                x-axis [Jan, Feb, Mar]
                y-axis "Revenue" 0 --> 1000
                bar [100, 200, 300, 400, 500]
                line [150, 250, 350, 450, 550]
            """,
        ]

        for source in variants {
            let svg = try renderMermaidSVG(source, RenderOptions())
            XCTAssertFalse(svg.isEmpty, "Expected non-empty SVG for source:\n\(source)")
        }
    }

    func test_renderer_handlesInfiniteAndOverflowCoordinates() throws {
        // Tiny y-axis range with large values can yield non-finite scaled coordinates.
        let infSource = """
        xychart-beta
            title "Inf coords"
            x-axis [A, B, C]
            y-axis "v" 0 --> 0
            bar [1, 2, 3]
            line [1, 2, 3]
        """
        let svg1 = try renderMermaidSVG(infSource, RenderOptions())
        XCTAssertFalse(svg1.isEmpty)

        // Values past 1e300 will overflow when multiplied by scaling factors.
        let overflowSource = """
        xychart-beta
            title "Overflow coords"
            x-axis [A, B, C]
            y-axis "v" 0 --> 1e308
            bar [1e300, 2e300, 3e300]
            line [1e300, 2e300, 3e300]
        """
        let svg2 = try renderMermaidSVG(overflowSource, RenderOptions())
        XCTAssertFalse(svg2.isEmpty)
    }

    func test_ascii_handlesInfiniteAndNaNValues() throws {
        // The ASCII path uses Int(round(...)) which traps on Inf/NaN; verify the guard works.
        let source = """
        xychart-beta
            title "ASCII guard"
            x-axis [A, B, C]
            y-axis "v" 0 --> 0
            bar [1, 2, 3]
            line [1, 2, 3]
        """
        let ascii = try MermaidRenderer.renderASCII(source: source)
        XCTAssertFalse(ascii.isEmpty)
    }
}
