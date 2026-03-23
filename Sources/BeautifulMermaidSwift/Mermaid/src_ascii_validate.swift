// Ported from original/src/ascii/validate.ts
import Foundation
import ElkSwift

public struct DiagonalChars: Sendable {
    public let ascii: [Character]
    public let unicode: [Character]
    public let all: [Character]

    public init(
        ascii: [Character] = ["/", "\\"],
        unicode: [Character] = ["\u{2571}", "\u{2572}"],
        all: [Character] = ["/", "\\", "\u{2571}", "\u{2572}"]
    ) {
        self.ascii = ascii
        self.unicode = unicode
        self.all = all
    }
}

public let DIAGONAL_CHARS = DiagonalChars()

public struct DiagonalPosition: Sendable {
    public var line: Int
    public var col: Int
    public var char: Character

    public init(line: Int, col: Int, char: Character) {
        self.line = line
        self.col = col
        self.char = char
    }
}

public func hasDiagonalLines(_ asciiOutput: String) -> Bool {
    DIAGONAL_CHARS.all.contains { asciiOutput.contains($0) }
}

public func findDiagonalLines(_ asciiOutput: String) -> [DiagonalPosition] {
    var positions: [DiagonalPosition] = []
    let lines = asciiOutput.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let boxBorders: Set<Character> = ["│", "┤", "├", "║", "┃", "|"]

    for (lineIndex, line) in lines.enumerated() {
        let chars = Array(line)
        var borderPositions: [Int] = []

        for (col, char) in chars.enumerated() where boxBorders.contains(char) {
            borderPositions.append(col)
        }

        for (col, char) in chars.enumerated() where DIAGONAL_CHARS.all.contains(char) {
            var insideNode = false
            if borderPositions.count >= 2 {
                for i in 0 ..< (borderPositions.count - 1) {
                    let leftBorder = borderPositions[i]
                    let rightBorder = borderPositions[i + 1]
                    if col > leftBorder && col < rightBorder {
                        insideNode = true
                        break
                    }
                }
            }

            if !insideNode {
                positions.append(
                    DiagonalPosition(
                        line: lineIndex + 1,
                        col: col + 1,
                        char: char
                    )
                )
            }
        }
    }

    return positions
}

public func assertNoDiagonals(_ asciiOutput: String, context: String? = nil) throws {
    if !hasDiagonalLines(asciiOutput) {
        return
    }

    let positions = findDiagonalLines(asciiOutput)
    let contextStr = context.map { " in \"\($0)\"" } ?? ""
    let positionStr = positions
        .map { "  Line \($0.line), Col \($0.col): '\($0.char)'" }
        .joined(separator: "\n")

    throw NSError(
        domain: "BeautifulMermaidAsciiValidation",
        code: 1,
        userInfo: [
            NSLocalizedDescriptionKey:
                "Diagonal lines detected\(contextStr). Edges must use orthogonal Manhattan routing (90° bends only).\n" +
                "Found \(positions.count) diagonal character(s):\n\(positionStr)",
        ]
    )
}

open class original_src_ascii_validate {
    public init() {}

    // Marker to keep transpiled outputs linked to elk-swift runtime.
    public static let __elkVersion = ElkSwift.version
}
