import Foundation

/// Decimal GB (10^9) or binary GiB (2^30), always one digit after the decimal point.
enum MemoryUnit: String, CaseIterable, Identifiable, Sendable {
    case gb = "GB"
    case gib = "GiB"

    var id: String { rawValue }

    var symbol: String { rawValue }

    /// Exact divisor for this unit. GB is decimal, GiB is binary.
    var divisor: UInt64 {
        switch self {
        case .gb:
            return 1_000_000_000
        case .gib:
            return 1_073_741_824
        }
    }

    static func fromStored(_ raw: String?) -> MemoryUnit {
        guard let raw, let unit = MemoryUnit(rawValue: raw) else {
            return .gb
        }
        return unit
    }
}

/// Polling period. The stored raw value is milliseconds.
/// Whole seconds 1, 2, 5 and 10 are still accepted: that is the 1.0 on-disk format.
enum RefreshInterval: Int, CaseIterable, Identifiable, Sendable {
    case twoTenths = 200
    case half = 500
    case one = 1_000
    case two = 2_000
    case five = 5_000
    case ten = 10_000

    var id: Int { rawValue }

    var seconds: TimeInterval { TimeInterval(rawValue) / 1_000 }

    func label(language: AppLanguage) -> String {
        L10n.intervalLabel(milliseconds: rawValue, language: language)
    }

    static func fromStored(_ raw: Int) -> RefreshInterval {
        if let interval = RefreshInterval(rawValue: raw) {
            return interval
        }
        switch raw {
        case 1:
            return .one
        case 2:
            return .two
        case 5:
            return .five
        case 10:
            return .ten
        default:
            return .one
        }
    }
}

enum ByteFormatter {
    /// Formats `bytes` as `18.4 GB` or `18.4 GiB`.
    /// Rounding is half away from zero at the first decimal place, using integer arithmetic.
    static func string(bytes: UInt64, unit: MemoryUnit) -> String {
        let tenths = roundedTenths(bytes: bytes, divisor: unit.divisor)
        let whole = tenths / 10
        let fraction = tenths % 10
        return "\(whole).\(fraction) \(unit.symbol)"
    }

    /// `(bytes / divisor)` rounded to one decimal, returned as that decimal times 10.
    static func roundedTenths(bytes: UInt64, divisor: UInt64) -> UInt64 {
        guard divisor > 0 else { return 0 }
        let (scaled, overflow) = bytes.multipliedReportingOverflow(by: 10)
        if !overflow {
            return (scaled + divisor / 2) / divisor
        }

        let whole = bytes / divisor
        let remainder = bytes % divisor
        let (remainderScaled, remainderOverflow) = remainder.multipliedReportingOverflow(by: 10)
        let extra: UInt64
        if remainderOverflow {
            extra = 10
        } else {
            extra = (remainderScaled + divisor / 2) / divisor
        }
        let (base, baseOverflow) = whole.multipliedReportingOverflow(by: 10)
        if baseOverflow {
            return UInt64.max
        }
        let (sum, sumOverflow) = base.addingReportingOverflow(extra)
        return sumOverflow ? UInt64.max : sum
    }
}
