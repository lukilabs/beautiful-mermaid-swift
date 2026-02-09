#!/usr/bin/env swift
//
//  GenerateAppIcon.swift
//  MermaidPlayground
//
//  Generates the app icon with a mermaid (mythical creature) theme.
//  Run with: swift GenerateAppIcon.swift
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()

// Create bitmap context
guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create context")
    exit(1)
}

// Flip coordinate system (0,0 at top-left)
context.translateBy(x: 0, y: size)
context.scaleBy(x: 1, y: -1)

// Draw gradient background (deep ocean)
let gradientColors = [
    CGColor(red: 0.05, green: 0.20, blue: 0.35, alpha: 1.0),  // Deep ocean blue
    CGColor(red: 0.00, green: 0.55, blue: 0.65, alpha: 1.0)   // Teal
] as CFArray

guard let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: gradientColors,
    locations: [0.0, 1.0]
) else {
    print("Failed to create gradient")
    exit(1)
}

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: size/2, y: 0),
    end: CGPoint(x: size/2, y: size),
    options: []
)

// Draw stylized mermaid tail silhouette
let centerX = size / 2
let centerY = size / 2

context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))

// Mermaid tail - elegant curved shape
context.beginPath()

// Start at top of tail (waist area)
let tailTop: CGFloat = 180
let tailBottom: CGFloat = 880
let tailWidth: CGFloat = 280

// Left side of tail body curving down
context.move(to: CGPoint(x: centerX - tailWidth/2, y: tailTop))

// Curve down the left side (body getting narrower)
context.addCurve(
    to: CGPoint(x: centerX - 60, y: 580),
    control1: CGPoint(x: centerX - tailWidth/2 - 40, y: 300),
    control2: CGPoint(x: centerX - 100, y: 450)
)

// Continue to where the tail fin splits
context.addCurve(
    to: CGPoint(x: centerX - 30, y: 700),
    control1: CGPoint(x: centerX - 50, y: 620),
    control2: CGPoint(x: centerX - 35, y: 660)
)

// Left tail fin - sweeping curve outward with more curl
context.addCurve(
    to: CGPoint(x: centerX - 350, y: tailBottom - 40),
    control1: CGPoint(x: centerX - 60, y: 760),
    control2: CGPoint(x: centerX - 320, y: 780)
)

// Curl at the tip of left fin
context.addCurve(
    to: CGPoint(x: centerX - 280, y: tailBottom + 20),
    control1: CGPoint(x: centerX - 380, y: tailBottom - 20),
    control2: CGPoint(x: centerX - 350, y: tailBottom + 40)
)

// Curve back to center bottom of tail fin
context.addCurve(
    to: CGPoint(x: centerX, y: 780),
    control1: CGPoint(x: centerX - 200, y: tailBottom + 10),
    control2: CGPoint(x: centerX - 80, y: 820)
)

// Right tail fin - sweeping curve outward with more curl
context.addCurve(
    to: CGPoint(x: centerX + 280, y: tailBottom + 20),
    control1: CGPoint(x: centerX + 80, y: 820),
    control2: CGPoint(x: centerX + 200, y: tailBottom + 10)
)

// Curl at the tip of right fin
context.addCurve(
    to: CGPoint(x: centerX + 350, y: tailBottom - 40),
    control1: CGPoint(x: centerX + 350, y: tailBottom + 40),
    control2: CGPoint(x: centerX + 380, y: tailBottom - 20)
)

// Curve back up to right side of tail
context.addCurve(
    to: CGPoint(x: centerX + 30, y: 700),
    control1: CGPoint(x: centerX + 320, y: 780),
    control2: CGPoint(x: centerX + 60, y: 760)
)

// Continue up the right side
context.addCurve(
    to: CGPoint(x: centerX + 60, y: 580),
    control1: CGPoint(x: centerX + 35, y: 660),
    control2: CGPoint(x: centerX + 50, y: 620)
)

// Curve up the right side of body (getting wider toward top)
context.addCurve(
    to: CGPoint(x: centerX + tailWidth/2, y: tailTop),
    control1: CGPoint(x: centerX + 100, y: 450),
    control2: CGPoint(x: centerX + tailWidth/2 + 40, y: 300)
)

// Close the top with a gentle curve
context.addCurve(
    to: CGPoint(x: centerX - tailWidth/2, y: tailTop),
    control1: CGPoint(x: centerX + tailWidth/4, y: tailTop - 30),
    control2: CGPoint(x: centerX - tailWidth/4, y: tailTop - 30)
)

context.closePath()
context.fillPath()

// Add scale pattern details (subtle lines on the tail)
context.setStrokeColor(CGColor(red: 0.85, green: 0.92, blue: 0.95, alpha: 0.4))
context.setLineWidth(3)

// Horizontal scale lines
for i in 0..<8 {
    let y = 250 + CGFloat(i) * 55
    let xOffset = CGFloat(i) * 8
    let width = max(80, tailWidth - CGFloat(i) * 35)

    context.move(to: CGPoint(x: centerX - width/2 + xOffset, y: y))
    context.addQuadCurve(
        to: CGPoint(x: centerX + width/2 - xOffset, y: y),
        control: CGPoint(x: centerX, y: y + 15)
    )
    context.strokePath()
}

// Add subtle wave decorations at the bottom corners
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.3))
context.setLineWidth(8)
context.setLineCap(.round)

// Small bubbles
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
let bubbles = [
    (x: 150.0, y: 200.0, r: 25.0),
    (x: 120.0, y: 280.0, r: 18.0),
    (x: 180.0, y: 320.0, r: 12.0),
    (x: 870.0, y: 180.0, r: 22.0),
    (x: 900.0, y: 260.0, r: 15.0),
    (x: 840.0, y: 340.0, r: 10.0),
]

for bubble in bubbles {
    context.fillEllipse(in: CGRect(
        x: bubble.x - bubble.r,
        y: bubble.y - bubble.r,
        width: bubble.r * 2,
        height: bubble.r * 2
    ))
}

// Create image from context
guard let cgImage = context.makeImage() else {
    print("Failed to create image")
    exit(1)
}

// Get the directory of this script
let scriptPath = CommandLine.arguments[0]
let scriptURL = URL(fileURLWithPath: scriptPath)
let projectDir = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputURL = projectDir
    .appendingPathComponent("Resources")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")
    .appendingPathComponent("AppIcon.png")

// Create destination
guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    print("Failed to create image destination")
    exit(1)
}

CGImageDestinationAddImage(destination, cgImage, nil)

if CGImageDestinationFinalize(destination) {
    print("Icon saved to: \(outputURL.path)")
} else {
    print("Failed to save icon")
    exit(1)
}
