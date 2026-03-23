// Ported from original/src/xychart/colors.ts
import Foundation

public let CHART_ACCENT_FALLBACK = "#3b82f6"

// MARK: - HSL ↔ Hex conversion

private func hexToHsl(_ hex: String) -> (h: Double, s: Double, l: Double) {
    let h = hex.replacingOccurrences(of: "#", with: "")
    let ri = Double(Int(h.prefix(2), radix: 16) ?? 0) / 255.0
    let gi = Double(Int(h.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255.0
    let bi = Double(Int(h.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255.0

    let maxC = max(ri, gi, bi)
    let minC = min(ri, gi, bi)
    let l = (maxC + minC) / 2.0

    if maxC == minC { return (0, 0, l * 100) }

    let d = maxC - minC
    let s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC)

    var hue: Double
    if maxC == ri {
        hue = ((gi - bi) / d + (gi < bi ? 6 : 0)) / 6.0
    } else if maxC == gi {
        hue = ((bi - ri) / d + 2) / 6.0
    } else {
        hue = ((ri - gi) / d + 4) / 6.0
    }

    return (hue * 360, s * 100, l * 100)
}

private func hslToHex(_ h: Double, _ s: Double, _ l: Double) -> String {
    let si = s / 100.0
    let li = l / 100.0

    let c = (1 - abs(2 * li - 1)) * si
    let x = c * (1 - abs(((h / 60).truncatingRemainder(dividingBy: 2)) - 1))
    let m = li - c / 2

    var r: Double, g: Double, b: Double
    if h < 60 { r = c; g = x; b = 0 }
    else if h < 120 { r = x; g = c; b = 0 }
    else if h < 180 { r = 0; g = c; b = x }
    else if h < 240 { r = 0; g = x; b = c }
    else if h < 300 { r = x; g = 0; b = c }
    else { r = c; g = 0; b = x }

    func toHex(_ v: Double) -> String {
        String(format: "%02x", Int(round((v + m) * 255)))
    }
    return "#\(toHex(r))\(toHex(g))\(toHex(b))"
}

// MARK: - Hex ↔ RGB conversion

private func hexToRgb(_ hex: String) -> (r: Int, g: Int, b: Int) {
    let h = hex.replacingOccurrences(of: "#", with: "")
    return (
        Int(h.prefix(2), radix: 16) ?? 0,
        Int(h.dropFirst(2).prefix(2), radix: 16) ?? 0,
        Int(h.dropFirst(4).prefix(2), radix: 16) ?? 0
    )
}

private func rgbToHex(_ r: Double, _ g: Double, _ b: Double) -> String {
    func toHex(_ v: Double) -> String {
        String(format: "%02x", Int(round(max(0, min(255, v)))))
    }
    return "#\(toHex(r))\(toHex(g))\(toHex(b))"
}

// MARK: - Public API

public func isValidHex(_ color: String) -> Bool {
    color.range(of: #"^#[0-9a-fA-F]{6}$"#, options: .regularExpression) != nil
}

public func isDarkBackground(_ bgHex: String) -> Bool {
    hexToHsl(bgHex).l < 50
}

public func mixHexColors(_ bgHex: String, _ fgHex: String, _ ratio: Double) -> String {
    let bg = hexToRgb(bgHex)
    let fg = hexToRgb(fgHex)
    let inv = 1 - ratio
    return rgbToHex(
        Double(bg.r) * inv + Double(fg.r) * ratio,
        Double(bg.g) * inv + Double(fg.g) * ratio,
        Double(bg.b) * inv + Double(fg.b) * ratio
    )
}

public func getSeriesColor(_ index: Int, _ accentColor: String, _ bgColor: String? = nil) -> String {
    if index == 0 { return accentColor }
    let safeAccent = isValidHex(accentColor) ? accentColor : CHART_ACCENT_FALLBACK
    let safeBg = bgColor.flatMap { isValidHex($0) ? $0 : nil }
    let hsl = hexToHsl(safeAccent)
    let chartS = max(55, min(85, hsl.s))

    let tier = Int(ceil(Double(index) / 2.0))
    let oddIndex = index % 2 == 1

    let dark: Bool
    if let safeBg, isDarkBackground(safeBg) {
        dark = !oddIndex
    } else {
        dark = oddIndex
    }
    let l = dark
        ? max(25, 48 - Double(tier) * 13)
        : min(78, 55 + Double(tier) * 11)

    let hShift = Double(dark ? -8 : 12) * Double(tier)
    let newH = ((hsl.h + hShift).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)

    return hslToHex(newH, chartS, l)
}
