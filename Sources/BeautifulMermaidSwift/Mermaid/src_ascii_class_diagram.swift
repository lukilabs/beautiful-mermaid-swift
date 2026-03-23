// Ported from original/src/ascii/class-diagram.ts
import Foundation
import ElkSwift

public struct AsciiClassMember {
    public var visibility: String?
    public var name: String
    public var type: String?

    public init(visibility: String? = nil, name: String, type: String? = nil) {
        self.visibility = visibility
        self.name = name
        self.type = type
    }
}

public struct AsciiClassNode {
    public var id: String
    public var label: String
    public var annotation: String?
    public var attributes: [AsciiClassMember]
    public var methods: [AsciiClassMember]

    public init(id: String, label: String, annotation: String? = nil, attributes: [AsciiClassMember] = [], methods: [AsciiClassMember] = []) {
        self.id = id
        self.label = label
        self.annotation = annotation
        self.attributes = attributes
        self.methods = methods
    }
}

public enum AsciiClassRelationshipType: String {
    case inheritance
    case realization
    case composition
    case aggregation
    case association
    case dependency
}

public struct AsciiClassRelationship {
    public var from: String
    public var to: String
    public var type: AsciiClassRelationshipType
    public var markerAt: String
    public var label: String?

    public init(from: String, to: String, type: AsciiClassRelationshipType, markerAt: String, label: String? = nil) {
        self.from = from
        self.to = to
        self.type = type
        self.markerAt = markerAt
        self.label = label
    }
}

public struct AsciiClassDiagram {
    public var classes: [AsciiClassNode]
    public var relationships: [AsciiClassRelationship]

    public init(classes: [AsciiClassNode], relationships: [AsciiClassRelationship] = []) {
        self.classes = classes
        self.relationships = relationships
    }
}

private struct AsciiRelMarker {
    var type: AsciiClassRelationshipType
    var markerAt: String
    var dashed: Bool
}

private struct AsciiPlacedClass {
    var cls: AsciiClassNode
    var sections: [[String]]
    var x: Int
    var y: Int
    var width: Int
    var height: Int
}

private func splitAsciiClassLines(_ text: String) -> [String] {
    text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
}

private func classClassifyBoxChar(_ ch: Character) -> CharRole {
    let chars: Set<Character> = ["┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "│", "─", "╭", "╮", "╰", "╯", "+", "-", "|"]
    return chars.contains(ch) ? .border : .text
}

private func formatClassMember(_ m: AsciiClassMember) -> String {
    let vis = m.visibility ?? ""
    let t = m.type.map { ": \($0)" } ?? ""
    return "\(vis)\(m.name)\(t)"
}

private func buildClassSections(_ cls: AsciiClassNode) -> [[String]] {
    var header: [String] = []
    if let annotation = cls.annotation {
        header.append("<<\(annotation)>>")
    }
    header.append(contentsOf: splitAsciiClassLines(cls.label))

    let attrs = cls.attributes.map(formatClassMember)
    let methods = cls.methods.map(formatClassMember)

    if attrs.isEmpty && methods.isEmpty { return [header] }
    if methods.isEmpty { return [header, attrs] }
    return [header, attrs, methods]
}

private func getRelMarker(_ type: AsciiClassRelationshipType, _ markerAt: String) -> AsciiRelMarker {
    let dashed = type == .dependency || type == .realization
    return AsciiRelMarker(type: type, markerAt: markerAt, dashed: dashed)
}

private func getMarkerShape(
    _ type: AsciiClassRelationshipType,
    _ useAscii: Bool,
    _ direction: String? = nil
) -> Character {
    switch type {
    case .inheritance, .realization:
        switch direction ?? "right" {
        case "down": return useAscii ? "^" : "△"
        case "up": return useAscii ? "v" : "▽"
        case "left": return useAscii ? ">" : "◁"
        default: return useAscii ? "<" : "▷"
        }
    case .composition:
        return useAscii ? "*" : "◆"
    case .aggregation:
        return useAscii ? "o" : "◇"
    case .association, .dependency:
        switch direction ?? "right" {
        case "down": return useAscii ? "v" : "▼"
        case "up": return useAscii ? "^" : "▲"
        case "left": return useAscii ? "<" : "◀"
        default: return useAscii ? ">" : "▶"
        }
    }
}

public func renderClassAscii(
    _ text: String,
    _ config: AsciiConfig,
    _ colorMode: ColorMode? = nil,
    _ theme: AsciiTheme? = nil
) throws -> String {
    let lines = text
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }

    let diagram = try parseClassDiagram(lines)
    let asciiDiagram = AsciiClassDiagram(
        classes: diagram.classes.map(_toAsciiClassNode),
        relationships: diagram.relationships.compactMap(_toAsciiClassRelationship)
    )
    return renderClassAsciiDiagram(asciiDiagram, config, colorMode, theme)
}

