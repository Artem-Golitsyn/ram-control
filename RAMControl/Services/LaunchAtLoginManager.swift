import Foundation
import ServiceManagement

enum LaunchAtLoginError: Error, Equatable {
    case requiresApproval
    case notFound
    case registrationFailed(message: String, status: String)
    case registrationDidNotEnable(status: String)
    case removalFailed(message: String, status: String)
}

extension LaunchAtLoginError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            return L10n.text(.loginRequiresApproval, .english)
        case .notFound:
            return L10n.text(.loginNotFound, .english)
        case .registrationFailed(let message, let status):
            return L10n.loginRegisterFailed(status: status, message: message, language: .english)
        case .registrationDidNotEnable(let status):
            return L10n.loginRegisterFailed(
                status: status,
                message: L10n.text(.loginRegisterNoEffect, .english),
                language: .english
            )
        case .removalFailed(let message, let status):
            return L10n.loginRemoveFailed(status: status, message: message, language: .english)
        }
    }
}

/// `SMAppService.mainApp`. Registration is not stored as a separate UserDefaults flag.
@MainActor
enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func enable() throws {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            return
        }
        do {
            try service.register()
        } catch {
            throw LaunchAtLoginError.registrationFailed(
                message: error.localizedDescription,
                status: statusName(service.status)
            )
        }
        switch service.status {
        case .enabled:
            return
        case .requiresApproval:
            throw LaunchAtLoginError.requiresApproval
        case .notFound:
            throw LaunchAtLoginError.notFound
        case .notRegistered:
            throw LaunchAtLoginError.registrationDidNotEnable(status: statusName(service.status))
        @unknown default:
            return
        }
    }

    static func disable() throws {
        let service = SMAppService.mainApp
        switch service.status {
        case .notRegistered, .notFound:
            return
        case .enabled, .requiresApproval:
            do {
                try service.unregister()
            } catch {
                throw LaunchAtLoginError.removalFailed(
                    message: error.localizedDescription,
                    status: statusName(service.status)
                )
            }
        @unknown default:
            do {
                try service.unregister()
            } catch {
                throw LaunchAtLoginError.removalFailed(
                    message: error.localizedDescription,
                    status: statusName(service.status)
                )
            }
        }
    }

    private static func statusName(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered:
            return "notRegistered"
        case .enabled:
            return "enabled"
        case .requiresApproval:
            return "requiresApproval"
        case .notFound:
            return "notFound"
        @unknown default:
            return "unknown"
        }
    }
}
