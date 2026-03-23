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

final class VisualReportGenerator: XCTestCase {

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

    /// Renders all diagrams to PNG and generates an HTML visual report.
    func testGenerateVisualReport() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let root = (cwd as NSString).deletingLastPathComponent

        let diagramsPath = (root as NSString).appendingPathComponent("verification/shared/test-diagrams.json")
        guard FileManager.default.fileExists(atPath: diagramsPath) else {
            XCTFail("Missing test-diagrams.json at \(diagramsPath)")
            return
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: diagramsPath))
        let testDiagrams = try JSONDecoder().decode(TestDiagrams.self, from: data)

        let outputDir = (root as NSString).appendingPathComponent("verification/output/png-cgcontext")
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        var results: [(diagram: TestDiagram, pngFile: String, success: Bool, error: String?)] = []

        for diagram in testDiagrams.diagrams {
            let pngFile = "\(diagram.id).png"
            let outPath = (outputDir as NSString).appendingPathComponent(pngFile)
            print("=== RENDERING \(diagram.id) ===")
            do {
                let pngData = try renderDiagramPng(source: diagram.source, theme: .default)
                try pngData.write(to: URL(fileURLWithPath: outPath))
                results.append((diagram, pngFile, true, nil))
            } catch {
                let fallback = renderFallbackPng(size: CGSize(width: 640, height: 240), message: "\(diagram.id): \(error.localizedDescription)")
                try? fallback.write(to: URL(fileURLWithPath: outPath))
                results.append((diagram, pngFile, false, error.localizedDescription))
                fputs("FAIL [\(diagram.id)]: \(error)\n", stderr)
            }
        }

        // Generate HTML report
        let htmlPath = (outputDir as NSString).appendingPathComponent("visual-report.html")
        let html = generateHtml(results: results)
        try html.write(toFile: htmlPath, atomically: true, encoding: .utf8)

        let successCount = results.filter { $0.success }.count
        let failCount = results.count - successCount
        print("\n=== Visual Report Generated ===")
        print("Output: \(outputDir)")
        print("HTML:   \(htmlPath)")
        print("Total:  \(results.count) diagrams")
        print("OK:     \(successCount)")
        print("Failed: \(failCount)")
        if failCount > 0 {
            for r in results where !r.success {
                print("  FAIL: \(r.diagram.id) — \(r.error ?? "unknown")")
            }
        }
        print("")
    }

    // MARK: - Rendering

    private func renderDiagramPng(source: String, theme: DiagramTheme, size: CGSize = CGSize(width: 1600, height: 1000)) throws -> Data {
        let width = Int(size.width)
        let height = Int(size.height)

        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw NSError(domain: "VisualReport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
        }

        // Fill background
        context.setFillColor(theme.background.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Flip to top-left coordinate system (raw CGContext has y=0 at bottom)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        // Render via CGContext pipeline
        try MermaidRenderer.render(
            source: source,
            in: context,
            bounds: CGRect(origin: .zero, size: size),
            theme: theme
        )

        return try pngData(from: context)
    }

    private func renderFallbackPng(size: CGSize, message: String) -> Data {
        let width = Int(size.width)
        let height = Int(size.height)

        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return Data()
        }

        context.setFillColor(CGColor(red: 1, green: 0.95, blue: 0.95, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))

        // Draw error text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: BMFont.systemFont(ofSize: 14),
            .foregroundColor: BMColor.red
        ]
        let nsStr = NSAttributedString(string: message, attributes: attrs)
        #if os(macOS)
        NSGraphicsContext.saveGraphicsState()
        let nsCtx = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsCtx
        nsStr.draw(at: NSPoint(x: 20, y: 20))
        NSGraphicsContext.restoreGraphicsState()
        #endif

        return (try? pngData(from: context)) ?? Data()
    }

    private func pngData(from context: CGContext) throws -> Data {
        guard let image = context.makeImage() else {
            throw NSError(domain: "VisualReport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to make CGImage"])
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.png.identifier as CFString,
            1, nil
        ) else {
            throw NSError(domain: "VisualReport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG destination"])
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "VisualReport", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG"])
        }
        return data as Data
    }

    // MARK: - HTML Report

    private func generateHtml(results: [(diagram: TestDiagram, pngFile: String, success: Bool, error: String?)]) -> String {
        let successCount = results.filter { $0.success }.count
        let failCount = results.count - successCount

        // Group by category
        var categories: [(name: String, items: [(diagram: TestDiagram, pngFile: String, success: Bool, error: String?)])] = []
        var seen: [String: Int] = [:]
        for r in results {
            if let idx = seen[r.diagram.category] {
                categories[idx].items.append(r)
            } else {
                seen[r.diagram.category] = categories.count
                categories.append((r.diagram.category, [r]))
            }
        }

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>CGContext Rendering Visual Report</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; color: #333; padding: 20px; }
            h1 { margin-bottom: 8px; }
            .summary { margin-bottom: 24px; padding: 16px; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
            .summary .ok { color: #16a34a; font-weight: 600; }
            .summary .fail { color: #dc2626; font-weight: 600; }
            .category { margin-bottom: 32px; }
            .category h2 { margin-bottom: 12px; text-transform: capitalize; border-bottom: 2px solid #e5e5e5; padding-bottom: 4px; }
            .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(520px, 1fr)); gap: 16px; }
            .card { background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
            .card.error { border: 2px solid #fca5a5; }
            .card-header { padding: 10px 14px; border-bottom: 1px solid #e5e5e5; display: flex; justify-content: space-between; align-items: center; }
            .card-header .name { font-weight: 600; font-size: 14px; }
            .card-header .id { font-size: 12px; color: #888; font-family: monospace; }
            .card-header .badge { font-size: 11px; padding: 2px 6px; border-radius: 4px; }
            .badge.ok { background: #dcfce7; color: #16a34a; }
            .badge.fail { background: #fee2e2; color: #dc2626; }
            .card-body { padding: 8px; }
            .card-body img { width: 100%; height: auto; display: block; border-radius: 4px; }
            .source-toggle { font-size: 12px; color: #6366f1; cursor: pointer; margin-top: 6px; display: inline-block; }
            .source-code { display: none; font-family: monospace; font-size: 11px; background: #f5f5f5; padding: 8px; border-radius: 4px; margin-top: 4px; white-space: pre-wrap; word-break: break-all; max-height: 200px; overflow-y: auto; }
            .error-msg { color: #dc2626; font-size: 12px; padding: 4px 0; }
        </style>
        </head>
        <body>
        <h1>CGContext Rendering Visual Report</h1>
        <div class="summary">
            <p>Generated: <strong>\(ISO8601DateFormatter().string(from: Date()))</strong></p>
            <p>Total diagrams: <strong>\(results.count)</strong> &nbsp;|&nbsp;
               <span class="ok">OK: \(successCount)</span> &nbsp;|&nbsp;
               <span class="fail">Failed: \(failCount)</span></p>
        </div>
        """

        for cat in categories {
            html += """
            <div class="category">
            <h2>\(cat.name) (\(cat.items.count))</h2>
            <div class="grid">
            """
            for (i, r) in cat.items.enumerated() {
                let statusClass = r.success ? "ok" : "fail"
                let statusBadge = r.success ? "OK" : "FAIL"
                let cardClass = r.success ? "card" : "card error"
                let uniqueId = "\(r.diagram.category)-\(i)"

                html += """
                <div class="\(cardClass)">
                  <div class="card-header">
                    <div>
                      <span class="name">\(escapeHtml(r.diagram.name))</span>
                      <span class="id">\(r.diagram.id)</span>
                    </div>
                    <span class="badge \(statusClass)">\(statusBadge)</span>
                  </div>
                  <div class="card-body">
                    <img src="\(r.pngFile)" alt="\(escapeHtml(r.diagram.name))" loading="lazy">
                """

                if let err = r.error {
                    html += "    <p class=\"error-msg\">\(escapeHtml(err))</p>\n"
                }

                // Source toggle
                let escaped = escapeHtml(r.diagram.source)
                html += """
                    <span class="source-toggle" onclick="document.getElementById('src-\(uniqueId)').style.display=document.getElementById('src-\(uniqueId)').style.display==='block'?'none':'block'">Show source</span>
                    <div class="source-code" id="src-\(uniqueId)">\(escaped)</div>
                  </div>
                </div>
                """
            }
            html += "</div></div>\n"
        }

        html += "</body></html>"
        return html
    }

    private func escapeHtml(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
