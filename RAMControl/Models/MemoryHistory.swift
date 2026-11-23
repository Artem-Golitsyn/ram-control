import Foundation

/// How far back the memory graph looks. Samples themselves are kept for the longest window.
enum HistoryWindow: Int, CaseIterable, Identifiable, Sendable {
    case one = 1
    case three = 3
    case five = 5
    case ten = 10

    var id: Int { rawValue }

    var seconds: TimeInterval { TimeInterval(rawValue) * 60 }

    func label(language: AppLanguage) -> String {
        L10n.historyWindowLabel(minutes: rawValue, language: language)
    }

    static func fromStored(_ minutes: Int) -> HistoryWindow {
        HistoryWindow(rawValue: minutes) ?? .five
    }
}

/// One successful memory sample. Not written to UserDefaults: the graph is session-only.
struct MemoryHistorySample: Equatable, Sendable {
    var date: Date
    var usedBytes: UInt64
    var totalBytes: UInt64
    var availableBytes: UInt64
    /// Color mix captured when the sample was stored. Later threshold edits do not repaint it.
    var blend: MemoryGraphBlend
}

/// How much red, yellow, and gray to mix for one point on the graph.
/// Weights are 0...1 and sum to 1. Red is critical, yellow is the middle of the warning band, gray is calm.
struct MemoryGraphBlend: Equatable, Sendable {
    var red: Double
    var yellow: Double
    var gray: Double
}

struct MemoryHistory: Equatable, Sendable {
    /// Matches the longest graph window. Older samples are dropped.
    static let retention: TimeInterval = 10 * 60
    /// A longer pause is a gap, not a line invented between two samples.
    static let maxConnectionGap: TimeInterval = 20
    /// Safety cap if the clock jumps and the time trim cannot shrink the buffer.
    static let maxSamples = 4_000

    private(set) var samples: [MemoryHistorySample] = []

    mutating func append(_ sample: MemoryHistorySample, now: Date) {
        samples.append(sample)
        trim(now: now)
    }

    mutating func trim(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.retention)
        let future = now.addingTimeInterval(2)
        samples.removeAll { $0.date < cutoff || $0.date > future }
        guard samples.count > Self.maxSamples else { return }
        samples.sort { $0.date < $1.date }
        samples.removeFirst(samples.count - Self.maxSamples)
    }

    /// Samples inside the window, oldest first. Values are copied as stored: nothing is rebinned.
    /// The caller draws the first sample on the left and the last sample on the right.
    static func visibleSamples(
        _ samples: [MemoryHistorySample],
        window: TimeInterval,
        now: Date
    ) -> [MemoryHistorySample] {
        guard window > 0 else { return [] }
        return samples
            .filter { sample in
                let age = now.timeIntervalSince(sample.date)
                return age >= 0 && age <= window
            }
            .sorted { $0.date < $1.date }
    }

    /// Splits a time-sorted series where a pause is longer than `maxGap`.
    static func runs(
        _ samples: [MemoryHistorySample],
        maxGap: TimeInterval = maxConnectionGap
    ) -> [[MemoryHistorySample]] {
        guard let first = samples.first else { return [] }
        var result: [[MemoryHistorySample]] = [[first]]
        for sample in samples.dropFirst() {
            let previous = result[result.count - 1].last?.date ?? sample.date
            if sample.date.timeIntervalSince(previous) > maxGap {
                result.append([sample])
            } else {
                result[result.count - 1].append(sample)
            }
        }
        return result
    }

    /// Five ages from the newest edge toward the start of the window: window/5, 2window/5, …, window.
    static func verticalTickAges(window: TimeInterval, count: Int = 5) -> [TimeInterval] {
        guard window > 0, count > 0 else { return [] }
        let step = window / Double(count)
        return (1...count).map { Double($0) * step }
    }

    /// 1 is the right edge (now). 0 is the left edge (start of the window).
    static func horizontalPosition(age: TimeInterval, window: TimeInterval) -> Double? {
        guard window > 0, age >= 0, age <= window else { return nil }
        return 1 - (age / window)
    }

    /// 1 is the top (maximum used in the visible series). 0 is the bottom (minimum).
    /// A flat series sits in the middle. A stored sample is not edited here.
    static func verticalPosition(used: Double, minimum: Double, maximum: Double) -> Double {
        guard used.isFinite, minimum.isFinite, maximum.isFinite, maximum > minimum else {
            return 0.5
        }
        let span = (used - minimum) / (maximum - minimum)
        return min(1, max(0, span))
    }
}

enum MemoryGraphColor {
    /// Smooth red → yellow → gray between the critical and warning ratios.
    /// At or below critical the blend is red. At or above warning it is gray. The midpoint is yellow.
    static func blend(
        availableBytes: UInt64,
        totalBytes: UInt64,
        thresholds: MemoryThresholds
    ) -> MemoryGraphBlend {
        guard totalBytes > 0, thresholds.isValid else {
            return MemoryGraphBlend(red: 0, yellow: 0, gray: 1)
        }
        let ratio = min(1, max(0, Double(availableBytes) / Double(totalBytes)))
        let critical = Double(thresholds.criticalPercent) / 100
        let warning = Double(thresholds.warningPercent) / 100
        guard warning > critical else {
            return MemoryGraphBlend(red: 0, yellow: 0, gray: 1)
        }
        if ratio <= critical {
            return MemoryGraphBlend(red: 1, yellow: 0, gray: 0)
        }
        if ratio >= warning {
            return MemoryGraphBlend(red: 0, yellow: 0, gray: 1)
        }
        let mid = (critical + warning) / 2
        if ratio <= mid {
            let span = mid - critical
            let amount = span > 0 ? smoothstep((ratio - critical) / span) : 1
            return MemoryGraphBlend(red: 1 - amount, yellow: amount, gray: 0)
        }
        let span = warning - mid
        let amount = span > 0 ? smoothstep((ratio - mid) / span) : 1
        return MemoryGraphBlend(red: 0, yellow: 1 - amount, gray: amount)
    }

    private static func smoothstep(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
}
