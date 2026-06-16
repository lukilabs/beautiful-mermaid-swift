// Pie chart model and positioned render data.
import Foundation

public struct PieChartSlice: Sendable {
    public var label: String
    public var value: Double

    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

public struct PieChart: Sendable {
    public var title: String?
    public var showData: Bool
    public var slices: [PieChartSlice]

    public init(title: String? = nil, showData: Bool = false, slices: [PieChartSlice] = []) {
        self.title = title
        self.showData = showData
        self.slices = slices
    }
}

public struct PositionedPieChart: Sendable {
    public var width: Double
    public var height: Double
    public var title: PositionedTitle?
    public var showData: Bool
    public var centerX: Double
    public var centerY: Double
    public var radius: Double
    public var slices: [PositionedPieSlice]
    public var legend: [PieLegendItem]

    public init(
        width: Double,
        height: Double,
        title: PositionedTitle? = nil,
        showData: Bool = false,
        centerX: Double,
        centerY: Double,
        radius: Double,
        slices: [PositionedPieSlice],
        legend: [PieLegendItem]
    ) {
        self.width = width
        self.height = height
        self.title = title
        self.showData = showData
        self.centerX = centerX
        self.centerY = centerY
        self.radius = radius
        self.slices = slices
        self.legend = legend
    }

    public static let empty = PositionedPieChart(
        width: 0,
        height: 0,
        centerX: 0,
        centerY: 0,
        radius: 0,
        slices: [],
        legend: []
    )
}

public struct PositionedPieSlice: Sendable {
    public var label: String
    public var value: Double
    public var percentage: Double
    public var startAngle: Double
    public var endAngle: Double
    public var midAngle: Double
    public var labelX: Double
    public var labelY: Double
    public var colorIndex: Int

    public init(
        label: String,
        value: Double,
        percentage: Double,
        startAngle: Double,
        endAngle: Double,
        midAngle: Double,
        labelX: Double,
        labelY: Double,
        colorIndex: Int
    ) {
        self.label = label
        self.value = value
        self.percentage = percentage
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.midAngle = midAngle
        self.labelX = labelX
        self.labelY = labelY
        self.colorIndex = colorIndex
    }
}

public struct PieLegendItem: Sendable {
    public var label: String
    public var value: Double
    public var percentage: Double
    public var x: Double
    public var y: Double
    public var colorIndex: Int

    public init(label: String, value: Double, percentage: Double, x: Double, y: Double, colorIndex: Int) {
        self.label = label
        self.value = value
        self.percentage = percentage
        self.x = x
        self.y = y
        self.colorIndex = colorIndex
    }
}
