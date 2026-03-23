import Foundation

public struct GraphLayout {
    public var config: LayoutConfig

    public init(config: LayoutConfig = LayoutConfig()) {
        self.config = config
    }

    public func layout(_ graph: MermaidGraph) throws -> PositionedGraph {
        _ = _ElkBridge.version
        switch graph.type {
        case .flowchart, .stateDiagram:
            return try layoutGraphSync(graph, config: config)
        case .classDiagram:
            guard let parsed = graph.payload as? ClassDiagram else {
                return PositionedGraph(diagram: graph, content: .classDiagram(classes: [], relationships: []))
            }
            let positioned = try layoutClassDiagramSync(parsed)
            return PositionedGraph(
                diagram: graph,
                width: positioned.width,
                height: positioned.height,
                content: .classDiagram(
                    classes: positioned.classes,
                    relationships: positioned.relationships
                )
            )
        case .erDiagram:
            guard let parsed = graph.payload as? ErDiagram else {
                return PositionedGraph(diagram: graph, content: .erDiagram(entities: [], relationships: []))
            }
            let positioned = try layoutErDiagramSync(parsed)
            return PositionedGraph(
                diagram: graph,
                width: positioned.width,
                height: positioned.height,
                content: .erDiagram(
                    entities: positioned.entities,
                    relationships: positioned.relationships
                )
            )
        case .sequenceDiagram:
            guard let parsed = graph.payload as? SequenceDiagram else {
                return PositionedGraph(diagram: graph, content: .sequenceDiagram(actors: [], messages: [], blocks: [], lifelines: [], activations: [], notes: []))
            }
            let positioned = try layoutSequenceDiagram(parsed)
            return PositionedGraph(
                diagram: graph,
                width: positioned.width,
                height: positioned.height,
                content: .sequenceDiagram(
                    actors: positioned.actors,
                    messages: positioned.messages,
                    blocks: positioned.blocks,
                    lifelines: positioned.lifelines,
                    activations: positioned.activations,
                    notes: positioned.notes
                )
            )
        case .xyChart:
            guard let chart = graph.payload as? XYChart else {
                return PositionedGraph(diagram: graph, content: .xyChart(PositionedXYChart.empty))
            }
            let positioned = layoutXYChart(chart)
            return PositionedGraph(
                diagram: graph,
                width: positioned.width,
                height: positioned.height,
                content: .xyChart(positioned)
            )
        }
    }
}
