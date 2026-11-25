import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: MemoryViewModel
    @State private var warningText = ""
    @State private var criticalText = ""
    @State private var thresholdFeedback: ThresholdFeedback?
    @State private var isApplyingThresholdEdit = false

    var body: some View {
        let language = viewModel.language
        settingsForm(language: language)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    Button(L10n.text(.resetSettings, language)) {
                        viewModel.resetPreferences()
                        syncThresholdFields(clearMessage: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
            .frame(width: Constants.settingsWidth)
        .onAppear {
            viewModel.refreshLaunchAtLoginStatus()
            syncThresholdFields(clearMessage: true)
        }
        .onChange(of: viewModel.thresholds) { _, _ in
            guard !isApplyingThresholdEdit else { return }
            syncThresholdFields(clearMessage: false)
        }
        .onChange(of: warningText) { _, _ in
            commitThresholdText()
        }
        .onChange(of: criticalText) { _, _ in
            commitThresholdText()
        }
    }

    private func settingsForm(language: AppLanguage) -> some View {
        Form {
            Section(L10n.text(.general, language)) {
                Toggle(
                    L10n.text(.launchAtLogin, language),
                    isOn: Binding(
                        get: { viewModel.launchAtLoginEnabled },
                        set: { viewModel.setLaunchAtLogin($0) }
                    )
                )
                if let launchAtLoginError = viewModel.launchAtLoginError {
                    Text(launchAtLoginError.userMessage(language: language))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                Picker(L10n.text(.updateInterval, language), selection: $viewModel.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.label(language: language)).tag(interval)
                    }
                }
            }

            Section(L10n.text(.appearance, language)) {
                Picker(L10n.text(.showPanel, language), selection: $viewModel.panelDisplay) {
                    ForEach(PanelDisplay.allCases) { mode in
                        Text(mode.label(language: language)).tag(mode)
                    }
                }
                Picker(L10n.text(.language, language), selection: $viewModel.language) {
                    ForEach(AppLanguage.allCases) { item in
                        Text(item.nativeName).tag(item)
                    }
                }
                Picker(L10n.text(.units, language), selection: $viewModel.unit) {
                    Text("GB").tag(MemoryUnit.gb)
                    Text("GiB").tag(MemoryUnit.gib)
                }
                Toggle(L10n.text(.showMemoryGraph, language), isOn: $viewModel.historyGraphEnabled)
                Picker(L10n.text(.graphPeriod, language), selection: $viewModel.historyWindow) {
                    ForEach(HistoryWindow.allCases) { window in
                        Text(window.label(language: language)).tag(window)
                    }
                }
                .disabled(!viewModel.historyGraphEnabled)
            }

            Section(L10n.text(.memoryThresholds, language)) {
                Text(L10n.text(.thresholdHelp, language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LabeledContent(L10n.text(.warning, language)) {
                    percentField($warningText)
                }
                LabeledContent(L10n.text(.critical, language)) {
                    percentField($criticalText)
                }
                if let thresholdFeedback {
                    Text(thresholdFeedback.message(language: language))
                        .font(.caption)
                        .foregroundStyle(thresholdFeedback.isError ? Color.red : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section(L10n.text(.about, language)) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.aboutVersion(AppInfo.version, language))
                    Text(L10n.aboutAuthor(language))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
    }

    private func percentField(_ text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            TextField("30", text: text)
                .frame(width: 56)
                .multilineTextAlignment(.trailing)
            Text("%")
                .foregroundStyle(.secondary)
        }
    }

    private func syncThresholdFields(clearMessage: Bool) {
        isApplyingThresholdEdit = true
        warningText = String(viewModel.thresholds.warningPercent)
        criticalText = String(viewModel.thresholds.criticalPercent)
        if clearMessage {
            thresholdFeedback = nil
        }
        isApplyingThresholdEdit = false
    }

    private func commitThresholdText() {
        guard !isApplyingThresholdEdit else { return }
        let warningRaw = warningText.trimmingCharacters(in: .whitespaces)
        let criticalRaw = criticalText.trimmingCharacters(in: .whitespaces)
        guard let warning = Int(warningRaw), let critical = Int(criticalRaw) else {
            thresholdFeedback = .invalidInput
            return
        }

        isApplyingThresholdEdit = true
        let result = viewModel.commitThresholds(warningPercent: warning, criticalPercent: critical)
        switch result {
        case .saved(let updated):
            warningText = String(updated.warningPercent)
            criticalText = String(updated.criticalPercent)
            thresholdFeedback = nil
        case .savedClamped(let updated, let notice):
            warningText = String(updated.warningPercent)
            criticalText = String(updated.criticalPercent)
            thresholdFeedback = .info(notice)
        case .rejected(let notice, let warningPercent, let criticalPercent):
            warningText = String(warningPercent)
            criticalText = String(criticalPercent)
            thresholdFeedback = .error(notice)
        }
        isApplyingThresholdEdit = false
    }
}

private enum ThresholdFeedback: Equatable {
    case info(ThresholdNotice)
    case error(ThresholdNotice)
    case invalidInput

    var isError: Bool {
        switch self {
        case .info:
            return false
        case .error, .invalidInput:
            return true
        }
    }

    func message(language: AppLanguage) -> String {
        switch self {
        case .info(let notice), .error(let notice):
            return notice.message(language: language)
        case .invalidInput:
            return L10n.text(.enterWholeNumbers, language)
        }
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.4"
    }
}
