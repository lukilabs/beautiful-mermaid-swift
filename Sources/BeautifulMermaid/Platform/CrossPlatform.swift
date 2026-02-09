// SPDX-License-Identifier: MIT
//
//  CrossPlatform.swift
//  BeautifulMermaid
//
//  Cross-platform type aliases for iOS/macOS compatibility
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit

public typealias BMView = UIView
public typealias BMColor = UIColor
public typealias BMBezierPath = UIBezierPath
public typealias BMFont = UIFont
public typealias BMImage = UIImage

extension BMBezierPath {
    public func bm_line(to point: CGPoint) {
        addLine(to: point)
    }

    public func bm_curve(to point: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
        addCurve(to: point, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
    }

    public var bm_cgPath: CGPath {
        cgPath
    }
}

#elseif canImport(AppKit)
import AppKit

public typealias BMView = NSView
public typealias BMColor = NSColor
public typealias BMBezierPath = NSBezierPath
public typealias BMFont = NSFont
public typealias BMImage = NSImage

extension BMBezierPath {
    public func bm_line(to point: CGPoint) {
        line(to: point)
    }

    public func bm_curve(to point: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
        curve(to: point, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
    }

    public var bm_cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }

    /// Convenience initializer for rounded rect (matches UIBezierPath API)
    public convenience init(roundedRect rect: NSRect, cornerRadius: CGFloat) {
        self.init(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    }
}

extension NSImage {
    public var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

#endif

// MARK: - Common Extensions

extension BMColor {
    public convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r, g, b, a: CGFloat
        switch hexSanitized.count {
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }

    public var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if canImport(UIKit)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif

        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    public func mixed(with other: BMColor, amount: CGFloat) -> BMColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        #if canImport(UIKit)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #elseif canImport(AppKit)
        if let c1 = usingColorSpace(.deviceRGB), let c2 = other.usingColorSpace(.deviceRGB) {
            c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        }
        #endif

        let clampedAmount = max(0, min(1, amount))
        return BMColor(
            red: r1 + (r2 - r1) * clampedAmount,
            green: g1 + (g2 - g1) * clampedAmount,
            blue: b1 + (b2 - b1) * clampedAmount,
            alpha: a1 + (a2 - a1) * clampedAmount
        )
    }

    public func lightened(by amount: CGFloat = 0.2) -> BMColor {
        mixed(with: BMColor.white, amount: amount)
    }

    public func darkened(by amount: CGFloat = 0.2) -> BMColor {
        mixed(with: BMColor.black, amount: amount)
    }
}
