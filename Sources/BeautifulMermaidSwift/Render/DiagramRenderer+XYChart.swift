import Foundation
import CoreGraphics
import CoreText
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {

    func _drawXYChart(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard let chart = positioned.xyChartData else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, chart.width), contentHeight: max(1, chart.height)) { ctx in
            let ch = chart.height
            // Flip to y=0-at-bottom: XY chart uses CTLineDraw which requires y-up,
            // and fy() maps SVG coordinates assuming y=0-at-bottom.
            ctx.translateBy(x: 0, y: ch)
            ctx.scaleBy(x: 1, y: -1)
            func fy(_ y: Double) -> Double { ch - y }

            // Background
            if !self.theme.transparent {
                ctx.setFillColor(self.theme.background.cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: chart.width, height: ch))
            }

            let textColor = self.theme.foreground.cgColor
            let mutedColor = self.theme.effectiveMuted().cgColor
            let bgColor = self.theme.background.cgColor

            // Grid dots
            let plotArea = chart.plotArea
            let xTicks = chart.xAxis.ticks.map(\.x)
            let yVals = chart.horizontal
                ? chart.yAxis.ticks.map(\.y)
                : chart.gridLines.map(\.y1)
            let xBase = xTicks.count > 1 ? abs(xTicks[1] - xTicks[0]) : plotArea.width / 6
            let yBase = yVals.count > 1 ? abs(yVals[1] - yVals[0]) : plotArea.height / 6
            let xGap = xBase / Double(max(1, Int((xBase / 20).rounded())))
            let yGap = yBase / Double(max(1, Int((yBase / 20).rounded())))
            let xAnchor = xTicks.first ?? plotArea.x
            let yAnchor = yVals.first ?? plotArea.y
            let xStart = xAnchor - ceil((xAnchor - plotArea.x) / xGap) * xGap
            let yStart = yAnchor - ceil((yAnchor - plotArea.y) / yGap) * yGap

            ctx.setFillColor(mutedColor)
            ctx.setAlpha(0.3)
            var dotY = yStart
            while dotY <= plotArea.y + plotArea.height + 0.5 {
                var dotX = xStart
                while dotX <= plotArea.x + plotArea.width + 0.5 {
                    ctx.fillEllipse(in: CGRect(x: dotX - 1.5, y: fy(dotY) - 1.5, width: 3, height: 3))
                    dotX += xGap
                }
                dotY += yGap
            }
            ctx.setAlpha(1.0)

            // Bars
            for bar in chart.bars {
                let seriesColor = self._xySeriesColor(bar.colorIndex, accentHex: _hex(self.theme.effectiveAccent()), bgHex: _hex(self.theme.background))
                let fillColor = self._mixCGColors(bgColor, seriesColor, ratio: 0.25)
                let barRect = CGRect(x: bar.x, y: fy(bar.y + bar.height), width: bar.width, height: bar.height)
                let cr = min(8, bar.width / 2, bar.height / 2)
                let barPath = CGPath(roundedRect: barRect, cornerWidth: cr, cornerHeight: cr, transform: nil)
                ctx.addPath(barPath)
                ctx.setFillColor(fillColor)
                ctx.fillPath()
                ctx.setStrokeColor(seriesColor)
                ctx.setLineWidth(1.5)
                ctx.addPath(barPath)
                ctx.strokePath()
            }

            // Lines
            for line in chart.lines {
                if line.points.isEmpty { continue }
                let seriesColor = self._xySeriesColor(line.colorIndex, accentHex: _hex(self.theme.effectiveAccent()), bgHex: _hex(self.theme.background))
                let flipped = line.points.map { LinePoint(x: $0.x, y: fy($0.y), value: $0.value, label: $0.label) }

                // Shadow
                ctx.saveGState()
                ctx.setStrokeColor(seriesColor)
                ctx.setLineWidth(5)
                ctx.setAlpha(0.12)
                self._addCurvePath(ctx, flipped, offsetY: -2)
                ctx.strokePath()
                ctx.restoreGState()

                // Main line
                ctx.setStrokeColor(seriesColor)
                ctx.setLineWidth(2.5)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                self._addCurvePath(ctx, flipped)
                ctx.strokePath()

                // Dots for sparse lines
                if flipped.count <= 12 {
                    for p in flipped {
                        ctx.setFillColor(seriesColor)
                        ctx.fillEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
                        ctx.setFillColor(bgColor)
                        ctx.fillEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
                        ctx.setFillColor(seriesColor)
                        ctx.fillEllipse(in: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4))
                    }
                }
            }

            // Axis labels (muted color, matching edge labels in flowcharts)
            let labelFont = BMFont.systemFont(ofSize: 12, weight: .regular)
            for tick in chart.xAxis.ticks {
                let anchor: NSTextAlignment = tick.textAnchor == "end" ? .right : tick.textAnchor == "start" ? .left : .center
                self._drawTextXY(ctx, tick.label, x: tick.labelX, y: fy(tick.labelY), font: labelFont, color: mutedColor, align: anchor)
            }
            for tick in chart.yAxis.ticks {
                let anchor: NSTextAlignment = tick.textAnchor == "end" ? .right : tick.textAnchor == "start" ? .left : .center
                self._drawTextXY(ctx, tick.label, x: tick.labelX, y: fy(tick.labelY), font: labelFont, color: mutedColor, align: anchor)
            }

            // Axis titles
            let axisTitleFont = BMFont.systemFont(ofSize: 15, weight: .medium)
            if let t = chart.xAxis.title {
                if let rotate = t.rotate {
                    ctx.saveGState()
                    ctx.translateBy(x: CGFloat(t.x), y: CGFloat(fy(t.y)))
                    ctx.rotate(by: CGFloat(-rotate) * .pi / 180)
                    self._drawTextXY(ctx, t.text, x: 0, y: 0, font: axisTitleFont, color: textColor, align: .center)
                    ctx.restoreGState()
                } else {
                    self._drawTextXY(ctx, t.text, x: t.x, y: fy(t.y), font: axisTitleFont, color: textColor, align: .center)
                }
            }
            if let t = chart.yAxis.title {
                if let rotate = t.rotate {
                    ctx.saveGState()
                    ctx.translateBy(x: CGFloat(t.x), y: CGFloat(fy(t.y)))
                    ctx.rotate(by: CGFloat(-rotate) * .pi / 180)
                    self._drawTextXY(ctx, t.text, x: 0, y: 0, font: axisTitleFont, color: textColor, align: .center)
                    ctx.restoreGState()
                } else {
                    self._drawTextXY(ctx, t.text, x: t.x, y: fy(t.y), font: axisTitleFont, color: textColor, align: .center)
                }
            }

            // Chart title (smaller font, centered at top)
            if let title = chart.title {
                let titleFont = BMFont.systemFont(ofSize: 16, weight: .semibold)
                self._drawTextXY(ctx, title.text, x: title.x, y: fy(title.y), font: titleFont, color: textColor, align: .center)
            }

            // Legend
            let legendFont = BMFont.systemFont(ofSize: 12, weight: .regular)

            for item in chart.legend {
                let seriesColor = self._xySeriesColor(item.colorIndex, accentHex: _hex(self.theme.effectiveAccent()), bgHex: _hex(self.theme.background))
                let iy = fy(item.y)
                let sy = iy  // swatch center matches text visual center
                if item.type == .bar {
                    let fillColor = self._mixCGColors(bgColor, seriesColor, ratio: 0.25)
                    let swatchRect = CGRect(x: item.x, y: sy - 5, width: 12, height: 10)
                    let swatchPath = CGPath(roundedRect: swatchRect, cornerWidth: 2, cornerHeight: 2, transform: nil)
                    ctx.addPath(swatchPath)
                    ctx.setFillColor(fillColor)
                    ctx.fillPath()
                    ctx.addPath(swatchPath)
                    ctx.setStrokeColor(seriesColor)
                    ctx.setLineWidth(1.5)
                    ctx.strokePath()
                } else {
                    ctx.setStrokeColor(seriesColor)
                    ctx.setLineWidth(2.5)
                    ctx.setLineCap(.round)
                    ctx.move(to: CGPoint(x: item.x, y: sy))
                    ctx.addLine(to: CGPoint(x: item.x + 12, y: sy))
                    ctx.strokePath()
                }
                self._drawTextXY(ctx, item.label, x: item.x + 17, y: iy, font: legendFont, color: mutedColor, align: .left)
            }
        }
    }

    private func _xySeriesColor(_ index: Int, accentHex: String?, bgHex: String?) -> CGColor {
        if index == 0 { return theme.effectiveAccent().cgColor }
        let hex = getSeriesColor(index, accentHex ?? _hex(theme.effectiveAccent()) ?? "#3b82f6", bgHex)
        return BMColor(hex: hex).cgColor
    }

    private func _mixCGColors(_ bg: CGColor, _ fg: CGColor, ratio: CGFloat) -> CGColor {
        let bgComps = bg.components ?? [1, 1, 1, 1]
        let fgComps = fg.components ?? [0, 0, 0, 1]
        let r = bgComps[0] * (1 - ratio) + fgComps[0] * ratio
        let g = (bgComps.count > 1 ? bgComps[1] : bgComps[0]) * (1 - ratio) + (fgComps.count > 1 ? fgComps[1] : fgComps[0]) * ratio
        let b = (bgComps.count > 2 ? bgComps[2] : bgComps[0]) * (1 - ratio) + (fgComps.count > 2 ? fgComps[2] : fgComps[0]) * ratio
        return CGColor(red: r, green: g, blue: b, alpha: 1)
    }

    private func _addCurvePath(_ ctx: CGContext, _ points: [LinePoint], offsetY: Double = 0) {
        guard !points.isEmpty else { return }
        if points.count == 1 {
            ctx.move(to: CGPoint(x: points[0].x, y: points[0].y + offsetY))
            return
        }
        if points.count == 2 {
            ctx.move(to: CGPoint(x: points[0].x, y: points[0].y + offsetY))
            ctx.addLine(to: CGPoint(x: points[1].x, y: points[1].y + offsetY))
            return
        }

        let n = points.count
        var h = [Double]()
        var delta = [Double]()
        for i in 0..<(n - 1) {
            let hi = points[i + 1].x - points[i].x
            h.append(hi)
            delta.append(hi == 0 ? 0 : (points[i + 1].y - points[i].y) / hi)
        }

        var c = [Double](repeating: 0, count: n)
        if n > 2 {
            var cp = [Double](repeating: 0, count: n)
            var dp = [Double](repeating: 0, count: n)
            for i in 1..<(n - 1) {
                let diag = 2 * (h[i - 1] + h[i])
                let rhs = 3 * (delta[i] - delta[i - 1])
                if i == 1 {
                    cp[i] = h[i] / diag
                    dp[i] = rhs / diag
                } else {
                    let w = diag - h[i - 1] * cp[i - 1]
                    cp[i] = h[i] / w
                    dp[i] = (rhs - h[i - 1] * dp[i - 1]) / w
                }
            }
            for i in stride(from: n - 2, through: 1, by: -1) {
                c[i] = dp[i] - cp[i] * c[i + 1]
            }
        }

        var slopes = [Double](repeating: 0, count: n)
        for i in 0..<(n - 1) {
            slopes[i] = delta[i] - h[i] * (2 * c[i] + c[i + 1]) / 3
        }
        slopes[n - 1] = delta[n - 2] + h[n - 2] * c[n - 2] / 3

        ctx.move(to: CGPoint(x: points[0].x, y: points[0].y + offsetY))
        for i in 0..<(n - 1) {
            let seg = h[i] / 3
            let cp1 = CGPoint(x: points[i].x + seg, y: points[i].y + slopes[i] * seg + offsetY)
            let cp2 = CGPoint(x: points[i + 1].x - seg, y: points[i + 1].y - slopes[i + 1] * seg + offsetY)
            ctx.addCurve(to: CGPoint(x: points[i + 1].x, y: points[i + 1].y + offsetY), control1: cp1, control2: cp2)
        }
    }

    private func _drawTextXY(_ ctx: CGContext, _ text: String, x: Double, y: Double, font: BMFont, color: CGColor, align: NSTextAlignment) {
        let attrString = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: BMColor(cgColor: color) ?? BMColor.black,
        ])
        let line = CTLineCreateWithAttributedString(attrString)
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        var ascent: CGFloat = 0, descent: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, nil)

        var drawX: CGFloat
        switch align {
        case .center: drawX = CGFloat(x) - textBounds.width / 2
        case .right: drawX = CGFloat(x) - textBounds.width
        default: drawX = CGFloat(x)
        }
        // Vertically center: baseline positioned so text midpoint aligns with y
        // In CGContext (y-up), text center = baseline + (ascent - descent)/2,
        // so baseline = y - (ascent - descent)/2
        let drawY = CGFloat(y) - (ascent - descent) / 2

        ctx.saveGState()
        ctx.textPosition = CGPoint(x: drawX, y: drawY)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
