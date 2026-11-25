import AppKit
import Foundation
import Observation
import os

private let memoryLogger = Logger(subsystem: "app.ramcontrol.RAMControl", category: "Memory")

@MainActor
@Observable
final class MemoryViewModel {
    private(set) var stats: MemoryStats?
    private(set) var lastError: MemoryMonitorError?
    private(set) var memoryHistory = MemoryHistory()

    var refreshInterval: RefreshInterval = .one {
        didSet { handleRefreshIntervalChange(from: oldValue) }
    }

    var historyGraphEnabled = true {
        didSet { persistHistoryGraphEnabled() }
    }

    var historyWindow: HistoryWindow = .five {
        didSet { persistHistoryWindow() }
    }

    var unit: MemoryUnit = .gb {
        didSet { persistUnit() }
    }

    var thresholds = MemoryThresholds.standard {
        didSet { persistThresholds() }
    }

    var language: AppLanguage = .english {
        didSet { persistLanguage() }
    }

    var panelDisplay: PanelDisplay = .heavyProcesses {
        didSet { handlePanelDisplayChange(from: oldValue) }
    }

    private(set) var heavyProcesses: [ProcessMemory] = []

    var launchAtLoginEnabled = false
    var launchAtLoginError: LaunchAtLoginError?

    private var didStart = false
    private var refreshGeneration: UInt64 = 0
    private var lastLoggedMessage: String?
    private nonisolated let refreshTasks = RefreshTaskStore()
    private nonisolated let events = SystemEventBridge()

    init() {
        let defaults = UserDefaults.standard
        Constants.registerDefaults(in: defaults)
        refreshInterval = RefreshInterval.fromStored(
            defaults.integer(forKey: Constants.DefaultsKey.refreshInterval)
        )
        if defaults.object(forKey: Constants.DefaultsKey.historyGraphEnabled) != nil {
            historyGraphEnabled = defaults.bool(forKey: Constants.DefaultsKey.historyGraphEnabled)
        }
        historyWindow = HistoryWindow.fromStored(
            defaults.integer(forKey: Constants.DefaultsKey.historyWindowMinutes)
        )
        unit = MemoryUnit.fromStored(defaults.string(forKey: Constants.DefaultsKey.memoryUnit))
        let warning = defaults.integer(forKey: Constants.DefaultsKey.warningPercent)
        let critical = defaults.integer(forKey: Constants.DefaultsKey.criticalPercent)
        if let sanitized = MemoryThresholds.sanitized(warningPercent: warning, criticalPercent: critical) {
            thresholds = sanitized
        }
        language = AppLanguage.fromStored(defaults.string(forKey: Constants.DefaultsKey.language))
        panelDisplay = PanelDisplay.fromStored(defaults.string(forKey: Constants.DefaultsKey.panelDisplay))
        launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
        didStart = true
        bindSystemEvents()
        restartMonitoring()
    }

    deinit {
        refreshTasks.cancel()
    }

    var pressureState: MemoryPressureState {
        guard lastError == nil, let stats, stats.totalBytes > 0 else {
            return .unavailable
        }
        return MemoryCalculator.pressureState(
            availableBytes: stats.availableBytes,
            totalBytes: stats.totalBytes,
            thresholds: thresholds
        )
    }

    var menuBarText: String {
        guard let stats = displayStats else { return "—" }
        return ByteFormatter.string(bytes: stats.availableBytes, unit: unit)
    }

    /// Anchor for the graph. The newest sample stays at the top until the next successful read.
    var historyReferenceDate: Date {
        memoryHistory.samples.last?.date ?? Date()
    }

    var displayStats: MemoryStats? {
        guard lastError == nil, let stats, stats.totalBytes > 0 else { return nil }
        return stats
    }

    var statusMessage: String? {
        if let lastError {
            return lastError.userMessage(language: language)
        }
        if stats?.totalBytes == 0 {
            return L10n.text(.totalMemoryZero, language)
        }
        return nil
    }

    func format(bytes: UInt64) -> String {
        ByteFormatter.string(bytes: bytes, unit: unit)
    }

