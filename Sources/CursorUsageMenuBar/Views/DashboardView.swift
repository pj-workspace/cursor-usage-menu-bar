import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @ObservedObject var viewModel: UsageViewModel
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let banner = viewModel.changeBanner {
                ChangeBannerView(alert: banner) {
                    viewModel.dismissChangeBanner()
                }
                Divider()
            }

            header
            Divider()
            tabPicker
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: PanelStyle.sectionSpacing) {
                    if !viewModel.hasToken {
                        setupCard
                    } else {
                        switch viewModel.selectedTab {
                        case .overview:
                            overviewTab
                        case .charts:
                            chartsTab
                        case .included:
                            includedTab
                        case .events:
                            eventsTab
                        case .account:
                            accountTab
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    footer
                }
                .padding(PanelStyle.padding)
            }
            .frame(maxHeight: 680)
        }
        .frame(width: PanelStyle.dashboardWidth)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t(.dashboardTitle))
                    .font(.headline)
                Text(viewModel.membershipLabel())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            dayFilterControl
            if viewModel.isInitialLoading {
                ProgressView().controlSize(.small)
            } else if let percent = viewModel.dashboard.usageLimit?.cyclePercentUsed
                ?? viewModel.summary?.billingPlan?.totalPercentUsed
                ?? viewModel.dashboard.periodUsage?.planUsage?.totalPercentUsed {
                Text("\(Int(percent.rounded()))%")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, PanelStyle.padding)
        .padding(.vertical, 10)
    }

    private var dayFilterControl: some View {
        Menu {
            Button(l10n.t(.dayFilterAll)) {
                viewModel.clearDayFilter()
            }
            if !viewModel.availableDays.isEmpty {
                Divider()
                ForEach(viewModel.availableDays, id: \.self) { day in
                    Button(day.formatted(.dateTime.month().day().weekday(.abbreviated).locale(l10n.resolved.locale))) {
                        viewModel.selectDay(day)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(viewModel.formattedSelectedDayLabel(language: l10n.resolved))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DashboardTab.allCases) { tab in
                    tabChip(tab)
                }
            }
            .padding(.horizontal, PanelStyle.padding)
            .padding(.vertical, 8)
        }
    }

    private func tabChip(_ tab: DashboardTab) -> some View {
        let selected = viewModel.selectedTab == tab
        return Button {
            viewModel.selectedTab = tab
        } label: {
            Label(tab.title(language: l10n.resolved), systemImage: tab.icon)
                .font(.caption.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overview

    private var overviewTab: some View {
        Group {
            PanelCard(title: viewModel.isDayFilterActive ? l10n.t(.dayStats) : l10n.t(.today)) {
                todayStatsContent
            }

            cloudAgentUsageCard

            if !viewModel.isDayFilterActive {
                PanelCard(title: l10n.t(.cycleUsage)) {
                    cycleSummaryContent
                }
            }
        }
    }

    @ViewBuilder
    private var cloudAgentUsageCard: some View {
        PanelCard(title: l10n.t(.cloudAgentUsage)) {
            if viewModel.isCloudAgentStatsPending {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(l10n.t(.cloudAgentLoadingHint))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.displayedCloudAgentUsage.hasData {
                cloudAgentUsageContent(viewModel.displayedCloudAgentUsage)
            } else {
                Text(l10n.t(.cloudAgentEmpty))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cloudAgentUsageContent(_ usage: CloudAgentUsageSummary) -> some View {
        VStack(spacing: 8) {
            PanelRow(label: l10n.t(.requestCount), value: "\(usage.eventCount)")
            PanelRow(
                label: l10n.t(.spend),
                value: viewModel.formattedCurrencyFromCents(usage.totalChargedCents)
            )
            PanelRow(label: l10n.t(.token), value: formatTokens(usage.totalTokens))
            PanelRow(label: l10n.t(.uniqueCloudAgents), value: "\(usage.uniqueAgentCount)")

            if !usage.topModels.isEmpty {
                Divider().padding(.vertical, 2)
                Text(l10n.t(.cloudAgentTopModels))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(usage.topModels) { slice in
                    PanelRow(
                        label: slice.model,
                        value: "\(slice.count) · \(viewModel.formattedCurrencyFromCents(slice.cents))"
                    )
                }
            }
        }
    }

    private var todayStatsContent: some View {
        VStack(spacing: 8) {
            if let todayPercent = viewModel.displayedDayStats.dailyPercent {
                HStack {
                    Text(l10n.t(.todayBillingPercent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(UsageAnalytics.formatPercent(todayPercent))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(todayPercent >= 10 ? .orange : .green)
                }
                if let limit = viewModel.dashboard.usageLimit {
                    PanelRow(
                        label: l10n.t(.todayUsage),
                        value: limit.formatDailyUsage(viewModel.displayedDayStats.usageUnits)
                    )
                }
            }
            PanelRow(label: l10n.t(.requestCount), value: "\(viewModel.displayedDayStats.eventCount)")
            PanelRow(
                label: l10n.t(.spend),
                value: viewModel.formattedCurrencyFromCents(viewModel.displayedDayStats.totalChargedCents)
            )
            PanelRow(label: l10n.t(.token), value: formatTokens(viewModel.displayedDayStats.totalTokens))
        }
    }

    private var cycleSummaryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let limit = viewModel.dashboard.usageLimit {
                HStack {
                    Text(l10n.t(.billingTotal))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(UsageAnalytics.formatPercent(limit.cyclePercentUsed))
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                    if let cost = viewModel.dashboard.displayTotalCostCents {
                        Text("· \(viewModel.formattedCurrencyFromCents(cost))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            UsagePoolsView(pools: viewModel.dashboard.usagePools)

            VStack(alignment: .leading, spacing: 8) {
                PanelRow(label: l10n.t(.cycleTotalSpend), value: viewModel.formattedTotalCost())
                PanelRow(
                    label: l10n.t(.apiUsed),
                    value: viewModel.formattedCurrencyFromCents(
                        viewModel.dashboard.usagePools.first(where: { $0.id == "api" })?.usedCents
                    )
                )
                PanelRow(
                    label: l10n.t(.autoBonusSpend),
                    value: viewModel.formattedCurrencyFromCents(viewModel.autoPoolSpendCents)
                )
                PanelRow(
                    label: l10n.t(.apiIncludedLimit),
                    value: viewModel.formattedCurrencyFromCents(viewModel.summary?.planLimit)
                )
                PanelRow(label: l10n.t(.billingPeriod), value: viewModel.formattedBillingPeriod())
                PanelRow(label: l10n.t(.totalEvents), value: "\(viewModel.dashboard.totalEventCount)")
            }
        }
    }

    // MARK: - Charts

    private var chartsTab: some View {
        Group {
            if !viewModel.isDayFilterActive {
                PanelCard(title: l10n.t(.yourUsage)) {
                    cumulativeUsageSection
                }

                PanelCard(title: l10n.t(.quotaDeclineCurve)) {
                    quotaChartSection(emptyMessage: l10n.t(.emptyQuotaCurve)) {
                        QuotaDeclineChart(
                            data: viewModel.dashboard.quotaCurves,
                            limitContext: viewModel.dashboard.usageLimit
                        )
                    }
                }

                PanelCard(title: l10n.t(.dailyUsagePercent)) {
                    chartSection(emptyMessage: l10n.t(.emptyDailyUsage)) {
                        DailyUsagePercentChart(
                            data: viewModel.dashboard.dailySpend,
                            limitContext: viewModel.dashboard.usageLimit
                        )
                        DailyUsagePercentList(
                            data: viewModel.dashboard.dailySpend,
                            limitContext: viewModel.dashboard.usageLimit
                        )
                    }
                }

                PanelCard(title: l10n.t(.dailySpend)) {
                    chartSection(emptyMessage: l10n.t(.emptyDailySpend)) {
                        DailySpendChart(data: viewModel.dashboard.dailySpend)
                    }
                }
            }

            PanelCard(title: l10n.t(.dailyModelShare)) {
                if viewModel.displayedModelShareDay == nil {
                    chartPlaceholder(
                        emptyMessage: l10n.t(.emptyDailyModelShare),
                        showLoading: viewModel.isLoadingCharts,
                        error: viewModel.chartLoadError
                    )
                } else {
                    DailyModelUsageChart(day: viewModel.displayedModelShareDay)
                }
            }

            PanelCard(title: l10n.t(.modelSpendDistribution)) {
                ModelSpendChart(data: viewModel.displayedModelBreakdown)
            }
        }
    }

    private var cumulativeUsageSection: some View {
        Group {
            if viewModel.dashboard.cumulativeModelSpend.isEmpty {
                chartPlaceholder(
                    emptyMessage: l10n.t(.emptyCumulativeUsage),
                    showLoading: viewModel.isLoadingCharts,
                    error: viewModel.chartLoadError
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    SpendSummaryCards(summary: viewModel.dashboard.spendSummary)
                    CumulativeUsageChart(points: viewModel.dashboard.cumulativeModelSpend)
                }
            }
        }
    }

    // MARK: - Included

    private var includedTab: some View {
        Group {
            PanelCard(title: l10n.t(.includedUsage)) {
                if let includedUsage = viewModel.displayedIncludedUsage {
                    IncludedUsageTable(
                        summary: includedUsage,
                        billingPeriod: viewModel.isDayFilterActive
                            ? viewModel.formattedSelectedDayLabel(language: l10n.resolved)
                            : viewModel.formattedBillingPeriod(),
                        todayUsagePercent: viewModel.displayedDayStats.dailyPercent,
                        cycleUsagePercent: viewModel.dashboard.usageLimit?.cyclePercentUsed
                    )
                } else {
                    ChartEmptyState(message: l10n.t(.emptyIncludedUsage))
                }
            }

            if let tokenUsage = viewModel.dashboard.modelTokenUsage {
                PanelCard(title: l10n.t(.modelTokenUsage)) {
                    ModelTokenUsageTable(summary: tokenUsage)
                }
            } else if !viewModel.isDayFilterActive {
                PanelCard(title: l10n.t(.modelTokenUsage)) {
                    ChartEmptyState(message: l10n.t(.loadingAggregatedUsage))
                }
            }

            PanelCard(title: l10n.t(.quotaUsage)) {
                SpendingBreakdownChart(items: viewModel.dashboard.spendingBreakdown)
            }
        }
    }

    // MARK: - Events

    private var eventsTab: some View {
        PanelCard(title: l10n.t(.usageDetails)) {
            usageEventsList
        }
    }

    private var usageEventsList: some View {
        let useLocal = viewModel.isDayFilterActive || viewModel.cachedUsageEvents != nil
        let localEvents = viewModel.filteredUsageEvents
        return UsageEventListView(
            cachedEvents: useLocal ? localEvents : viewModel.cachedUsageEvents,
            availableModels: viewModel.availableUsageEventModels,
            events: useLocal
                ? Array(localEvents.prefix(viewModel.dashboard.usageEventsPageSize))
                : viewModel.dashboard.events,
            totalCount: useLocal ? localEvents.count : viewModel.dashboard.totalEventCount,
            currentPage: useLocal ? 1 : viewModel.dashboard.usageEventsPage,
            totalPages: useLocal
                ? max(1, Int(ceil(Double(localEvents.count) / Double(max(1, viewModel.dashboard.usageEventsPageSize)))))
                : viewModel.dashboard.usageEventsTotalPages,
            pageSize: viewModel.dashboard.usageEventsPageSize,
            isLoading: viewModel.isLoadingUsageEventsPage && !useLocal,
            forceLocalPaging: useLocal,
            onPageChange: { page in
                guard !useLocal else { return }
                Task { await viewModel.loadUsageEventsPage(page) }
            }
        )
    }

    // MARK: - Account

    private var accountTab: some View {
        Group {
            let profile = viewModel.dashboard.userProfile
            let auth = viewModel.dashboard.authMe
            let summary = viewModel.summary
            let period = viewModel.dashboard.periodUsage
            let limit = viewModel.dashboard.usageLimit

            PanelCard(title: l10n.t(.billingCycle)) {
                VStack(spacing: 8) {
                    PanelRow(
                        label: l10n.t(.billingUsage),
                        value: UsageAnalytics.formatPercent(limit?.cyclePercentUsed)
                    )
                    PanelRow(label: l10n.t(.cycleTotalSpend), value: viewModel.formattedTotalCost())
                    PanelRow(label: l10n.t(.billingPeriod), value: viewModel.formattedBillingPeriod())
                    PanelRow(
                        label: l10n.t(.includedLimit),
                        value: viewModel.formattedCurrencyFromCents(summary?.planLimit)
                    )
                }
            }

            PanelCard(title: l10n.t(.dualPoolStatus)) {
                VStack(spacing: 8) {
                    PanelRow(
                        label: l10n.t(.apiPool),
                        value: summary?.namedModelSelectedDisplayMessage
                            ?? period?.namedModelSelectedDisplayMessage
                            ?? "—"
                    )
                    PanelRow(
                        label: l10n.t(.autoComposer),
                        value: summary?.autoModelSelectedDisplayMessage
                            ?? period?.autoModelSelectedDisplayMessage
                            ?? "—"
                    )
                }
            }

            if let limitMessage = period?.displayMessage,
               limitMessage.localizedCaseInsensitiveContains("usage limit") {
                PanelCard(title: l10n.t(.quotaExplanation)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(limitMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(
                            l10n.format(
                                .quotaExplanationBody,
                                viewModel.formattedCurrencyFromCents(period?.planUsage?.limit),
                                UsageAnalytics.formatPercent(limit?.cyclePercentUsed)
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            PanelCard(title: l10n.t(.account)) {
                VStack(spacing: 8) {
                    PanelRow(
                        label: l10n.t(.user),
                        value: auth?.name ?? profile?.displayNameOrEmail ?? "—"
                    )
                    PanelRow(label: l10n.t(.email), value: auth?.email ?? "—")
                    PanelRow(label: l10n.t(.plan), value: viewModel.membershipLabel())
                    PanelRow(
                        label: l10n.t(.handle),
                        value: profile?.profile?.handle.map { "@\($0)" } ?? "—"
                    )
                }
            }

            PanelCard(title: l10n.t(.activeSessions)) {
                ActiveSessionsView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Shared

    private var setupCard: some View {
        PanelCard(title: l10n.t(.getStarted)) {
            VStack(alignment: .leading, spacing: 10) {
                Text(l10n.t(.setupTokenHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(l10n.t(.goToSettings)) { showSettings = true }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let lastUpdated = viewModel.lastUpdated {
                Text(l10n.format(.updatedAt, lastUpdated.formatted(date: .omitted, time: .shortened)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(l10n.t(.refresh)) { Task { await viewModel.refresh() } }
                .controlSize(.small)
                .disabled(viewModel.isInitialLoading || viewModel.isLoadingCharts)
            Button(l10n.t(.settings)) { showSettings = true }
                .controlSize(.small)
            Button(l10n.t(.quitApp)) { AppLifecycle.quit() }
                .controlSize(.small)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    @ViewBuilder
    private func chartSection<Content: View>(
        emptyMessage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if viewModel.dashboard.dailySpend.isEmpty {
            chartPlaceholder(
                emptyMessage: emptyMessage,
                showLoading: viewModel.isLoadingCharts,
                error: viewModel.chartLoadError
            )
        } else {
            content()
        }
    }

    @ViewBuilder
    private func quotaChartSection<Content: View>(
        emptyMessage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if viewModel.dashboard.quotaCurves.isEmpty {
            chartPlaceholder(
                emptyMessage: emptyMessage,
                showLoading: viewModel.isLoadingCharts,
                error: viewModel.chartLoadError
            )
        } else {
            content()
        }
    }

    @ViewBuilder
    private func chartPlaceholder(emptyMessage: String, showLoading: Bool, error: String?) -> some View {
        if showLoading {
            ChartLoadingState(message: l10n.t(.loadingChartData))
        } else if let error {
            ChartErrorState(message: error)
        } else {
            ChartEmptyState(message: emptyMessage)
        }
    }
}
