import Foundation

/// One process and the physical memory charged to it. Not stored in UserDefaults.
struct ProcessMemory: Equatable, Sendable, Identifiable {
    var pid: Int32
    var name: String
    var bytes: UInt64

    var id: Int32 { pid }
}

/// Picks the processes shown on the panel. The live machine is not the oracle: tests feed this list.
enum ProcessMemoryRanking {
    static let displayedCount = 8

    /// Highest footprint first. Equal footprints keep the smaller pid first. Zero bytes are dropped.
    static func top(_ processes: [ProcessMemory], limit: Int = displayedCount) -> [ProcessMemory] {
        guard limit > 0 else { return [] }
        return processes
            .filter { $0.pid >= 0 && $0.bytes > 0 }
            .sorted { lhs, rhs in
                if lhs.bytes != rhs.bytes {
                    return lhs.bytes > rhs.bytes
                }
                if lhs.pid != rhs.pid {
                    return lhs.pid < rhs.pid
                }
                return lhs.name < rhs.name
            }
            .prefix(limit)
            .map { $0 }
    }
}

enum ProcessMemoryName {
    /// Shortens a reverse-DNS executable such as `com.apple.WebKit.WebContent` to `WebContent`.
    /// Names with a space stay whole, so `Firefox GPU Helper` is unchanged.
    static func display(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return trimmed }
        let parts = trimmed.split(separator: ".")
        guard parts.count >= 3, let last = parts.last, !last.isEmpty else { return trimmed }
        return String(last)
    }
}
