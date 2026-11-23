import SwiftUI

@main
struct RAMControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = MemoryViewModel()

    var body: some Scene {
        MenuBarExtra {
            MemoryPopoverView(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
        .defaultSize(width: 560, height: 820)
        .windowResizability(.contentSize)
    }
}