private func _toAsciiClassNode(_ cls: ClassNode) -> AsciiClassNode {
    AsciiClassNode(
        id: cls.id,
        label: cls.label,
        annotation: cls.annotation,
        attributes: cls.attributes.map(_toAsciiClassMember),
        methods: cls.methods.map(_toAsciiClassMember)
    )
}

private func _toAsciiClassMember(_ member: ClassMember) -> AsciiClassMember {
    let visibility: String?
    if member.visibility.isEmpty {
        visibility = nil
    } else {
        visibility = member.visibility
    }

    return AsciiClassMember(
        visibility: visibility,
        name: member.isMethod ? "\(member.name)(\(member.params ?? ""))" : member.name,
        type: member.type
    )
}

private func _toAsciiClassRelationship(_ rel: ClassRelationship) -> AsciiClassRelationship? {
    guard let type = AsciiClassRelationshipType(rawValue: rel.type.lowercased()) else {
        return nil
    }
    return AsciiClassRelationship(
        from: rel.from,
        to: rel.to,
        type: type,
        markerAt: rel.markerAt,
        label: rel.label
    )
}

public func renderClassAsciiDiagram(
    _ diagram: AsciiClassDiagram,
    _ config: AsciiConfig,
    _ colorMode: ColorMode? = nil,
    _ theme: AsciiTheme? = nil
) -> String {
    if diagram.classes.isEmpty {
        return ""
    }

    let useAscii = config.useAscii
    let hGap = 4
    let vGap = 3

    var classSections: [String: [[String]]] = [:]
    var classBoxW: [String: Int] = [:]
    var classBoxH: [String: Int] = [:]

    for cls in diagram.classes {
        let sections = buildClassSections(cls)
        classSections[cls.id] = sections

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

        classBoxW[cls.id] = boxW
        classBoxH[cls.id] = boxH
    }

    var classById: [String: AsciiClassNode] = [:]
    for cls in diagram.classes {
        classById[cls.id] = cls
    }

    var parents: [String: Set<String>] = [:]
    var children: [String: Set<String>] = [:]

    for rel in diagram.relationships {
        let isHierarchical = rel.type == .inheritance || rel.type == .realization
        let parentId = (isHierarchical && rel.markerAt == "to") ? rel.to : rel.from
        let childId = (isHierarchical && rel.markerAt == "to") ? rel.from : rel.to

        var pset = parents[childId] ?? Set<String>()
        pset.insert(parentId)
        parents[childId] = pset

        var cset = children[parentId] ?? Set<String>()
        cset.insert(childId)
        children[parentId] = cset
    }

    var level: [String: Int] = [:]
    let roots = diagram.classes.filter { (parents[$0.id] ?? Set<String>()).isEmpty }
    var queue = roots.map { $0.id }
    for id in queue {
        level[id] = 0
    }

    let levelCap = diagram.classes.count - 1
    var qi = 0
    while qi < queue.count {
        let id = queue[qi]
        qi += 1
        guard let childSet = children[id] else { continue }

        for childId in childSet {
            let newLevel = (level[id] ?? 0) + 1
            if newLevel > levelCap {
                continue
            }
            if level[childId] == nil || (level[childId] ?? 0) < newLevel {
                level[childId] = newLevel
                queue.append(childId)
            }
        }
    }

    for cls in diagram.classes where level[cls.id] == nil {
        level[cls.id] = 0
    }

    let maxLevel = max(level.values.max() ?? 0, 0)
    var levelGroups = Array(repeating: [String](), count: maxLevel + 1)
    for cls in diagram.classes {
        levelGroups[level[cls.id] ?? 0].append(cls.id)
    }

    var placed: [String: AsciiPlacedClass] = [:]
    var currentY = 0

    for lv in 0...maxLevel {
        let group = levelGroups[lv]
        if group.isEmpty { continue }

        var currentX = 0
        var maxH = 0

        for id in group {
            guard let cls = classById[id], let w = classBoxW[id], let h = classBoxH[id], let sections = classSections[id] else { continue }
            placed[id] = AsciiPlacedClass(cls: cls, sections: sections, x: currentX, y: currentY, width: w, height: h)
            currentX += w + hGap
            maxH = max(maxH, h)
        }

        currentY += maxH + vGap
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
                    setC(cx, cy, ch, classClassifyBoxChar(ch))
                }
            }
        }
    }

    func isInsideBox(_ x: Int, _ y: Int, _ excludeIds: Set<String>? = nil) -> Bool {
        for (id, p) in placed {
            if excludeIds?.contains(id) == true { continue }
            if x >= p.x, x <= p.x + p.width - 1, y >= p.y, y <= p.y + p.height - 1 {
                return true
            }
        }
        return false
    }

    func findClearColumn(_ startX: Int, _ y1: Int, _ y2: Int, _ excludeIds: Set<String>) -> Int {
        let low = min(y1, y2)
        let high = max(y1, y2)

        var clear = true
        if low <= high {
            for y in low...high where isInsideBox(startX, y, excludeIds) {
                clear = false
                break
            }
        }
        if clear { return startX }

        for offset in 1..<(totalW + 10) {
            let rightX = startX + offset
            clear = true
            if low <= high {
                for y in low...high where isInsideBox(rightX, y, excludeIds) {
                    clear = false
                    break
                }
            }
            if clear { return rightX }

            let leftX = startX - offset
            if leftX >= 0 {
                clear = true
                if low <= high {
                    for y in low...high where isInsideBox(leftX, y, excludeIds) {
                        clear = false
                        break
                    }
                }
                if clear { return leftX }
            }
        }

        return totalW + 2
    }

    let h: Character = useAscii ? "-" : "─"
    let v: Character = useAscii ? "|" : "│"
    let dashH: Character = useAscii ? "." : "╌"
    let dashV: Character = useAscii ? ":" : "┊"

    for rel in diagram.relationships {
        guard let fromP = placed[rel.from], let toP = placed[rel.to] else { continue }

        let marker = getRelMarker(rel.type, rel.markerAt)
        let lineH = marker.dashed ? dashH : h
        let lineV = marker.dashed ? dashV : v

        let excludeIds = Set([rel.from, rel.to])

        let fromCX = fromP.x + Int(floor(Double(fromP.width) / 2.0))
        let fromBY = fromP.y + fromP.height - 1
        let toCX = toP.x + Int(floor(Double(toP.width) / 2.0))
        let toTY = toP.y

        if fromBY < toTY {
            let routeX = findClearColumn(fromCX, fromBY + 1, toTY - 1, excludeIds)
            let needsDetour = routeX != fromCX

            if routeX >= totalW {
                _ = increaseSize(&canvas, routeX + 2, max(0, totalH - 1))
                _ = increaseRoleCanvasSize(&rc, routeX + 2, max(0, totalH - 1))
            }

            if needsDetour {
                let exitY = fromBY + 1
                let entryY = toTY - 1

                let lx1 = min(fromCX, routeX)
                let rx1 = max(fromCX, routeX)
                for x in lx1...rx1 {
                    setC(x, exitY, lineH, .line)
                }
                if !useAscii, exitY < (canvas.first?.count ?? 0) {
                    if fromCX < routeX {
                        setC(fromCX, exitY, "└", .corner)
                        setC(routeX, exitY, "┐", .corner)
                    } else {
                        setC(fromCX, exitY, "┘", .corner)
                        setC(routeX, exitY, "┌", .corner)
                    }
                }

                if exitY + 1 <= entryY {
                    for y in (exitY + 1)...entryY {
                        setC(routeX, y, lineV, .line)
                    }
                }

                if routeX != toCX {
                    let lx2 = min(routeX, toCX)
                    let rx2 = max(routeX, toCX)
                    for x in lx2...rx2 {
                        setC(x, entryY, lineH, .line)
                    }
                    if !useAscii, entryY < (canvas.first?.count ?? 0) {
                        if routeX < toCX {
                            setC(routeX, entryY, "└", .corner)
                            setC(toCX, entryY, "┐", .corner)
                        } else {
                            setC(routeX, entryY, "┘", .corner)
                            setC(toCX, entryY, "┌", .corner)
                        }
                    }
                }

                if marker.markerAt == "to" {
                    setC(toCX, entryY, getMarkerShape(marker.type, useAscii, "down"), .arrow)
                }
                if marker.markerAt == "from" {
                    setC(fromCX, fromBY + 1, getMarkerShape(marker.type, useAscii, "down"), .arrow)
                }
            } else {
                let midY = fromBY + Int(floor(Double(toTY - fromBY) / 2.0))

                if fromBY + 1 <= midY {
                    for y in (fromBY + 1)...midY {
                        setC(fromCX, y, lineV, .line)
                    }
                }

                if fromCX != toCX, midY < (canvas.first?.count ?? 0) {
                    let lx = min(fromCX, toCX)
                    let rx = max(fromCX, toCX)
                    for x in lx...rx {
                        setC(x, midY, lineH, .line)
                    }
                    if !useAscii {
                        setC(fromCX, midY, fromCX < toCX ? "└" : "┘", .corner)
                        setC(toCX, midY, fromCX < toCX ? "┐" : "┌", .corner)
                    }
                }

                if midY + 1 < toTY {
                    for y in (midY + 1)..<toTY {
                        setC(toCX, y, lineV, .line)
                    }
                }

                if marker.markerAt == "to" {
                    setC(toCX, toTY - 1, getMarkerShape(marker.type, useAscii, "down"), .arrow)
                }
                if marker.markerAt == "from" {
                    setC(fromCX, fromBY + 1, getMarkerShape(marker.type, useAscii, "down"), .arrow)
                }
            }
        } else if toP.y + toP.height - 1 < fromP.y {
            let fromTY = fromP.y
            let toBY = toP.y + toP.height - 1
            let midY = toBY + Int(floor(Double(fromTY - toBY) / 2.0))

            if fromTY - 1 >= midY {
                for y in stride(from: fromTY - 1, through: midY, by: -1) {
                    setC(fromCX, y, lineV, .line)
                }
            }

            if fromCX != toCX {
                let lx = min(fromCX, toCX)
                let rx = max(fromCX, toCX)
                for x in lx...rx {
                    setC(x, midY, lineH, .line)
                }
                if !useAscii, midY >= 0, midY < totalH {
                    setC(fromCX, midY, fromCX < toCX ? "┌" : "┐", .corner)
                    setC(toCX, midY, fromCX < toCX ? "┘" : "└", .corner)
                }
            }

            if midY - 1 > toBY {
                for y in stride(from: midY - 1, through: toBY + 1, by: -1) {
                    setC(toCX, y, lineV, .line)
                }
            }

            if marker.markerAt == "from" {
                let my = fromTY - 1
                setC(fromCX, my, getMarkerShape(marker.type, useAscii, "up"), .arrow)
            }
            if marker.markerAt == "to" {
                let isHierarchical = marker.type == .inheritance || marker.type == .realization
                let markerDir = isHierarchical ? "down" : "up"
                let my = toBY + 1
                setC(toCX, my, getMarkerShape(marker.type, useAscii, markerDir), .arrow)
            }
        } else {
            let detourY = max(fromBY, toP.y + toP.height - 1) + 2
            _ = increaseSize(&canvas, max(0, totalW - 1), detourY + 1)
            _ = increaseRoleCanvasSize(&rc, max(0, totalW - 1), detourY + 1)

            if fromBY + 1 <= detourY {
                for y in (fromBY + 1)...detourY {
                    setC(fromCX, y, lineV, .line)
                }
            }

            let lx = min(fromCX, toCX)
            let rx = max(fromCX, toCX)
            for x in lx...rx {
                setC(x, detourY, lineH, .line)
            }

            if detourY - 1 >= toP.y + toP.height {
                for y in stride(from: detourY - 1, through: toP.y + toP.height, by: -1) {
                    setC(toCX, y, lineV, .line)
                }
            }

            if marker.markerAt == "from" {
                setC(fromCX, fromBY + 1, getMarkerShape(marker.type, useAscii, "down"), .arrow)
            }
            if marker.markerAt == "to" {
                setC(toCX, toP.y + toP.height, getMarkerShape(marker.type, useAscii, "up"), .arrow)
            }
        }

        if let label = rel.label, !label.isEmpty {
            let lines = splitAsciiClassLines(label)
            let maxLabelWidth = (lines.map { $0.count }.max() ?? 0) + 2

            let baseMidY: Int
            let idealMidX: Int

            if fromBY < toTY {
                baseMidY = Int(floor(Double((fromBY + 1) + (toTY - 1)) / 2.0))
                idealMidX = Int(floor(Double(fromCX + toCX) / 2.0))
            } else if toP.y + toP.height - 1 < fromP.y {
                let toBY = toP.y + toP.height - 1
                baseMidY = Int(floor(Double((toBY + 1) + (fromP.y - 1)) / 2.0))
                idealMidX = Int(floor(Double(fromCX + toCX) / 2.0))
            } else {
                baseMidY = max(fromBY, toP.y + toP.height - 1) + 2
                idealMidX = Int(floor(Double(fromCX + toCX) / 2.0))
            }

            var labelY = baseMidY
            let halfHeight = Int(floor(Double(lines.count) / 2.0))

            var labelInBox = false
            for i in 0..<lines.count {
                let y = labelY - halfHeight + i
                let idealLabelStart = idealMidX - Int(floor(Double(maxLabelWidth) / 2.0))
                let labelStart = max(0, idealLabelStart)
                for x in labelStart..<(labelStart + maxLabelWidth) where isInsideBox(x, y, excludeIds) {
                    labelInBox = true
                    break
                }
                if labelInBox { break }
            }

            if labelInBox {
                let gapTop = fromBY + 1
                let gapBottom = toTY - 1
                if gapTop <= gapBottom {
                    for y in gapTop...gapBottom {
                        var clearRow = true
                        let idealLabelStart = idealMidX - Int(floor(Double(maxLabelWidth) / 2.0))
                        let labelStart = max(0, idealLabelStart)
                        for x in labelStart..<(labelStart + maxLabelWidth) where isInsideBox(x, y, excludeIds) {
                            clearRow = false
                            break
                        }
                        if clearRow {
                            labelY = y
                            break
                        }
                    }
                }
            }

            let startY = labelY - halfHeight
            for (lineIdx, line) in lines.enumerated() {
                let paddedLine = " \(line) "
                let idealLabelStart = idealMidX - Int(floor(Double(paddedLine.count) / 2.0))
                let labelStart = max(0, idealLabelStart)
                let y = startY + lineIdx
                let labelEnd = labelStart + paddedLine.count
                if labelEnd > 0, y >= 0 {
                    _ = increaseSize(&canvas, max(labelEnd, 1), max(y + 1, 1))
                    _ = increaseRoleCanvasSize(&rc, max(labelEnd, 1), max(y + 1, 1))
                }
                for (i, ch) in paddedLine.enumerated() {
                    let lx = labelStart + i
                    if lx >= 0, y >= 0 {
                        setC(lx, y, ch, .text)
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

open class original_src_ascii_class_diagram {
    public init() {}

    public static let __elkVersion = ElkSwift.version
}
