import Darwin
import Foundation

/// Reads the processes that currently occupy the most physical memory.
/// Footprint is `ri_phys_footprint` from `proc_pid_rusage` (`RUSAGE_INFO_V4`), the same
/// quantity as the Memory column in Activity Monitor. Resident size is not a substitute.
/// Called from the single refresh task. No `ps`, `top`, or other shell.
enum ProcessMemoryReader {
    nonisolated static func readTop(limit: Int = ProcessMemoryRanking.displayedCount) -> [ProcessMemory] {
        let ranked = ProcessMemoryRanking.top(footprints(), limit: limit)
        return ranked.map { process in
            ProcessMemory(
                pid: process.pid,
                name: processName(pid: process.pid),
                bytes: process.bytes
            )
        }
    }

    private nonisolated static func footprints() -> [ProcessMemory] {
        processIDs().compactMap { pid in
            guard let bytes = physicalFootprint(pid: pid) else { return nil }
            return ProcessMemory(pid: pid, name: "", bytes: bytes)
        }
    }

    private nonisolated static func processIDs() -> [pid_t] {
        var capacity = 512
        var listed: [pid_t] = []
        for _ in 0..<6 {
            var pids = [pid_t](repeating: 0, count: capacity)
            let written = proc_listpids(
                UInt32(PROC_ALL_PIDS),
                0,
                &pids,
                Int32(capacity * MemoryLayout<pid_t>.stride)
            )
            guard written > 0 else { return [] }
            let count = Int(written) / MemoryLayout<pid_t>.stride
            listed = Array(pids.prefix(count))
            if count < capacity {
                return listed
            }
            capacity *= 2
        }
        return listed
    }

    private nonisolated static func physicalFootprint(pid: pid_t) -> UInt64? {
        var info = rusage_info_v4()
        let status = withUnsafeMutableBytes(of: &info) { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return -1 }
            return proc_pid_rusage(pid, RUSAGE_INFO_V4, base.assumingMemoryBound(to: rusage_info_t?.self))
        }
        guard status == 0, info.ri_phys_footprint > 0 else { return nil }
        return info.ri_phys_footprint
    }

    private nonisolated static func processName(pid: pid_t) -> String {
        var pathBuffer = [CChar](repeating: 0, count: 4 * 1024)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        if pathLength > 0 {
            let path = String(cString: pathBuffer)
            let fileName = (path as NSString).lastPathComponent
            let display = ProcessMemoryName.display(fileName)
            if !display.isEmpty { return display }
        }

        var nameBuffer = [CChar](repeating: 0, count: 256)
        let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if nameLength > 0 {
            let display = ProcessMemoryName.display(String(cString: nameBuffer))
            if !display.isEmpty { return display }
        }
        return String(pid)
    }
}
