import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @ObservedObject var viewModel: UsageViewModel
    var onClose: (() -> Void)?
    @State private var tokenInput = ""
    @State private var showToken = false
    @State private var tokenConfigured = false

    var body: some View {
        VStack(spacing: 0) {
            if let onClose {
                PanelToolbar(title: l10n.t(.settingsTitle), onBack: onClose)
                Divider()
            }

            VStack(alignment: .leading, spacing: PanelStyle.sectionSpacing) {
                instructionCard
                tokenCard
                refreshCard
                languageCard
                statusCard
                Button(l10n.t(.quitApp)) { AppLifecycle.quit() }
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)
            }
            .padding(PanelStyle.padding)
        }
        .frame(width: PanelStyle.width)
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            tokenConfigured = viewModel.hasToken
        }
        .onChange(of: tokenInput) { _, newValue in
            if tokenConfigured, !newValue.isEmpty {
                tokenConfigured = false
            }
        }
    }

    private var instructionCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.caption)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.t(.tokenInstruction))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link(l10n.t(.openDashboardLink), destination: URL(string: "https://cursor.com/dashboard/usage")!)
                    .font(.caption)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PanelStyle.cornerRadius))
    }

    private var tokenCard: some View {
        PanelCard(title: l10n.t(.sessionToken)) {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    if showToken {
                        TextField("WorkosCursorSessionToken", text: $tokenInput, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2 ... 4)
                    } else {
                        SecureField("WorkosCursorSessionToken", text: $tokenInput)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                HStack {
                    Toggle(l10n.t(.showToken), isOn: $showToken)
                        .font(.caption)
                        .toggleStyle(.checkbox)
                    Spacer()
                    if tokenConfigured {
                        Label(l10n.t(.tokenSaved), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        viewModel.saveToken(tokenInput)
                        if viewModel.hasToken {
                            tokenConfigured = true
                            tokenInput = ""
                        }
                    } label: {
                        Text(l10n.t(.save))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(
                        tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || tokenConfigured
                    )

                    Button(l10n.t(.clear), role: .destructive) {
                        tokenInput = ""
                        tokenConfigured = false
                        viewModel.clearToken()
                    }
                    .controlSize(.regular)
                    .disabled(!viewModel.hasToken)
                }
            }
        }
    }

    private var refreshCard: some View {
        PanelCard(title: l10n.t(.autoRefresh)) {
            VStack(alignment: .leading, spacing: 6) {
                PanelRow(label: l10n.t(.requestInterval), value: l10n.t(.requestIntervalValue))
                Text(l10n.t(.pacerHint))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var languageCard: some View {
        PanelCard(title: l10n.t(.language)) {
            Picker(l10n.t(.language), selection: $l10n.preference) {
                ForEach(LocalizationManager.Preference.allCases) { preference in
                    Text(preference.displayName(language: l10n.resolved)).tag(preference)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusCard: some View {
        PanelCard(title: l10n.t(.status)) {
            VStack(spacing: 8) {
                HStack {
                    Text(l10n.t(.token))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    StatusBadge(
                        text: viewModel.hasToken ? l10n.t(.configured) : l10n.t(.notConfigured),
                        isActive: viewModel.hasToken
                    )
                }

                if let lastUpdated = viewModel.lastUpdated {
                    Divider()
                    PanelRow(
                        label: l10n.t(.lastRefresh),
                        value: lastUpdated.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
        }
    }
}
