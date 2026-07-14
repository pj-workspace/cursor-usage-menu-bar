import SwiftUI

struct MenuContentView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(viewModel: viewModel, onClose: { showSettings = false })
            } else {
                DashboardView(viewModel: viewModel, showSettings: $showSettings)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}
