import Darwin
import Foundation

enum MemoryMonitorError: Error, Sendable {
    case physicalMemory(errno: Int32)
    case pageSize(kernReturn: Int32)
    case pageSizeZero
    case vmStatistics(kernReturn: Int32)
    case swapUsage(errno: Int32)
    case invalidSample

    var kernOrErrno: Int32 {
        switch self {
        case .physicalMemory(let errno), .swapUsage(let errno):
            return errno
        case .pageSize(let kernReturn), .vmStatistics(let kernReturn):
            return kernReturn
        case .pageSizeZero, .invalidSample:
            return 0
        }
    }
}

extension MemoryMonitorError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .physicalMemory(let errno):
            return "sysctl hw.memsize failed: \(posixMessage(errno)) (errno \(errno))"
        case .pageSize(let kernReturn):
            return "host_page_size failed: \(kernMessage(kernReturn)) (kern_return_t \(kernReturn))"
        case .pageSizeZero:
            return "host_page_size returned a page size of 0"
        case .vmStatistics(let kernReturn):
            return "host_statistics64(HOST_VM_INFO64) failed: \(kernMessage(kernReturn)) (kern_return_t \(kernReturn))"
        case .swapUsage(let errno):
            return "sysctl VM_SWAPUSAGE failed: \(posixMessage(errno)) (errno \(errno))"
        case .invalidSample:
            return "Memory counters could not be converted into bytes"
        }
    }
}

/// The only place that calls Mach and sysctl. No shell commands, no estimated zeros on failure.
enum MemoryMonitor {
    nonisolated static func readSample() -> Result<MemoryStats, MemoryMonitorError> {
        do {
            let totalBytes = try physicalMemoryBytes()
            let pageSize = try pageSizeBytes()
            let statistics = try vmStatistics()
            let swapBytes = try readSwapUsedBytes()
            let input = MemorySampleInput(
                pageSize: pageSize,
                totalBytes: totalBytes,
                swapUsedBytes: swapBytes,
                freePages: UInt64(statistics.free_count),
                activePages: UInt64(statistics.active_count),
                inactivePages: UInt64(statistics.inactive_count),
                wiredPages: UInt64(statistics.wire_count),
                purgeablePages: UInt64(statistics.purgeable_count),
                speculativePages: UInt64(statistics.speculative_count),
                compressorPages: UInt64(statistics.compressor_page_count),
                internalPages: UInt64(statistics.internal_page_count),
                externalPages: UInt64(statistics.external_page_count)
            )
            guard let stats = MemoryCalculator.makeStats(from: input) else {
                return .failure(.invalidSample)
            }
            return .success(stats)
        } catch let error as MemoryMonitorError {
            return .failure(error)
        } catch {
            return .failure(.invalidSample)
        }
    }

    private nonisolated static func physicalMemoryBytes() throws -> UInt64 {
        var bytes: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let status = sysctlbyname("hw.memsize", &bytes, &size, nil, 0)
        guard status == 0 else {
            throw MemoryMonitorError.physicalMemory(errno: errno)
        }
        return bytes
    }

    private nonisolated static func pageSizeBytes() throws -> UInt64 {
        var pageSize: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &pageSize)
        guard result == KERN_SUCCESS else {
            throw MemoryMonitorError.pageSize(kernReturn: result)
        }
        guard pageSize > 0 else {
            throw MemoryMonitorError.pageSizeZero
        }
        return UInt64(pageSize)
    }

    private nonisolated static func vmStatistics() throws -> vm_statistics64_data_t {
        var statistics = vm_statistics64_data_t()
        // HOST_VM_INFO64_COUNT is `sizeof(vm_statistics64_data_t) / sizeof(integer_t)` in
        // mach/host_info.h. Swift does not import that macro ("structure not supported"),
        // so the same division is done with the struct stride, which matches C sizeof.
        let countValue = MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        guard countValue > 0 else {
            throw MemoryMonitorError.vmStatistics(kernReturn: KERN_INVALID_ARGUMENT)
        }
        var count = mach_msg_type_number_t(countValue)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: countValue) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            throw MemoryMonitorError.vmStatistics(kernReturn: result)
        }
        return statistics
    }

    /// `vm_statistics64` has no byte-sized swap-used field. `VM_SWAPUSAGE` fills `struct xsw_usage`;
    /// `xsu_used` is the kernel's current swap usage in bytes (sys/sysctl.h).
    private nonisolated static func readSwapUsedBytes() throws -> UInt64 {
        var mib: [Int32] = [CTL_VM, VM_SWAPUSAGE]
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        let status = mib.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return -1 }
            return sysctl(base, u_int(buffer.count), &usage, &size, nil, 0)
        }
        guard status == 0 else {
            throw MemoryMonitorError.swapUsage(errno: errno)
        }
        return usage.xsu_used
    }
}

func posixMessage(_ code: Int32) -> String {
    guard let pointer = strerror(code) else {
        return "unknown errno"
    }
    return String(cString: pointer)
}

func kernMessage(_ code: Int32) -> String {
    let pointer = mach_error_string(code)
    guard let pointer else {
        return "unknown kern_return_t"
    }
    return String(cString: pointer)
}
