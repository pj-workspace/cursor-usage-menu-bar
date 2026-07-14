import Foundation

struct UsageSummary: Decodable, Sendable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let membershipType: String?
    let autoModelSelectedDisplayMessage: String?
    let namedModelSelectedDisplayMessage: String?
    let individualUsage: IndividualUsage?
    let teamUsage: TeamUsage?

    struct IndividualUsage: Decodable, Sendable {
        let plan: PlanUsage?
        let overall: PlanUsage?
        let onDemand: OnDemandUsage?
    }

    struct PlanUsage: Decodable, Sendable {
        let enabled: Bool?
        let used: Double?
        let limit: Double?
        let remaining: Double?
        let autoPercentUsed: Double?
        let apiPercentUsed: Double?
        let totalPercentUsed: Double?
    }

    struct OnDemandUsage: Decodable, Sendable {
        let enabled: Bool?
        let used: Double?
        let limit: Double?
        let remaining: Double?
    }

    struct TeamUsage: Decodable, Sendable {
        let onDemand: OnDemandUsage?
    }

    var billingPlan: PlanUsage? {
        individualUsage?.plan ?? individualUsage?.overall
    }

    var displayPercentUsed: Double? {
        billingPlan?.totalPercentUsed
            ?? billingPlan?.apiPercentUsed
            ?? billingPlan?.autoPercentUsed
    }

    var planUsed: Double? { billingPlan?.used }
    var planLimit: Double? { billingPlan?.limit }
    var planRemaining: Double? { billingPlan?.remaining }
    var onDemandUsedCents: Double? { individualUsage?.onDemand?.used }
}

struct PeriodUsageResponse: Decodable, Sendable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let displayMessage: String?
    let autoModelSelectedDisplayMessage: String?
    let namedModelSelectedDisplayMessage: String?
    let autoBucketModels: [String]?
    let planUsage: PlanUsageDetail?
    let onDemandUsage: OnDemandUsageDetail?

    struct PlanUsageDetail: Decodable, Sendable {
        let totalSpend: Double?
        let includedSpend: Double?
        let bonusSpend: Double?
        let limit: Double?
        let remaining: Double?
        let autoSpend: Double?
        let apiSpend: Double?
        let autoPercentUsed: Double?
        let apiPercentUsed: Double?
        let totalPercentUsed: Double?
    }

    struct OnDemandUsageDetail: Decodable, Sendable {
        let used: Double?
        let limit: Double?
        let remaining: Double?
    }
}

struct UserProfileResponse: Decodable, Sendable {
    let profile: PublicProfile?
    let publicVisibilityAllowed: Bool?
    let maxVisibility: String?

    struct PublicProfile: Decodable, Sendable {
        let handle: String?
        let displayName: String?
        let avatarUrl: String?
        let visibility: String?
        let createdAt: String?
        let updatedAt: String?
    }

    var displayNameOrEmail: String {
        if let displayName = profile?.displayName, !displayName.isEmpty { return displayName }
        if let handle = profile?.handle, !handle.isEmpty { return "@\(handle)" }
        return "—"
    }
}

struct AuthMeResponse: Decodable, Sendable {
    let email: String?
    let emailVerified: Bool?
    let name: String?
    let sub: String?
    let picture: String?
    let createdAt: String?
    let updatedAt: String?
    let numericId: Int?

    enum CodingKeys: String, CodingKey {
        case email
        case emailVerified = "email_verified"
        case name, sub, picture
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case numericId = "id"
    }

    var workosId: String? { sub }
    var id: String? { sub ?? numericId.map(String.init) }
}

struct AggregatedUsageResponse: Decodable, Sendable {
    let aggregations: [ModelAggregation]?
    let totalInputTokens: String?
    let totalOutputTokens: String?
    let totalCacheWriteTokens: String?
    let totalCacheReadTokens: String?
    let totalCostCents: Double?

    struct ModelAggregation: Decodable, Sendable {
        let modelIntent: String?
        let inputTokens: String?
        let outputTokens: String?
        let cacheWriteTokens: String?
        let cacheReadTokens: String?
        let totalCents: Double?
        let tier: Int?
    }
}

struct UsageEventsResponse: Decodable, Sendable {
    let totalUsageEventsCount: Int?
    let usageEventsDisplay: [UsageEvent]?
}

