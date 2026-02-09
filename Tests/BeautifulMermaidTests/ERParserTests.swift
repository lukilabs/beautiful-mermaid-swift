//
//  ERParserTests.swift
//  BeautifulMermaidTests
//
//  Unit tests for ER diagram parser - all cardinality patterns
//

import XCTest
@testable import BeautifulMermaid

final class ERParserTests: XCTestCase {

    // MARK: - Cardinality Pattern Tests

    func testAllCardinalityPatterns() throws {
        // Test all 4 cardinality types on both sides
        let testCases: [(source: String, card1: String, card2: String)] = [
            // One (||)
            ("erDiagram\n  A ||--|| B : one-to-one", "one", "one"),
            // Zero-one (|o or o|)
            ("erDiagram\n  A |o--o| B : opt-to-opt", "zero-one", "zero-one"),
            // Many (}| or |{)
            ("erDiagram\n  A }|--|{ B : many-to-many", "many", "many"),
            // Zero-many (o{ or {o)
            ("erDiagram\n  A o{--{o B : zero-many-both", "zero-many", "zero-many"),
            // Mixed patterns from verification
            ("erDiagram\n  A ||--o{ B : one-to-zero-many", "one", "zero-many"),
            ("erDiagram\n  A |o--|{ B : opt-to-many", "zero-one", "many"),
            ("erDiagram\n  A }|--o{ B : many-to-zero-many", "many", "zero-many"),
        ]

        let parser = ERParser()

        for (source, expectedCard1, expectedCard2) in testCases {
            let lines = source.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            let diagram = try parser.parseErDiagram(lines, startIndex: 1)

            XCTAssertEqual(diagram.relationships.count, 1, "Failed for: \(source)")
            if let rel = diagram.relationships.first {
                XCTAssertEqual(rel.cardinality1, expectedCard1, "Card1 failed for: \(source)")
                XCTAssertEqual(rel.cardinality2, expectedCard2, "Card2 failed for: \(source)")
            }
        }
    }

    // MARK: - Failing Verification Cases

    func testER6OptionalMany() throws {
        let source = "erDiagram\n  SUPERVISOR |o--|{ EMPLOYEE : manages"
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let parser = ERParser()
        let diagram = try parser.parseErDiagram(lines, startIndex: 1)

        XCTAssertEqual(diagram.entities.count, 2, "Expected 2 entities")
        XCTAssertEqual(diagram.relationships.count, 1, "Expected 1 relationship")

        if let rel = diagram.relationships.first {
            XCTAssertEqual(rel.entity1, "SUPERVISOR")
            XCTAssertEqual(rel.entity2, "EMPLOYEE")
            XCTAssertEqual(rel.cardinality1, "zero-one")
            XCTAssertEqual(rel.cardinality2, "many")
            XCTAssertEqual(rel.label, "manages")
        }
    }

    func testER8AllCardinality() throws {
        let source = """
        erDiagram
          A ||--|| B : one-to-one
          C ||--o{ D : one-to-many
          E |o--|{ F : opt-to-many
          G }|--o{ H : many-to-many
        """
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let parser = ERParser()
        let diagram = try parser.parseErDiagram(lines, startIndex: 1)

        XCTAssertEqual(diagram.entities.count, 8, "Expected 8 entities")
        XCTAssertEqual(diagram.relationships.count, 4, "Expected 4 relationships")
    }
}
