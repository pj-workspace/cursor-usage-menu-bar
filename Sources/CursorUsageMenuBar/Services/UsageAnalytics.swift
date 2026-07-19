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
                    model: displayModelName(model),
                    cents: cents,
                    count: 1
                )
            }
            .sorted { $0.cents > $1.cents }

            if !slices.isEmpty { return topSlices(slices) }
        }
        return modelBreakdownFromEvents(events)
    }

    static func includedUsage(
        from aggregated: AggregatedUsageResponse?,
        billing context: UsageLimitContext?,
        autoBucketModels: [String]? = nil,
        apiPercentUsed: Double? = nil,
        autoPercentUsed: Double? = nil
    ) -> IncludedUsageSummary? {
        guard let aggregations = aggregated?.aggregations, !aggregations.isEmpty else { return nil }

        let rows = aggregations.compactMap { item -> IncludedUsageRow? in
            guard let model = item.modelIntent else { return nil }
            let tokens = aggregationTokenTotal(item)
            let costCents = item.totalCents ?? 0
            guard tokens > 0 || costCents > 0 else { return nil }
            return IncludedUsageRow(
                model: displayModelName(model),
                tokens: tokens,
                costCents: costCents,
                usagePercent: 0,
                pool: resolveUsagePool(for: model, autoBucketModels: autoBucketModels)
            )
        }

        return buildIncludedUsage(
            from: rows,
            apiPercentUsed: apiPercentUsed ?? context?.apiPool.percent,
            autoPercentUsed: autoPercentUsed ?? context?.autoPool.percent,
            cyclePercentUsed: context?.cyclePercentUsed
        )
    }

    /// 按日筛选：当日组内按花费占比分摊到 100%（无双池周期口径）
    static func includedUsage(
        fromEvents events: [UsageEvent],
        billing context: UsageLimitContext?,
        autoBucketModels: [String]? = nil
    ) -> IncludedUsageSummary? {
        guard !events.isEmpty else { return nil }
        let language = LocalizationManager.resolvedLanguage()
        let grouped = Dictionary(grouping: events) { event in
            displayModelName(event.model ?? L10n.string(.unknownModel, language: language))
        }

        let rows = grouped.compactMap { model, modelEvents -> IncludedUsageRow? in
            let tokens = modelEvents.map(\.totalTokens).reduce(0, +)
            let costCents = modelEvents.compactMap(\.chargedCents).reduce(0, +)
            guard tokens > 0 || costCents > 0 else { return nil }
            return IncludedUsageRow(
                model: model,
                tokens: tokens,
                costCents: costCents,
                usagePercent: 0,
                pool: resolveUsagePool(for: model, autoBucketModels: autoBucketModels)
            )
        }

        // 当日：仍按双池分组，但每组内百分比合计为该组在当日花费中的占比 ×100（组间可对比）
        // 更直观：组内模型%合计 = 该组当日花费/当日总花费×100
        let dayCost = rows.map(\.costCents).reduce(0, +)
        guard dayCost > 0 else {
            return buildIncludedUsage(
                from: rows,
                apiPercentUsed: 0,
                autoPercentUsed: 0,
                cyclePercentUsed: context?.cyclePercentUsed
            )
        }

        let apiCost = rows.filter { $0.pool == .api }.map(\.costCents).reduce(0, +)
        let autoCost = rows.filter { $0.pool == .firstParty }.map(\.costCents).reduce(0, +)
        return buildIncludedUsage(
            from: rows,
            apiPercentUsed: apiCost / dayCost * 100,
            autoPercentUsed: autoCost / dayCost * 100,
            cyclePercentUsed: context?.cyclePercentUsed
        )
    }

    /// 对齐 Cursor 官网 Included Usage（前端同款算法，非爬虫）：
    /// - API 组合计 = apiPercentUsed；第一方组合计 = autoPercentUsed
    /// - 组内 model% = 组百分比 × (modelCost ÷ poolCost)
    /// - Token / totalCents 均来自 get-aggregated-usage-events，官网也不返回现成 model%
    private static func buildIncludedUsage(
        from rows: [IncludedUsageRow],
        apiPercentUsed: Double?,
        autoPercentUsed: Double?,
        cyclePercentUsed: Double?
    ) -> IncludedUsageSummary? {
        guard !rows.isEmpty else { return nil }

        let apiRows = rows.filter { $0.pool == .api }
        let autoRows = rows.filter { $0.pool == .firstParty }
        let apiCost = apiRows.map(\.costCents).reduce(0, +)
        let autoCost = autoRows.map(\.costCents).reduce(0, +)
        let apiPoolPercent = apiPercentUsed ?? 0
        let autoPoolPercent = autoPercentUsed ?? 0

        func score(_ poolRows: [IncludedUsageRow], poolPercent: Double, poolCost: Double) -> [IncludedUsageRow] {
            let tokenTotal = poolRows.map(\.tokens).reduce(0, +)
            return poolRows
                .map { row in
                    let percent: Double
                    if poolCost > 0, row.costCents > 0 {
                        percent = poolPercent * (row.costCents / poolCost)
                    } else if tokenTotal > 0, poolPercent > 0 {
                        percent = poolPercent * (Double(row.tokens) / Double(tokenTotal))
                    } else {
                        percent = 0
                    }
                    return IncludedUsageRow(
                        model: row.model,
                        tokens: row.tokens,
                        costCents: row.costCents,
                        usagePercent: percent,
                        pool: row.pool
                    )
                }
                .sorted { lhs, rhs in
                    if abs(lhs.usagePercent - rhs.usagePercent) > 0.0001 {
                        return lhs.usagePercent > rhs.usagePercent
                    }
                    if lhs.costCents != rhs.costCents { return lhs.costCents > rhs.costCents }
                    return lhs.tokens > rhs.tokens
                }
        }

        var groups: [IncludedUsageGroup] = []
        if !apiRows.isEmpty {
            let scored = score(apiRows, poolPercent: apiPoolPercent, poolCost: apiCost)
            groups.append(
                IncludedUsageGroup(
                    id: ModelPricingCatalog.Pool.api.rawValue,
                    pool: .api,
                    rows: scored,
                    totalTokens: scored.map(\.tokens).reduce(0, +),
                    totalCostCents: apiCost,
                    // 组头用官方池百分比，避免舍入误差导致与官网组头不一致
                    usagePercent: apiPoolPercent
                )
            )
        }
        if !autoRows.isEmpty {
            let scored = score(autoRows, poolPercent: autoPoolPercent, poolCost: autoCost)
            groups.append(
                IncludedUsageGroup(
                    id: ModelPricingCatalog.Pool.firstParty.rawValue,
                    pool: .firstParty,
                    rows: scored,
                    totalTokens: scored.map(\.tokens).reduce(0, +),
                    totalCostCents: autoCost,
                    usagePercent: autoPoolPercent
                )
            )
        }

        return IncludedUsageSummary(
            groups: groups,
            billingPercent: cyclePercentUsed,
            totalUsagePercent: groups.map(\.usagePercent).reduce(0, +)
        )
    }

    /// 对齐 Cursor 官网 Included Usage：Auto / Composer / Grok → 第一方；其余按公开 API 价
    static func resolveUsagePool(for model: String, autoBucketModels: [String]?) -> ModelPricingCatalog.Pool {
        let lower = model.lowercased()

        if isFirstPartyModel(lower, autoBucketModels: autoBucketModels) {
            return .firstParty
        }

        return ModelPricingCatalog.rule(for: model).pool
    }

    static func isFirstPartyModel(_ model: String, autoBucketModels: [String]?) -> Bool {
        let lower = model.lowercased()

        if let autoBucketModels, !autoBucketModels.isEmpty {
            let matched = autoBucketModels.contains { autoModel in
                let normalized = autoModel.lowercased()
                return lower == normalized
                    || lower.hasPrefix(normalized + "-")
                    || normalized.hasPrefix(lower + "-")
            }
            if matched { return true }
        }

        // Cursor 官网第一方：auto/default、composer-2*、cursor-grok*
        if lower == "auto" || lower == "default" || lower == "cursor-small" {
            return true
        }
        if lower.hasPrefix("composer-2") || lower.hasPrefix("cursor-grok") || lower.hasPrefix("grok-4.5") {
            return true
        }
        return false
    }

    static func dayStats(
        from events: [UsageEvent],
        day: Date,
        billing context: UsageLimitContext?
    ) -> TodayUsageStats {
        let calendar = Calendar.current
        let dayEvents = events.filter { event in
            guard let date = event.eventDate else { return false }
            return calendar.isDate(date, inSameDayAs: day)
        }
        let cents = dayEvents.compactMap(\.chargedCents).reduce(0, +)
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
            eventCount: dayEvents.count,
            totalChargedCents: cents,
            totalTokens: dayEvents.map(\.totalTokens).reduce(0, +),
            usageUnits: cents,
            dailyPercent: dailyPercent
        )
    }

    static func dailyModelShare(from events: [UsageEvent], topLimit: Int = 6) -> [DailyModelShareDay] {
        let calendar = Calendar.current
        let language = LocalizationManager.resolvedLanguage()
        let othersLabel = L10n.string(.othersModel, language: language)

        let grouped = Dictionary(grouping: events) { event -> Date in
            guard let date = event.eventDate else { return Date.distantPast }
            return calendar.startOfDay(for: date)
        }

        return grouped
            .filter { $0.key != Date.distantPast }
            .sorted { $0.key < $1.key }
            .map { date, dayEvents in
                let modelTokens = Dictionary(grouping: dayEvents) { event in
                    displayModelName(event.model ?? L10n.string(.unknownModel, language: language))
                }
                .map { model, modelEvents -> (String, Int) in
                    (model, modelEvents.map(\.totalTokens).reduce(0, +))
                }
                .filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }

                let dayTotal = modelTokens.map(\.1).reduce(0, +)
                let top = Array(modelTokens.prefix(topLimit))
                let remainder = modelTokens.dropFirst(topLimit)

                var slices = top.map { model, tokens in
                    DailyModelShareSlice(
                        model: model,
                        tokens: tokens,
                        percent: dayTotal > 0 ? Double(tokens) / Double(dayTotal) * 100 : 0
                    )
                }

                if !remainder.isEmpty {
                    let otherTokens = remainder.map(\.1).reduce(0, +)
                    slices.append(
                        DailyModelShareSlice(
                            model: othersLabel,
                            tokens: otherTokens,
                            percent: dayTotal > 0 ? Double(otherTokens) / Double(dayTotal) * 100 : 0
                        )
                    )
                }

                return DailyModelShareDay(date: date, slices: slices, totalTokens: dayTotal)
            }
            .filter { !$0.slices.isEmpty }
    }

    static func modelTokenUsage(
        from aggregated: AggregatedUsageResponse?,
        billing context: UsageLimitContext?
    ) -> ModelTokenUsageSummary? {
        guard let aggregated, let aggregations = aggregated.aggregations, !aggregations.isEmpty else {
            return nil
        }

        let costTotal = context?.cycleTotalCostCents
            ?? aggregated.totalCostCents
            ?? aggregations.compactMap(\.totalCents).reduce(0, +)
        let billingPercent = context?.cyclePercentUsed ?? 0

        let rows = aggregations.compactMap { item -> ModelTokenUsageRow? in
            guard let model = item.modelIntent else { return nil }
            let cost = item.totalCents ?? 0
            let percent: Double? = {
                guard billingPercent > 0, costTotal > 0, cost > 0 else { return nil }
                return billingPercent * (cost / costTotal)
            }()
            return ModelTokenUsageRow(
                id: model,
                model: displayModelName(model),
                rawModel: model,
                inputTokens: parseTokenCount(item.inputTokens),
                outputTokens: parseTokenCount(item.outputTokens),
                cacheReadTokens: parseTokenCount(item.cacheReadTokens),
                cacheWriteTokens: parseTokenCount(item.cacheWriteTokens),
                totalCents: cost,
                usagePercent: percent
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

    private static func aggregationTokenTotal(_ item: AggregatedUsageResponse.ModelAggregation) -> Int {
        parseTokenCount(item.inputTokens)
            + parseTokenCount(item.outputTokens)
            + parseTokenCount(item.cacheReadTokens)
            + parseTokenCount(item.cacheWriteTokens)
    }

    private static func usagePercent(tokens: Int, totalTokens: Int, billingPercent: Double) -> Double {
        guard totalTokens > 0, billingPercent > 0 else {
            guard totalTokens > 0 else { return 0 }
            return Double(tokens) / Double(totalTokens) * 100
        }
        return Double(tokens) / Double(totalTokens) * billingPercent
    }

    static func displayModelName(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        // Cursor 事件里 Auto 常记为 default，官网 Included Usage 显示为 auto
        if trimmed.lowercased() == "default" { return "auto" }
        return trimmed
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
                model: displayModelName(model),
                cents: modelEvents.compactMap(\.chargedCents).reduce(0, +),
                count: modelEvents.count
            )
        }
        .sorted { $0.cents > $1.cents }
        return topSlices(slices)
    }

    private static func topSlices(_ slices: [ModelSpendSlice], limit: Int = 8) -> [ModelSpendSlice] {
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

    static func formatBillingPeriod(start: Date?, end: Date?, language: ResolvedLanguage) -> String? {
        guard let start, let end else { return nil }
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(language.locale)
        return "\(start.formatted(formatter)) - \(end.formatted(formatter))"
    }
}
