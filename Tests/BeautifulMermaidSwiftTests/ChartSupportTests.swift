import XCTest
@testable import BeautifulMermaid

final class ChartSupportTests: XCTestCase {
    func testPieChartExampleParsesAndRenders() throws {
        let source = """
        pie title Breakdown of Favorite Colors
            "Red" : 30
            "Blue" : 25
            "Green" : 20
            "Yellow" : 15
            "Other" : 10
        """

        let graph = try MermaidRenderer.parse(source)
        XCTAssertEqual(graph.type, .pieChart)
        guard case .pieChart(let chart)? = graph.typedPayload else {
            return XCTFail("Expected pieChart typed payload")
        }
        XCTAssertEqual(chart.title, "Breakdown of Favorite Colors")
        XCTAssertEqual(chart.slices.count, 5)
        XCTAssertEqual(chart.slices.first?.label, "Red")
        XCTAssertEqual(chart.slices.first?.value, 30)

        let positioned = try MermaidRenderer.layout(source)
        XCTAssertEqual(positioned.pieChartData?.slices.count, 5)

        let svg = try renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("data-piechart-slices=\"5\""))
        XCTAssertTrue(svg.contains("Breakdown of Favorite Colors"))
        XCTAssertTrue(svg.contains("data-label=\"Red\""))

        let ascii = try MermaidRenderer.renderASCII(source: source)
        XCTAssertTrue(ascii.contains("Red"))
        XCTAssertTrue(ascii.contains("30%"))

        let image = try MermaidRenderer.renderImage(source: source)
        XCTAssertNotNil(image)
    }

    func testPieChartAliasAndShowData() throws {
        let source = """
        pieChart showData title Votes
            "A" : 2
            "B" : 1
        """

        let graph = try MermaidRenderer.parse(source)
        XCTAssertEqual(graph.type, .pieChart)
        guard case .pieChart(let chart)? = graph.typedPayload else {
            return XCTFail("Expected pieChart typed payload")
        }
        XCTAssertTrue(chart.showData)

        let svg = try renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains(">A 2<"))
    }

}
