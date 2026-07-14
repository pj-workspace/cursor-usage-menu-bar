import Combine
import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var dashboard: DashboardSnapshot = .empty
    @Published private(set) var isInitialLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var hasToken: Bool
    @Published var selectedTab: DashboardTab = .usage

    @Published private(set) var isLoadingUsageEventsPage = false
    @Published private(set) var isLoadingCharts = false
    @Published private(set) var chartLoadError: String?

    @Published var changeBanner: UsageChangeAlert?

    private let apiClient = CursorAPIClient()
    private var backgroundSyncTask: Task<Void, Never>?
    private var chartSyncTask: Task<Void, Never>?
    private var metricsFingerprint: Int?
    private var chartFingerprint: Int?
    private var isReadyForChangeNotifications = false
    private var memoryUsageEventsCache: (key: String, store: UsageEventsCache.Store)?
    private var languageObserver: AnyCancellable?

    init() {
        hasToken = KeychainService.loadToken() != nil
        UsageChangeNotifier.requestAuthorization()
        languageObserver = LocalizationManager.shared.$preference
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        startBackgroundSync()
    }

    deinit {
        backgroundSyncTask?.cancel()
        chartSyncTask?.cancel()
    }

    var summary: UsageSummary? { dashboard.summary }
    var todayStats: TodayUsageStats { dashboard.todayStats }

    var menuBarTitle: String {
        menuBarTitle(language: LocalizationManager.shared.resolved)
    }

    func menuBarTitle(language: ResolvedLanguage) -> String {
        if !hasToken { return L10n.string(.menuNotConfigured, language: language) }
        if isInitialLoading, summary == nil { return "…" }
        if let percent = dashboard.usageLimit?.cyclePercentUsed
            ?? summary?.billingPlan?.totalPercentUsed
            ?? dashboard.periodUsage?.planUsage?.totalPercentUsed {
            return "\(Int(percent.rounded()))%"
        }
        if let todayPercent = dashboard.todayStats.dailyPercent {
            return UsageAnalytics.formatPercent(todayPercent)
        }
        if let remaining = summary?.planRemaining {
            return formatCount(remaining)
        }
        return "—"
    }

    var menuBarSymbolName: String {
        let percent = dashboard.usageLimit?.cyclePercentUsed
            ?? summary?.billingPlan?.totalPercentUsed
            ?? dashboard.periodUsage?.planUsage?.totalPercentUsed
        guard let percent else {
            return hasToken ? "gauge" : "gauge.with.dots.needle.0percent"
        }
        if percent >= 90 { return "gauge.with.dots.needle.100percent" }
        if percent >= 70 { return "gauge.with.dots.needle.67percent" }
        return "gauge.with.dots.needle.33percent"
    }

    func saveToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = L10n.string(.tokenEmpty, language: LocalizationManager.shared.resolved)
            return
        }
        do {
            try KeychainService.saveToken(trimmed)
            hasToken = true
            errorMessage = nil
            metricsFingerprint = nil
            chartFingerprint = nil
            isReadyForChangeNotifications = false
            changeBanner = nil
            memoryUsageEventsCache = nil
            UsageEventsCache.clearAll()
            startBackgroundSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearToken() {
        do {
            try KeychainService.deleteToken()
            hasToken = false
            dashboard = .empty
            lastUpdated = nil
            errorMessage = nil
            metricsFingerprint = nil
            chartFingerprint = nil
            isReadyForChangeNotifications = false
            changeBanner = nil
            memoryUsageEventsCache = nil
            UsageEventsCache.clearAll()
            backgroundSyncTask?.cancel()
            chartSyncTask?.cancel()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 用户手动触发同步；UI 仍只在数据变化时更新
    func refresh() async {
        await syncFromServer(initialLoad: false)
        await awaitChartSync(initialLoad: false, force: true)
    }

    func loadUsageEventsPage(_ page: Int) async {
        guard let startMs = dashboard.billingCycleStartMs,
              let endMs = dashboard.billingCycleEndMs
        else { return }

        let targetPage = max(1, min(page, dashboard.usageEventsTotalPages))
        guard targetPage != dashboard.usageEventsPage, !isLoadingUsageEventsPage else { return }

        if let pageData = cachedUsageEventsPage(
            startMs: startMs,
            endMs: endMs,
            page: targetPage,
            pageSize: dashboard.usageEventsPageSize
        ) {
            dashboard = dashboard.withPagedEvents(pageData)
            return
        }

        guard let token = KeychainService.loadToken() else { return }

        isLoadingUsageEventsPage = true
        defer { isLoadingUsageEventsPage = false }

        let result = await apiClient.fetchUsageEventsPage(
            token: token,
            startMs: startMs,
            endMs: endMs,
            page: targetPage,
            pageSize: dashboard.usageEventsPageSize
        )

        if let pageData = result.page {
            dashboard = dashboard.withPagedEvents(pageData)
        } else if let error = result.error {
            errorMessage = error
        }
    }

    func startBackgroundSync() {
        backgroundSyncTask?.cancel()
        chartSyncTask?.cancel()

        backgroundSyncTask = Task { [weak self] in
            guard let self else { return }
            await self.syncFromServer(initialLoad: self.dashboard.summary == nil)
            await self.awaitChartSync(initialLoad: true, force: false)
            self.isReadyForChangeNotifications = true

            while !Task.isCancelled {
                await RequestPacer.shared.sleepUntilNextCycle()
                guard !Task.isCancelled else { break }
                await self.syncFromServer(initialLoad: false)
                if self.dashboard.dailySpend.isEmpty
                    || self.isUsageEventsCacheStale(expectedTotal: self.dashboard.totalEventCount) {
                    await self.awaitChartSync(initialLoad: false, force: false)
                }
            }
        }
    }

    func dismissChangeBanner() {
        changeBanner = nil
    }

    private func syncFromServer(initialLoad: Bool) async {
        guard let token = KeychainService.loadToken() else {
            hasToken = false
            errorMessage = CursorAPIError.missingToken.message(
                language: LocalizationManager.shared.resolved
            )
            return
        }

        if initialLoad {
            isInitialLoading = true
        }

        let snapshot = await apiClient.fetchDashboardData(token: token)
        applyMetricsIfChanged(snapshot, initialLoad: initialLoad)

        if initialLoad {
            isInitialLoading = false
        }
    }

    private func applyMetricsIfChanged(_ incoming: DashboardSnapshot, initialLoad: Bool) {
        if initialLoad || dashboard.summary == nil {
            metricsFingerprint = incoming.metricsFingerprint
            chartFingerprint = nil
            dashboard = incoming
            lastUpdated = Date()
            updateErrorMessage(from: incoming)
            hydrateUsageEventsPageFromCache(page: 1)
            if isReadyForChangeNotifications {
                scheduleChartSync()
            }
            return
        }

        let merged = dashboard.applyingMetrics(from: incoming)
        guard merged.metricsFingerprint != metricsFingerprint else { return }

        let billingCycleChanged = merged.billingCycleStartMs != dashboard.billingCycleStartMs
            || merged.billingCycleEndMs != dashboard.billingCycleEndMs

        if billingCycleChanged,
           let oldStart = dashboard.billingCycleStartMs,
           let oldEnd = dashboard.billingCycleEndMs {
            UsageEventsCache.clear(startMs: oldStart, endMs: oldEnd)
            if memoryUsageEventsCache?.key == usageEventsCacheKey(startMs: oldStart, endMs: oldEnd) {
                memoryUsageEventsCache = nil
            }
        }

        let previous = dashboard
        metricsFingerprint = merged.metricsFingerprint
        dashboard = merged
        lastUpdated = Date()
        updateErrorMessage(from: merged)
        notifyChange(from: previous, to: merged)

        let eventCountChanged = merged.totalEventCount != previous.totalEventCount
        let cacheStale = isUsageEventsCacheStale(expectedTotal: merged.totalEventCount)
        if billingCycleChanged || eventCountChanged || cacheStale || dashboard.dailySpend.isEmpty {
            scheduleChartSync()
        }
    }

    private func notifyChange(from previous: DashboardSnapshot, to updated: DashboardSnapshot) {
        guard isReadyForChangeNotifications else { return }

        let message = UsageChangeNotifier.describeChange(
            from: previous,
            to: updated,
            language: LocalizationManager.shared.resolved
        )
        let defaultMessage = L10n.string(.changeDefault, language: LocalizationManager.shared.resolved)
        guard message != defaultMessage else { return }

        changeBanner = UsageChangeAlert(
            title: L10n.string(.changeBannerTitle, language: LocalizationManager.shared.resolved),
            message: message
        )
        UsageChangeNotifier.notify(
            title: L10n.string(.notificationTitle, language: LocalizationManager.shared.resolved),
            body: message
        )
    }

    private func scheduleChartSync() {
        startChartSyncTask(initialLoad: !isReadyForChangeNotifications, force: false)
    }

    private func startChartSyncTask(initialLoad: Bool, force: Bool) {
        chartSyncTask?.cancel()
        chartSyncTask = Task { [weak self] in
            await self?.performChartSync(initialLoad: initialLoad, force: force)
        }
    }

    private func awaitChartSync(initialLoad: Bool, force: Bool) async {
        chartSyncTask?.cancel()
        let task = Task<Void, Never> { [weak self] in
            await self?.performChartSync(initialLoad: initialLoad, force: force)
        }
        chartSyncTask = task
        await task.value
    }

    private func performChartSync(initialLoad: Bool, force: Bool) async {
        guard !Task.isCancelled else { return }
        guard let token = KeychainService.loadToken(),
              let startMs = dashboard.billingCycleStartMs,
              let endMs = dashboard.billingCycleEndMs
        else { return }

        if !force,
           chartFingerprint != nil,
           !dashboard.dailySpend.isEmpty,
           !isUsageEventsCacheStale(expectedTotal: dashboard.totalEventCount) {
            return
        }

        isLoadingCharts = true
        chartLoadError = nil
        defer { isLoadingCharts = false }

        let result = await apiClient.fetchAllBillingCycleEvents(
            token: token,
            startMs: startMs,
            endMs: endMs
        )

        guard !Task.isCancelled else { return }

        if result.events.isEmpty {
            chartLoadError = result.error ?? L10n.string(.chartLoadRetry, language: LocalizationManager.shared.resolved)
            return
        }

        let updated = dashboard.withChartData(from: result.events)
        if !force, updated.chartFingerprint == chartFingerprint { return }

        persistUsageEventsCache(
            events: result.events,
            totalCount: result.totalCount,
            startMs: startMs,
            endMs: endMs
        )

        let pageData = UsageEventsPage.slice(
            from: result.events,
            totalCount: result.totalCount,
            page: dashboard.usageEventsPage,
            pageSize: dashboard.usageEventsPageSize
        )

        let previous = dashboard
        chartFingerprint = updated.chartFingerprint
        dashboard = updated.withPagedEvents(pageData)
        lastUpdated = Date()
        chartLoadError = result.error

        guard !initialLoad, isReadyForChangeNotifications else { return }
        notifyChange(from: previous, to: updated)
    }

    private func updateErrorMessage(from snapshot: DashboardSnapshot) {
        if snapshot.summary == nil, snapshot.periodUsage == nil, snapshot.userProfile == nil {
            errorMessage = snapshot.partialErrors.first
                ?? L10n.string(.fetchDataFailed, language: LocalizationManager.shared.resolved)
        } else if snapshot.partialErrors.isEmpty {
            errorMessage = nil
        } else {
            errorMessage = snapshot.partialErrors.joined(separator: "\n")
        }
    }

    func formattedBillingPeriod() -> String {
        let start = summary?.billingCycleStart ?? dashboard.periodUsage?.billingCycleStart
        let end = summary?.billingCycleEnd ?? dashboard.periodUsage?.billingCycleEnd
        guard let start, let end else { return "—" }
        return "\(formatDate(start)) → \(formatDate(end))"
    }

    func formattedCurrencyFromCents(_ cents: Double?) -> String {
        guard let cents else { return "—" }
        return String(format: "$%.2f", cents / 100)
    }

    func formattedTotalCost() -> String {
        formattedCurrencyFromCents(dashboard.displayTotalCostCents)
    }

    func formattedCurrencyFromDollars(_ dollars: Double?) -> String {
        guard let dollars else { return "—" }
        return String(format: "$%.2f", dollars)
    }

    func formatCount(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    func membershipLabel() -> String {
        summary?.membershipType?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
            ?? "—"
    }

    /// 本周期全量用量明细（来自本地缓存）
    var cachedUsageEvents: [UsageEvent]? {
        guard let startMs = dashboard.billingCycleStartMs,
              let endMs = dashboard.billingCycleEndMs,
              let store = loadUsageEventsStore(startMs: startMs, endMs: endMs),
              !store.events.isEmpty
        else { return nil }
        return store.events
    }

    /// 实际使用过的模型（仅来自全量事件，不含未使用的配置项）
    var availableUsageEventModels: [String] {
        guard let events = cachedUsageEvents else {
            return Array(Set(dashboard.events.map(\.simplifiedModel))).sorted()
        }
        return Array(Set(events.map(\.simplifiedModel))).sorted()
    }

    private func formatDate(_ isoString: String) -> String {
        guard let date = UsageAnalytics.parseISODate(isoString) else { return isoString }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func usageEventsCacheKey(startMs: String, endMs: String) -> String {
        "\(startMs)|\(endMs)"
    }

    private func loadUsageEventsStore(startMs: String, endMs: String) -> UsageEventsCache.Store? {
        let key = usageEventsCacheKey(startMs: startMs, endMs: endMs)
        if let memoryUsageEventsCache, memoryUsageEventsCache.key == key {
            return memoryUsageEventsCache.store
        }
        guard let store = UsageEventsCache.load(startMs: startMs, endMs: endMs) else { return nil }
        memoryUsageEventsCache = (key, store)
        return store
    }

    private func persistUsageEventsCache(
        events: [UsageEvent],
        totalCount: Int,
        startMs: String,
        endMs: String
    ) {
        UsageEventsCache.save(events: events, totalCount: totalCount, startMs: startMs, endMs: endMs)
        memoryUsageEventsCache = (
            usageEventsCacheKey(startMs: startMs, endMs: endMs),
            UsageEventsCache.Store(
                billingCycleStartMs: startMs,
                billingCycleEndMs: endMs,
                totalCount: totalCount,
                fetchedAt: Date(),
                events: events
            )
        )
    }

    private func invalidateUsageEventsCache(startMs: String, endMs: String) {
        UsageEventsCache.clear(startMs: startMs, endMs: endMs)
        if memoryUsageEventsCache?.key == usageEventsCacheKey(startMs: startMs, endMs: endMs) {
            memoryUsageEventsCache = nil
        }
    }

    private func isUsageEventsCacheStale(expectedTotal: Int) -> Bool {
        guard let startMs = dashboard.billingCycleStartMs,
              let endMs = dashboard.billingCycleEndMs,
              let store = loadUsageEventsStore(startMs: startMs, endMs: endMs)
        else { return true }
        return store.events.count < expectedTotal
    }

    private func cachedUsageEventsPage(
        startMs: String,
        endMs: String,
        page: Int,
        pageSize: Int
    ) -> UsageEventsPage? {
        guard UsageEventsCache.canServePage(
            startMs: startMs,
            endMs: endMs,
            page: page,
            pageSize: pageSize
        ) else { return nil }

        if let store = loadUsageEventsStore(startMs: startMs, endMs: endMs) {
            return UsageEventsPage.slice(
                from: store.events,
                totalCount: store.totalCount,
                page: page,
                pageSize: pageSize
            )
        }
        return UsageEventsCache.page(
            startMs: startMs,
            endMs: endMs,
            page: page,
            pageSize: pageSize
        )
    }

    private func hydrateUsageEventsPageFromCache(page: Int) {
        guard let startMs = dashboard.billingCycleStartMs,
              let endMs = dashboard.billingCycleEndMs,
              let pageData = cachedUsageEventsPage(
                startMs: startMs,
                endMs: endMs,
                page: page,
                pageSize: dashboard.usageEventsPageSize
              )
        else { return }

        dashboard = dashboard.withPagedEvents(pageData)
    }
}
