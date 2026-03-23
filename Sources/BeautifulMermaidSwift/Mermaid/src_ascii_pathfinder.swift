// Ported from original/src/ascii/pathfinder.ts
import Foundation
import ElkSwift

open class original_src_ascii_pathfinder {
    public init() {}

    public static let __elkVersion = ElkSwift.version

    public typealias GridCoord = original_src_ascii_converter.GridCoord
    public typealias AsciiNode = original_src_ascii_converter.AsciiNode

    private struct PQItem {
        var coord: GridCoord
        var priority: Int
    }

    private struct MinHeap {
        private var items: [PQItem] = []

        var count: Int {
            items.count
        }

        mutating func push(_ item: PQItem) {
            items.append(item)
            bubbleUp(items.count - 1)
        }

        mutating func pop() -> PQItem? {
            guard !items.isEmpty else { return nil }
            let top = items[0]
            let last = items.removeLast()
            if !items.isEmpty {
                items[0] = last
                sinkDown(0)
            }
            return top
        }

        private mutating func bubbleUp(_ index: Int) {
            var i = index
            while i > 0 {
                let parent = (i - 1) >> 1
                if items[i].priority < items[parent].priority {
                    items.swapAt(i, parent)
                    i = parent
                } else {
                    break
                }
            }
        }

        private mutating func sinkDown(_ index: Int) {
            var i = index
            let n = items.count
            while true {
                var smallest = i
                let left = 2 * i + 1
                let right = 2 * i + 2

                if left < n, items[left].priority < items[smallest].priority {
                    smallest = left
                }
                if right < n, items[right].priority < items[smallest].priority {
                    smallest = right
                }

                if smallest != i {
                    items.swapAt(i, smallest)
                    i = smallest
                } else {
                    break
                }
            }
        }
    }

    public static func heuristic(_ a: GridCoord, _ b: GridCoord) -> Int {
        let absX = abs(a.x - b.x)
        let absY = abs(a.y - b.y)
        if absX == 0 || absY == 0 {
            return absX + absY
        }
        return absX + absY + 1
    }

    private static let MOVE_DIRS: [GridCoord] = [
        GridCoord(x: 1, y: 0),
        GridCoord(x: -1, y: 0),
        GridCoord(x: 0, y: 1),
        GridCoord(x: 0, y: -1),
    ]

    private static func isFreeInGrid(_ grid: [String: AsciiNode], _ c: GridCoord) -> Bool {
        if c.x < 0 || c.y < 0 {
            return false
        }
        return grid[original_src_ascii_converter.gridKey(c)] == nil
    }

    public static func getPath(
        _ grid: [String: AsciiNode],
        from: GridCoord,
        to: GridCoord
    ) -> [GridCoord]? {
        var pq = MinHeap()
        pq.push(PQItem(coord: from, priority: 0))

        var costSoFar: [String: Int] = [original_src_ascii_converter.gridKey(from): 0]
        var cameFrom: [String: GridCoord?] = [original_src_ascii_converter.gridKey(from): nil]

        while pq.count > 0 {
            guard let current = pq.pop()?.coord else { break }

            if original_src_ascii_converter.gridCoordEquals(current, to) {
                var path: [GridCoord] = []
                var cursor: GridCoord? = current
                while let c = cursor {
                    path.insert(c, at: 0)
                    cursor = cameFrom[original_src_ascii_converter.gridKey(c)] ?? nil
                }
                return path
            }

            let currentCost = costSoFar[original_src_ascii_converter.gridKey(current)] ?? 0
            for dir in MOVE_DIRS {
                let next = GridCoord(x: current.x + dir.x, y: current.y + dir.y)
                if !isFreeInGrid(grid, next) && !original_src_ascii_converter.gridCoordEquals(next, to) {
                    continue
                }

                let newCost = currentCost + 1
                let nextKey = original_src_ascii_converter.gridKey(next)
                if costSoFar[nextKey] == nil || newCost < (costSoFar[nextKey] ?? Int.max) {
                    costSoFar[nextKey] = newCost
                    let priority = newCost + heuristic(next, to)
                    pq.push(PQItem(coord: next, priority: priority))
                    cameFrom[nextKey] = current
                }
            }
        }

        return nil
    }

    public static func mergePath(_ path: [GridCoord]) -> [GridCoord] {
        if path.count <= 2 {
            return path
        }

        var toRemove = Set<Int>()
        var step0 = path[0]
        var step1 = path[1]

        for idx in 2..<path.count {
            let step2 = path[idx]
            let prevDx = step1.x - step0.x
            let prevDy = step1.y - step0.y
            let dx = step2.x - step1.x
            let dy = step2.y - step1.y

            if prevDx == dx && prevDy == dy {
                toRemove.insert(idx - 1)
            }

            step0 = step1
            step1 = step2
        }

        return path.enumerated().compactMap { idx, coord in
            toRemove.contains(idx) ? nil : coord
        }
    }
}
