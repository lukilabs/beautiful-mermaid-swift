// SPDX-License-Identifier: MIT
//
//  CGPoint+Extensions.swift
//  BeautifulMermaid
//
//  Vector math utilities for CGPoint
//

import Foundation
import CoreGraphics

extension CGPoint {
    /// Add two points
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    /// Subtract two points
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    /// Multiply point by scalar
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    /// Divide point by scalar
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    /// Distance to another point
    func distance(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }

    /// Squared distance (avoids sqrt for comparison)
    func distanceSquared(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return dx * dx + dy * dy
    }

    /// Magnitude (length) of vector
    var magnitude: CGFloat {
        sqrt(x * x + y * y)
    }

    /// Normalized unit vector
    var normalized: CGPoint {
        let mag = magnitude
        guard mag > 0 else { return .zero }
        return CGPoint(x: x / mag, y: y / mag)
    }

    /// Angle in radians from origin
    var angle: CGFloat {
        atan2(y, x)
    }

    /// Angle to another point in radians
    func angle(to other: CGPoint) -> CGFloat {
        let delta = other - self
        return delta.angle
    }

    /// Dot product
    func dot(_ other: CGPoint) -> CGFloat {
        x * other.x + y * other.y
    }

    /// Cross product (z-component of 3D cross product)
    func cross(_ other: CGPoint) -> CGFloat {
        x * other.y - y * other.x
    }

    /// Linear interpolation between two points
    func lerp(to other: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (other.x - x) * t,
            y: y + (other.y - y) * t
        )
    }

    /// Midpoint to another point
    func midpoint(to other: CGPoint) -> CGPoint {
        lerp(to: other, t: 0.5)
    }

    /// Rotate point around origin by angle in radians
    func rotated(by angle: CGFloat) -> CGPoint {
        let cos = Darwin.cos(angle)
        let sin = Darwin.sin(angle)
        return CGPoint(
            x: x * cos - y * sin,
            y: x * sin + y * cos
        )
    }

    /// Rotate point around another point by angle in radians
    func rotated(around center: CGPoint, by angle: CGFloat) -> CGPoint {
        let translated = self - center
        let rotated = translated.rotated(by: angle)
        return rotated + center
    }

    /// Perpendicular vector (rotated 90 degrees counter-clockwise)
    var perpendicular: CGPoint {
        CGPoint(x: -y, y: x)
    }

    /// Project this point onto a line defined by two points
    func projected(onto lineStart: CGPoint, lineEnd: CGPoint) -> CGPoint {
        let line = lineEnd - lineStart
        let lineLength = line.magnitude
        guard lineLength > 0 else { return lineStart }

        let t = max(0, min(1, (self - lineStart).dot(line) / (lineLength * lineLength)))
        return lineStart + line * t
    }

    /// Distance from this point to a line segment
    func distance(toLineFrom lineStart: CGPoint, to lineEnd: CGPoint) -> CGFloat {
        let projected = projected(onto: lineStart, lineEnd: lineEnd)
        return distance(to: projected)
    }
}

// MARK: - CGSize Extensions

extension CGSize {
    /// Add two sizes
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    /// Multiply size by scalar
    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }

    /// Maximum dimension
    var maxDimension: CGFloat {
        max(width, height)
    }

    /// Minimum dimension
    var minDimension: CGFloat {
        min(width, height)
    }

    /// As a point (for vector operations)
    var asPoint: CGPoint {
        CGPoint(x: width, y: height)
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    /// Center point of rect
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    /// Create rect from center point and size
    init(center: CGPoint, size: CGSize) {
        self.init(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Expand rect by padding
    func expanded(by padding: CGFloat) -> CGRect {
        CGRect(
            x: minX - padding,
            y: minY - padding,
            width: width + padding * 2,
            height: height + padding * 2
        )
    }

    /// Expand rect by different padding on each side
    func expanded(horizontal: CGFloat, vertical: CGFloat) -> CGRect {
        CGRect(
            x: minX - horizontal,
            y: minY - vertical,
            width: width + horizontal * 2,
            height: height + vertical * 2
        )
    }

    /// Four corners of the rect
    var corners: [CGPoint] {
        [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: maxY)
        ]
    }

    /// Four edge midpoints of the rect
    var edgeMidpoints: [CGPoint] {
        [
            CGPoint(x: midX, y: minY),  // Top
            CGPoint(x: maxX, y: midY),  // Right
            CGPoint(x: midX, y: maxY),  // Bottom
            CGPoint(x: minX, y: midY)   // Left
        ]
    }
}
