// Ported from original/src/ascii/shapes/corners.ts
import Foundation
import ElkSwift

public struct CornerChars: Sendable {
    public var tl: Character
    public var tr: Character
    public var bl: Character
    public var br: Character

    public init(tl: Character, tr: Character, bl: Character, br: Character) {
        self.tl = tl
        self.tr = tr
        self.bl = bl
        self.br = br
    }
}

public struct ShapeCorners: Sendable {
    public var unicode: CornerChars
    public var ascii: CornerChars

    public init(unicode: CornerChars, ascii: CornerChars) {
        self.unicode = unicode
        self.ascii = ascii
    }
}

public let SHAPE_CORNERS: [AsciiNodeShape: ShapeCorners] = [
    "rectangle": ShapeCorners(
        unicode: CornerChars(tl: "┌", tr: "┐", bl: "└", br: "┘"),
        ascii: CornerChars(tl: "+", tr: "+", bl: "+", br: "+")
    ),
    "rounded": ShapeCorners(
        unicode: CornerChars(tl: "╭", tr: "╮", bl: "╰", br: "╯"),
        ascii: CornerChars(tl: ".", tr: ".", bl: "'", br: "'")
    ),
    "circle": ShapeCorners(
        unicode: CornerChars(tl: "◯", tr: "◯", bl: "◯", br: "◯"),
        ascii: CornerChars(tl: "o", tr: "o", bl: "o", br: "o")
    ),
    "doublecircle": ShapeCorners(
        unicode: CornerChars(tl: "◎", tr: "◎", bl: "◎", br: "◎"),
        ascii: CornerChars(tl: "@", tr: "@", bl: "@", br: "@")
    ),
    "diamond": ShapeCorners(
        unicode: CornerChars(tl: "◇", tr: "◇", bl: "◇", br: "◇"),
        ascii: CornerChars(tl: "<", tr: ">", bl: "<", br: ">")
    ),
    "hexagon": ShapeCorners(
        unicode: CornerChars(tl: "⌜", tr: "⌝", bl: "⌞", br: "⌟"),
        ascii: CornerChars(tl: "*", tr: "*", bl: "*", br: "*")
    ),
    "stadium": ShapeCorners(
        unicode: CornerChars(tl: "(", tr: ")", bl: "(", br: ")"),
        ascii: CornerChars(tl: "(", tr: ")", bl: "(", br: ")")
    ),
    "subroutine": ShapeCorners(
        unicode: CornerChars(tl: "╟", tr: "╢", bl: "╟", br: "╢"),
        ascii: CornerChars(tl: "|", tr: "|", bl: "|", br: "|")
    ),
    "cylinder": ShapeCorners(
        unicode: CornerChars(tl: "╭", tr: "╮", bl: "╰", br: "╯"),
        ascii: CornerChars(tl: ".", tr: ".", bl: "'", br: "'")
    ),
    "asymmetric": ShapeCorners(
        unicode: CornerChars(tl: "▷", tr: "┐", bl: "▷", br: "┘"),
        ascii: CornerChars(tl: ">", tr: "+", bl: ">", br: "+")
    ),
    "trapezoid": ShapeCorners(
        unicode: CornerChars(tl: "/", tr: "\\", bl: "└", br: "┘"),
        ascii: CornerChars(tl: "/", tr: "\\", bl: "+", br: "+")
    ),
    "trapezoid-alt": ShapeCorners(
        unicode: CornerChars(tl: "┌", tr: "┐", bl: "\\", br: "/"),
        ascii: CornerChars(tl: "+", tr: "+", bl: "\\", br: "/")
    ),
    "state-start": ShapeCorners(
        unicode: CornerChars(tl: "●", tr: "●", bl: "●", br: "●"),
        ascii: CornerChars(tl: "*", tr: "*", bl: "*", br: "*")
    ),
    "state-end": ShapeCorners(
        unicode: CornerChars(tl: "◉", tr: "◉", bl: "◉", br: "◉"),
        ascii: CornerChars(tl: "@", tr: "@", bl: "@", br: "@")
    ),
]

public func getCorners(_ shape: AsciiNodeShape, _ useAscii: Bool) -> CornerChars {
    let fallback = ShapeCorners(
        unicode: CornerChars(tl: "\u{250C}", tr: "\u{2510}", bl: "\u{2514}", br: "\u{2518}"),
        ascii: CornerChars(tl: "+", tr: "+", bl: "+", br: "+")
    )
    let corners = SHAPE_CORNERS[shape] ?? fallback
    return useAscii ? corners.ascii : corners.unicode
}

open class original_src_ascii_shapes_corners {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
