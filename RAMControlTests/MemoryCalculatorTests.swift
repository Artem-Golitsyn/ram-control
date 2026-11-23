import XCTest
@testable import RAMControl

final class MemoryCalculatorTests: XCTestCase {
    func testPagesToBytesAppleSiliconAndIntelPageSizes() {
        XCTAssertEqual(MemoryCalculator.pagesToBytes(2, pageSize: 16_384), 32_768)
        XCTAssertEqual(MemoryCalculator.pagesToBytes(3, pageSize: 4_096), 12_288)
        XCTAssertEqual(MemoryCalculator.pagesToBytes(0, pageSize: 16_384), 0)
        XCTAssertEqual(MemoryCalculator.pagesToBytes(1, pageSize: 16_384), 16_384)
    }

    func testPagesToBytesRejectsZeroPageSizeAndSaturatesOverflow() {
        XCTAssertNil(MemoryCalculator.pagesToBytes(10, pageSize: 0))
        XCTAssertNil(MemoryCalculator.pagesToBytes(0, pageSize: 0))
        XCTAssertEqual(MemoryCalculator.pagesToBytes(UInt64.max, pageSize: 2), UInt64.max)
        XCTAssertEqual(MemoryCalculator.pagesToBytes(UInt64.max, pageSize: UInt64.max), UInt64.max)
        XCTAssertEqual(MemoryCalculator.pagesToBytes(1, pageSize: UInt64.max), UInt64.max)
        XCTAssertEqual(MemoryCalculator.pagesToBytes(0, pageSize: UInt64.max), 0)
    }

    func testMakeStatsRejectsZeroPageSize() {
        var input = sample()
        input.pageSize = 0
        input.totalBytes = 16_384
        XCTAssertNil(MemoryCalculator.makeStats(from: input))
    }

    func testAvailableMatchesActivityMonitorFootprint() throws {
        let stats = try XCTUnwrap(MemoryCalculator.makeStats(from: sample(
            pageSize: 16_384,
            totalPages: 1_000,
            swapBytes: 123_456_789,
            free: 80,
            active: 200,
            inactive: 300,
            wired: 10,
            purgeable: 25,
            speculative: 40,
            compressor: 5,
            internalPages: 100,
            externalPages: 400
        )))

        let page: UInt64 = 16_384
        let appPages: UInt64 = 100 - 25
        XCTAssertEqual(stats.appMemoryBytes, appPages * page)
        XCTAssertEqual(stats.wiredBytes, 10 * page)
        XCTAssertEqual(stats.compressedBytes, 5 * page)
        let usedPages = appPages + 10 + 5
        XCTAssertEqual(stats.usedBytes, usedPages * page)
        XCTAssertEqual(stats.availableBytes, (1_000 - usedPages) * page)
        XCTAssertEqual(stats.usedBytes, stats.totalBytes - stats.availableBytes)
        XCTAssertLessThanOrEqual(stats.availableBytes, stats.totalBytes)

        XCTAssertEqual(stats.activeBytes, 200 * page)
        XCTAssertEqual(stats.inactiveBytes, 300 * page)
        XCTAssertEqual(stats.purgeableBytes, 25 * page)
        XCTAssertEqual(stats.swapUsedBytes, 123_456_789)
    }

    func testSameFootprintOn4KiBPages() throws {
        let stats = try XCTUnwrap(MemoryCalculator.makeStats(from: sample(
            pageSize: 4_096,
            totalPages: 1_000,
            wired: 10,
            purgeable: 25,
            compressor: 5,
            internalPages: 100
        )))
        XCTAssertEqual(stats.appMemoryBytes, 75 * 4_096)
        XCTAssertEqual(stats.usedBytes, 90 * 4_096)
        XCTAssertEqual(stats.availableBytes, 910 * 4_096)
        XCTAssertEqual(stats.usedBytes, stats.totalBytes - stats.availableBytes)
    }

    func testPurgeableGreaterThanInternalClampsAppMemoryToZero() throws {
        let stats = try XCTUnwrap(MemoryCalculator.makeStats(from: sample(
            totalPages: 100,
            wired: 4,
            purgeable: 40,
            compressor: 1,
            internalPages: 10
        )))
        XCTAssertEqual(stats.appMemoryBytes, 0)
        XCTAssertEqual(stats.usedBytes, 5 * 16_384)
        XCTAssertEqual(stats.availableBytes, 95 * 16_384)
        XCTAssertEqual(stats.purgeableBytes, 40 * 16_384)
    }

