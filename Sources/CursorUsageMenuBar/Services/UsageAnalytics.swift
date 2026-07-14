import Foundation

enum UsageAnalytics {
    /// 双用量池：API 按 apiPercentUsed × limit 计算；Auto+Composer 按 bonusSpend
    static func resolveUsagePools(
        summary: UsageSummary?,
        period: PeriodUsageResponse?
    ) -> [UsagePoolMetrics] {
        let plan = summary?.billingPlan
        let periodPlan = period?.planUsage

        let apiPercent = plan?.apiPercentUsed ?? periodPlan?.apiPercentUsed
        let autoPercent = plan?.autoPercentUsed ?? periodPlan?.autoPercentUsed
        let apiLimit = plan?.limit ?? periodPlan?.limit
        let apiUsed = resolveAPIUsedCents(
            percent: apiPercent,
            limitCents: apiLimit,
            explicitSpend: periodPlan?.apiSpend
        )
        let autoSpend = periodPlan?.bonusSpend
            ?? periodPlan?.autoSpend
            ?? {
                guard let total = periodPlan?.totalSpend, let included = periodPlan?.includedSpend else {
                    return nil
                }
                return max(0, total - included)
            }()

        let apiMessage = summary?.namedModelSelectedDisplayMessage
            ?? period?.namedModelSelectedDisplayMessage
        let autoMessage = summary?.autoModelSelectedDisplayMessage
            ?? period?.autoModelSelectedDisplayMessage

        let language = LocalizationManager.resolvedLanguage()
        return [
            UsagePoolMetrics(
                id: "api",
                title: L10n.string(.poolApi, language: language),
                percent: apiPercent,
                usedCents: apiUsed,
                limitCents: apiLimit,
                spendCents: apiUsed,
                displayMessage: apiMessage
            ),
            UsagePoolMetrics(
                id: "auto",
                title: L10n.string(.poolAuto, language: language),
                percent: autoPercent,
                usedCents: nil,
                limitCents: nil,
                spendCents: autoSpend,
                displayMessage: autoMessage
            ),
        ]
    }

    /// Billing API 已用 = apiPercentUsed × 包含额度（plan.limit）
    static func resolveAPIUsedCents(
        percent: Double?,
        limitCents: Double?,
        explicitSpend: Double?
    ) -> Double? {
        if let explicitSpend { return explicitSpend }
        guard let percent, let limitCents else { return nil }
        return limitCents * (percent / 100)
    }

    /// Billing 总口径：totalPercentUsed + 全周期花费
    static func resolveBillingBaseline(
        summary: UsageSummary?,
        period: PeriodUsageResponse?,
        aggregated: AggregatedUsageResponse?
    ) -> UsageLimitContext? {
        let plan = summary?.billingPlan
        let periodPlan = period?.planUsage
        let percent = plan?.totalPercentUsed
            ?? periodPlan?.totalPercentUsed
            ?? 0
        let canonicalCostCents = aggregated?.totalCostCents ?? periodPlan?.totalSpend
        let pools = resolveUsagePools(summary: summary, period: period)

        guard percent > 0 || canonicalCostCents != nil || pools.contains(where: { $0.percent != nil }) else {
            return nil
        }

        let resolvedLimit: Double
        if let canonicalCostCents, percent > 0 {
            resolvedLimit = canonicalCostCents / (percent / 100)
        } else if let apiLimit = plan?.limit, let apiPercent = plan?.apiPercentUsed, apiPercent > 0 {
            resolvedLimit = apiLimit / (apiPercent / 100)
        } else {
            resolvedLimit = plan?.limit ?? periodPlan?.limit ?? 0
        }

        return UsageLimitContext(
            cycleLimitCents: resolvedLimit,
            cyclePercentUsed: percent,
            cycleTotalCostCents: canonicalCostCents,
            cycleUsedCents: canonicalCostCents,
            apiPool: pools[0],
            autoPool: pools[1]
        )
    }

