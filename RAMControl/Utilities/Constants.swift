import Foundation

enum Constants {
    enum DefaultsKey {
        static let refreshInterval = "refreshIntervalSeconds"
        static let memoryUnit = "memoryUnit"
        static let warningPercent = "warningThresholdPercent"
        static let criticalPercent = "criticalThresholdPercent"
        static let language = "appLanguage"
        static let historyGraphEnabled = "memoryGraphEnabled"
        static let historyWindowMinutes = "memoryGraphMinutes"
        static let panelDisplay = "panelDisplay"

        static let all = [
            refreshInterval,
            memoryUnit,
            warningPercent,
            criticalPercent,
            language,
            historyGraphEnabled,
            historyWindowMinutes,
            panelDisplay,
        ]
    }

    static func registerDefaults(in defaults: UserDefaults) {
        defaults.register(defaults: [
            DefaultsKey.refreshInterval: RefreshInterval.one.rawValue,
            DefaultsKey.memoryUnit: MemoryUnit.gb.rawValue,
            DefaultsKey.warningPercent: MemoryThresholds.standard.warningPercent,
            DefaultsKey.criticalPercent: MemoryThresholds.standard.criticalPercent,
            DefaultsKey.language: AppLanguage.english.rawValue,
            DefaultsKey.historyGraphEnabled: true,
            DefaultsKey.historyWindowMinutes: HistoryWindow.five.rawValue,
            DefaultsKey.panelDisplay: PanelDisplay.heavyProcesses.rawValue,
        ])
    }

    static let popoverWidth: CGFloat = 300
    static let settingsWidth: CGFloat = 520
}
