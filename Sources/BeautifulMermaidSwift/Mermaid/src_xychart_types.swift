// Ported from original/src/xychart/types.ts
import Foundation

// MARK: - Parsed types

public enum XYSeriesType: String, Sendable {
    case bar
    case line
}

public struct XYAxis: Sendable {
    public var title: String?
    public var categories: [String]?
    public var range: (min: Double, max: Double)?

    public init(title: String? = nil, categories: [String]? = nil, range: (min: Double, max: Double)? = nil) {
        self.title = title
        self.categories = categories
        self.range = range
    }
}

public struct XYChartSeries: Sendable {
    public var type: XYSeriesType
    public var data: [Double]

    public init(type: XYSeriesType, data: [Double]) {
        self.type = type
        self.data = data
    }
}

public struct XYChart: Sendable {
    public var title: String?
    public var horizontal: Bool
    public var xAxis: XYAxis
    public var yAxis: XYAxis
    public var series: [XYChartSeries]

    public init(title: String? = nil, horizontal: Bool = false, xAxis: XYAxis = XYAxis(), yAxis: XYAxis = XYAxis(), series: [XYChartSeries] = []) {
        self.title = title
        self.horizontal = horizontal
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.series = series
    }
}

// MARK: - Positioned types (ready for SVG rendering)

public struct PositionedXYChart: Sendable {
    public var width: Double
    public var height: Double
    public var horizontal: Bool
    public var title: PositionedTitle?
    public var xAxis: PositionedXYAxis
    public var yAxis: PositionedXYAxis
    public var plotArea: XYPlotArea
    public var bars: [PositionedBar]
    public var lines: [PositionedLine]
    public var gridLines: [XYGridLine]
    public var legend: [XYLegendItem]

    public init(
        width: Double, height: Double, horizontal: Bool = false,
        title: PositionedTitle? = nil,
        xAxis: PositionedXYAxis, yAxis: PositionedXYAxis,
        plotArea: XYPlotArea,
        bars: [PositionedBar], lines: [PositionedLine],
        gridLines: [XYGridLine], legend: [XYLegendItem]
    ) {
        self.width = width
        self.height = height
        self.horizontal = horizontal
        self.title = title
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.plotArea = plotArea
        self.bars = bars
        self.lines = lines
        self.gridLines = gridLines
        self.legend = legend
    }

    /// An empty XY chart with no data.
    public static let empty = PositionedXYChart(
        width: 0, height: 0,
        xAxis: PositionedXYAxis(ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)),
        yAxis: PositionedXYAxis(ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)),
        plotArea: XYPlotArea(x: 0, y: 0, width: 0, height: 0),
        bars: [], lines: [], gridLines: [], legend: []
    )
}

public struct PositionedTitle: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
}

public struct PositionedXYAxis: Sendable {
    public var title: AxisTitle?
    public var ticks: [XYAxisTick]
    public var line: AxisLine

    public init(title: AxisTitle? = nil, ticks: [XYAxisTick], line: AxisLine) {
        self.title = title
        self.ticks = ticks
        self.line = line
    }
}

public struct AxisTitle: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var rotate: Double?
}

public struct AxisLine: Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
}

public struct XYAxisTick: Sendable {
    public var label: String
    public var x: Double
    public var y: Double
    public var tx: Double
    public var ty: Double
    public var labelX: Double
    public var labelY: Double
    public var textAnchor: String // "start", "middle", "end"
}

public struct XYPlotArea: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
}

public struct PositionedBar: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var value: Double
    public var label: String?
    public var seriesIndex: Int
    public var colorIndex: Int
}

public struct PositionedLine: Sendable {
    public var points: [LinePoint]
    public var seriesIndex: Int
    public var colorIndex: Int
}

public struct LinePoint: Sendable {
    public var x: Double
    public var y: Double
    public var value: Double
    public var label: String?
}

public struct XYGridLine: Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
}

public struct XYLegendItem: Sendable {
    public var label: String
    public var x: Double
    public var y: Double
    public var type: XYSeriesType
    public var seriesIndex: Int
    public var colorIndex: Int
}
