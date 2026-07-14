import Foundation
import SwiftUI
import UserNotifications

enum UsageChangeNotifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func describeChange(
        from previous: DashboardSnapshot,
        to updated: DashboardSnapshot,
        language: ResolvedLanguage
    ) -> String {
        var parts: [String] = []

        let oldPercent = previous.usageLimit?.cyclePercentUsed
        let newPercent = updated.usageLimit?.cyclePercentUsed
        if let newPercent, oldPercent != newPercent {
            let oldText = UsageAnalytics.formatPercent(oldPercent)
            let newText = UsageAnalytics.formatPercent(newPercent)
            parts.append(
                String(
                    format: L10n.string(.changeBilling, language: language),
                    locale: language.locale,
                    oldText,
                    newText
                )
            )
        }

        let oldCost = previous.displayTotalCostCents
        let newCost = updated.displayTotalCostCents
        if let newCost, oldCost != newCost {
            let oldText = oldCost.map { String(format: "$%.2f", $0 / 100) } ?? "—"
            let newText = String(format: "$%.2f", newCost / 100)
            parts.append(
                String(
                    format: L10n.string(.changeSpend, language: language),
                    locale: language.locale,
                    oldText,
                    newText
                )
            )
        }

        let oldEvents = previous.totalEventCount
        let newEvents = updated.totalEventCount
        if oldEvents != newEvents {
            parts.append(
                String(
                    format: L10n.string(.changeEvents, language: language),
                    locale: language.locale,
                    oldEvents,
                    newEvents
                )
            )
        }

        if parts.isEmpty, previous.dailySpend.count != updated.dailySpend.count {
            parts.append(
                String(
                    format: L10n.string(.changeDailyChart, language: language),
                    locale: language.locale,
                    updated.dailySpend.count
                )
            )
        }

        if parts.isEmpty {
            return L10n.string(.changeDefault, language: language)
        }
        return parts.joined(separator: " · ")
    }

    static func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "cursor-usage-change-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

struct UsageChangeAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ChangeBannerView: View {
    let alert: UsageChangeAlert
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(.orange)
                .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.caption.weight(.semibold))
                Text(alert.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PanelStyle.padding)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }
}
