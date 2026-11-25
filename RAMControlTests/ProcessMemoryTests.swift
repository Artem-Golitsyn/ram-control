import XCTest
@testable import RAMControl

final class ProcessMemoryTests: XCTestCase {
    func testTopKeepsTheEightHeaviest() {
        let processes = (0..<12).map { index in
            ProcessMemory(pid: Int32(index), name: "p\(index)", bytes: UInt64(index + 1) * 100)
        }
        let top = ProcessMemoryRanking.top(processes)
        XCTAssertEqual(top.map(\.pid), [11, 10, 9, 8, 7, 6, 5, 4])
        XCTAssertEqual(top.map(\.bytes), [1_200, 1_100, 1_000, 900, 800, 700, 600, 500])
    }

    func testTopDropsZeroBytesAndOrdersTiesByPid() {
        let processes = [
            ProcessMemory(pid: 4, name: "b", bytes: 50),
            ProcessMemory(pid: 2, name: "a", bytes: 50),
            ProcessMemory(pid: 9, name: "idle", bytes: 0),
            ProcessMemory(pid: 3, name: "c", bytes: 10),
            ProcessMemory(pid: -1, name: "bad", bytes: 999),
        ]
        let top = ProcessMemoryRanking.top(processes)
        XCTAssertEqual(top.map(\.pid), [2, 4, 3])
    }

    func testTopKeepsAShortListAndRejectsAZeroLimit() {
        let processes = [
            ProcessMemory(pid: 1, name: "one", bytes: 2),
            ProcessMemory(pid: 2, name: "two", bytes: 8),
        ]
        XCTAssertEqual(ProcessMemoryRanking.top(processes).map(\.pid), [2, 1])
        XCTAssertTrue(ProcessMemoryRanking.top(processes, limit: 0).isEmpty)
        XCTAssertTrue(ProcessMemoryRanking.top([]).isEmpty)
    }

    func testDisplayNameShortensReverseDNSExecutables() {
        XCTAssertEqual(ProcessMemoryName.display("com.apple.WebKit.WebContent"), "WebContent")
        XCTAssertEqual(ProcessMemoryName.display("Firefox GPU Helper"), "Firefox GPU Helper")
        XCTAssertEqual(ProcessMemoryName.display("phpstorm"), "phpstorm")
        XCTAssertEqual(ProcessMemoryName.display("Cursor Helper"), "Cursor Helper")
        XCTAssertEqual(ProcessMemoryName.display("  "), "")
    }

    func testPanelDisplayDefaultsAndLabels() {
        XCTAssertEqual(PanelDisplay.fromStored(nil), .heavyProcesses)
        XCTAssertEqual(PanelDisplay.fromStored("unknown"), .heavyProcesses)
        XCTAssertEqual(PanelDisplay.fromStored("statistics"), .statistics)
        XCTAssertEqual(PanelDisplay.fromStored("heavyProcesses"), .heavyProcesses)
        XCTAssertEqual(PanelDisplay.heavyProcesses.label(language: .russian), "Тяжелые процессы")
        XCTAssertEqual(PanelDisplay.statistics.label(language: .russian), "Статистика")
        XCTAssertEqual(PanelDisplay.heavyProcesses.label(language: .english), "Heavy Processes")
        XCTAssertEqual(PanelDisplay.statistics.label(language: .english), "Statistics")
        XCTAssertEqual(L10n.text(.showPanel, .russian), "Показывать")
        XCTAssertEqual(L10n.text(.showPanel, .english), "Show")
        XCTAssertEqual(L10n.text(.noHeavyProcesses, .russian), "Нет процессов")
        XCTAssertEqual(L10n.text(.noHeavyProcesses, .english), "No processes")
    }

    func testReaderReturnsASortedListNoLargerThanEight() {
        let processes = ProcessMemoryReader.readTop()
        XCTAssertLessThanOrEqual(processes.count, ProcessMemoryRanking.displayedCount)
        XCTAssertEqual(processes.map(\.bytes), processes.map(\.bytes).sorted(by: >))
        for process in processes {
            XCTAssertGreaterThan(process.bytes, 0)
            XCTAssertFalse(process.name.isEmpty)
            XCTAssertGreaterThanOrEqual(process.pid, 0)
        }
    }
}
