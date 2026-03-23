// Ported from original/src/ascii/er-diagram.ts
import Foundation
import ElkSwift

public struct AsciiErAttribute {
    public var keys: [String]
    public var type: String
    public var name: String

    public init(keys: [String] = [], type: String, name: String) {
        self.keys = keys
        self.type = type
        self.name = name
    }
}

public struct AsciiErEntity {
    public var id: String
    public var label: String
    public var attributes: [AsciiErAttribute]

    public init(id: String, label: String, attributes: [AsciiErAttribute] = []) {
        self.id = id
        self.label = label
        self.attributes = attributes
    }
}

public enum AsciiErCardinality: String {
    case one = "one"
    case zeroOne = "zero-one"
    case many = "many"
    case zeroMany = "zero-many"
}

public struct AsciiErRelationship {
    public var entity1: String
    public var entity2: String
    public var cardinality1: AsciiErCardinality
    public var cardinality2: AsciiErCardinality
    public var identifying: Bool
    public var label: String?

    public init(
        entity1: String,
        entity2: String,
        cardinality1: AsciiErCardinality,
        cardinality2: AsciiErCardinality,
        identifying: Bool = true,
        label: String? = nil
    ) {
        self.entity1 = entity1
        self.entity2 = entity2
        self.cardinality1 = cardinality1
        self.cardinality2 = cardinality2
        self.identifying = identifying
        self.label = label
    }
}

public struct AsciiErDiagram {
    public var entities: [AsciiErEntity]
    public var relationships: [AsciiErRelationship]

    public init(entities: [AsciiErEntity], relationships: [AsciiErRelationship] = []) {
        self.entities = entities
        self.relationships = relationships
    }
}

private struct AsciiPlacedEntity {
    var entity: AsciiErEntity
    var sections: [[String]]
    var x: Int
    var y: Int
    var width: Int
    var height: Int
}

private func splitAsciiErLines(_ text: String) -> [String] {
    text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
}

