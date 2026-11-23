import AppKit
import SwiftUI

enum PressureStyle {
    /// Usage bar and the state badge. Numbers on the panel stay gray.
    /// Above the warning threshold the bar is gray. Between the thresholds it is yellow.
    /// At or below the critical threshold it is red.
    static func panelColor(for state: MemoryPressureState) -> Color {
        switch state {
        case .normal:
            return Color(nsColor: .systemGray)
        case .warning:
            return .yellow
        case .critical:
            return .red
        case .unavailable:
            return .primary
        }
    }

    static func panelBarColor(for state: MemoryPressureState) -> Color {
        guard state != .unavailable else { return .accentColor }
        return panelColor(for: state)
    }

    static var valueColor: Color {
        Color(nsColor: .systemGray)
    }
}
