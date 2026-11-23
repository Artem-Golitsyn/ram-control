import Foundation

/// Pure conversion from Mach page counters into byte statistics.
///
/// Confirmed in the macOS SDK `mach/vm_statistics.h` (`struct vm_statistics64`):
/// - `speculative_count` is already included in `free_count` ("speculative pages are already
///   accounted for in free_count"). It is never added on top of free.
/// - `purgeable_count` is "# of pages purgeable". It is not a disjoint pool: those pages already
///   sit in the anonymous/active/inactive/wired sets. Adding `free + inactive + purgeable`
///   double-counts and can report Available greater than Total.
/// - `internal_page_count` is "# of pages that are anonymous" and is present in this SDK.
/// - `compressor_page_count` is "# of pages used by the compressed pager to hold all the
///   compressed data". That footprint is the Compressed figure. It is not
///   `total_uncompressed_pages_in_compressor`.
/// - There is no swap *byte* field on `vm_statistics64`. This SDK does contain
///   `swapped_count` (compressor pages currently stored in swap) and `swap_count` (pages
///   populated in the swap file). Those are page counters. Swap Used bytes come from
///   `xsw_usage.xsu_used` and are passed in already converted.
///
/// Activity Monitor on macOS 14+ treats memory in use as:
///   App (anonymous, excluding purgeable) + Wired + Compressed footprint.
/// Available is whatever physical RAM that sum does not occupy.
enum MemoryCalculator {
    /// Page count times page size. `nil` when `pageSize` is 0. Overflow saturates at `UInt64.max`.
    static func pagesToBytes(_ pages: UInt64, pageSize: UInt64) -> UInt64? {
        guard pageSize != 0 else { return nil }
        let (value, overflow) = pages.multipliedReportingOverflow(by: pageSize)
        return overflow ? UInt64.max : value
    }

    static func makeStats(from input: MemorySampleInput) -> MemoryStats? {
        guard input.pageSize != 0 else { return nil }

        // These counters are intentionally not terms of Used. `speculativePages` is a subset of
        // `freePages`. `externalPages` is file cache the system can reclaim. Adding any of them
        // would disagree with Activity Monitor.
        _ = (input.freePages, input.speculativePages, input.externalPages)

        guard
            let activeBytes = pagesToBytes(input.activePages, pageSize: input.pageSize),
            let inactiveBytes = pagesToBytes(input.inactivePages, pageSize: input.pageSize),
            let wiredBytes = pagesToBytes(input.wiredPages, pageSize: input.pageSize),
            let compressedBytes = pagesToBytes(input.compressorPages, pageSize: input.pageSize),
            let purgeableBytes = pagesToBytes(input.purgeablePages, pageSize: input.pageSize)
        else {
            return nil
        }

        let appPages = saturatingSubtract(input.internalPages, input.purgeablePages)
        guard let appMemoryBytes = pagesToBytes(appPages, pageSize: input.pageSize) else {
            return nil
        }

        let occupied = saturatingAdd(appMemoryBytes, saturatingAdd(wiredBytes, compressedBytes))
        let usedBytes = min(input.totalBytes, occupied)
        let availableBytes = saturatingSubtract(input.totalBytes, usedBytes)

        return MemoryStats(
            totalBytes: input.totalBytes,
            availableBytes: availableBytes,
            usedBytes: usedBytes,
            appMemoryBytes: appMemoryBytes,
            activeBytes: activeBytes,
            inactiveBytes: inactiveBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes,
            purgeableBytes: purgeableBytes,
            swapUsedBytes: input.swapUsedBytes
        )
    }

    /// `available / total > warning` → normal, `> critical` → warning, otherwise critical.
    /// `total == 0` does not divide. An invalid threshold pair does not invent a band.
    static func pressureState(
        availableBytes: UInt64,
        totalBytes: UInt64,
        thresholds: MemoryThresholds
    ) -> MemoryPressureState {
        guard totalBytes > 0, thresholds.isValid else { return .unavailable }
        if ratioGreaterThan(availableBytes, totalBytes, percent: thresholds.warningPercent) {
            return .normal
        }
        if ratioGreaterThan(availableBytes, totalBytes, percent: thresholds.criticalPercent) {
            return .warning
        }
        return .critical
    }

    /// `numerator / denominator > percent / 100`, without dividing by zero.
    static func ratioGreaterThan(_ numerator: UInt64, _ denominator: UInt64, percent: Int) -> Bool {
        guard denominator > 0, percent >= 0 else { return false }
        let percent = UInt64(percent)
        let (left, leftOverflow) = numerator.multipliedReportingOverflow(by: 100)
        let (right, rightOverflow) = denominator.multipliedReportingOverflow(by: percent)
        if !leftOverflow && !rightOverflow {
            return left > right
        }
        return (Double(numerator) / Double(denominator)) > (Double(percent) / 100.0)
    }

    static func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt64.max : value
    }

    static func saturatingSubtract(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.subtractingReportingOverflow(rhs)
        return overflow ? 0 : value
    }
}
