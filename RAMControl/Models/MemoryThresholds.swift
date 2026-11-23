import Foundation

/// Warning and critical are percentages of *available* memory relative to physical RAM.
/// `critical` must be strictly less than `warning`. Both lie in 1...99.
struct MemoryThresholds: Equatable, Sendable {
    var warningPercent: Int
    var criticalPercent: Int

    static let standard = MemoryThresholds(warningPercent: 30, criticalPercent: 15)

    var isValid: Bool {
        Self.isValid(warningPercent: warningPercent, criticalPercent: criticalPercent)
    }

    static func isValid(warningPercent: Int, criticalPercent: Int) -> Bool {
        (1...99).contains(warningPercent)
            && (1...99).contains(criticalPercent)
            && criticalPercent < warningPercent
    }

    /// Clamps each side into 1...99. Returns nil when the clamped pair is still invalid.
    static func sanitized(warningPercent: Int, criticalPercent: Int) -> MemoryThresholds? {
        switch commit(warningPercent: warningPercent, criticalPercent: criticalPercent) {
        case .saved(let thresholds), .savedClamped(let thresholds, _):
            return thresholds
        case .rejected:
            return nil
        }
    }

    static func commit(warningPercent: Int, criticalPercent: Int) -> ThresholdCommit {
        let warning = min(99, max(1, warningPercent))
        let critical = min(99, max(1, criticalPercent))
        let clamped = warning != warningPercent || critical != criticalPercent
        guard critical < warning else {
            return .rejected(
                notice: .criticalMustBeLower,
                warningPercent: warning,
                criticalPercent: critical
            )
        }
        let thresholds = MemoryThresholds(warningPercent: warning, criticalPercent: critical)
        if clamped {
            return .savedClamped(thresholds, notice: .limitedToRange)
        }
        return .saved(thresholds)
    }
}

enum ThresholdNotice: Equatable, Sendable {
    case criticalMustBeLower
    case limitedToRange
}

enum ThresholdCommit: Equatable, Sendable {
    case saved(MemoryThresholds)
    case savedClamped(MemoryThresholds, notice: ThresholdNotice)
    case rejected(notice: ThresholdNotice, warningPercent: Int, criticalPercent: Int)
}
