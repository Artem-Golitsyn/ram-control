import Foundation

/// UI language. English is the default; Russian is optional and stored in UserDefaults.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case russian = "ru"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en_US")
        case .russian:
            return Locale(identifier: "ru_RU")
        }
    }

    /// Native name of the language, shown in both UI languages so the picker stays recognizable.
    var nativeName: String {
        switch self {
        case .english:
            return "English"
        case .russian:
            return "Русский"
        }
    }

    static func fromStored(_ raw: String?) -> AppLanguage {
        guard let raw, let language = AppLanguage(rawValue: raw) else {
            return .english
        }
        return language
    }
}

enum L10nKey: Sendable {
    case general
    case launchAtLogin
    case updateInterval
    case appearance
    case language
    case showPanel
    case heavyProcesses
    case statistics
    case noHeavyProcesses
    case showMemoryGraph
    case graphPeriod
    case units
    case memoryThresholds
    case thresholdHelp
    case warning
    case critical
    case about
    case resetSettings
    case memory
    case available
    case used
    case active
    case inactive
    case wired
    case compressed
    case purgeable
    case swapUsed
    case physicalRAM
    case settings
    case quit
    case availableMemoryAccessibility
    case memoryUsedAccessibility
    case percentAccessibility
    case totalMemoryZero
    case enterWholeNumbers
    case criticalMustBeLower
    case valuesLimited
    case stateNormal
    case stateWarning
    case stateCritical
    case stateUnavailable
    case loginRequiresApproval
    case loginNotFound
    case loginRegisterFailed
    case loginRemoveFailed
    case loginRegisterNoEffect
    case memsizeFailed
    case pageSizeFailed
    case pageSizeZero
    case vmStatisticsFailed
    case swapFailed
    case invalidSample
}

enum L10n {
    /// Author name and year. Do not translate or transliterate.
    static let authorCredit = "Голицын Артем (2026)"

    static func text(_ key: L10nKey, _ language: AppLanguage) -> String {
        switch language {
        case .english:
            return english(key)
        case .russian:
            return russian(key)
        }
    }

    static func intervalLabel(milliseconds: Int, language: AppLanguage) -> String {
        let number = intervalNumber(milliseconds)
        switch language {
        case .english:
            let unit = milliseconds == 1_000 ? "second" : "seconds"
            return "\(number) \(unit)"
        case .russian:
            let unit: String
            if milliseconds % 1_000 != 0 {
                unit = "секунды"
            } else {
                unit = russianSecondsWord(max(0, milliseconds / 1_000))
            }
            return "\(number) \(unit)"
        }
    }

