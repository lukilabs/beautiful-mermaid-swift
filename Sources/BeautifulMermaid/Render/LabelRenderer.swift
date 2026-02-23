// SPDX-License-Identifier: MIT
//
//  LabelRenderer.swift
//  BeautifulMermaid
//
//  Renders text labels using CoreText
//

import Foundation
import CoreGraphics
import CoreText

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Text alignment options
public enum TextAlignment {
    case left
    case center
    case right
}

/// Vertical alignment options
public enum VerticalAlignment {
    case top
    case center
    case bottom
}

/// Renders text labels
public class LabelRenderer {

    public init() {}

    /// Draw text at a specific point (centered by default)
    public func drawText(
        _ text: String,
        at point: CGPoint,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .center
    ) {
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        // Calculate position based on alignment
        var x = point.x
        let y = point.y - size.height / 2

        switch alignment {
        case .left:
            break // x stays at point.x
        case .center:
            x = point.x - size.width / 2
        case .right:
            x = point.x - size.width
        }

        let rect = CGRect(x: x, y: y, width: size.width, height: size.height)

        drawAttributedString(attributedString, in: rect, context: context)
    }

    /// Draw text within a bounding rect
    public func drawText(
        _ text: String,
        in rect: CGRect,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .left,
        verticalAlignment: VerticalAlignment = .center
    ) {
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        // Calculate position
        var x = rect.minX
        var y = rect.minY

        switch alignment {
        case .left:
            x = rect.minX
        case .center:
            x = rect.minX + (rect.width - size.width) / 2
        case .right:
            x = rect.maxX - size.width
        }

        switch verticalAlignment {
        case .top:
            y = rect.minY
        case .center:
            y = rect.minY + (rect.height - size.height) / 2
        case .bottom:
            y = rect.maxY - size.height
        }

        let drawRect = CGRect(x: x, y: y, width: size.width, height: size.height)
        drawAttributedString(attributedString, in: drawRect, context: context)
    }

    /// Draw multiline text
    public func drawMultilineText(
        _ text: String,
        in rect: CGRect,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .center,
        lineSpacing: CGFloat = 4
    ) {
        guard !text.isEmpty else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        switch alignment {
        case .left:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .right:
            paragraphStyle.alignment = .right
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        drawAttributedString(attributedString, in: rect, context: context, multiline: true)
    }

    // MARK: - Private Drawing

    private func drawAttributedString(
        _ attributedString: NSAttributedString,
        in rect: CGRect,
        context: CGContext,
        multiline: Bool = false
    ) {
        context.saveGState()

        #if canImport(UIKit)
        // UIKit context is already in the correct orientation
        attributedString.draw(in: rect)
        #elseif canImport(AppKit)
        // The main context has been flipped for AppKit (in DiagramRenderer),
        // making y=0 at top and y increasing downward.
        // NSAttributedString.draw expects y=0 at bottom (AppKit default).
        // We need to un-flip locally for text to appear correctly.

        // Apply inverse flip around the center of the rect
        // Translate to rect's center, flip, translate back
        let centerY = rect.midY
        context.translateBy(x: 0, y: centerY)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -centerY)

        attributedString.draw(in: rect)
        #endif

        context.restoreGState()
    }
}

// MARK: - Text Measurement

extension LabelRenderer {
    /// Measure text size
    public func measureText(_ text: String, font: BMFont) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        return attributedString.size()
    }

    /// Calculate the bounding rect for text
    public func boundingRect(for text: String, font: BMFont, maxWidth: CGFloat? = nil) -> CGRect {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        if let maxWidth = maxWidth {
            let constraintRect = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
            return (text as NSString).boundingRect(
                with: constraintRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
        } else {
            let size = (text as NSString).size(withAttributes: attributes)
            return CGRect(origin: .zero, size: size)
        }
    }
}
