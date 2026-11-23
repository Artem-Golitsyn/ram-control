import SwiftUI

struct MenuBarLabel: View {
    var viewModel: MemoryViewModel

    var body: some View {
        Text(viewModel.menuBarText)
            .font(.system(size: 13, weight: .medium))
            .monospacedDigit()
            .accessibilityLabel(
                L10n.availableMemoryAccessibility(viewModel.menuBarText, viewModel.language)
            )
            .help(viewModel.pressureState.title(language: viewModel.language))
    }
}