    static func historyWindowLabel(minutes: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        case .russian:
            return "\(minutes) \(russianMinutesWord(minutes, accusative: false))"
        }
    }

    static func memoryGraphAccessibility(minutes: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            if minutes == 1 {
                return "Memory graph for the last minute"
            }
            return "Memory graph for the last \(minutes) minutes"
        case .russian:
            if minutes == 1 {
                return "График памяти за последнюю минуту"
            }
            return "График памяти за последние \(minutes) \(russianMinutesWord(minutes, accusative: true))"
        }
    }

    static func graphTickLabel(seconds: TimeInterval, language: AppLanguage) -> String {
        let whole = max(0, Int(seconds.rounded()))
        if whole > 0, whole % 60 == 0 {
            let minutes = whole / 60
            switch language {
            case .english:
                return "\(minutes) min"
            case .russian:
                return "\(minutes) мин"
            }
        }
        if whole < 60 {
            switch language {
            case .english:
                return "\(whole) s"
            case .russian:
                return "\(whole) с"
            }
        }
        let minutes = whole / 60
        let rest = whole % 60
        switch language {
        case .english:
            return "\(minutes) min \(rest) s"
        case .russian:
            return "\(minutes) мин \(rest) с"
        }
    }

    static func aboutVersion(_ version: String, _ language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Version: RAM Control version \(version)"
        case .russian:
            return "Версия: RAM Control версия \(version)"
        }
    }

    static func aboutAuthor(_ language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Author: \(authorCredit)"
        case .russian:
            return "Автор: \(authorCredit)"
        }
    }

    private static func intervalNumber(_ milliseconds: Int) -> String {
        if milliseconds % 1_000 == 0 {
            return String(milliseconds / 1_000)
        }
        let tenths = milliseconds / 100
        return "\(tenths / 10).\(tenths % 10)"
    }

    static func physicalRAM(_ total: String, _ language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Physical RAM \(total)"
        case .russian:
            return "Физическая RAM \(total)"
        }
    }

    static func availableMemoryAccessibility(_ value: String, _ language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Available memory \(value)"
        case .russian:
            return "Доступная память \(value)"
        }
    }

    static func percentAccessibility(_ percent: Int, _ language: AppLanguage) -> String {
        switch language {
        case .english:
            return "\(percent) percent"
        case .russian:
            return "\(percent) процентов"
        }
    }

    static func loginRegisterFailed(status: String, message: String, language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Could not register the login item (status: \(status)). \(message)"
        case .russian:
            return "Не удалось зарегистрировать автозапуск (статус: \(status)). \(message)"
        }
    }

    static func loginRemoveFailed(status: String, message: String, language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Could not remove the login item (status: \(status)). \(message)"
        case .russian:
            return "Не удалось удалить автозапуск (статус: \(status)). \(message)"
        }
    }

    static func systemCallFailed(
        _ key: L10nKey,
        detail: String,
        codeName: String,
        code: Int32,
        language: AppLanguage
    ) -> String {
        let lead = text(key, language)
        return "\(lead): \(detail) (\(codeName) \(code))"
    }

    private static func russianMinutesWord(_ minutes: Int, accusative: Bool) -> String {
        let mod10 = minutes % 10
        let mod100 = minutes % 100
        if (11...14).contains(mod100) {
            return "минут"
        }
        switch mod10 {
        case 1:
            return accusative ? "минуту" : "минута"
        case 2, 3, 4:
            return "минуты"
        default:
            return "минут"
        }
    }

    private static func russianSecondsWord(_ seconds: Int) -> String {
        let mod10 = seconds % 10
        let mod100 = seconds % 100
        if (11...14).contains(mod100) {
            return "секунд"
        }
        switch mod10 {
        case 1:
            return "секунда"
        case 2, 3, 4:
            return "секунды"
        default:
            return "секунд"
        }
    }

    private static func english(_ key: L10nKey) -> String {
        switch key {
        case .general: return "General"
        case .launchAtLogin: return "Launch at Login"
        case .updateInterval: return "Update Interval"
        case .appearance: return "Appearance"
        case .language: return "Language"
        case .showPanel: return "Show"
        case .heavyProcesses: return "Heavy Processes"
        case .statistics: return "Statistics"
        case .noHeavyProcesses: return "No processes"
        case .showMemoryGraph: return "Memory Graph"
        case .graphPeriod: return "Graph Period"
        case .units: return "Units"
        case .memoryThresholds: return "Memory Thresholds"
        case .thresholdHelp:
            return "Available memory as a percentage of total physical RAM. Critical must be lower than Warning. Values are limited to 1–99%."
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .about: return "About"
        case .resetSettings: return "Reset Settings"
        case .memory: return "Memory"
        case .available: return "Available"
        case .used: return "Used"
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .wired: return "Wired"
        case .compressed: return "Compressed"
        case .purgeable: return "Purgeable"
        case .swapUsed: return "Swap Used"
        case .physicalRAM: return "Physical RAM"
        case .settings: return "Settings…"
        case .quit: return "Quit"
        case .availableMemoryAccessibility: return "Available memory"
        case .memoryUsedAccessibility: return "Memory used"
        case .percentAccessibility: return "percent"
        case .totalMemoryZero:
            return "Total physical memory is 0, so available memory cannot be calculated."
        case .enterWholeNumbers:
            return "Enter whole numbers from 1 to 99. Critical must be lower than Warning."
        case .criticalMustBeLower: return "Critical must be lower than Warning."
        case .valuesLimited: return "Values are limited to 1–99%."
        case .stateNormal: return "Normal"
        case .stateWarning: return "Warning"
        case .stateCritical: return "Critical"
        case .stateUnavailable: return "Unavailable"
        case .loginRequiresApproval:
            return "macOS requires approval before RAM Control can open at login. Enable RAM Control in System Settings → General → Login Items & Extensions. (SMAppService status: requiresApproval)"
        case .loginNotFound:
            return "SMAppService could not find RAM Control (status: notFound). Copy RAM Control.app to /Applications or the Login Items folder, then try again."
        case .loginRegisterFailed: return "Could not register the login item"
        case .loginRemoveFailed: return "Could not remove the login item"
        case .loginRegisterNoEffect: return "register() returned without enabling the login item."
        case .memsizeFailed: return "sysctl hw.memsize failed"
        case .pageSizeFailed: return "host_page_size failed"
        case .pageSizeZero: return "host_page_size returned a page size of 0"
        case .vmStatisticsFailed: return "host_statistics64(HOST_VM_INFO64) failed"
        case .swapFailed: return "sysctl VM_SWAPUSAGE failed"
        case .invalidSample: return "Memory counters could not be converted into bytes"
        }
    }

    private static func russian(_ key: L10nKey) -> String {
        switch key {
        case .general: return "Основные"
        case .launchAtLogin: return "Запуск при входе"
        case .updateInterval: return "Интервал обновления"
        case .appearance: return "Оформление"
        case .language: return "Язык"
        case .showPanel: return "Показывать"
        case .heavyProcesses: return "Тяжелые процессы"
        case .statistics: return "Статистика"
        case .noHeavyProcesses: return "Нет процессов"
        case .showMemoryGraph: return "График памяти"
        case .graphPeriod: return "Период графика"
        case .units: return "Единицы"
        case .memoryThresholds: return "Пороги памяти"
        case .thresholdHelp:
            return "Доступная память в процентах от общего объёма физической RAM. Критичный порог должен быть ниже предупреждения. Допустимы значения от 1 до 99%."
        case .warning: return "Предупреждение"
        case .critical: return "Критичный"
        case .about: return "О программе"
        case .resetSettings: return "Сбросить настройки"
        case .memory: return "Память"
        case .available: return "Доступно"
        case .used: return "Занято"
        case .active: return "Активная"
        case .inactive: return "Неактивная"
        case .wired: return "Закреплённая"
        case .compressed: return "Сжатая"
        case .purgeable: return "Очищаемая"
        case .swapUsed: return "Подкачка"
        case .physicalRAM: return "Физическая RAM"
        case .settings: return "Настройки…"
        case .quit: return "Завершить"
        case .availableMemoryAccessibility: return "Доступная память"
        case .memoryUsedAccessibility: return "Занятая память"
        case .percentAccessibility: return "процентов"
        case .totalMemoryZero:
            return "Общий объём физической памяти равен 0, поэтому доступную память вычислить нельзя."
        case .enterWholeNumbers:
            return "Введите целые числа от 1 до 99. Критичный порог должен быть ниже предупреждения."
        case .criticalMustBeLower: return "Критичный порог должен быть ниже предупреждения."
        case .valuesLimited: return "Значения ограничены диапазоном 1–99%."
        case .stateNormal: return "Норма"
        case .stateWarning: return "Внимание"
        case .stateCritical: return "Критично"
        case .stateUnavailable: return "Нет данных"
        case .loginRequiresApproval:
            return "macOS требует подтверждения, прежде чем RAM Control сможет открываться при входе. Включите RAM Control в «Системные настройки → Основные → Объекты входа и расширения». (SMAppService: requiresApproval)"
        case .loginNotFound:
            return "SMAppService не нашёл RAM Control (статус: notFound). Скопируйте «RAM Control.app» в /Applications или в папку объектов входа и повторите попытку."
        case .loginRegisterFailed: return "Не удалось зарегистрировать автозапуск"
        case .loginRemoveFailed: return "Не удалось удалить автозапуск"
        case .loginRegisterNoEffect: return "register() завершился, но автозапуск не включился."
        case .memsizeFailed: return "Не удалось выполнить sysctl hw.memsize"
        case .pageSizeFailed: return "Не удалось выполнить host_page_size"
        case .pageSizeZero: return "host_page_size вернул размер страницы 0"
        case .vmStatisticsFailed: return "Не удалось выполнить host_statistics64(HOST_VM_INFO64)"
        case .swapFailed: return "Не удалось выполнить sysctl VM_SWAPUSAGE"
        case .invalidSample: return "Счётчики памяти не удалось перевести в байты"
        }
    }
}

