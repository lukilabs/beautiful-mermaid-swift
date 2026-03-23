import XCTest
@testable import BeautifulMermaid
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

final class VisualComparisonExporterTests: XCTestCase {
    struct TestDiagram: Codable {
        let id: String
        let category: String
        let name: String
        let source: String
        let options: [String: Bool]?
    }

    struct TestDiagrams: Codable {
        let diagrams: [TestDiagram]
    }

    func testExportAllDiagramsToPNG() throws {
        let env = ProcessInfo.processInfo.environment
        let inputDir = env["VERIFICATION_INPUT_DIR"] ?? defaultVerificationPath(component: "shared")
        let outputDir: String
        if let envOutput = env["VERIFICATION_OUTPUT_DIR"] {
            let parent = (envOutput as NSString).deletingLastPathComponent
            outputDir = (parent as NSString).appendingPathComponent("png")
        } else {
            outputDir = defaultVerificationPath(component: "output/png")
        }

        let diagramsPath = (inputDir as NSString).appendingPathComponent("test-diagrams.json")
        guard FileManager.default.fileExists(atPath: diagramsPath) else {
            XCTFail("Missing verification input: \(diagramsPath)")
            return
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: diagramsPath))
        let testDiagrams = try JSONDecoder().decode(TestDiagrams.self, from: data)
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        for diagram in testDiagrams.diagrams {
            let outPath = (outputDir as NSString).appendingPathComponent("\(diagram.id).png")
            do {
                let pngData = try renderPngData(source: diagram.source, title: diagram.id)
                try pngData.write(to: URL(fileURLWithPath: outPath))
            } catch {
                let fallback = try renderFallbackPngData(size: CGSize(width: 640, height: 240), title: "\(diagram.id) export error")
                try? fallback.write(to: URL(fileURLWithPath: outPath))
                fputs("Visual export failed (\(diagram.id)): \(error)\n", stderr)
            }
        }
    }

    private func renderPngData(source: String, title: String) throws -> Data {
        let size = CGSize(width: 1600, height: 1000)
        let context = try makeBitmapContext(size: size)
        context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))

        try MermaidRenderer.render(
            source: source,
            in: context,
            bounds: CGRect(origin: .zero, size: size),
            theme: .default
        )

        return try pngData(from: context, title: title)
    }

    private func renderFallbackPngData(size: CGSize, title: String) throws -> Data {
        let context = try makeBitmapContext(size: size)
        context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))
        return try pngData(from: context, title: title)
    }

    private func makeBitmapContext(size: CGSize) throws -> CGContext {
        let width = max(1, Int(size.width.rounded(.up)))
        let height = max(1, Int(size.height.rounded(.up)))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw NSError(domain: "VisualExporter", code: 1)
        }
        return context
    }

    private func pngData(from context: CGContext, title: String) throws -> Data {
        _ = title
        guard let image = context.makeImage() else {
            throw NSError(domain: "VisualExporter", code: 2)
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "VisualExporter", code: 3)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "VisualExporter", code: 4)
        }
        return data as Data
    }

    private func defaultVerificationPath(component: String) -> String {
        let cwd = FileManager.default.currentDirectoryPath
        let root = (cwd as NSString).deletingLastPathComponent
        return (root as NSString).appendingPathComponent("verification/\(component)")
    }
}
