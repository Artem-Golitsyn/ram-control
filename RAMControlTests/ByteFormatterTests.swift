import XCTest
@testable import RAMControl

final class ByteFormatterTests: XCTestCase {
    func testDecimalGigabytes() {
        XCTAssertEqual(ByteFormatter.string(bytes: 1_000_000_000, unit: .gb), "1.0 GB")
        XCTAssertEqual(ByteFormatter.string(bytes: 1_500_000_000, unit: .gb), "1.5 GB")
        XCTAssertEqual(ByteFormatter.string(bytes: 1_050_000_000, unit: .gb), "1.1 GB")
        XCTAssertEqual(ByteFormatter.string(bytes: 1_040_000_000, unit: .gb), "1.0 GB")
        XCTAssertEqual(ByteFormatter.string(bytes: 10_000_000_000, unit: .gb), "10.0 GB")
        XCTAssertEqual(ByteFormatter.string(bytes: 1_073_741_824, unit: .gb), "1.1 GB")
    }

    func testBinaryGibibytes() {
        XCTAssertEqual(ByteFormatter.string(bytes: 1_073_741_824, unit: .gib), "1.0 GiB")
        XCTAssertEqual(ByteFormatter.string(bytes: 1_610_612_736, unit: .gib), "1.5 GiB")
        XCTAssertEqual(ByteFormatter.string(bytes: 1_000_000_000, unit: .gib), "0.9 GiB")
    }

    func testZeroAndSmallValues() {
        XCTAssertEqual(ByteFormatter.string(bytes: 0, unit: .gb), "0.0 GB")
        XCTAssertEqual(ByteFormatter.string(bytes: 0, unit: .gib), "0.0 GiB")
        XCTAssertEqual(ByteFormatter.string(bytes: 1, unit: .gb), "0.0 GB")
        XCTAssertEqual(ByteFormatter.string(bytes: 49_999_999, unit: .gb), "0.0 GB")
        XCTAssertEqual(ByteFormatter.string(bytes: 50_000_000, unit: .gb), "0.1 GB")
    }

    func testDecimalSeparatorIsADot() {
        let text = ByteFormatter.string(bytes: 18_400_000_000, unit: .gb)
        XCTAssertEqual(text, "18.4 GB")
        XCTAssertFalse(text.contains(","))
    }

    func testMaximumUInt64DoesNotCrash() {
        XCTAssertEqual(ByteFormatter.string(bytes: .max, unit: .gb), "18446744073.7 GB")
    }

    func testStoredUnitAndIntervalFallBack() {
        XCTAssertEqual(MemoryUnit.fromStored("GB"), .gb)
        XCTAssertEqual(MemoryUnit.fromStored("GiB"), .gib)
        XCTAssertEqual(MemoryUnit.fromStored(nil), .gb)
        XCTAssertEqual(MemoryUnit.fromStored("MB"), .gb)
        XCTAssertEqual(RefreshInterval.fromStored(1), .one)
        XCTAssertEqual(RefreshInterval.fromStored(2), .two)
        XCTAssertEqual(RefreshInterval.fromStored(5), .five)
        XCTAssertEqual(RefreshInterval.fromStored(10), .ten)
        XCTAssertEqual(RefreshInterval.fromStored(200), .twoTenths)
        XCTAssertEqual(RefreshInterval.fromStored(500), .half)
        XCTAssertEqual(RefreshInterval.fromStored(1_000), .one)
        XCTAssertEqual(RefreshInterval.fromStored(2_000), .two)
        XCTAssertEqual(RefreshInterval.fromStored(5_000), .five)
        XCTAssertEqual(RefreshInterval.fromStored(10_000), .ten)
        XCTAssertEqual(RefreshInterval.fromStored(7), .one)
        XCTAssertEqual(RefreshInterval.fromStored(0), .one)
        XCTAssertEqual(RefreshInterval.twoTenths.seconds, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(RefreshInterval.half.seconds, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(RefreshInterval.one.seconds, 1, accuracy: 0.000_001)
        XCTAssertEqual(RefreshInterval.twoTenths.label(language: .english), "0.2 seconds")
        XCTAssertEqual(RefreshInterval.half.label(language: .english), "0.5 seconds")
        XCTAssertEqual(RefreshInterval.half.label(language: .russian), "0.5 секунды")
        XCTAssertEqual(RefreshInterval.twoTenths.label(language: .russian), "0.2 секунды")
        XCTAssertEqual(RefreshInterval.one.label(language: .english), "1 second")
        XCTAssertEqual(RefreshInterval.two.label(language: .english), "2 seconds")
        XCTAssertEqual(RefreshInterval.one.label(language: .russian), "1 секунда")
        XCTAssertEqual(RefreshInterval.five.label(language: .russian), "5 секунд")
        XCTAssertEqual(AppLanguage.fromStored(nil), .english)
        XCTAssertEqual(AppLanguage.fromStored("ru"), .russian)
        XCTAssertEqual(AppLanguage.fromStored("de"), .english)
        XCTAssertEqual(L10n.text(.memory, .english), "Memory")
        XCTAssertEqual(L10n.text(.memory, .russian), "Память")
        XCTAssertEqual(L10n.authorCredit, "Голицын Артем (2026)")
    }
}