    func testAvailableDoesNotExceedTotalWhenFootprintOverflows() throws {
        let stats = try XCTUnwrap(MemoryCalculator.makeStats(from: sample(
            pageSize: UInt64.max,
            totalPages: 0,
            wired: UInt64.max,
            compressor: UInt64.max,
            internalPages: UInt64.max
        )))
        XCTAssertEqual(stats.totalBytes, 0)
        XCTAssertEqual(stats.availableBytes, 0)
        XCTAssertEqual(stats.usedBytes, 0)

        let clamped = try XCTUnwrap(MemoryCalculator.makeStats(from: MemorySampleInput(
            pageSize: 4_096,
            totalBytes: 1_000,
            swapUsedBytes: 50,
            freePages: 0,
            activePages: 0,
            inactivePages: 0,
            wiredPages: UInt64.max / 2,
            purgeablePages: 0,
            speculativePages: 0,
            compressorPages: UInt64.max / 2,
            internalPages: UInt64.max / 2,
            externalPages: 0
        )))
        XCTAssertEqual(clamped.totalBytes, 1_000)
        XCTAssertEqual(clamped.usedBytes, 1_000)
        XCTAssertEqual(clamped.availableBytes, 0)
        XCTAssertEqual(clamped.swapUsedBytes, 50)
        XCTAssertEqual(clamped.usedBytes, clamped.totalBytes - clamped.availableBytes)
    }

    func testSpeculativeFreeAndExternalDoNotChangeAvailable() throws {
        let base = sample(
            totalPages: 500,
            free: 20,
            active: 10,
            inactive: 30,
            wired: 8,
            purgeable: 4,
            speculative: 0,
            compressor: 2,
            internalPages: 40,
            externalPages: 0
        )
        let inflated = sample(
            totalPages: 500,
            free: 400,
            active: 10,
            inactive: 30,
            wired: 8,
            purgeable: 4,
            speculative: 350,
            compressor: 2,
            internalPages: 40,
            externalPages: 9_000
        )
        let left = try XCTUnwrap(MemoryCalculator.makeStats(from: base))
        let right = try XCTUnwrap(MemoryCalculator.makeStats(from: inflated))
        XCTAssertEqual(left.availableBytes, right.availableBytes)
        XCTAssertEqual(left.usedBytes, right.usedBytes)
        XCTAssertLessThanOrEqual(left.availableBytes, left.totalBytes)
        XCTAssertEqual(left.activeBytes, right.activeBytes)
        XCTAssertNotEqual(base.freePages, inflated.freePages)
        XCTAssertNotEqual(base.speculativePages, inflated.speculativePages)
        XCTAssertNotEqual(base.externalPages, inflated.externalPages)
    }

    func testNaiveSumWouldExceedTotalButFootprintDoesNot() throws {
        let input = sample(
            totalPages: 100,
            free: 80,
            inactive: 40,
            wired: 10,
            purgeable: 50,
            speculative: 30,
            compressor: 5,
            internalPages: 20
        )
        let stats = try XCTUnwrap(MemoryCalculator.makeStats(from: input))
        let naive = (input.freePages + input.inactivePages + input.purgeablePages) * input.pageSize
        XCTAssertGreaterThan(naive, stats.totalBytes)
        XCTAssertEqual(stats.appMemoryBytes, 0)
        XCTAssertEqual(stats.usedBytes, 15 * input.pageSize)
        XCTAssertEqual(stats.availableBytes, 85 * input.pageSize)
        XCTAssertEqual(stats.usedBytes + stats.availableBytes, stats.totalBytes)
    }

    func testDefaultPressureBoundaries() {
        let thresholds = MemoryThresholds.standard
        XCTAssertEqual(state(available: 3_001, total: 10_000, thresholds), .normal)
        XCTAssertEqual(state(available: 3_000, total: 10_000, thresholds), .warning)
        XCTAssertEqual(state(available: 1_501, total: 10_000, thresholds), .warning)
        XCTAssertEqual(state(available: 1_500, total: 10_000, thresholds), .critical)
        XCTAssertEqual(state(available: 1_499, total: 10_000, thresholds), .critical)
        XCTAssertEqual(state(available: 0, total: 10_000, thresholds), .critical)
        XCTAssertEqual(state(available: 10_000, total: 10_000, thresholds), .normal)
        XCTAssertEqual(state(available: 0, total: 0, thresholds), .unavailable)
        XCTAssertEqual(state(available: 1, total: 0, thresholds), .unavailable)
    }