extension MemoryPressureState {
    func title(language: AppLanguage) -> String {
        switch self {
        case .normal:
            return L10n.text(.stateNormal, language)
        case .warning:
            return L10n.text(.stateWarning, language)
        case .critical:
            return L10n.text(.stateCritical, language)
        case .unavailable:
            return L10n.text(.stateUnavailable, language)
        }
    }
}

extension ThresholdNotice {
    func message(language: AppLanguage) -> String {
        switch self {
        case .criticalMustBeLower:
            return L10n.text(.criticalMustBeLower, language)
        case .limitedToRange:
            return L10n.text(.valuesLimited, language)
        }
    }
}

extension MemoryMonitorError {
    func userMessage(language: AppLanguage) -> String {
        switch self {
        case .physicalMemory(let code):
            return L10n.systemCallFailed(
                .memsizeFailed,
                detail: posixMessage(code),
                codeName: "errno",
                code: code,
                language: language
            )
        case .pageSize(let code):
            return L10n.systemCallFailed(
                .pageSizeFailed,
                detail: kernMessage(code),
                codeName: "kern_return_t",
                code: code,
                language: language
            )
        case .pageSizeZero:
            return L10n.text(.pageSizeZero, language)
        case .vmStatistics(let code):
            return L10n.systemCallFailed(
                .vmStatisticsFailed,
                detail: kernMessage(code),
                codeName: "kern_return_t",
                code: code,
                language: language
            )
        case .swapUsage(let code):
            return L10n.systemCallFailed(
                .swapFailed,
                detail: posixMessage(code),
                codeName: "errno",
                code: code,
                language: language
            )
        case .invalidSample:
            return L10n.text(.invalidSample, language)
        }
    }
}

extension LaunchAtLoginError {
    func userMessage(language: AppLanguage) -> String {
        switch self {
        case .requiresApproval:
            return L10n.text(.loginRequiresApproval, language)
        case .notFound:
            return L10n.text(.loginNotFound, language)
        case .registrationFailed(let message, let status):
            return L10n.loginRegisterFailed(status: status, message: message, language: language)
        case .registrationDidNotEnable(let status):
            return L10n.loginRegisterFailed(
                status: status,
                message: L10n.text(.loginRegisterNoEffect, language),
                language: language
            )
        case .removalFailed(let message, let status):
            return L10n.loginRemoveFailed(status: status, message: message, language: language)
        }
    }
}