    func commitThresholds(warningPercent: Int, criticalPercent: Int) -> ThresholdCommit {
        let result = MemoryThresholds.commit(
            warningPercent: warningPercent,
            criticalPercent: criticalPercent
        )
        switch result {
        case .saved(let updated), .savedClamped(let updated, _):
            thresholds = updated
        case .rejected:
            break
        }
        return result
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try LaunchAtLoginManager.enable()
            } else {
                try LaunchAtLoginManager.disable()
            }
            launchAtLoginError = nil
        } catch let error as LaunchAtLoginError {
            launchAtLoginError = error
        } catch {
            launchAtLoginError = .registrationFailed(
                message: error.localizedDescription,
                status: "unknown"
            )
        }
        launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    }

    func resetPreferences() {
        let defaults = UserDefaults.standard
        for key in Constants.DefaultsKey.all {
            defaults.removeObject(forKey: key)
        }
        refreshInterval = .one
        historyGraphEnabled = true
        historyWindow = .five
        unit = .gb
        thresholds = .standard
        language = .english
        panelDisplay = .heavyProcesses
    }

    func stopMonitoring() {
        refreshTasks.cancel()
    }

    func refreshNow() async {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        let includeProcesses = panelDisplay == .heavyProcesses
        let refresh = await Task.detached(priority: .utility) {
            let sample = MemoryMonitor.readSample()
            let processes = includeProcesses ? ProcessMemoryReader.readTop() : nil
            return MemoryRefresh(sample: sample, processes: processes)
        }.value
        guard !Task.isCancelled, generation == refreshGeneration else { return }
        apply(refresh)
    }

    private func restartMonitoring() {
        let seconds = refreshInterval.seconds
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runLoop(seconds: seconds)
        }
        refreshTasks.replace(with: task)
    }

    private func runLoop(seconds: TimeInterval) async {
        while !Task.isCancelled {
            await refreshNow()
            if Task.isCancelled { break }
            do {
                try await Task.sleep(nanoseconds: nanoseconds(seconds))
            } catch {
                break
            }
        }
    }

    private func apply(_ refresh: MemoryRefresh) {
        if let processes = refresh.processes {
            heavyProcesses = processes
        }
        apply(refresh.sample)
    }

    private func apply(_ result: Result<MemoryStats, MemoryMonitorError>) {
        switch result {
        case .success(let sample):
            stats = sample
            if sample.totalBytes == 0 {
                lastError = nil
                logTransition(L10n.text(.totalMemoryZero, .english))
                return
            }
            lastError = nil
            let now = Date()
            var history = memoryHistory
            history.append(
                MemoryHistorySample(
                    date: now,
                    usedBytes: sample.usedBytes,
                    totalBytes: sample.totalBytes,
                    availableBytes: sample.availableBytes,
                    blend: MemoryGraphColor.blend(
                        availableBytes: sample.availableBytes,
                        totalBytes: sample.totalBytes,
                        thresholds: thresholds
                    )
                ),
                now: now
            )
            memoryHistory = history
            logTransition(
                "RAM Control available \(format(bytes: sample.availableBytes)) of \(format(bytes: sample.totalBytes)), swap \(format(bytes: sample.swapUsedBytes))"
            )
        case .failure(let error):
            stats = nil
            lastError = error
            logTransition(error.userMessage(language: .english))
        }
    }

    private func handleRefreshIntervalChange(from oldValue: RefreshInterval) {
        guard didStart else { return }
        UserDefaults.standard.set(refreshInterval.rawValue, forKey: Constants.DefaultsKey.refreshInterval)
        guard refreshInterval != oldValue else { return }
        restartMonitoring()
    }

    private func persistHistoryGraphEnabled() {
        guard didStart else { return }
        UserDefaults.standard.set(historyGraphEnabled, forKey: Constants.DefaultsKey.historyGraphEnabled)
    }

    private func persistHistoryWindow() {
        guard didStart else { return }
        UserDefaults.standard.set(historyWindow.rawValue, forKey: Constants.DefaultsKey.historyWindowMinutes)
    }

    private func persistUnit() {
        guard didStart else { return }
        UserDefaults.standard.set(unit.rawValue, forKey: Constants.DefaultsKey.memoryUnit)
    }

    private func persistLanguage() {
        guard didStart else { return }
        UserDefaults.standard.set(language.rawValue, forKey: Constants.DefaultsKey.language)
    }

    private func handlePanelDisplayChange(from oldValue: PanelDisplay) {
        guard didStart else { return }
        UserDefaults.standard.set(panelDisplay.rawValue, forKey: Constants.DefaultsKey.panelDisplay)
        guard panelDisplay != oldValue else { return }
        Task { await refreshNow() }
    }

    private func persistThresholds() {
        guard didStart else { return }
        let defaults = UserDefaults.standard
        defaults.set(thresholds.warningPercent, forKey: Constants.DefaultsKey.warningPercent)
        defaults.set(thresholds.criticalPercent, forKey: Constants.DefaultsKey.criticalPercent)
    }

    private func bindSystemEvents() {
        events.start(
            onWake: { [weak self] in
                Task { @MainActor in
                    await self?.refreshNow()
                }
            },
            onTerminate: { [weak self] in
                Task { @MainActor in
                    self?.stopMonitoring()
                }
            }
        )
    }

    private func logTransition(_ message: String) {
        guard message != lastLoggedMessage else { return }
        lastLoggedMessage = message
        memoryLogger.info("\(message, privacy: .public)")
        fputs(message + "\n", stderr)
        fflush(stderr)
    }

    private func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
        guard seconds > 0 else { return 1_000_000_000 }
        let raw = seconds * 1_000_000_000
        guard raw < Double(UInt64.max) else { return UInt64.max }
        return UInt64(raw)
    }
}

private struct MemoryRefresh: Sendable {
    var sample: Result<MemoryStats, MemoryMonitorError>
    var processes: [ProcessMemory]?
}

private final class RefreshTaskStore: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    func replace(with newTask: Task<Void, Never>) {
        lock.lock()
        let previous = task
        task = newTask
        lock.unlock()
        previous?.cancel()
    }

    func cancel() {
        lock.lock()
        let previous = task
        task = nil
        lock.unlock()
        previous?.cancel()
    }
}

/// Forwards wake and terminate notifications onto the main actor without a second polling loop.
/// `willSleep` is intentionally not a second timer: the single `Task.sleep` is suspended by the
/// system, and `didWake` / `screensDidWake` request one immediate sample.
private final class SystemEventBridge: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var wakeHandler: (@Sendable () -> Void)?
    private var terminateHandler: (@Sendable () -> Void)?
    private var started = false

    func start(
        onWake: @escaping @Sendable () -> Void,
        onTerminate: @escaping @Sendable () -> Void
    ) {
        lock.lock()
        wakeHandler = onWake
        terminateHandler = onTerminate
        let shouldStart = !started
        started = true
        lock.unlock()
        guard shouldStart else { return }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            self,
            selector: #selector(handleWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspace.addObserver(
            self,
            selector: #selector(handleWake(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func handleWake(_ notification: Notification) {
        let handler = withLock { wakeHandler }
        handler?()
    }

    @objc private func handleTerminate(_ notification: Notification) {
        let handler = withLock { terminateHandler }
        handler?()
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