struct UsageEvent: Codable, Sendable, Identifiable {
    let timestamp: String?
    let model: String?
    let kind: String?
    let usageBasedCosts: String?
    let chargedCents: Double?
    let requestsCosts: Double?
    let isTokenBasedCall: Bool?
    let isChargeable: Bool?
    let conversationId: String?
    let subscriptionProductId: String?
    let tokenUsage: TokenUsage?

    struct TokenUsage: Codable, Sendable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheWriteTokens: Int?
        let cacheReadTokens: Int?
        let totalCents: Double?
    }

    var id: String {
        [
            timestamp,
            model,
            kind,
            conversationId,
            chargedCents.map { String($0) },
        ]
        .compactMap { $0 }
        .joined(separator: "|")
    }

    var eventDate: Date? {
        guard let timestamp, let milliseconds = Double(timestamp) else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }

    var totalTokens: Int {
        (tokenUsage?.inputTokens ?? 0)
            + (tokenUsage?.outputTokens ?? 0)
            + (tokenUsage?.cacheWriteTokens ?? 0)
            + (tokenUsage?.cacheReadTokens ?? 0)
    }

    var kindLabel: String {
        kindLabel(language: LocalizationManager.resolvedLanguage())
    }

    func kindLabel(language: ResolvedLanguage) -> String {
        guard let kind else { return "—" }
        switch kind {
        case "USAGE_EVENT_KIND_INCLUDED_IN_PRO_PLUS":
            return L10n.string(.kindProPlus, language: language)
        case "USAGE_EVENT_KIND_INCLUDED_IN_PRO":
            return L10n.string(.kindPro, language: language)
        case "USAGE_EVENT_KIND_INCLUDED_IN_BUSINESS":
            return L10n.string(.kindBusiness, language: language)
        case "USAGE_EVENT_KIND_USAGE_BASED":
            return L10n.string(.kindUsageBased, language: language)
        case "USAGE_EVENT_KIND_FREE":
            return L10n.string(.kindFree, language: language)
        default:
            return kind
                .replacingOccurrences(of: "USAGE_EVENT_KIND_", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    var formattedTime: String {
        guard let eventDate else { return "—" }
        return eventDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    var formattedCost: String {
        guard let chargedCents else { return "—" }
        if chargedCents < 0.01 { return String(format: "$%.4f", chargedCents / 100) }
        return String(format: "$%.2f", chargedCents / 100)
    }

    var formattedTotalTokens: String? {
        guard totalTokens > 0 else { return nil }
        return Self.formatTokenCount(totalTokens)
    }

    static func formatTokenCount(_ count: Int?) -> String {
        guard let count else { return "—" }
        if count >= 1_000_000 { return String(format: "%.2fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    var simplifiedModel: String {
        Self.simplifiedName(for: model)
    }

    static func simplifiedName(for model: String?) -> String {
        guard let model, !model.isEmpty else { return "未知模型" }
        var name = model
            .replacingOccurrences(of: "-thinking", with: "")
            .replacingOccurrences(of: "-medium", with: "")
            .replacingOccurrences(of: "-high", with: "")
            .replacingOccurrences(of: "-low", with: "")
            .replacingOccurrences(of: "-fast", with: "")
        if name.hasPrefix("cursor-") {
            name = String(name.dropFirst("cursor-".count))
        }
        return name
    }
}

struct DailySpendPoint: Identifiable, Sendable {
    let id: String
    let date: Date
    let cents: Double
    let usageUnits: Double
    let requestCount: Int
    let dailyPercent: Double?
    let cumulativePercent: Double?

    init(
        date: Date,
        cents: Double,
        usageUnits: Double,
        requestCount: Int,
        dailyPercent: Double? = nil,
        cumulativePercent: Double? = nil
    ) {
        self.date = date
        self.cents = cents
        self.usageUnits = usageUnits
        self.requestCount = requestCount
        self.dailyPercent = dailyPercent
        self.cumulativePercent = cumulativePercent
        id = ISO8601DateFormatter().string(from: date)
    }

    var dollars: Double { cents / 100 }
}

enum QuotaCurveSeries: String, CaseIterable, Identifiable, Sendable {
    case total = "Total"
    case api = "API"
    case auto = "Auto"

    var id: String { rawValue }
}

struct QuotaCurvePoint: Identifiable, Sendable {
    let id: String
    let date: Date
    let series: QuotaCurveSeries
    let remainingPercent: Double
    let usedPercent: Double

    init(date: Date, series: QuotaCurveSeries, remainingPercent: Double, usedPercent: Double) {
        self.date = date
        self.series = series
        self.remainingPercent = remainingPercent
        self.usedPercent = usedPercent
        id = "\(ISO8601DateFormatter().string(from: date))-\(series.rawValue)"
    }
}

struct UsagePoolMetrics: Identifiable, Sendable {
    let id: String
    let title: String
    let percent: Double?
    let usedCents: Double?
    let limitCents: Double?
    let spendCents: Double?
    let displayMessage: String?

    var dollarSubtitle: String? {
        if let usedCents, let limitCents {
            return String(format: "$%.2f / $%.2f", usedCents / 100, limitCents / 100)
        }
        if let spendCents {
            return String(format: "$%.2f", spendCents / 100)
        }
        return nil
    }

    func localizedTitle(language: ResolvedLanguage) -> String {
        switch id {
        case "api":
            return L10n.string(.poolApi, language: language)
        case "auto":
            return L10n.string(.poolAuto, language: language)
        default:
            return title
        }
    }
}

struct UsageLimitContext: Sendable {
    /// Billing 总配额（美分），由 totalSpend / totalPercentUsed 反推
    let cycleLimitCents: Double
    /// Billing 页 totalPercentUsed
    let cyclePercentUsed: Double
    /// get-aggregated-usage-events 本周期总费用（美分）
    let cycleTotalCostCents: Double?
    /// 本周期 totalSpend（美分）
    let cycleUsedCents: Double?
    let apiPool: UsagePoolMetrics
    let autoPool: UsagePoolMetrics

    var usageCostDollars: Double? {
        guard let cycleTotalCostCents else { return nil }
        return cycleTotalCostCents / 100
    }

    func formatBaseline() -> String {
        formatBaseline(language: LocalizationManager.resolvedLanguage())
    }

    func formatBaseline(language: ResolvedLanguage) -> String {
        let percent = UsageAnalytics.formatPercent(cyclePercentUsed)
        if let cost = usageCostDollars {
            return String(
                format: L10n.string(.billingBaselineWithCost, language: language),
                locale: language.locale,
                percent,
                String(format: "%.2f", cost)
            )
        }
        return String(
            format: L10n.string(.billingBaseline, language: language),
            locale: language.locale,
            percent
        )
    }

    func formatDailyUsage(_ cents: Double) -> String {
        String(format: "$%.2f", cents / 100)
    }
}

struct ModelSpendSlice: Identifiable, Sendable {
    let id: String
    let model: String
    let cents: Double
    let count: Int

    init(model: String, cents: Double, count: Int) {
        self.model = model
        self.cents = cents
        self.count = count
        id = model
    }

    var dollars: Double { cents / 100 }
}

struct ModelTokenUsageRow: Identifiable, Sendable {
    let id: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheWriteTokens: Int
    let totalCents: Double

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens
    }
}

struct ModelTokenUsageSummary: Sendable {
    let rows: [ModelTokenUsageRow]
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCacheReadTokens: Int
    let totalCacheWriteTokens: Int
    let totalCostCents: Double?

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheReadTokens + totalCacheWriteTokens
    }
}

struct SpendingBreakdownItem: Identifiable, Sendable {
    let id: String
    let label: String
    let percent: Double
    let spendCents: Double?
    let colorName: String
}

struct UsageEventsPage: Sendable {
    let events: [UsageEvent]
    let totalCount: Int
    let page: Int
    let pageSize: Int

    var totalPages: Int {
        max(1, Int(ceil(Double(totalCount) / Double(pageSize))))
    }

    static func slice(
        from allEvents: [UsageEvent],
        totalCount: Int,
        page: Int,
        pageSize: Int
    ) -> UsageEventsPage {
        let safePage = max(1, page)
        let start = (safePage - 1) * pageSize
        guard start < allEvents.count else {
            return UsageEventsPage(events: [], totalCount: totalCount, page: safePage, pageSize: pageSize)
        }
        let end = min(start + pageSize, allEvents.count)
        return UsageEventsPage(
            events: Array(allEvents[start ..< end]),
            totalCount: totalCount,
            page: safePage,
            pageSize: pageSize
        )
    }
}

struct DashboardSnapshot: Sendable {
    let summary: UsageSummary?
    let periodUsage: PeriodUsageResponse?
    let aggregatedUsage: AggregatedUsageResponse?
    let userProfile: UserProfileResponse?
    let authMe: AuthMeResponse?
    let events: [UsageEvent]
    let totalEventCount: Int
    let usageLimit: UsageLimitContext?
    let usagePools: [UsagePoolMetrics]
    let dailySpend: [DailySpendPoint]
    let quotaCurves: [QuotaCurvePoint]
    let modelBreakdown: [ModelSpendSlice]
    let spendingBreakdown: [SpendingBreakdownItem]
    let todayStats: TodayUsageStats
    let partialErrors: [String]
    let billingCycleStartMs: String?
    let billingCycleEndMs: String?
    let usageEventsPage: Int
    let usageEventsPageSize: Int

    static let empty = DashboardSnapshot(
        summary: nil,
        periodUsage: nil,
        aggregatedUsage: nil,
        userProfile: nil,
        authMe: nil,
        events: [],
        totalEventCount: 0,
        usageLimit: nil,
        usagePools: [],
        dailySpend: [],
        quotaCurves: [],
        modelBreakdown: [],
        spendingBreakdown: [],
        todayStats: .empty,
        partialErrors: [],
        billingCycleStartMs: nil,
        billingCycleEndMs: nil,
        usageEventsPage: 1,
        usageEventsPageSize: 20
    )

    var usageEventsTotalPages: Int {
        max(1, Int(ceil(Double(totalEventCount) / Double(usageEventsPageSize))))
    }

    var modelTokenUsage: ModelTokenUsageSummary? {
        UsageAnalytics.modelTokenUsage(from: aggregatedUsage)
    }

    /// 统一本周期花费口径：优先 aggregated，其次 spending
    var displayTotalCostCents: Double? {
        usageLimit?.cycleTotalCostCents
            ?? aggregatedUsage?.totalCostCents
            ?? periodUsage?.planUsage?.totalSpend
    }

    func withPagedEvents(_ page: UsageEventsPage) -> DashboardSnapshot {
        DashboardSnapshot(
            summary: summary,
            periodUsage: periodUsage,
            aggregatedUsage: aggregatedUsage,
            userProfile: userProfile,
            authMe: authMe,
            events: page.events,
            totalEventCount: page.totalCount,
            usageLimit: usageLimit,
            usagePools: usagePools,
            dailySpend: dailySpend,
            quotaCurves: quotaCurves,
            modelBreakdown: modelBreakdown,
            spendingBreakdown: spendingBreakdown,
            todayStats: todayStats,
            partialErrors: partialErrors,
            billingCycleStartMs: billingCycleStartMs,
            billingCycleEndMs: billingCycleEndMs,
            usageEventsPage: page.page,
            usageEventsPageSize: page.pageSize
        )
    }

    func withChartData(from allEvents: [UsageEvent]) -> DashboardSnapshot {
        DashboardSnapshot(
            summary: summary,
            periodUsage: periodUsage,
            aggregatedUsage: aggregatedUsage,
            userProfile: userProfile,
            authMe: authMe,
            events: events,
            totalEventCount: totalEventCount,
            usageLimit: usageLimit,
            usagePools: usagePools,
            dailySpend: UsageAnalytics.dailyUsage(from: allEvents, billing: usageLimit),
            quotaCurves: UsageAnalytics.quotaCurves(
                from: allEvents,
                billing: usageLimit,
                summary: summary,
                period: periodUsage
            ),
            modelBreakdown: UsageAnalytics.modelBreakdown(from: aggregatedUsage, events: allEvents),
            spendingBreakdown: spendingBreakdown,
            todayStats: UsageAnalytics.todayStats(from: allEvents, billing: usageLimit),
            partialErrors: partialErrors,
            billingCycleStartMs: billingCycleStartMs,
            billingCycleEndMs: billingCycleEndMs,
            usageEventsPage: usageEventsPage,
            usageEventsPageSize: usageEventsPageSize
        )
    }

    /// 后台同步时合并新指标，保留用户当前正在看的明细页
    func applyingMetrics(from incoming: DashboardSnapshot) -> DashboardSnapshot {
        DashboardSnapshot(
            summary: incoming.summary,
            periodUsage: incoming.periodUsage,
            aggregatedUsage: incoming.aggregatedUsage,
            userProfile: incoming.userProfile,
            authMe: incoming.authMe,
            events: events,
            totalEventCount: incoming.totalEventCount,
            usageLimit: incoming.usageLimit,
            usagePools: incoming.usagePools,
            dailySpend: dailySpend,
            quotaCurves: quotaCurves,
            modelBreakdown: modelBreakdown,
            spendingBreakdown: incoming.spendingBreakdown,
            todayStats: todayStats,
            partialErrors: incoming.partialErrors,
            billingCycleStartMs: incoming.billingCycleStartMs,
            billingCycleEndMs: incoming.billingCycleEndMs,
            usageEventsPage: usageEventsPage,
            usageEventsPageSize: usageEventsPageSize
        )
    }

    /// Billing / 用量核心指标指纹，用于判断是否需要刷新 UI
    var metricsFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(summary?.billingPlan?.totalPercentUsed)
        hasher.combine(summary?.billingPlan?.apiPercentUsed)
        hasher.combine(summary?.billingPlan?.autoPercentUsed)
        hasher.combine(summary?.billingPlan?.used)
        hasher.combine(summary?.billingPlan?.limit)
        hasher.combine(summary?.membershipType)
        hasher.combine(periodUsage?.planUsage?.totalSpend)
        hasher.combine(periodUsage?.planUsage?.includedSpend)
        hasher.combine(periodUsage?.planUsage?.bonusSpend)
        hasher.combine(aggregatedUsage?.totalCostCents)
        hasher.combine(totalEventCount)
        hasher.combine(partialErrors.joined(separator: "|"))
        for pool in usagePools {
            hasher.combine(pool.id)
            hasher.combine(pool.percent)
            hasher.combine(pool.usedCents)
            hasher.combine(pool.limitCents)
            hasher.combine(pool.spendCents)
            hasher.combine(pool.displayMessage)
        }
        return hasher.finalize()
    }

    /// 图表类数据指纹
    var chartFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(dailySpend.count)
        for point in dailySpend {
            hasher.combine(point.id)
            hasher.combine(point.cents)
            hasher.combine(point.dailyPercent)
        }
        for point in quotaCurves {
            hasher.combine(point.id)
            hasher.combine(point.remainingPercent)
        }
        for slice in modelBreakdown {
            hasher.combine(slice.id)
            hasher.combine(slice.cents)
        }
        hasher.combine(todayStats.eventCount)
        hasher.combine(todayStats.totalChargedCents)
        hasher.combine(todayStats.dailyPercent)
        return hasher.finalize()
    }
}

struct TodayUsageStats: Sendable {
    let eventCount: Int
    let totalChargedCents: Double
    let totalTokens: Int
    let usageUnits: Double
    let dailyPercent: Double?

    static let empty = TodayUsageStats(
        eventCount: 0,
        totalChargedCents: 0,
        totalTokens: 0,
        usageUnits: 0,
        dailyPercent: nil
    )
}

enum DashboardTab: CaseIterable, Identifiable, Sendable {
    case usage
    case spending
    case billing

    var id: String { String(describing: self) }

    var icon: String {
        switch self {
        case .usage: return "chart.bar.fill"
        case .spending: return "dollarsign.circle.fill"
        case .billing: return "creditcard.fill"
        }
    }
}

enum CursorAPIError: LocalizedError, Sendable {
    case missingToken
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingFailed(String)

    var errorDescription: String? {
        message(language: LocalizationManager.resolvedLanguage())
    }

    func message(language: ResolvedLanguage) -> String {
        switch self {
        case .missingToken:
            return L10n.string(.apiErrorMissingToken, language: language)
        case .invalidResponse:
            return L10n.string(.apiErrorInvalidResponse, language: language)
        case let .httpError(statusCode, message):
            return String(
                format: L10n.string(.apiErrorHttp, language: language),
                locale: language.locale,
                statusCode,
                message
            )
        case let .decodingFailed(message):
            return String(
                format: L10n.string(.apiErrorDecode, language: language),
                locale: language.locale,
                message
            )
        }
    }
}
