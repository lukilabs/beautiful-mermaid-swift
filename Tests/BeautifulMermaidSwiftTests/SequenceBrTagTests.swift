import XCTest
@testable import BeautifulMermaid

final class SequenceBrTagTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source
            .components(separatedBy: CharacterSet(charactersIn: "\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }

    func testNoteHtmlBreaksNormalizeToNewlines() throws {
        let source = """
        sequenceDiagram
            Note right of B: line 1<br/>line 2<BR>line 3<br />line 4
            A->>B: Hello
        """

        let diagram = try parseSequenceDiagram(lines(source))

        XCTAssertEqual(diagram.notes.count, 1)
        XCTAssertEqual(diagram.notes[0].text, "line 1\nline 2\nline 3\nline 4")
        XCTAssertFalse(diagram.notes[0].text.contains("<br"))
    }

    func testMultilineNoteIncreasesNoteHeight() throws {
        let singleSource = """
        sequenceDiagram
            participant A
            participant B
            Note right of B: Single line
            A->>B: Hello
        """
        let multiSource = """
        sequenceDiagram
            participant A
            participant B
            Note right of B: Line 1<br/>Line 2
            A->>B: Hello
        """

        let single = try layoutSequenceDiagram(try parseSequenceDiagram(lines(singleSource)))
        let multi = try layoutSequenceDiagram(try parseSequenceDiagram(lines(multiSource)))

        XCTAssertEqual(single.notes.count, 1)
        XCTAssertEqual(multi.notes.count, 1)
        XCTAssertGreaterThan(multi.notes[0].height, single.notes[0].height)
    }
}
