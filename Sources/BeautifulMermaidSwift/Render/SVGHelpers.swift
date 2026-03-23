import Foundation
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

func _hex(_ color: BMColor) -> String? {
    #if targetEnvironment(macCatalyst) || canImport(UIKit)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    #elseif canImport(AppKit)
    guard let rgb = color.usingColorSpace(.deviceRGB) else { return nil }
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
    #else
    return nil
    #endif

    let ri = Int(max(0, min(255, (r * 255).rounded())))
    let gi = Int(max(0, min(255, (g * 255).rounded())))
    let bi = Int(max(0, min(255, (b * 255).rounded())))
    return String(format: "#%02X%02X%02X", ri, gi, bi)
}

func _flattenKnownSvgTokens(_ svg: String, theme: DiagramTheme) -> String {
    let bg = _hex(theme.background) ?? "#FFFFFF"
    let fg = _hex(theme.foreground) ?? "#27272A"
    let line = _hex(theme.effectiveLine()) ?? fg
    let muted = _hex(theme.effectiveMuted()) ?? line
    let surface = _hex(theme.effectiveSurface()) ?? bg
    let border = _hex(theme.effectiveBorder()) ?? line

    let replacements: [(token: String, value: String)] = [
        ("_line", line),
        ("_arrow", line),
        ("_node-fill", surface),
        ("_node-stroke", border),
        ("_group-fill", surface),
        ("_group-hdr", surface),
        ("_inner-stroke", border),
        ("_text", fg),
        ("_text-sec", muted),
        ("_text-muted", muted),
        ("_state-end-outer", fg),
        ("_state-end-inner", bg),
    ]

    var out = svg
    for item in replacements {
        let pattern = #"var\(\s*--\#(item.token)\s*(?:,\s*[^)]*)?\)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: (out as NSString).length)
            out = regex.stringByReplacingMatches(in: out, range: range, withTemplate: item.value)
        }
    }
    return out
}

func _resolveSvgCssVariables(_ svg: String) -> String {
    let ns = svg as NSString
    let pattern = "--([a-zA-Z0-9_-]+)\\s*:\\s*([^;\\\"]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return svg
    }

    let matches = regex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
    if matches.isEmpty { return svg }

    var vars: [String: String] = [:]
    for m in matches where m.numberOfRanges >= 3 {
        let name = ns.substring(with: m.range(at: 1))
        let value = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
        vars[name] = value
    }

    guard let varRegex = try? NSRegularExpression(
        pattern: #"var\(\s*--([a-zA-Z0-9_-]+)\s*(?:,\s*([^)]+))?\)"#
    ) else {
        return svg
    }

    func resolveVars(in input: String) -> String {
        var out = input
        for _ in 0..<16 {
            let source = out as NSString
            let range = NSRange(location: 0, length: source.length)
            let varMatches = varRegex.matches(in: out, range: range)
            if varMatches.isEmpty { break }

            var changed = false
            for m in varMatches.reversed() {
                guard m.numberOfRanges >= 2 else { continue }
                let key = source.substring(with: m.range(at: 1))
                let fallback: String? = (m.numberOfRanges >= 3 && m.range(at: 2).location != NSNotFound)
                    ? source.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    : nil

                let replacement = vars[key] ?? fallback ?? ""
                if !replacement.isEmpty {
                    out = (out as NSString).replacingCharacters(in: m.range(at: 0), with: replacement)
                    changed = true
                }
            }
            if !changed { break }
        }
        return out
    }

    // First resolve variable definitions themselves.
    for _ in 0..<8 {
        var changed = false
        for (k, v) in vars {
            let rv = resolveVars(in: v)
            if rv != v {
                vars[k] = rv
                changed = true
            }
        }
        if !changed { break }
    }

    var out = resolveVars(in: svg)

    // AppKit/UIKit SVG rasterizers do not reliably support color-mix().
    // Replace remaining dynamic CSS with deterministic solid colors.
    let mixPattern = #"color-mix\([^)]+\)"#
    if let mixRegex = try? NSRegularExpression(pattern: mixPattern) {
        let nsOut = out as NSString
        let matches = mixRegex.matches(in: out, range: NSRange(location: 0, length: nsOut.length))
        for m in matches.reversed() {
            out = (out as NSString).replacingCharacters(in: m.range, with: "#666666")
        }
    }

    let unresolvedVarPattern = #"var\([^)]+\)"#
    if let unresolvedVarRegex = try? NSRegularExpression(pattern: unresolvedVarPattern) {
        let nsOut = out as NSString
        let matches = unresolvedVarRegex.matches(in: out, range: NSRange(location: 0, length: nsOut.length))
        for m in matches.reversed() {
            out = (out as NSString).replacingCharacters(in: m.range, with: "#666666")
        }
    }

    return out
}