    func testCustomThresholdsAndNonDivisibleRatio() {
        let thresholds = MemoryThresholds(warningPercent: 40, criticalPercent: 10)
        XCTAssertEqual(state(available: 4_001, total: 10_000, thresholds), .normal)
        XCTAssertEqual(state(available: 4_000, total: 10_000, thresholds), .warning)
        XCTAssertEqual(state(available: 1_001, total: 10_000, thresholds), .warning)
        XCTAssertEqual(state(available: 1_000, total: 10_000, thresholds), .critical)
        XCTAssertEqual(state(available: 2, total: 3, thresholds), .normal)
    }

    func testInvalidThresholdsDoNotInventABand() {
        let invalid = MemoryThresholds(warningPercent: 10, criticalPercent: 20)
        XCTAssertFalse(invalid.isValid)
        XCTAssertEqual(state(available: 5_000, total: 10_000, invalid), .unavailable)
    }

    func testThresholdSanitizingClampsAndRejects() {
        XCTAssertEqual(
            MemoryThresholds.sanitized(warningPercent: 30, criticalPercent: 15),
            .standard
        )
        XCTAssertEqual(
            MemoryThresholds.sanitized(warningPercent: 100, criticalPercent: 1),
            MemoryThresholds(warningPercent: 99, criticalPercent: 1)
        )
        XCTAssertEqual(
            MemoryThresholds.sanitized(warningPercent: 50, criticalPercent: 0),
            MemoryThresholds(warningPercent: 50, criticalPercent: 1)
        )
        XCTAssertNil(MemoryThresholds.sanitized(warningPercent: 15, criticalPercent: 15))
        XCTAssertNil(MemoryThresholds.sanitized(warningPercent: 10, criticalPercent: 20))
        XCTAssertNil(MemoryThresholds.sanitized(warningPercent: 0, criticalPercent: -5))
        XCTAssertNil(MemoryThresholds.sanitized(warningPercent: 10, criticalPercent: 200))
        XCTAssertEqual(
            MemoryThresholds.commit(warningPercent: 100, criticalPercent: 10),
            .savedClamped(
                MemoryThresholds(warningPercent: 99, criticalPercent: 10),
                notice: .limitedToRange
            )
        )
        if case .rejected(let notice, let warning, let critical) = MemoryThresholds.commit(
            warningPercent: 15,
            criticalPercent: 40
        ) {
            XCTAssertEqual(notice, .criticalMustBeLower)
            XCTAssertEqual(warning, 15)
            XCTAssertEqual(critical, 40)
        } else {
            XCTFail("Expected the invalid pair to be rejected")
        }
    }

    func testSaturatingSubtractClampsAtZero() {
        XCTAssertEqual(MemoryCalculator.saturatingSubtract(5, 9), 0)
        XCTAssertEqual(MemoryCalculator.saturatingSubtract(9, 5), 4)
        XCTAssertEqual(MemoryCalculator.saturatingAdd(UInt64.max, 1), UInt64.max)
    }

    private func state(
        _ available: UInt64,
        _ total: UInt64,
        _ thresholds: MemoryThresholds
    ) -> MemoryPressureState {
        MemoryCalculator.pressureState(
            availableBytes: available,
            totalBytes: total,
            thresholds: thresholds
        )
    }

    private func state(
        available: UInt64,
        total: UInt64,
        _ thresholds: MemoryThresholds
    ) -> MemoryPressureState {
        state(available, total, thresholds)
    }

    private func sample(
        pageSize: UInt64 = 16_384,
        totalPages: UInt64 = 1_000,
        swapBytes: UInt64 = 0,
        free: UInt64 = 0,
        active: UInt64 = 0,
        inactive: UInt64 = 0,
        wired: UInt64 = 0,
        purgeable: UInt64 = 0,
        speculative: UInt64 = 0,
        compressor: UInt64 = 0,
        internalPages: UInt64 = 0,
        externalPages: UInt64 = 0
    ) -> MemorySampleInput {
        let (totalBytes, overflow) = totalPages.multipliedReportingOverflow(by: pageSize)
        return MemorySampleInput(
            pageSize: pageSize,
            totalBytes: overflow ? UInt64.max : totalBytes,
            swapUsedBytes: swapBytes,
            freePages: free,
            activePages: active,
            inactivePages: inactive,
            wiredPages: wired,
            purgeablePages: purgeable,
            speculativePages: speculative,
            compressorPages: compressor,
            internalPages: internalPages,
            externalPages: externalPages
        )
    }
}
