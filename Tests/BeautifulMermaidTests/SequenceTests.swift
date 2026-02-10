//
//  SequenceTests.swift
//  BeautifulMermaidTests
//
//  Tests for sequence diagram parsing, layout, and rendering
//

import XCTest
@testable import BeautifulMermaid

final class SequenceTests: XCTestCase {

    // MARK: - Parser Tests

    func testBasicParticipants() {
        let source = """
        sequenceDiagram
            participant A
            participant B
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.actors.count, 2)
        XCTAssertEqual(diagram.actors[0].id, "A")
        XCTAssertEqual(diagram.actors[0].label, "A")
        XCTAssertEqual(diagram.actors[0].type, .participant)
        XCTAssertEqual(diagram.actors[1].id, "B")
    }

    func testParticipantAlias() {
        let source = """
        sequenceDiagram
            participant A as Alice
            participant B as Bob
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.actors.count, 2)
        XCTAssertEqual(diagram.actors[0].id, "A")
        XCTAssertEqual(diagram.actors[0].label, "Alice")
        XCTAssertEqual(diagram.actors[1].id, "B")
        XCTAssertEqual(diagram.actors[1].label, "Bob")
    }

    func testActorType() {
        let source = """
        sequenceDiagram
            actor U as User
            participant S as System
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.actors.count, 2)
        XCTAssertEqual(diagram.actors[0].id, "U")
        XCTAssertEqual(diagram.actors[0].type, .actor)
        XCTAssertEqual(diagram.actors[1].id, "S")
        XCTAssertEqual(diagram.actors[1].type, .participant)
    }

    func testBasicMessage() {
        let source = """
        sequenceDiagram
            A->>B: Hello
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.messages.count, 1)
        XCTAssertEqual(diagram.messages[0].from, "A")
        XCTAssertEqual(diagram.messages[0].to, "B")
        XCTAssertEqual(diagram.messages[0].label, "Hello")
        XCTAssertEqual(diagram.messages[0].lineStyle, .solid)
        XCTAssertEqual(diagram.messages[0].arrowHead, .filled)
    }

    func testAllArrowTypes() {
        let source = """
        sequenceDiagram
            A->>B: Solid filled
            A-->>B: Dashed filled
            A-)B: Solid open
            A--)B: Dashed open
            A-xB: Solid cross
            A--xB: Dashed cross
            A->B: Solid none
            A-->B: Dashed none
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.messages.count, 8)

        // Solid filled
        XCTAssertEqual(diagram.messages[0].lineStyle, .solid)
        XCTAssertEqual(diagram.messages[0].arrowHead, .filled)

        // Dashed filled
        XCTAssertEqual(diagram.messages[1].lineStyle, .dashed)
        XCTAssertEqual(diagram.messages[1].arrowHead, .filled)

        // Solid open
        XCTAssertEqual(diagram.messages[2].lineStyle, .solid)
        XCTAssertEqual(diagram.messages[2].arrowHead, .open)

        // Dashed open
        XCTAssertEqual(diagram.messages[3].lineStyle, .dashed)
        XCTAssertEqual(diagram.messages[3].arrowHead, .open)

        // Solid cross
        XCTAssertEqual(diagram.messages[4].lineStyle, .solid)
        XCTAssertEqual(diagram.messages[4].arrowHead, .cross)

        // Dashed cross
        XCTAssertEqual(diagram.messages[5].lineStyle, .dashed)
        XCTAssertEqual(diagram.messages[5].arrowHead, .cross)

        // Solid none
        XCTAssertEqual(diagram.messages[6].lineStyle, .solid)
        XCTAssertEqual(diagram.messages[6].arrowHead, .none)

        // Dashed none
        XCTAssertEqual(diagram.messages[7].lineStyle, .dashed)
        XCTAssertEqual(diagram.messages[7].arrowHead, .none)
    }

    func testActivationMarkers() {
        let source = """
        sequenceDiagram
            A->>+B: Activate B
            B-->>-A: Deactivate B
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.messages.count, 2)
        XCTAssertTrue(diagram.messages[0].activate)
        XCTAssertFalse(diagram.messages[0].deactivate)
        XCTAssertFalse(diagram.messages[1].activate)
        XCTAssertTrue(diagram.messages[1].deactivate)
    }

    func testSelfMessage() {
        let source = """
        sequenceDiagram
            A->>A: Think
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.messages.count, 1)
        XCTAssertTrue(diagram.messages[0].isSelfMessage)
        XCTAssertEqual(diagram.messages[0].from, "A")
        XCTAssertEqual(diagram.messages[0].to, "A")
    }

    func testLoopBlock() {
        let source = """
        sequenceDiagram
            loop Every minute
                A->>B: Check
            end
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.blocks.count, 1)
        XCTAssertEqual(diagram.blocks[0].type, .loop)
        XCTAssertEqual(diagram.blocks[0].label, "Every minute")
        XCTAssertEqual(diagram.blocks[0].startIndex, 0)
        XCTAssertEqual(diagram.blocks[0].endIndex, 0)
    }

    func testAltBlock() {
        let source = """
        sequenceDiagram
            alt Success
                A->>B: OK
            else Failure
                A->>B: Error
            end
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.blocks.count, 1)
        XCTAssertEqual(diagram.blocks[0].type, .alt)
        XCTAssertEqual(diagram.blocks[0].label, "Success")
        XCTAssertEqual(diagram.blocks[0].dividers.count, 1)
        XCTAssertEqual(diagram.blocks[0].dividers[0].label, "Failure")
    }

    func testOptBlock() {
        let source = """
        sequenceDiagram
            opt Optional
                A->>B: Maybe
            end
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.blocks.count, 1)
        XCTAssertEqual(diagram.blocks[0].type, .opt)
        XCTAssertEqual(diagram.blocks[0].label, "Optional")
    }

    func testParBlock() {
        let source = """
        sequenceDiagram
            par Parallel
                A->>B: Task 1
            and
                A->>C: Task 2
            end
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.blocks.count, 1)
        XCTAssertEqual(diagram.blocks[0].type, .par)
        XCTAssertEqual(diagram.blocks[0].dividers.count, 1)
    }

    func testNestedBlocks() {
        let source = """
        sequenceDiagram
            loop Daily
                alt Online
                    A->>B: Send
                else Offline
                    A->>A: Queue
                end
            end
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.blocks.count, 2)
        // Note: Blocks are stored in order they close, so inner block closes first
    }

    func testNoteLeftOf() {
        let source = """
        sequenceDiagram
            Note left of A: Comment
            A->>B: Hello
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.notes.count, 1)
        XCTAssertEqual(diagram.notes[0].position, .left)
        XCTAssertEqual(diagram.notes[0].actorIds, ["A"])
        XCTAssertEqual(diagram.notes[0].text, "Comment")
    }

    func testNoteRightOf() {
        let source = """
        sequenceDiagram
            Note right of B: Another
            A->>B: Hello
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.notes.count, 1)
        XCTAssertEqual(diagram.notes[0].position, .right)
        XCTAssertEqual(diagram.notes[0].actorIds, ["B"])
    }

    func testNoteOver() {
        let source = """
        sequenceDiagram
            Note over A,B: Spanning
            A->>B: Hello
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.notes.count, 1)
        XCTAssertEqual(diagram.notes[0].position, .over)
        XCTAssertEqual(diagram.notes[0].actorIds, ["A", "B"])
    }

    func testImplicitParticipants() {
        let source = """
        sequenceDiagram
            A->>B: Hello
            B->>C: Forward
        """

        let diagram = parseSequenceDiagram(source)

        // Participants should be created implicitly
        XCTAssertEqual(diagram.actors.count, 3)
        XCTAssertEqual(diagram.actors.map { $0.id }, ["A", "B", "C"])
    }

    // MARK: - Layout Tests

    func testBasicLayout() {
        let source = """
        sequenceDiagram
            participant A as Alice
            participant B as Bob
            A->>B: Hello
        """

        let diagram = parseSequenceDiagram(source)
        let positioned = layoutSequenceDiagram(diagram)

        // Check actors are positioned
        XCTAssertEqual(positioned.actors.count, 2)
        XCTAssertTrue(positioned.actors[0].centerX < positioned.actors[1].centerX)

        // Check lifelines exist
        XCTAssertEqual(positioned.lifelines.count, 2)

        // Check message exists
        XCTAssertEqual(positioned.messages.count, 1)
        XCTAssertEqual(positioned.messages[0].points.count, 2)
    }

    func testSelfMessageLayout() {
        let source = """
        sequenceDiagram
            A->>A: Think
        """

        let diagram = parseSequenceDiagram(source)
        let positioned = layoutSequenceDiagram(diagram)

        XCTAssertEqual(positioned.messages.count, 1)
        XCTAssertTrue(positioned.messages[0].isSelfMessage)
        XCTAssertEqual(positioned.messages[0].points.count, 4) // Loop has 4 points
    }

    func testActivationLayout() {
        let source = """
        sequenceDiagram
            A->>+B: Start
            B-->>-A: Done
        """

        let diagram = parseSequenceDiagram(source)
        let positioned = layoutSequenceDiagram(diagram)

        XCTAssertEqual(positioned.activations.count, 1)
        XCTAssertEqual(positioned.activations[0].actorId, "B")
    }

    func testBlockLayout() {
        let source = """
        sequenceDiagram
            loop Test
                A->>B: Check
            end
        """

        let diagram = parseSequenceDiagram(source)
        let positioned = layoutSequenceDiagram(diagram)

        XCTAssertEqual(positioned.blocks.count, 1)
        XCTAssertTrue(positioned.blocks[0].bounds.width > 0)
        XCTAssertTrue(positioned.blocks[0].bounds.height > 0)
    }

    func testDiagramBounds() {
        let source = """
        sequenceDiagram
            participant A
            participant B
            A->>B: Hello
        """

        let diagram = parseSequenceDiagram(source)
        let positioned = layoutSequenceDiagram(diagram)

        XCTAssertTrue(positioned.width > 0)
        XCTAssertTrue(positioned.height > 0)
    }

    // MARK: - Integration Tests

    func testFullDiagram() {
        let source = """
        sequenceDiagram
            participant A as Alice
            actor B as Bob

            A->>+B: Hello Bob!
            Note right of B: Bob thinks
            B-->>-A: Hi Alice

            loop Every minute
                A->>B: Check status
            end

            alt Success
                B->>A: OK
            else Failure
                B->>A: Error
            end
        """

        let diagram = parseSequenceDiagram(source)

        XCTAssertEqual(diagram.actors.count, 2)
        XCTAssertEqual(diagram.messages.count, 5)
        XCTAssertEqual(diagram.blocks.count, 2)
        XCTAssertEqual(diagram.notes.count, 1)

        let positioned = layoutSequenceDiagram(diagram)

        XCTAssertTrue(positioned.width > 0)
        XCTAssertTrue(positioned.height > 0)
        XCTAssertEqual(positioned.actors.count, 2)
        XCTAssertEqual(positioned.messages.count, 5)
    }

    func testSelfMessageLabelIncludedInBounds() {
        let source = """
        sequenceDiagram
            participant C as Client
            participant S as Server
            C->>+S: Request
            S->>+S: Process
            S-->>-C: Response
        """

        let diagram = parseSequenceDiagram(source)
        let positioned = layoutSequenceDiagram(diagram)

        // Find the self-message "Process"
        let selfMsg = positioned.messages.first { $0.isSelfMessage }
        XCTAssertNotNil(selfMsg, "Should have a self-message")

        guard let msg = selfMsg else { return }

        // Measure the label width the same way the layout engine does
        let labelWidth = RenderConfig.shared.estimateTextWidth(
            msg.label,
            fontSize: RenderConfig.shared.fontSizeEdgeLabel,
            fontWeight: RenderConfig.shared.fontWeightEdgeLabel
        )

        // The diagram width must be large enough to contain the label
        let labelRightEdge = msg.labelPosition.x + labelWidth
        XCTAssertGreaterThanOrEqual(
            positioned.width,
            labelRightEdge,
            "Diagram width (\(positioned.width)) must accommodate self-message label right edge (\(labelRightEdge))"
        )
    }

    func testMermaidParserBackwardsCompatibility() throws {
        let source = """
        sequenceDiagram
            participant A as Alice
            participant B as Bob
            A->>B: Hello
            B-->>A: Hi
        """

        // Test that the old MermaidParser still works
        let graph = try MermaidParser.parse(source)

        XCTAssertEqual(graph.type, .sequenceDiagram)
        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 2)
    }

    // MARK: - Helpers

    private func parseSequenceDiagram(_ source: String) -> SequenceDiagram {
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var startIndex = 0
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("sequenceDiagram") {
                startIndex = index + 1
                break
            }
        }

        let parser = SequenceParser()
        return parser.parseSequence(lines, startIndex: startIndex)
    }

    private func layoutSequenceDiagram(_ diagram: SequenceDiagram) -> PositionedSequenceDiagram {
        let layout = SequenceLayout()
        return layout.layoutSequence(diagram, config: LayoutConfig())
    }
}
