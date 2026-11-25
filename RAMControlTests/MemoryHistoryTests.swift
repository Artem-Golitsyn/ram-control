import XCTest
@testable import RAMControl

final class MemoryHistoryTests: XCTestCase {
    func testVisibleSamplesKeepTheirValuesAndReadLeftToRight() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let samples = [
            point(at: now, used: 80, total: 100),
            point(at: now.addingTimeInterval(-45), used: 10, total: 100),
            point(at: now.addingTimeInterval(-20), used: 40, total: 100),
        ]
        let visible = MemoryHistory.visibleSamples(samples, window: 60, now: now)
        XCTAssertEqual(visible.map(\.usedBytes), [10, 40, 80])
        let nowX = try XCTUnwrap(MemoryHistory.horizontalPosition(age: 0, window: 60))
        let edgeX = try XCTUnwrap(MemoryHistory.horizontalPosition(age: 60, window: 60))
        XCTAssertEqual(nowX, 1, accuracy: 0.000_001)
        XCTAssertEqual(edgeX, 0, accuracy: 0.000_001)
    }

    func testSamplesOutsideTheWindowAreDropped() {
        let now = Date(timeIntervalSince1970: 10_000)
        let samples = [
            point(at: now.addingTimeInterval(-60.1), used: 90, total: 100),
            point(at: now.addingTimeInterval(0.1), used: 70, total: 100),
            point(at: now.addingTimeInterval(-60), used: 25, total: 100),
        ]
        let visible = MemoryHistory.visibleSamples(samples, window: 60, now: now)
        XCTAssertEqual(visible.map(\.usedBytes), [25])
    }

    func testCloseSamplesAreNotReplacedByANewerOne() {
        let now = Date(timeIntervalSince1970: 10_000)
        let samples = [
            point(at: now.addingTimeInterval(-14), used: 10, total: 100),
            point(at: now.addingTimeInterval(-1), used: 70, total: 100),
        ]
        let visible = MemoryHistory.visibleSamples(samples, window: 60, now: now)
        XCTAssertEqual(visible.map(\.usedBytes), [10, 70])
    }

    func testEmptyWindowProducesNoSamples() {
        let now = Date(timeIntervalSince1970: 10_000)
        let samples = [point(at: now, used: 10, total: 100)]
        XCTAssertTrue(MemoryHistory.visibleSamples(samples, window: 0, now: now).isEmpty)
        XCTAssertTrue(MemoryHistory.visibleSamples([], window: 60, now: now).isEmpty)
        XCTAssertNil(MemoryHistory.horizontalPosition(age: -1, window: 60))
        XCTAssertNil(MemoryHistory.horizontalPosition(age: 61, window: 60))
    }

    func testVerticalScaleUsesVisibleMinimumAndMaximum() {
        XCTAssertEqual(MemoryHistory.verticalPosition(used: 10, minimum: 10, maximum: 80), 0)
        XCTAssertEqual(MemoryHistory.verticalPosition(used: 80, minimum: 10, maximum: 80), 1)
        XCTAssertEqual(MemoryHistory.verticalPosition(used: 45, minimum: 10, maximum: 80), 0.5, accuracy: 0.000_001)
        XCTAssertEqual(MemoryHistory.verticalPosition(used: 40, minimum: 40, maximum: 40), 0.5)
    }

    func testLongGapBreaksTheLineAndKeepsBothSamples() {
        let now = Date(timeIntervalSince1970: 10_000)
        let samples = [
            point(at: now.addingTimeInterval(-40), used: 10, total: 100),
            point(at: now.addingTimeInterval(-19), used: 20, total: 100),
            point(at: now, used: 30, total: 100),
        ]
        let runs = MemoryHistory.runs(samples)
        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(runs[0].map(\.usedBytes), [10])
        XCTAssertEqual(runs[1].map(\.usedBytes), [20, 30])
    }

    func testGraphBlendIsRedYellowGray() {
        let thresholds = MemoryThresholds.standard
        let critical = MemoryGraphColor.blend(availableBytes: 150, totalBytes: 1_000, thresholds: thresholds)
        XCTAssertEqual(critical, MemoryGraphBlend(red: 1, yellow: 0, gray: 0))

        let below = MemoryGraphColor.blend(availableBytes: 100, totalBytes: 1_000, thresholds: thresholds)
        XCTAssertEqual(below, MemoryGraphBlend(red: 1, yellow: 0, gray: 0))

        let middle = MemoryGraphColor.blend(availableBytes: 225, totalBytes: 1_000, thresholds: thresholds)
        XCTAssertEqual(middle.red, 0, accuracy: 0.000_001)
        XCTAssertEqual(middle.yellow, 1, accuracy: 0.000_001)
        XCTAssertEqual(middle.gray, 0, accuracy: 0.000_001)

        let halfway = MemoryGraphColor.blend(availableBytes: 1_875, totalBytes: 10_000, thresholds: thresholds)
        XCTAssertEqual(halfway.red, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(halfway.yellow, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(halfway.gray, 0, accuracy: 0.000_001)

        let calm = MemoryGraphColor.blend(availableBytes: 300, totalBytes: 1_000, thresholds: thresholds)
        XCTAssertEqual(calm, MemoryGraphBlend(red: 0, yellow: 0, gray: 1))
        let above = MemoryGraphColor.blend(availableBytes: 500, totalBytes: 1_000, thresholds: thresholds)
        XCTAssertEqual(above, MemoryGraphBlend(red: 0, yellow: 0, gray: 1))

        let invalid = MemoryThresholds(warningPercent: 10, criticalPercent: 20)
        let neutral = MemoryGraphColor.blend(availableBytes: 500, totalBytes: 1_000, thresholds: invalid)
        XCTAssertEqual(neutral, MemoryGraphBlend(red: 0, yellow: 0, gray: 1))
        let zero = MemoryGraphColor.blend(availableBytes: 0, totalBytes: 0, thresholds: thresholds)
        XCTAssertEqual(zero, MemoryGraphBlend(red: 0, yellow: 0, gray: 1))
    }

    func testVerticalTicksSplitTheWindowIntoFive() {
        XCTAssertEqual(MemoryHistory.verticalTickAges(window: 300), [60, 120, 180, 240, 300])
        XCTAssertEqual(MemoryHistory.verticalTickAges(window: 60), [12, 24, 36, 48, 60])
        XCTAssertTrue(MemoryHistory.verticalTickAges(window: 0).isEmpty)
    }

    func testStoredBlendIsNotRecomputed() {
        let now = Date(timeIntervalSince1970: 10_000)
        let painted = MemoryGraphBlend(red: 1, yellow: 0, gray: 0)
        let samples = [point(at: now, used: 80, total: 100, blend: painted)]
        let visible = MemoryHistory.visibleSamples(samples, window: 60, now: now)
        XCTAssertEqual(visible.first?.blend, painted)
    }

    func testTrimKeepsTenMinutesAndDropsTheFuture() {
        let now = Date(timeIntervalSince1970: 10_000)
        var history = MemoryHistory()
        history.append(point(at: now.addingTimeInterval(-601), used: 1, total: 10), now: now)
        history.append(point(at: now.addingTimeInterval(-600), used: 2, total: 10), now: now)
        history.append(point(at: now, used: 3, total: 10), now: now)
        history.append(point(at: now.addingTimeInterval(3), used: 4, total: 10), now: now)
        XCTAssertEqual(history.samples.map(\.usedBytes), [2, 3])
    }

    func testStoredWindowsAndIntervalLabels() {
        XCTAssertEqual(HistoryWindow.fromStored(1), .one)
        XCTAssertEqual(HistoryWindow.fromStored(3), .three)
        XCTAssertEqual(HistoryWindow.fromStored(5), .five)
        XCTAssertEqual(HistoryWindow.fromStored(10), .ten)
        XCTAssertEqual(HistoryWindow.fromStored(7), .five)
        XCTAssertEqual(HistoryWindow.one.label(language: .english), "1 minute")
        XCTAssertEqual(HistoryWindow.three.label(language: .english), "3 minutes")
        XCTAssertEqual(HistoryWindow.five.label(language: .russian), "5 минут")
        XCTAssertEqual(HistoryWindow.one.label(language: .russian), "1 минута")
        XCTAssertEqual(HistoryWindow.three.label(language: .russian), "3 минуты")
        XCTAssertEqual(L10n.memoryGraphAccessibility(minutes: 1, language: .russian), "График памяти за последнюю минуту")
        XCTAssertEqual(L10n.memoryGraphAccessibility(minutes: 5, language: .english), "Memory graph for the last 5 minutes")
        XCTAssertEqual(L10n.aboutVersion("1.4", .russian), "Версия: RAM Control версия 1.4")
        XCTAssertEqual(L10n.aboutVersion("1.4", .english), "Version: RAM Control version 1.4")
        XCTAssertEqual(L10n.graphTickLabel(seconds: 60, language: .english), "1 min")
        XCTAssertEqual(L10n.graphTickLabel(seconds: 300, language: .russian), "5 мин")
        XCTAssertEqual(L10n.graphTickLabel(seconds: 12, language: .russian), "12 с")
        XCTAssertEqual(L10n.graphTickLabel(seconds: 12, language: .english), "12 s")
        XCTAssertEqual(L10n.aboutAuthor(.russian), "Автор: Голицын Артем (2026)")
        XCTAssertEqual(L10n.aboutAuthor(.english), "Author: Голицын Артем (2026)")
    }

    private func point(
        at date: Date,
        used: UInt64,
        total: UInt64,
        blend: MemoryGraphBlend = MemoryGraphBlend(red: 0, yellow: 0, gray: 1)
    ) -> MemoryHistorySample {
        MemoryHistorySample(
            date: date,
            usedBytes: used,
            totalBytes: total,
            availableBytes: total > used ? total - used : 0,
            blend: blend
        )
    }
}
