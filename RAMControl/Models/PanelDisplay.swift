import Foundation

/// What the lower part of the panel lists. Heavy processes is the default.
enum PanelDisplay: String, CaseIterable, Identifiable, Sendable {
    case heavyProcesses = "heavyProcesses"
    case statistics = "statistics"

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .heavyProcesses:
            return L10n.text(.heavyProcesses, language)
        case .statistics:
            return L10n.text(.statistics, language)
        }
    }

    static func fromStored(_ raw: String?) -> PanelDisplay {
        guard let raw, let display = PanelDisplay(rawValue: raw) else {
            return .heavyProcesses
        }
        return display
    }
}