    /// 每日占比 = Billing总百分比 × (当日费用 / 本周期总费用)
    /// 与 CursorHub 按 aggregated 费用分摊 Billing 百分比的思路一致
    static func dailyUsage(
        from events: [UsageEvent],
        billing context: UsageLimitContext?
    ) -> [DailySpendPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event -> Date in
            guard let date = event.eventDate else { return Date.distantPast }
            return calendar.startOfDay(for: date)
        }

        let points = grouped
            .filter { $0.key != Date.distantPast }
            .map { date, dayEvents -> DailySpendPoint in
                let cents = dayEvents.compactMap(\.chargedCents).reduce(0, +)
                return DailySpendPoint(
                    date: date,
                    cents: cents,
                    usageUnits: cents,
                    requestCount: dayEvents.count
                )
            }
            .sorted { $0.date < $1.date }

        guard let context else { return points }

        let cycleTotalCost = context.cycleTotalCostCents
            ?? points.map(\.cents).reduce(0, +)
        let cyclePercent = context.cyclePercentUsed

        var cumulative: Double = 0
        return points.map { point in
            let dailyPercent: Double?
            if cycleTotalCost > 0, cyclePercent > 0 {
                dailyPercent = cyclePercent * (point.cents / cycleTotalCost)
            } else if context.cycleLimitCents > 0 {
                dailyPercent = point.cents / context.cycleLimitCents * 100
            } else {
                dailyPercent = nil
            }

            if let dailyPercent {
                cumulative += dailyPercent
            }

            return DailySpendPoint(
                date: point.date,
                cents: point.cents,
                usageUnits: point.cents,
                requestCount: point.requestCount,
                dailyPercent: dailyPercent,
                cumulativePercent: dailyPercent != nil ? cumulative : nil
            )
        }
    }

    /// 三条额度下降曲线：按日累计花费比例分摊各池已用%，剩余 = 100% - 已用%
    static func quotaCurves(
        from events: [UsageEvent],
        billing context: UsageLimitContext?,
        summary: UsageSummary?,
        period: PeriodUsageResponse?
    ) -> [QuotaCurvePoint] {
        guard let context else { return [] }

        let plan = summary?.billingPlan
        let periodPlan = period?.planUsage
        let totalPercent = context.cyclePercentUsed
        let apiPercent = plan?.apiPercentUsed
            ?? periodPlan?.apiPercentUsed
            ?? context.apiPool.percent
            ?? 0
        let autoPercent = plan?.autoPercentUsed
            ?? periodPlan?.autoPercentUsed
            ?? context.autoPool.percent
            ?? 0

        let autoModels = period?.autoBucketModels
        let calendar = Calendar.current

        struct DaySpend {
            var total: Double = 0
            var api: Double = 0
            var auto: Double = 0
        }

        var daily: [Date: DaySpend] = [:]
        for event in events {
            guard let date = event.eventDate else { continue }
            let day = calendar.startOfDay(for: date)
            let cents = event.chargedCents ?? 0
            guard cents > 0 else { continue }

            var spend = daily[day] ?? DaySpend()
            spend.total += cents
            if isAutoBucketEvent(event, autoBucketModels: autoModels) {
                spend.auto += cents
            } else {
                spend.api += cents
            }
            daily[day] = spend
        }

        let sortedDays = daily.keys.sorted()
        guard !sortedDays.isEmpty else { return [] }

        let totalSpend = daily.values.map(\.total).reduce(0, +)
        let totalApiSpend = daily.values.map(\.api).reduce(0, +)
        let totalAutoSpend = daily.values.map(\.auto).reduce(0, +)

        var cumTotal: Double = 0
        var cumApi: Double = 0
        var cumAuto: Double = 0
        var points: [QuotaCurvePoint] = []

        for day in sortedDays {
            let spend = daily[day]!
            cumTotal += spend.total
            cumApi += spend.api
            cumAuto += spend.auto

            let totalUsed = totalSpend > 0 ? totalPercent * (cumTotal / totalSpend) : 0
            let apiUsed = totalApiSpend > 0 ? apiPercent * (cumApi / totalApiSpend) : 0
            let autoUsed = totalAutoSpend > 0 ? autoPercent * (cumAuto / totalAutoSpend) : 0

            points.append(
                QuotaCurvePoint(
                    date: day,
                    series: .total,
                    remainingPercent: max(0, 100 - totalUsed),
                    usedPercent: totalUsed
                )
            )
            points.append(
                QuotaCurvePoint(
                    date: day,
                    series: .api,
                    remainingPercent: max(0, 100 - apiUsed),
                    usedPercent: apiUsed
                )
            )
            points.append(
                QuotaCurvePoint(
                    date: day,
                    series: .auto,
                    remainingPercent: max(0, 100 - autoUsed),
                    usedPercent: autoUsed
                )
            )
        }

        return points
    }

    static func isAutoBucketEvent(_ event: UsageEvent, autoBucketModels: [String]?) -> Bool {
        guard let model = event.model?.lowercased(), !model.isEmpty else { return false }

        if let autoBucketModels, !autoBucketModels.isEmpty {
            return autoBucketModels.contains { autoModel in
                let normalized = autoModel.lowercased()
                return model == normalized || model.contains(normalized)
            }
        }

        let autoHints = ["composer", "default", "cursor-small", "auto"]
        return autoHints.contains { model.contains($0) }
    }

    static func modelBreakdown(
        from aggregated: AggregatedUsageResponse?,
        events: [UsageEvent]
    ) -> [ModelSpendSlice] {
        if let aggregations = aggregated?.aggregations, !aggregations.isEmpty {
            let slices = aggregations.compactMap { item -> ModelSpendSlice? in
                guard let model = item.modelIntent else { return nil }
                let cents = item.totalCents ?? 0
                return ModelSpendSlice(
                    model: simplifyModelName(model),
                    cents: cents,
                    count: 1
                )
            }
            .sorted { $0.cents > $1.cents }

            if !slices.isEmpty { return topSlices(slices) }
        }
        return modelBreakdownFromEvents(events)
    }

    static func modelTokenUsage(from aggregated: AggregatedUsageResponse?) -> ModelTokenUsageSummary? {
        guard let aggregated, let aggregations = aggregated.aggregations, !aggregations.isEmpty else {
            return nil
        }

        let rows = aggregations.compactMap { item -> ModelTokenUsageRow? in
            guard let model = item.modelIntent else { return nil }
            return ModelTokenUsageRow(
                id: model,
                model: simplifyModelName(model),
                inputTokens: parseTokenCount(item.inputTokens),
                outputTokens: parseTokenCount(item.outputTokens),
                cacheReadTokens: parseTokenCount(item.cacheReadTokens),
                cacheWriteTokens: parseTokenCount(item.cacheWriteTokens),
                totalCents: item.totalCents ?? 0
            )
        }
        .sorted { $0.totalCents > $1.totalCents }

        guard !rows.isEmpty else { return nil }

        return ModelTokenUsageSummary(
            rows: rows,
            totalInputTokens: parseTokenCount(aggregated.totalInputTokens),
            totalOutputTokens: parseTokenCount(aggregated.totalOutputTokens),
            totalCacheReadTokens: parseTokenCount(aggregated.totalCacheReadTokens),
            totalCacheWriteTokens: parseTokenCount(aggregated.totalCacheWriteTokens),
            totalCostCents: aggregated.totalCostCents
        )
    }

    private static func parseTokenCount(_ value: String?) -> Int {
        guard let value, let count = Int(value) else { return 0 }
        return count
    }

    private static func modelBreakdownFromEvents(_ events: [UsageEvent]) -> [ModelSpendSlice] {
        let language = LocalizationManager.resolvedLanguage()
        let unknown = L10n.string(.unknownModel, language: language)
        let grouped = Dictionary(grouping: events) { $0.model ?? unknown }
        let slices = grouped.map { model, modelEvents in
            ModelSpendSlice(
                model: simplifyModelName(model),
                cents: modelEvents.compactMap(\.chargedCents).reduce(0, +),
                count: modelEvents.count
            )
        }
        .sorted { $0.cents > $1.cents }
        return topSlices(slices)
    }

    private static func topSlices(_ slices: [ModelSpendSlice], limit: Int = 6) -> [ModelSpendSlice] {
        guard slices.count > limit else { return slices }
        let top = Array(slices.prefix(limit - 1))
        let others = slices.dropFirst(limit - 1)
        return top + [
            ModelSpendSlice(
                model: L10n.string(.othersModel, language: LocalizationManager.resolvedLanguage()),
                cents: others.map(\.cents).reduce(0, +),
                count: others.map(\.count).reduce(0, +)
            ),
        ]
    }

    static func spendingBreakdown(
        from period: PeriodUsageResponse?,
        summary: UsageSummary?
    ) -> [SpendingBreakdownItem] {
        var items: [SpendingBreakdownItem] = []

        if let plan = summary?.billingPlan {
            if let total = plan.totalPercentUsed {
                items.append(
                    SpendingBreakdownItem(
                        id: "total",
                        label: "Billing 总计",
                        percent: total,
                        spendCents: period?.planUsage?.totalSpend,
                        colorName: "blue"
                    )
                )
            }
            if let auto = plan.autoPercentUsed {
                items.append(
                    SpendingBreakdownItem(
                        id: "auto",
                        label: "Auto + Composer",
                        percent: auto,
                        spendCents: period?.planUsage?.bonusSpend,
                        colorName: "purple"
                    )
                )
            }
            if let api = plan.apiPercentUsed {
                let apiUsed = resolveAPIUsedCents(
                    percent: api,
                    limitCents: plan.limit,
                    explicitSpend: period?.planUsage?.apiSpend
                )
                items.append(
                    SpendingBreakdownItem(
                        id: "api",
                        label: "API",
                        percent: api,
                        spendCents: apiUsed,
                        colorName: "orange"
                    )
                )
            }
        }

        if items.isEmpty, let plan = period?.planUsage {
            if let total = plan.totalPercentUsed {
                items.append(
                    SpendingBreakdownItem(
                        id: "total",
                        label: "Spending 总计",
                        percent: total,
                        spendCents: plan.totalSpend,
                        colorName: "blue"
                    )
                )
            }
        }
        return items
    }

    static func todayStats(
        from events: [UsageEvent],
        billing context: UsageLimitContext?
    ) -> TodayUsageStats {
        let calendar = Calendar.current
        let todayEvents = events.filter { event in
            guard let date = event.eventDate else { return false }
            return calendar.isDateInToday(date)
        }
        let cents = todayEvents.compactMap(\.chargedCents).reduce(0, +)

        let dailyPercent: Double? = {
            guard let context else { return nil }
            let cycleTotal = context.cycleTotalCostCents ?? cents
            if cycleTotal > 0, context.cyclePercentUsed > 0 {
                return context.cyclePercentUsed * (cents / cycleTotal)
            }
            if context.cycleLimitCents > 0 {
                return cents / context.cycleLimitCents * 100
            }
            return nil
        }()

        return TodayUsageStats(
            eventCount: todayEvents.count,
            totalChargedCents: cents,
            totalTokens: todayEvents.map(\.totalTokens).reduce(0, +),
            usageUnits: cents,
            dailyPercent: dailyPercent
        )
    }

    static func parseISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let milliseconds = Double(value), value.allSatisfy(\.isNumber) {
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func billingCycleRange(summary: UsageSummary?) -> (start: Date, end: Date) {
        let start = parseISODate(summary?.billingCycleStart)
            ?? Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let end = parseISODate(summary?.billingCycleEnd) ?? Date()
        return (start, end)
    }

    static func formatPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value < 1 {
            return String(format: "%.2f%%", value)
        }
        if value < 10 {
            return String(format: "%.1f%%", value)
        }
        return String(format: "%.0f%%", value.rounded())
    }

    private static func simplifyModelName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "-thinking", with: "")
            .replacingOccurrences(of: "-medium", with: "")
            .replacingOccurrences(of: "-high", with: "")
            .replacingOccurrences(of: "claude-", with: "claude ")
    }
}
