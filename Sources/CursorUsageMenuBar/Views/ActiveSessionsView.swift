import SwiftUI

struct ActiveSessionsView: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @ObservedObject var viewModel: UsageViewModel

    @State private var pendingRevokeSession: AuthSession?

    private var sessions: [AuthSession] {
        viewModel.dashboard.activeSessions.sorted { lhs, rhs in
            (lhs.createdAt ?? "") > (rhs.createdAt ?? "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                Link(l10n.t(.openWebSessions), destination: sessionsSettingsURL)
                    .font(.caption2)
            }

            if sessions.isEmpty {
                Text(l10n.t(.sessionsEmpty))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    sessionRow(session)
                }
            }
        }
        .alert(l10n.t(.sessionRevoke), isPresented: revokeAlertBinding) {
            Button(l10n.t(.sessionRevoke), role: .destructive) {
                guard let session = pendingRevokeSession else { return }
                pendingRevokeSession = nil
                Task { await viewModel.revokeSession(session) }
            }
            Button(l10n.t(.cancel), role: .cancel) {
                pendingRevokeSession = nil
            }
        } message: {
            Text(l10n.t(.sessionRevokeConfirm))
        }
    }

    private var sessionsSettingsURL: URL {
        URL(string: "https://cursor.com/dashboard/settings#active-sessions")!
    }

    private var revokeAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingRevokeSession != nil },
            set: { if !$0 { pendingRevokeSession = nil } }
        )
    }

    @ViewBuilder
    private func sessionRow(_ session: AuthSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.kindLabel(language: l10n.resolved))
                        .font(.caption.weight(.semibold))
                    Text(
                        "\(l10n.t(.sessionCreated)) · \(session.formattedTimestamp(session.createdAt, language: l10n.resolved))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    Text(
                        "\(l10n.t(.sessionExpires)) · \(session.formattedTimestamp(session.expiresAt, language: l10n.resolved))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if viewModel.revokingSessionID == session.sessionId {
                    ProgressView().controlSize(.small)
                } else {
                    Button(l10n.t(.sessionRevoke)) {
                        pendingRevokeSession = session
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
