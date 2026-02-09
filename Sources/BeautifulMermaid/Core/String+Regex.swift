// SPDX-License-Identifier: MIT
// BeautifulMermaid - String Regex Extensions

import Foundation

extension String {
    /// Match a regex pattern and return captured groups (excluding full match).
    /// Returns nil if no match, or array of strings for each capture group.
    /// Unmatched optional groups return empty string.
    ///
    /// - Parameter pattern: The regex pattern to match
    /// - Returns: Array of captured group strings, or nil if no match
    func match(pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range) else {
            return nil
        }

        var results: [String] = []
        for i in 1..<match.numberOfRanges {
            if let captureRange = Range(match.range(at: i), in: self) {
                results.append(String(self[captureRange]))
            } else {
                results.append("")
            }
        }

        return results.isEmpty ? nil : results
    }

    /// Match a regex pattern and return all captured groups including the full match at index 0.
    /// Returns nil if no match, or array of strings for each group.
    /// Unmatched optional groups return empty string.
    ///
    /// - Parameter pattern: The regex pattern to match
    /// - Returns: Array of captured group strings (index 0 is full match), or nil if no match
    func matchWithCaptures(pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range) else {
            return nil
        }

        var results: [String] = []
        for i in 0..<match.numberOfRanges {
            if let captureRange = Range(match.range(at: i), in: self) {
                results.append(String(self[captureRange]))
            } else {
                results.append("")
            }
        }

        return results
    }

    /// Match a regex pattern and return all groups including full match.
    /// Returns nil if no match, or array of optional strings for each group.
    /// Unmatched optional groups return nil (not empty string).
    ///
    /// - Parameter pattern: The regex pattern to match
    /// - Returns: Array of optional captured group strings (index 0 is full match), or nil if no match
    func matchWithOptionalGroups(pattern: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        guard let result = regex.firstMatch(in: self, options: [], range: range) else {
            return nil
        }

        var groups: [String?] = []
        for i in 0..<result.numberOfRanges {
            if let range = Range(result.range(at: i), in: self) {
                groups.append(String(self[range]))
            } else {
                groups.append(nil)
            }
        }
        return groups
    }
}