private func erClassifyBoxChar(_ ch: Character) -> CharRole {
    let chars: Set<Character> = ["┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "│", "─", "╭", "╮", "╰", "╯", "+", "-", "|"]
    return chars.contains(ch) ? .border : .text
}

private func formatErAttribute(_ attr: AsciiErAttribute) -> String {
    let keyStr = attr.keys.isEmpty ? "   " : "\(attr.keys.joined(separator: ",")) "
    return "\(keyStr)\(attr.type) \(attr.name)"
}

private func buildEntitySections(_ entity: AsciiErEntity) -> [[String]] {
    let header = splitAsciiErLines(entity.label)
    let attrs = entity.attributes.map(formatErAttribute)
    if attrs.isEmpty {
        return [header]
    }
    return [header, attrs]
}

private func getCrowsFootChars(_ card: AsciiErCardinality, _ useAscii: Bool, _ isRight: Bool = false) -> String {
    if useAscii {
        switch card {
        case .one:
            return "|"
        case .zeroOne:
            return "o|"
        case .many:
            return isRight ? "<" : ">"
        case .zeroMany:
            return isRight ? "o<" : ">o"
        }
    }

    switch card {
    case .one:
        return "│"
    case .zeroOne:
        return "○│"
    case .many:
        return isRight ? "╟" : "╢"
    case .zeroMany:
        return isRight ? "○╟" : "╢○"
    }
}

private func findConnectedComponents(_ diagram: AsciiErDiagram) -> [Set<String>] {
    var visited = Set<String>()
    var components: [Set<String>] = []

    var neighbors: [String: Set<String>] = [:]
    for ent in diagram.entities {
        neighbors[ent.id] = Set<String>()
    }
    for rel in diagram.relationships {
        neighbors[rel.entity1, default: Set<String>()].insert(rel.entity2)
        neighbors[rel.entity2, default: Set<String>()].insert(rel.entity1)
    }

    func dfs(_ startId: String, _ component: inout Set<String>) {
        var stack = [startId]
        while !stack.isEmpty {
            let nodeId = stack.removeLast()
            if visited.contains(nodeId) {
                continue
            }

            visited.insert(nodeId)
            component.insert(nodeId)

            for neighbor in neighbors[nodeId] ?? Set<String>() where !visited.contains(neighbor) {
                stack.append(neighbor)
            }
        }
    }

    for ent in diagram.entities where !visited.contains(ent.id) {
        var component = Set<String>()
        dfs(ent.id, &component)
        if !component.isEmpty {
            components.append(component)
        }
    }

    return components
}

private enum AsciiErRenderError: Error, LocalizedError {
    case invalidCardinality(String)

    var errorDescription: String? {
        switch self {
        case let .invalidCardinality(raw):
            return "Unsupported ER cardinality: \(raw)"
        }
    }
}

private func _toAsciiCardinality(_ raw: String) throws -> AsciiErCardinality {
    switch raw {
    case AsciiErCardinality.one.rawValue:
        return .one
    case AsciiErCardinality.zeroOne.rawValue:
        return .zeroOne
    case AsciiErCardinality.many.rawValue:
        return .many
    case AsciiErCardinality.zeroMany.rawValue:
        return .zeroMany
    default:
        throw AsciiErRenderError.invalidCardinality(raw)
    }
}

public func renderErAscii(
    _ text: String,
    _ config: AsciiConfig,
    _ colorMode: ColorMode? = nil,
    _ theme: AsciiTheme? = nil
) throws -> String {
    let lines = splitAsciiErLines(text)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    let parsed = try parseErDiagram(lines)

    if parsed.entities.isEmpty {
        return ""
    }

    let entities = parsed.entities.map { ent in
        AsciiErEntity(
            id: ent.id,
            label: ent.label,
            attributes: ent.attributes.map { attr in
                AsciiErAttribute(keys: attr.keys, type: attr.type, name: attr.name)
            }
        )
    }

    let relationships = try parsed.relationships.map { rel in
        AsciiErRelationship(
            entity1: rel.entity1,
            entity2: rel.entity2,
            cardinality1: try _toAsciiCardinality(rel.cardinality1),
            cardinality2: try _toAsciiCardinality(rel.cardinality2),
            identifying: rel.identifying,
            label: rel.label.isEmpty ? nil : rel.label
        )
    }

    let diagram = AsciiErDiagram(entities: entities, relationships: relationships)
    return renderErAsciiDiagram(diagram, config, colorMode, theme)
}

public func renderErAsciiDiagram(
    _ diagram: AsciiErDiagram,
    _ config: AsciiConfig,
    _ colorMode: ColorMode? = nil,
    _ theme: AsciiTheme? = nil
) -> String {
    if diagram.entities.isEmpty {
        return ""
    }

    let useAscii = config.useAscii
    let hGap = 6
    let vGap = 4
    let componentGap = 6

    var entitySections: [String: [[String]]] = [:]
    var entityBoxW: [String: Int] = [:]
    var entityBoxH: [String: Int] = [:]

    for ent in diagram.entities {
        let sections = buildEntitySections(ent)
        entitySections[ent.id] = sections

        var maxTextW = 0
        for section in sections {
            for line in section {
                maxTextW = max(maxTextW, line.count)
            }
        }
        let boxW = maxTextW + 4

        var totalLines = 0
        for section in sections {
            totalLines += max(section.count, 1)
        }
        let boxH = totalLines + (sections.count - 1) + 2

        entityBoxW[ent.id] = boxW
        entityBoxH[ent.id] = boxH
    }

    let components = findConnectedComponents(diagram)

    var placed: [String: AsciiPlacedEntity] = [:]
    var currentY = 0

    for component in components {
        let componentEntities = diagram.entities.filter { component.contains($0.id) }
        let maxPerRow = max(2, Int(ceil(sqrt(Double(componentEntities.count)))))

        var currentX = 0
        var maxRowH = 0
        var colCount = 0

        for ent in componentEntities {
            guard let w = entityBoxW[ent.id], let h = entityBoxH[ent.id], let sections = entitySections[ent.id] else { continue }

            if colCount >= maxPerRow {
                currentY += maxRowH + vGap
                currentX = 0
                maxRowH = 0
                colCount = 0
            }

            placed[ent.id] = AsciiPlacedEntity(entity: ent, sections: sections, x: currentX, y: currentY, width: w, height: h)

            currentX += w + hGap
            maxRowH = max(maxRowH, h)
            colCount += 1
        }

        currentY += maxRowH + componentGap
    }

    var totalW = 0
    var totalH = 0
    for p in placed.values {
        totalW = max(totalW, p.x + p.width)
        totalH = max(totalH, p.y + p.height)
    }
    totalW += 4
    totalH += 2

    var canvas = mkCanvas(max(0, totalW - 1), max(0, totalH - 1))
    var rc = mkRoleCanvas(max(0, totalW - 1), max(0, totalH - 1))

    func setC(_ x: Int, _ y: Int, _ ch: Character, _ role: CharRole) {
        if x >= 0, y >= 0 {
            if x >= canvas.count || y >= (canvas.first?.count ?? 0) {
                _ = increaseSize(&canvas, x, y)
                _ = increaseRoleCanvasSize(&rc, x, y)
            }
            if x < canvas.count, y < (canvas.first?.count ?? 0) {
                canvas[x][y] = ch
                setRole(&rc, x, y, role)
            }
        }
    }

    for p in placed.values {
        let boxCanvas = drawMultiBox(p.sections, useAscii)
        if boxCanvas.isEmpty || (boxCanvas.first?.isEmpty ?? true) { continue }
        for bx in 0..<boxCanvas.count {
            for by in 0..<(boxCanvas.first?.count ?? 0) {
                let ch = boxCanvas[bx][by]
                if ch == " " { continue }
                let cx = p.x + bx
                let cy = p.y + by
                if cx < totalW, cy < totalH {
                    setC(cx, cy, ch, erClassifyBoxChar(ch))
                }
            }
        }
    }

    let h: Character = useAscii ? "-" : "─"
    let v: Character = useAscii ? "|" : "│"
    let dashH: Character = useAscii ? "." : "╌"
    let dashV: Character = useAscii ? ":" : "┊"

    for rel in diagram.relationships {
        guard let e1 = placed[rel.entity1], let e2 = placed[rel.entity2] else { continue }

        let lineH = rel.identifying ? h : dashH
        let lineV = rel.identifying ? v : dashV

        let e1CX = e1.x + Int(floor(Double(e1.width) / 2.0))
        let e1CY = e1.y + Int(floor(Double(e1.height) / 2.0))
        let e2CX = e2.x + Int(floor(Double(e2.width) / 2.0))
        let e2CY = e2.y + Int(floor(Double(e2.height) / 2.0))

        let sameRow = abs(e1CY - e2CY) < max(e1.height, e2.height)

        if sameRow {
            let left: AsciiPlacedEntity
            let right: AsciiPlacedEntity
            let leftCard: AsciiErCardinality
            let rightCard: AsciiErCardinality
            if e1CX < e2CX {
                left = e1; right = e2
                leftCard = rel.cardinality1; rightCard = rel.cardinality2
            } else {
                left = e2; right = e1
                leftCard = rel.cardinality2; rightCard = rel.cardinality1
            }

            let startX = left.x + left.width
            let endX = right.x - 1
            let lineY = left.y + Int(floor(Double(left.height) / 2.0))

            if startX <= endX {
                for x in startX...endX {
                    setC(x, lineY, lineH, .line)
                }
            }

            let leftChars = Array(getCrowsFootChars(leftCard, useAscii, false))
            for (i, ch) in leftChars.enumerated() {
                setC(startX + i, lineY, ch, .arrow)
            }

            let rightChars = Array(getCrowsFootChars(rightCard, useAscii, true))
            for (i, ch) in rightChars.enumerated() {
                setC(endX - rightChars.count + 1 + i, lineY, ch, .arrow)
            }

            if let label = rel.label, !label.isEmpty {
                let lines = splitAsciiErLines(label)
                let gapMid = Int(floor(Double(startX + endX) / 2.0))

                for (lineIdx, line) in lines.enumerated() {
                    let labelStart = max(startX, gapMid - Int(floor(Double(line.count) / 2.0)))
                    let labelY = lineY + 1 + lineIdx
                    _ = increaseSize(&canvas, max(labelStart + line.count, 1), max(labelY + 1, 1))
                    _ = increaseRoleCanvasSize(&rc, max(labelStart + line.count, 1), max(labelY + 1, 1))
                    for (i, ch) in line.enumerated() {
                        let lx = labelStart + i
                        if lx >= startX, lx <= endX {
                            setC(lx, labelY, ch, .text)
                        }
                    }
                }
            }
        } else {
            let upper: AsciiPlacedEntity
            let lower: AsciiPlacedEntity
            let upperCard: AsciiErCardinality
            let lowerCard: AsciiErCardinality
            if e1CY < e2CY {
                upper = e1; lower = e2
                upperCard = rel.cardinality1; lowerCard = rel.cardinality2
            } else {
                upper = e2; lower = e1
                upperCard = rel.cardinality2; lowerCard = rel.cardinality1
            }

            let startY = upper.y + upper.height
            let endY = lower.y - 1
            let lineX = upper.x + Int(floor(Double(upper.width) / 2.0))

            if startY <= endY {
                for y in startY...endY {
                    setC(lineX, y, lineV, .line)
                }
            }

            let lowerCX = lower.x + Int(floor(Double(lower.width) / 2.0))
            if lineX != lowerCX {
                let midY = Int(floor(Double(startY + endY) / 2.0))
                let lx = min(lineX, lowerCX)
                let rx = max(lineX, lowerCX)
                for x in lx...rx {
                    setC(x, midY, lineH, .line)
                }
                if midY + 1 <= endY {
                    for y in (midY + 1)...endY {
                        setC(lowerCX, y, lineV, .line)
                    }
                }
            }

            let upperChars = Array(getCrowsFootChars(upperCard, useAscii, false))
            for (i, ch) in upperChars.enumerated() {
                setC(lineX - Int(floor(Double(upperChars.count) / 2.0)) + i, startY, ch, .arrow)
            }

            let targetX = (lineX != lowerCX) ? lowerCX : lineX
            let lowerChars = Array(getCrowsFootChars(lowerCard, useAscii, true))
            for (i, ch) in lowerChars.enumerated() {
                setC(targetX - Int(floor(Double(lowerChars.count) / 2.0)) + i, endY, ch, .arrow)
            }

            if let label = rel.label, !label.isEmpty {
                let lines = splitAsciiErLines(label)
                let midY = Int(floor(Double(startY + endY) / 2.0))
                let startLabelY = midY - Int(floor(Double(lines.count - 1) / 2.0))

                for (lineIdx, line) in lines.enumerated() {
                    let labelX = lineX + 2
                    let y = startLabelY + lineIdx
                    if y < 0 { continue }
                    for (i, ch) in line.enumerated() {
                        let lx = labelX + i
                        if lx >= 0 {
                            _ = increaseSize(&canvas, lx + 1, y + 1)
                            _ = increaseRoleCanvasSize(&rc, lx + 1, y + 1)
                            setC(lx, y, ch, .text)
                        }
                    }
                }
            }
        }
    }

    return canvasToString(
        canvas,
        options: CanvasToStringOptions(roleCanvas: rc, colorMode: colorMode, theme: theme)
    )
}

open class original_src_ascii_er_diagram {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
