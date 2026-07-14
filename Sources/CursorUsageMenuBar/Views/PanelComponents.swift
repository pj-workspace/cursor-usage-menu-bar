import SwiftUI

enum PanelStyle {
    static let width: CGFloat = 340
    static let dashboardWidth: CGFloat = 400
    static let cornerRadius: CGFloat = 10
    static let sectionSpacing: CGFloat = 10
    static let padding: CGFloat = 14
}

struct PanelCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: PanelStyle.cornerRadius))
    }
}

struct PanelRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct PanelToolbar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(.background.secondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.headline)

            Spacer()

            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, PanelStyle.padding)
        .padding(.vertical, 10)
    }
}

struct StatusBadge: View {
    let text: String
    let isActive: Bool

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12))
            .foregroundStyle(isActive ? .green : .secondary)
            .clipShape(Capsule())
    }
}
