// SPDX-License-Identifier: MIT
//
//  ColorUtilities.swift
//  BeautifulMermaid
//
//  Color manipulation utilities
//

import Foundation
import CoreGraphics

/// Color manipulation utilities
public struct ColorUtilities {

    /// Calculate relative luminance of a color
    public static func luminance(of color: BMColor) -> CGFloat {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if canImport(UIKit)
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        if let rgbColor = color.usingColorSpace(.deviceRGB) {
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        #endif

        // sRGB to linear conversion
        func linearize(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    /// Calculate contrast ratio between two colors
    public static func contrastRatio(between color1: BMColor, and color2: BMColor) -> CGFloat {
        let l1 = luminance(of: color1)
        let l2 = luminance(of: color2)

        let lighter = max(l1, l2)
        let darker = min(l1, l2)

        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Check if a color is considered "dark"
    public static func isDark(_ color: BMColor) -> Bool {
        luminance(of: color) < 0.5
    }

    /// Get a contrasting text color (black or white)
    public static func contrastingTextColor(for background: BMColor) -> BMColor {
        isDark(background) ? BMColor.white : BMColor.black
    }

    /// Adjust color saturation
    public static func adjustSaturation(of color: BMColor, by amount: CGFloat) -> BMColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if canImport(UIKit)
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let newS = max(0, min(1, s + amount))
        return BMColor(hue: h, saturation: newS, brightness: b, alpha: a)
        #elseif canImport(AppKit)
        if let hsbColor = color.usingColorSpace(.deviceRGB) {
            hsbColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let newS = max(0, min(1, s + amount))
            return BMColor(hue: h, saturation: newS, brightness: b, alpha: a)
        }
        return color
        #endif
    }

    /// Adjust color brightness
    public static func adjustBrightness(of color: BMColor, by amount: CGFloat) -> BMColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if canImport(UIKit)
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let newB = max(0, min(1, b + amount))
        return BMColor(hue: h, saturation: s, brightness: newB, alpha: a)
        #elseif canImport(AppKit)
        if let hsbColor = color.usingColorSpace(.deviceRGB) {
            hsbColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let newB = max(0, min(1, b + amount))
            return BMColor(hue: h, saturation: s, brightness: newB, alpha: a)
        }
        return color
        #endif
    }

    /// Create a color palette from a base color
    public static func palette(from baseColor: BMColor, steps: Int = 5) -> [BMColor] {
        var colors: [BMColor] = []
        let step = 1.0 / CGFloat(steps)

        for i in 0..<steps {
            let amount = CGFloat(i) * step - 0.5
            let adjusted = adjustBrightness(of: baseColor, by: amount * 0.5)
            colors.append(adjusted)
        }

        return colors
    }

    /// Generate complementary color
    public static func complementary(of color: BMColor) -> BMColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if canImport(UIKit)
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let newH = (h + 0.5).truncatingRemainder(dividingBy: 1.0)
        return BMColor(hue: newH, saturation: s, brightness: b, alpha: a)
        #elseif canImport(AppKit)
        if let hsbColor = color.usingColorSpace(.deviceRGB) {
            hsbColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let newH = (h + 0.5).truncatingRemainder(dividingBy: 1.0)
            return BMColor(hue: newH, saturation: s, brightness: b, alpha: a)
        }
        return color
        #endif
    }
}
