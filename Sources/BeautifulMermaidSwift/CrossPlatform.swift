import Foundation
import CoreGraphics

#if targetEnvironment(macCatalyst)
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

#elseif canImport(UIKit)
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

// MARK: - BMColor Extensions

extension BMColor {
    public convenience init(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        raw = raw.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)

        let r, g, b, a: CGFloat
        switch raw.count {
        case 6:
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
            a = 1
        case 8:
            r = CGFloat((value & 0xFF000000) >> 24) / 255
            g = CGFloat((value & 0x00FF0000) >> 16) / 255
            b = CGFloat((value & 0x0000FF00) >> 8) / 255
            a = CGFloat(value & 0x000000FF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }

    /// Compare two colors by their RGBA components (avoids hexString round-trip loss and alpha drop)
    public func bmColorEquals(_ other: BMColor) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #elseif canImport(AppKit)
        if let c1 = usingColorSpace(.deviceRGB), let c2 = other.usingColorSpace(.deviceRGB) {
            c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        }
        #endif
        return r1 == r2 && g1 == g2 && b1 == b2 && a1 == a2
    }

    public var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        guard let rgbColor = usingColorSpace(.deviceRGB) else { return "#000000" }
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    public func mixed(with other: BMColor, amount: CGFloat) -> BMColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #elseif canImport(AppKit)
        if let c1 = usingColorSpace(.deviceRGB), let c2 = other.usingColorSpace(.deviceRGB) {
            c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        }
        #endif

        let t = max(0, min(1, amount))
        return BMColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }

    public func lightened(by amount: CGFloat = 0.2) -> BMColor {
        mixed(with: BMColor.white, amount: amount)
    }

    public func darkened(by amount: CGFloat = 0.2) -> BMColor {
        mixed(with: BMColor.black, amount: amount)
    }
}

// MARK: - ColorMix Constants

public enum ColorMix {
    public static let text: CGFloat = 1.0
    public static let textSec: CGFloat = 0.60
    public static let textMuted: CGFloat = 0.40
    public static let textFaint: CGFloat = 0.25
    public static let line: CGFloat = 0.50
    public static let arrow: CGFloat = 0.85
    public static let nodeFill: CGFloat = 0.03
    public static let nodeStroke: CGFloat = 0.20
    public static let groupHeader: CGFloat = 0.05
    public static let innerStroke: CGFloat = 0.12
    public static let keyBadge: CGFloat = 0.10
}

// MARK: - CGRect Extension

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
