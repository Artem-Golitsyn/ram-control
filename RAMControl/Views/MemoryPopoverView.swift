import AppKit
import SwiftUI

struct MemoryPopoverView: View {
    var viewModel: MemoryViewModel
    @Environment(\.openSettings) private var openSettings

    private var language: AppLanguage {
        viewModel.language
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            availableBlock
            usageBlock
            metrics
            Divider()
            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            actionRow
        }
        .padding(16)
        .frame(width: Constants.popoverWidth)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(L10n.text(.memory, language))
                .font(.headline)
            Spacer()
            Text(viewModel.pressureState.title(language: language))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(badgeForeground)
                .background(badgeBackground, in: Capsule())
        }
    }

    private var availableBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.text(.available, language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(availableText)
                .font(.system(size: 32, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: availableText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(L10n.physicalRAM(totalText, language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var usageBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            MemoryUsageBar(usedFraction: usedFraction, tint: barTint, language: language)
            HStack {
                Text(L10n.text(.used, language))
                Spacer()
                Text(L10n.text(.available, language))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            if viewModel.historyGraphEnabled {
                MemoryHistoryChart(
                    samples: viewModel.memoryHistory.samples,
                    window: viewModel.historyWindow.seconds,
                    now: viewModel.historyReferenceDate,
                    unit: viewModel.unit,
                    language: language,
                    minutes: viewModel.historyWindow.rawValue
                )
                .padding(.top, 4)
            }
        }
    }

    private var metrics: some View {
        VStack(spacing: 6) {
            metricRow(L10n.text(.available, language), availableText)
            metricRow(L10n.text(.used, language), usedText)
            metricRow(L10n.text(.active, language), bytesText(\.activeBytes))
            metricRow(L10n.text(.inactive, language), bytesText(\.inactiveBytes))
            metricRow(L10n.text(.wired, language), bytesText(\.wiredBytes))
            metricRow(L10n.text(.compressed, language), bytesText(\.compressedBytes))
            metricRow(L10n.text(.purgeable, language), bytesText(\.purgeableBytes))
            metricRow(L10n.text(.swapUsed, language), bytesText(\.swapUsedBytes))
        }
    }

    private var actionRow: some View {
        HStack {
            Button(L10n.text(.settings, language)) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(80))
                    SettingsWindowOpener.orderFront()
                }
            }
            .keyboardShortcut(",", modifiers: .command)

            Spacer()

            Button(L10n.text(.quit, language)) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .controlSize(.small)
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
        }
        .font(.callout)
    }

    private var availableText: String {
        guard let stats = viewModel.displayStats else { return "—" }
        return viewModel.format(bytes: stats.availableBytes)
    }

    private var usedText: String {
        guard let stats = viewModel.displayStats else { return "—" }
        return viewModel.format(bytes: stats.usedBytes)
    }

    private var totalText: String {
        guard let stats = viewModel.displayStats else { return "—" }
        return viewModel.format(bytes: stats.totalBytes)
    }

    private func bytesText(_ keyPath: KeyPath<MemoryStats, UInt64>) -> String {
        guard let stats = viewModel.displayStats else { return "—" }
        return viewModel.format(bytes: stats[keyPath: keyPath])
    }

    private var usedFraction: Double {
        guard let stats = viewModel.displayStats, stats.totalBytes > 0 else { return 0 }
        return Double(stats.usedBytes) / Double(stats.totalBytes)
    }

    private var valueColor: Color {
        PressureStyle.valueColor
    }

    private var barTint: Color {
        PressureStyle.panelBarColor(for: viewModel.pressureState)
    }

    private var badgeForeground: Color {
        guard viewModel.pressureState != .unavailable else { return .primary }
        return barTint
    }

    private var badgeBackground: Color {
        guard viewModel.pressureState != .unavailable else {
            return Color.secondary.opacity(0.15)
        }
        return badgeForeground.opacity(0.18)
    }
}

@MainActor
enum SettingsWindowOpener {
    static func orderFront() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows {
            let style = window.styleMask
            let isSettingsWindow = style.contains(.titled)
                && style.contains(.closable)
                && !style.contains(.nonactivatingPanel)
            if isSettingsWindow {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
