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

/// Generates a self-contained HTML visual report from the example app's test diagrams.
///
/// Run with: `swift test --filter VisualReportGenerator`
///
/// The report is written to the project root as `visual-report.html`.
/// Images are embedded as base64 data URIs — no separate PNG files needed.
final class VisualReportGenerator: XCTestCase {

    struct DiagramEntry: Codable {
        let id: String
        let category: String
        let name: String
        let source: String
        let options: [String: Bool]?
    }

    struct DiagramsFile: Codable {
        let version: String?
        let description: String?
        let diagrams: [DiagramEntry]
    }

    // MARK: - Test Entry Point

    func testGenerateVisualReport() throws {
        let projectRoot = Self.findProjectRoot()
        let jsonPath = (projectRoot as NSString).appendingPathComponent(
            "Examples/MermaidPlayground/Resources/test-diagrams.json"
        )

        guard FileManager.default.fileExists(atPath: jsonPath) else {
            XCTFail("Missing test-diagrams.json at \(jsonPath)")
            return
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let file = try JSONDecoder().decode(DiagramsFile.self, from: data)

        var results: [(diagram: DiagramEntry, base64Png: String?, success: Bool, error: String?)] = []

        for diagram in file.diagrams {
            print("Rendering \(diagram.id)...")
            do {
                let pngData = try renderDiagramPng(source: diagram.source, theme: .default)
                let base64 = pngData.base64EncodedString()
                results.append((diagram, base64, true, nil))
            } catch {
                results.append((diagram, nil, false, error.localizedDescription))
                fputs("FAIL [\(diagram.id)]: \(error)\n", stderr)
            }
        }

        let htmlPath = (projectRoot as NSString).appendingPathComponent("visual-report.html")
        let html = generateHtml(results: results)
        try html.write(toFile: htmlPath, atomically: true, encoding: .utf8)

        let ok = results.filter(\.success).count
        let fail = results.count - ok
        print("\nVisual report: \(htmlPath)")
        print("Total: \(results.count)  OK: \(ok)  Failed: \(fail)")
        if fail > 0 {
            for r in results where !r.success {
                print("  FAIL: \(r.diagram.id) — \(r.error ?? "unknown")")
            }
        }
    }

    // MARK: - Project Root

    private static func findProjectRoot() -> String {
        // Walk up from this source file to find the directory containing Package.swift
        var dir = (URL(fileURLWithPath: #file).deletingLastPathComponent().path as NSString)
            .deletingLastPathComponent  // Tests/
        dir = (dir as NSString).deletingLastPathComponent  // project root

        if FileManager.default.fileExists(atPath: (dir as NSString).appendingPathComponent("Package.swift")) {
            return dir
        }

        // Fallback: cwd parent (matches `swift test` default working directory)
        return (FileManager.default.currentDirectoryPath as NSString).deletingLastPathComponent
    }

    // MARK: - Rendering

    private func renderDiagramPng(
        source: String,
        theme: DiagramTheme,
        size: CGSize = CGSize(width: 1600, height: 1000)
    ) throws -> Data {
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

        context.setFillColor(theme.background.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Flip to top-left origin (CGContext default is bottom-left)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        try MermaidRenderer.render(
            source: source,
            in: context,
            bounds: CGRect(origin: .zero, size: size),
            theme: theme
        )

        return try pngData(from: context)
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

    // MARK: - HTML Generation

    private func generateHtml(
        results: [(diagram: DiagramEntry, base64Png: String?, success: Bool, error: String?)]
    ) -> String {
        let ok = results.filter(\.success).count
        let fail = results.count - ok

        // Group by category preserving order
        var categories: [(name: String, items: [(diagram: DiagramEntry, base64Png: String?, success: Bool, error: String?)])] = []
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
        <title>Beautiful Mermaid — Visual Report</title>
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; color: #333; padding: 24px; }
        h1 { margin-bottom: 8px; }
        .summary { margin-bottom: 24px; padding: 16px; background: #fff; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
        .summary .ok { color: #16a34a; font-weight: 600; }
        .summary .fail { color: #dc2626; font-weight: 600; }
        .filters { margin-bottom: 16px; display: flex; gap: 8px; flex-wrap: wrap; }
        .filters button { padding: 4px 12px; border: 1px solid #d4d4d4; border-radius: 6px; background: #fff; cursor: pointer; font-size: 13px; }
        .filters button.active { background: #333; color: #fff; border-color: #333; }
        .category { margin-bottom: 32px; }
        .category h2 { margin-bottom: 12px; text-transform: capitalize; border-bottom: 2px solid #e5e5e5; padding-bottom: 4px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(520px, 1fr)); gap: 16px; }
        .card { background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
        .card.error { border: 2px solid #fca5a5; }
        .card-header { padding: 10px 14px; border-bottom: 1px solid #e5e5e5; display: flex; justify-content: space-between; align-items: center; }
        .card-header .name { font-weight: 600; font-size: 14px; }
        .card-header .id { font-size: 12px; color: #888; font-family: monospace; margin-left: 6px; }
        .badge { font-size: 11px; padding: 2px 6px; border-radius: 4px; }
        .badge.ok { background: #dcfce7; color: #16a34a; }
        .badge.fail { background: #fee2e2; color: #dc2626; }
        .card-body { padding: 8px; }
        .card-body img { width: 100%; height: auto; display: block; border-radius: 4px; background: #fafafa; }
        .error-msg { color: #dc2626; font-size: 12px; padding: 4px 0; }
        .source-toggle { font-size: 12px; color: #6366f1; cursor: pointer; margin-top: 6px; display: inline-block; user-select: none; }
        .source-code { display: none; font-family: 'SF Mono', Menlo, monospace; font-size: 11px; background: #f5f5f5; padding: 8px; border-radius: 4px; margin-top: 4px; white-space: pre-wrap; word-break: break-all; max-height: 200px; overflow-y: auto; }
        </style>
        </head>
        <body>
        <h1>Beautiful Mermaid — Visual Report</h1>
        <div class="summary">
            <p>Generated: <strong>\(_timestamp())</strong></p>
            <p>Total: <strong>\(results.count)</strong> &nbsp;|&nbsp;
               <span class="ok">OK: \(ok)</span> &nbsp;|&nbsp;
               <span class="fail">Failed: \(fail)</span></p>
        </div>
        <div class="filters" id="filters"></div>
        """

        for cat in categories {
            html += """
            <div class="category" data-category="\(escapeHtml(cat.name))">
            <h2>\(escapeHtml(cat.name)) (\(cat.items.count))</h2>
            <div class="grid">
            """

            for (i, r) in cat.items.enumerated() {
                let statusClass = r.success ? "ok" : "fail"
                let statusBadge = r.success ? "OK" : "FAIL"
                let cardClass = r.success ? "card" : "card error"
                let uid = "\(r.diagram.category)-\(i)"

                html += """
                <div class="\(cardClass)">
                  <div class="card-header">
                    <div>
                      <span class="name">\(escapeHtml(r.diagram.name))</span>
                      <span class="id">\(escapeHtml(r.diagram.id))</span>
                    </div>
                    <span class="badge \(statusClass)">\(statusBadge)</span>
                  </div>
                  <div class="card-body">
                """

                if let b64 = r.base64Png {
                    html += "    <img src=\"data:image/png;base64,\(b64)\" alt=\"\(escapeHtml(r.diagram.name))\" loading=\"lazy\">\n"
                }

                if let err = r.error {
                    html += "    <p class=\"error-msg\">\(escapeHtml(err))</p>\n"
                }

                let escaped = escapeHtml(r.diagram.source)
                html += """
                    <span class="source-toggle" onclick="var e=document.getElementById('src-\(uid)');e.style.display=e.style.display==='block'?'none':'block'">Show source</span>
                    <div class="source-code" id="src-\(uid)">\(escaped)</div>
                  </div>
                </div>
                """
            }
            html += "</div></div>\n"
        }

        // Category filter script
        html += """
        <script>
        (function() {
            var cats = document.querySelectorAll('.category');
            var names = [];
            cats.forEach(function(c) { names.push(c.dataset.category); });
            var unique = names.filter(function(v, i, a) { return a.indexOf(v) === i; });
            var box = document.getElementById('filters');
            var allBtn = document.createElement('button');
            allBtn.textContent = 'All';
            allBtn.className = 'active';
            allBtn.onclick = function() {
                cats.forEach(function(c) { c.style.display = ''; });
                box.querySelectorAll('button').forEach(function(b) { b.className = ''; });
                allBtn.className = 'active';
            };
            box.appendChild(allBtn);
            unique.forEach(function(name) {
                var btn = document.createElement('button');
                btn.textContent = name;
                btn.onclick = function() {
                    cats.forEach(function(c) { c.style.display = c.dataset.category === name ? '' : 'none'; });
                    box.querySelectorAll('button').forEach(function(b) { b.className = ''; });
                    btn.className = 'active';
                };
                box.appendChild(btn);
            });
        })();
        </script>
        </body></html>
        """

        return html
    }

    private func _timestamp() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }

    private func escapeHtml(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
