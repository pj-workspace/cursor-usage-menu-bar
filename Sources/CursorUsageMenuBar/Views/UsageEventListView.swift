import SwiftUI

private enum UsageSourceFilter: String, CaseIterable, Identifiable {
    case all
    case cloudAgent
    case local

    var id: String { rawValue }

    func title(language: ResolvedLanguage) -> String {
        switch self {
        case .all:
            return L10n.string(.sourceAll, language: language)
        case .cloudAgent:
            return L10n.string(.sourceCloudAgent, language: language)
        case .local:
            return L10n.string(.sourceLocal, language: language)
        }
    }
}

struct UsageEventListView: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let cachedEvents: [UsageEvent]?
    let availableModels: [String]
    let events: [UsageEvent]
    let totalCount: Int
    let currentPage: Int
    let totalPages: Int
    let pageSize: Int
    let isLoading: Bool
    var forceLocalPaging: Bool = false
    let onPageChange: (Int) -> Void

    @State private var searchText = ""
    @State private var selectedModel = L10n.allModelsMarker
    @State private var selectedSource: UsageSourceFilter = .all
    @State private var filterPage = 1
    @State private var expandedEventID: String?

    private var modelOptions: [String] {
        [L10n.allModelsMarker] + availableModels
    }

    private var isGlobalFilterActive: Bool {
        forceLocalPaging
            || selectedModel != L10n.allModelsMarker
            || selectedSource != .all
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canFilterGlobally: Bool {
        guard let cachedEvents, !cachedEvents.isEmpty else { return false }
        return true
    }

    private var globallyFilteredEvents: [UsageEvent] {
        guard let cachedEvents else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return cachedEvents.filter { event in
            let matchesModel = selectedModel == L10n.allModelsMarker || event.model == selectedModel
            guard matchesModel else { return false }
            switch selectedSource {
            case .all:
                break
            case .cloudAgent:
                guard event.isCloudAgent else { return false }
            case .local:
                guard !event.isCloudAgent else { return false }
            }
            guard !query.isEmpty else { return true }
            let haystack = [
                event.model,
                event.kind,
                event.cloudAgentId,
                event.conversationId,
                event.kindLabel(language: l10n.resolved),
                event.formattedTime,
                event.formattedCost,
                event.formattedTotalTokens,
            ]
            .compactMap { $0 }
            .map { $0.lowercased() }
            return haystack.contains { $0.contains(query) }
        }
    }

    private var activeTotalCount: Int {
        if isGlobalFilterActive, canFilterGlobally {
            return globallyFilteredEvents.count
        }
        return totalCount
    }

    private var activePage: Int {
        isGlobalFilterActive && canFilterGlobally ? filterPage : currentPage
    }

    private var activeTotalPages: Int {
        max(1, Int(ceil(Double(activeTotalCount) / Double(pageSize))))
    }

    private var displayedEvents: [UsageEvent] {
        if isGlobalFilterActive, canFilterGlobally {
            return UsageEventsPage.slice(
                from: globallyFilteredEvents,
                totalCount: globallyFilteredEvents.count,
                page: filterPage,
                pageSize: pageSize
            ).events
        }
        return events
    }

    private var displayStartIndex: Int {
        guard activeTotalCount > 0 else { return 0 }
        return (activePage - 1) * pageSize + 1
    }

    private var displayEndIndex: Int {
        min(activePage * pageSize, activeTotalCount)
    }

    private var statusLine: String {
        if isGlobalFilterActive, canFilterGlobally {
            return l10n.format(.filterStatus, activeTotalCount, activePage, activeTotalPages)
        }
        if isGlobalFilterActive, !canFilterGlobally {
            return l10n.format(.waitingCache, totalCount)
        }
        return l10n.format(.listStatus, totalCount, currentPage, totalPages)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isLoading, !isGlobalFilterActive || !canFilterGlobally {
                    ProgressView().controlSize(.mini)
                }
                Spacer()
                if activeTotalCount > 0 {
                    Text("\(displayStartIndex)-\(displayEndIndex)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 8) {
                TextField(
                    canFilterGlobally ? l10n.t(.searchAll) : l10n.t(.searchPage),
                    text: $searchText
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)

                Picker(l10n.t(.sourceFilter), selection: $selectedSource) {
                    ForEach(UsageSourceFilter.allCases) { source in
                        Text(source.title(language: l10n.resolved)).tag(source)
                    }
                }
                .labelsHidden()
                .frame(width: 108)

                Picker(l10n.t(.model), selection: $selectedModel) {
                    ForEach(modelOptions, id: \.self) { model in
                        Text(model == L10n.allModelsMarker ? l10n.t(.allModels) : model).tag(model)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }

            if isGlobalFilterActive, !canFilterGlobally {
                EventListEmptyState(message: l10n.t(.loadingFullDetails))
            } else if displayedEvents.isEmpty {
                EventListEmptyState(message: emptyMessage)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(displayedEvents) { event in
                        UsageEventRow(
                            event: event,
                            isExpanded: expandedEventID == event.id,
                            onToggle: {
                                expandedEventID = expandedEventID == event.id ? nil : event.id
                            }
                        )

                        if event.id != displayedEvents.last?.id {
                            Divider()
                                .padding(.leading, 8)
                        }
                    }
                }
            }

            paginationBar
        }
        .onChange(of: currentPage) { _, _ in
            expandedEventID = nil
        }
        .onChange(of: selectedModel) { _, _ in
            filterPage = 1
            expandedEventID = nil
        }
        .onChange(of: selectedSource) { _, _ in
            filterPage = 1
            expandedEventID = nil
        }
        .onChange(of: searchText) { _, _ in
            filterPage = 1
            expandedEventID = nil
        }
        .onChange(of: availableModels) { _, models in
            if selectedModel != L10n.allModelsMarker, !models.contains(selectedModel) {
                selectedModel = L10n.allModelsMarker
            }
        }
    }

    private var emptyMessage: String {
        if events.isEmpty, (cachedEvents?.isEmpty ?? true) {
            return l10n.t(.noUsageEvents)
        }
        if isGlobalFilterActive {
            return l10n.t(.noMatchingEvents)
        }
        return l10n.t(.noPageRecords)
    }

    private var paginationBar: some View {
        HStack(spacing: 10) {
            Button {
                goToPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(activePage <= 1 || isPaginationDisabled)

            Text(l10n.format(.pageNumber, activePage))
                .font(.caption.weight(.medium))
                .monospacedDigit()

            Button {
                goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(activePage >= activeTotalPages || isPaginationDisabled)

            Spacer()

            Button(l10n.t(.firstPage)) { goToPage(1) }
                .controlSize(.small)
                .disabled(activePage <= 1 || isPaginationDisabled)

            Button(l10n.t(.lastPage)) { goToPage(activeTotalPages) }
                .controlSize(.small)
                .disabled(activePage >= activeTotalPages || isPaginationDisabled)
        }
        .font(.caption)
    }

    private var isPaginationDisabled: Bool {
        if isGlobalFilterActive, !canFilterGlobally { return true }
        if isGlobalFilterActive, canFilterGlobally { return false }
        return isLoading
    }

    private func goToPreviousPage() {
        goToPage(activePage - 1)
    }

    private func goToNextPage() {
        goToPage(activePage + 1)
    }

    private func goToPage(_ page: Int) {
        let target = max(1, min(page, activeTotalPages))
        if isGlobalFilterActive, canFilterGlobally {
            filterPage = target
            expandedEventID = nil
        } else {
            onPageChange(target)
        }
    }
}

private struct ModelBillingRulesSection: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let model: String
    let eventDate: Date?
    let billingContext: String?

    private var rule: ModelPricingCatalog.Rule {
        ModelPricingCatalog.rule(for: model, at: eventDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text(l10n.t(.pricingRules))
                    .font(.caption.weight(.semibold))
                Spacer()
                Link(l10n.t(.officialDocs), destination: ModelPricingCatalog.docsURL)
                    .font(.caption2)
            }

            VStack(alignment: .leading, spacing: 4) {
                detailLine(l10n.t(.model), rule.displayName)
                if let provider = rule.provider {
                    detailLine(l10n.t(.provider), provider)
                }
                detailLine(l10n.t(.billingPool), rule.pool.label(language: l10n.resolved))

                ForEach(rule.rateLines(language: l10n.resolved), id: \.self) { line in
                    Text(line)
                        .font(.caption2)
                        .monospacedDigit()
                }

                Text(rule.pool.summary(language: l10n.resolved))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let billingContext {
                    Text(billingContext)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let notes = rule.notes {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(l10n.t(.teamsTokenFee))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.caption2.weight(.medium))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TokenCalculatedCostSection: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let estimate: ModelPricingCatalog.TokenCostEstimate
    let actualChargedCents: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.t(.calculatedPrice))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(estimate.components) { component in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(component.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Text(component.formulaText)
                        .font(.caption2)
                        .monospacedDigit()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(l10n.t(.calculatedTotal))
                    .font(.caption2.weight(.semibold))
                    .frame(width: 72, alignment: .leading)
                Text(estimate.formattedTotal)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            if let actualChargedCents {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(l10n.t(.actualCharge))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Text(formatActual(actualChargedCents))
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func formatActual(_ cents: Double) -> String {
        if cents < 1 { return String(format: "$%.4f", cents / 100) }
        return String(format: "$%.2f", cents / 100)
    }
}

private struct UsageEventRow: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let event: UsageEvent
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(event.model ?? event.simplifiedModel)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                            if event.isCloudAgent {
                                StatusBadge(
                                    text: l10n.t(.cloudAgentBadge),
                                    isActive: true
                                )
                            }
                            StatusBadge(
                                text: event.kindLabel(language: l10n.resolved),
                                isActive: event.isChargeable ?? true
                            )
                        }
                        Text(event.formattedTime)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(event.formattedCost)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                        if let tokens = event.formattedTotalTokens {
                            Text("\(tokens) tok")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ModelBillingRulesSection(
                        model: event.model ?? event.simplifiedModel,
                        eventDate: event.eventDate,
                        billingContext: ModelPricingCatalog.billingContext(for: event, language: l10n.resolved)
                    )

                    if let model = event.model, model != event.simplifiedModel {
                        detailRow(l10n.t(.fullModel), model)
                    }
                    detailRow(l10n.t(.type), event.kind)
                    if let subscription = event.subscriptionProductId {
                        detailRow(l10n.t(.subscription), subscription)
                    }
                    if let conversationId = event.conversationId {
                        detailRow(l10n.t(.conversationId), conversationId)
                    }
                    if let cloudAgentId = event.cloudAgentId, !cloudAgentId.isEmpty {
                        detailRow(l10n.t(.cloudAgentId), cloudAgentId)
                    }
                    if let tokenUsage = event.tokenUsage {
                        detailRow(l10n.t(.inputTokens), UsageEvent.formatTokenCount(tokenUsage.inputTokens))
                        detailRow(l10n.t(.outputTokens), UsageEvent.formatTokenCount(tokenUsage.outputTokens))
                        if let cacheRead = tokenUsage.cacheReadTokens, cacheRead > 0 {
                            detailRow(l10n.t(.cacheRead), UsageEvent.formatTokenCount(cacheRead))
                        }
                        if let cacheWrite = tokenUsage.cacheWriteTokens, cacheWrite > 0 {
                            detailRow(l10n.t(.cacheWrite), UsageEvent.formatTokenCount(cacheWrite))
                        }

                        if let estimate = ModelPricingCatalog.estimatedCost(
                            for: event.model ?? event.simplifiedModel,
                            tokenUsage: tokenUsage,
                            at: event.eventDate
                        ) {
                            TokenCalculatedCostSection(
                                estimate: estimate,
                                actualChargedCents: event.chargedCents
                            )
                        } else if let totalCents = tokenUsage.totalCents {
                            detailRow(l10n.t(.tokenFee), String(format: "$%.4f", totalCents / 100))
                        }
                    }
                    if event.totalTokens > 0 {
                        detailRow(l10n.t(.tokenTotal), UsageEvent.formatTokenCount(event.totalTokens))
                    }
                    if let isTokenBasedCall = event.isTokenBasedCall {
                        detailRow(
                            l10n.t(.tokenBasedBilling),
                            isTokenBasedCall ? l10n.t(.yes) : l10n.t(.no)
                        )
                    }
                    if let usageBasedCosts = event.usageBasedCosts,
                       usageBasedCosts != "-",
                       usageBasedCosts != event.formattedCost {
                        detailRow(l10n.t(.usageBasedCosts), usageBasedCosts)
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 8)
    }

    private func detailRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value ?? "—")
                .font(.caption2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct EventListEmptyState: View {
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "list.bullet.rectangle")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
    }
}
