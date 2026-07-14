import SwiftUI

@main
struct CursorUsageMenuBarApp: App {
    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var localization = LocalizationManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(viewModel: viewModel)
                .environmentObject(localization)
        } label: {
            MenuBarLabel(viewModel: viewModel)
                .environmentObject(localization)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.menuBarSymbolName)
            Text(viewModel.menuBarTitle(language: l10n.resolved))
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
    }
}
