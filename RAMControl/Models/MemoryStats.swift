import Foundation

/// Page counters copied out of `vm_statistics64` plus the two values that structure does not
/// express as a byte quantity: physical RAM (`hw.memsize`) and swap bytes (`xsw_usage.xsu_used`).
struct MemorySampleInput: Equatable, Sendable {
    var pageSize: UInt64
    var totalBytes: UInt64
    var swapUsedBytes: UInt64
    var freePages: UInt64
    var activePages: UInt64
    var inactivePages: UInt64
    var wiredPages: UInt64
    var purgeablePages: UInt64
    var speculativePages: UInt64
    var compressorPages: UInt64
    var internalPages: UInt64
    var externalPages: UInt64
}

struct MemoryStats: Equatable, Sendable {
    var totalBytes: UInt64
    var availableBytes: UInt64
    var usedBytes: UInt64
    /// Anonymous memory that is not purgeable. Intermediate of the Used formula, not a menu row.
    var appMemoryBytes: UInt64
    var activeBytes: UInt64
    var inactiveBytes: UInt64
    var wiredBytes: UInt64
    var compressedBytes: UInt64
    var purgeableBytes: UInt64
    var swapUsedBytes: UInt64
}

enum MemoryPressureState: Equatable, Sendable {
    case normal
    case warning
    case critical
    case unavailable

}
