//
//  VersionChange.swift
//  yatagarasu
//

import Foundation

/// How big a jump an update is, judged from its version numbers.
enum VersionChange: Hashable {
    case major
    case minor
    case patch
    /// Versions that don't parse as dotted numbers (dates, hashes, "latest").
    case unknown

    /// Compares the leading numeric components of two version strings.
    /// `"15.4"` → `"16.0"` is major, `"22.8"` → `"22.9"` minor, `"1.24.4"` → `"1.24.5"` patch.
    static func between(_ current: String?, and next: String?) -> VersionChange {
        guard
            let current = components(of: current), !current.isEmpty,
            let next = components(of: next), !next.isEmpty
        else {
            return .unknown
        }

        for (index, pair) in zip(current, next).enumerated() where pair.0 != pair.1 {
            switch index {
            case 0: return .major
            case 1: return .minor
            default: return .patch
            }
        }

        return next.count > current.count ? .patch : .unknown
    }

    /// `"1.24.5_1"` → `[1, 24, 5]`; stops at the first non-numeric segment.
    private static func components(of version: String?) -> [Int]? {
        guard let version else { return nil }
        let core = version.split(whereSeparator: { !$0.isNumber && $0 != "." }).first ?? ""
        var numbers: [Int] = []
        for segment in core.split(separator: ".") {
            guard let number = Int(segment) else { break }
            numbers.append(number)
        }
        return numbers
    }
}
