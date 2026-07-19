import Charts
import SwiftUI

private struct DailySpendLabelCandidate {
    let point: DailySpendPoint
    let value: Double
}

extension Array where Element == DailySpendPoint {
    /// 只为重要且彼此间隔足够的柱子挑选额度标签，避免重叠。
    func annotatedPercentLabelIDs() -> Set<String> {
        annotatedLabelIDs { point in
            guard let percent = point.dailyPercent, percent > 0 else { return nil }
            return percent
        }
    }

    /// 按当日花费金额挑选柱顶标签。
    func annotatedDollarLabelIDs() -> Set<String> {
        annotatedLabelIDs { point in
            let dollars = point.dollars
            guard dollars > 0 else { return nil }
            return dollars
        }
    }

    private func annotatedLabelIDs(value: (DailySpendPoint) -> Double?) -> Set<String> {
        let candidates = compactMap { point -> DailySpendLabelCandidate? in
            guard let metric = value(point) else { return nil }
            return DailySpendLabelCandidate(point: point, value: metric)
        }
        guard !candidates.isEmpty else { return [] }

        let peak = candidates.map(\.value).max() ?? 0
        let threshold = Swift.max(peak * 0.12, peak > 1 ? 0.5 : 0.01)
        let calendar = Calendar.current
        let minGapDays = candidates.count > 12 ? 3 : (candidates.count > 7 ? 2 : 1)
        let maxLabels = Swift.min(7, Swift.max(4, candidates.count / 3))

        var chosen: [DailySpendLabelCandidate] = []
        for candidate in candidates.sorted(by: { $0.value > $1.value }) {
            if candidate.value < threshold, !chosen.isEmpty { continue }

            let day = calendar.startOfDay(for: candidate.point.date)
            let tooClose = chosen.contains { other in
                let otherDay = calendar.startOfDay(for: other.point.date)
                let gap = abs(calendar.dateComponents([.day], from: otherDay, to: day).day ?? 0)
                return gap < minGapDays
            }
            if tooClose { continue }

            chosen.append(candidate)
            if chosen.count >= maxLabels { break }
        }

        return Set(chosen.map(\.point.id))
    }
}

private struct DailyPercentBarLabel: View {
    let percent: Double

    var body: some View {
        Text(UsageAnalytics.formatPercent(percent))
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
            .background(.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
    }
}

private struct DailyDollarBarLabel: View {
    let dollars: Double

    var body: some View {
        Text(formatDollars(dollars))
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
            .background(.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
    }

    private func formatDollars(_ amount: Double) -> String {
        if amount < 0.01 { return String(format: "$%.4f", amount) }
        if amount < 10 { return String(format: "$%.2f", amount) }
        return String(format: "$%.1f", amount)
    }
}

struct DailySpendChart: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let data: [DailySpendPoint]

    private var annotatedPointIDs: Set<String> {
        data.annotatedDollarLabelIDs()
    }

    private var maxDollars: Double {
        let peak = data.map(\.dollars).max() ?? 0
        return Swift.max(peak * 1.2, 0.5)
    }

    var body: some View {
        if data.isEmpty {
            ChartEmptyState(message: l10n.t(.emptyDailySpend))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t(.dailySpendLabelHint))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Chart(data) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("花费", point.dollars)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 4) {
                        if point.dollars > 0, annotatedPointIDs.contains(point.id) {
                            DailyDollarBarLabel(dollars: point.dollars)
                        }
                    }
                }
                .chartYScale(domain: 0 ... maxDollars * 1.15)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, data.count / 5))) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("$\(amount, specifier: "%.1f")")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxisLabel(l10n.t(.spendAxis))
                .frame(height: 180)
            }
        }
    }
}

struct DailyUsagePercentChart: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let data: [DailySpendPoint]
    let limitContext: UsageLimitContext?

    private var hasPercentData: Bool {
        data.contains { $0.dailyPercent != nil }
    }

    private var maxDailyPercent: Double {
        let peak = data.compactMap(\.dailyPercent).max() ?? 0
        return max(peak * 1.25, 0.5)
    }

    private var annotatedPointIDs: Set<String> {
        data.annotatedPercentLabelIDs()
    }

    var body: some View {
        if data.isEmpty {
            ChartEmptyState(message: l10n.t(.emptyDailyUsage))
        } else if !hasPercentData {
            ChartEmptyState(message: l10n.t(.noPercentData))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let limitContext {
                    Text(limitContext.formatBaseline(language: l10n.resolved))
                        .font(.caption.weight(.semibold))
                    Text(l10n.t(.dailyPercentFormula))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Chart(data) { point in
                    let percent = point.dailyPercent ?? 0
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("占总额度", percent)
                    )
                    .foregroundStyle(percentColor(percent).gradient)
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 4) {
                        if percent > 0, annotatedPointIDs.contains(point.id) {
                            DailyPercentBarLabel(percent: percent)
                        }
                    }
                }
                .chartYScale(domain: 0 ... maxDailyPercent * 1.12)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, data.count / 5))) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let pct = value.as(Double.self) {
                                Text(UsageAnalytics.formatPercent(pct))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxisLabel(l10n.t(.percentOfBilling))
                .frame(height: 180)
            }
        }
    }

    private func percentColor(_ percent: Double) -> Color {
        if percent >= 15 { return .red }
        if percent >= 8 { return .orange }
        return .blue
    }
}

struct QuotaDeclineChart: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let data: [QuotaCurvePoint]
    let limitContext: UsageLimitContext?

    private var hasData: Bool {
        !data.isEmpty
    }

    private var seriesColors: [String: Color] {
        [
            QuotaCurveSeries.total.rawValue: .blue,
            QuotaCurveSeries.api.rawValue: .orange,
            QuotaCurveSeries.auto.rawValue: .purple,
        ]
    }

    var body: some View {
        if !hasData {
            ChartEmptyState(message: l10n.t(.emptyQuotaCurve))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let limitContext {
                    Text(limitContext.formatBaseline(language: l10n.resolved))
                        .font(.caption.weight(.semibold))
                }
                Text(l10n.t(.quotaDeclineFormula))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Chart(data) { point in
                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("剩余额度", point.remainingPercent)
                    )
                    .foregroundStyle(by: .value("类型", point.series.rawValue))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("剩余额度", point.remainingPercent)
                    )
                    .foregroundStyle(by: .value("类型", point.series.rawValue))
                    .symbolSize(18)
                }
                .chartForegroundStyleScale(domain: Array(seriesColors.keys), range: Array(seriesColors.values))
                .chartYScale(domain: 0 ... 100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, uniqueDayCount / 5))) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: 25)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let pct = value.as(Double.self) {
                                Text("\(Int(pct))%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxisLabel(l10n.t(.remainingQuotaPercent))
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 200)

                quotaLegend
            }
        }
    }

    private var uniqueDayCount: Int {
        Set(data.map(\.date)).count
    }

    private var quotaLegend: some View {
        HStack(spacing: 12) {
            ForEach(QuotaCurveSeries.allCases) { series in
                let latest = data.last(where: { $0.series == series })
                HStack(spacing: 4) {
                    Circle()
                        .fill(seriesColors[series.rawValue] ?? .gray)
                        .frame(width: 8, height: 8)
                    Text(series.rawValue)
                        .font(.caption2)
                    if let latest {
                        Text(UsageAnalytics.formatPercent(latest.remainingPercent))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}

struct DailyUsagePercentList: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let data: [DailySpendPoint]
    let limitContext: UsageLimitContext?

    var body: some View {
        let recent = Array(data.suffix(7).reversed())
        if recent.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                ForEach(recent) { point in
                    HStack(alignment: .firstTextBaseline) {
                        Text(point.date.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .leading)
                        Spacer()
                        if let daily = point.dailyPercent {
                            Text(UsageAnalytics.formatPercent(daily))
                                .font(.caption.weight(.semibold))
                            if let cumulative = point.cumulativePercent {
                                Text(l10n.format(.cumulative, UsageAnalytics.formatPercent(cumulative)))
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        if let limitContext {
                            Text(limitContext.formatDailyUsage(point.cents))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

struct ModelSpendChart: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let data: [ModelSpendSlice]

    private let palette: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo, .gray]

    var body: some View {
        if data.isEmpty {
            ChartEmptyState(message: l10n.t(.emptyModelDistribution))
        } else {
            HStack(alignment: .top, spacing: 12) {
                Chart(Array(data.enumerated()), id: \.element.id) { index, slice in
                    SectorMark(
                        angle: .value("花费", max(slice.dollars, 0.01)),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.2
                    )
                    .foregroundStyle(palette[index % palette.count])
                    .cornerRadius(2)
                }
                .frame(width: 120, height: 120)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, slice in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(palette[index % palette.count])
                                    .frame(width: 8, height: 8)
                                Text(slice.model)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Text("$\(slice.dollars, specifier: "%.2f")")
                                    .font(.caption2.weight(.medium))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }
}

struct IncludedUsageTable: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let summary: IncludedUsageSummary
    let billingPeriod: String?
    var todayUsagePercent: Double? = nil
    var cycleUsagePercent: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                if let billingPeriod {
                    Text(billingPeriod)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let cycleUsagePercent {
                    Text(l10n.format(.cycleUsagePercentShort, UsageAnalytics.formatPercent(cycleUsagePercent)))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }

            if let todayUsagePercent {
                HStack {
                    Text(l10n.t(.todayBillingPercent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(UsageAnalytics.formatPercent(todayUsagePercent))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(todayUsagePercent >= 10 ? .orange : .green)
                }
                .padding(.vertical, 4)
            }

            Text(l10n.t(.includedUsageCostHint))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(l10n.t(.columnItem))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(l10n.t(.columnTokens))
                    .frame(width: 72, alignment: .trailing)
                Text(l10n.t(.columnUsage))
                    .frame(width: 52, alignment: .trailing)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(summary.groups) { group in
                Divider()
                groupHeader(group)
                ForEach(group.rows) { row in
                    modelRow(row)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func groupHeader(_ group: IncludedUsageGroup) -> some View {
        HStack(spacing: 8) {
            Text(group.pool.label(language: l10n.resolved))
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(UsageEvent.formatTokenCount(group.totalTokens, language: l10n.resolved))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
            Text(UsageAnalytics.formatPercent(group.usagePercent))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private func modelRow(_ row: IncludedUsageRow) -> some View {
        HStack(spacing: 8) {
            Text(row.model)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(UsageEvent.formatTokenCount(row.tokens, language: l10n.resolved))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
            Text(UsageAnalytics.formatPercent(row.usagePercent))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

struct DailyModelUsageChart: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let day: DailyModelShareDay?

    private let palette: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo, .mint, .gray]

    private var slices: [DailyModelShareSlice] {
        day?.slices ?? []
    }

    var body: some View {
        if slices.isEmpty {
            ChartEmptyState(message: l10n.t(.emptyDailyModelShare))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if let day {
                    Text(day.date.formatted(.dateTime.year().month().day().weekday(.wide).locale(l10n.resolved.locale)))
                        .font(.caption.weight(.semibold))
                    Text(l10n.t(.dailyModelShareHint))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 12) {
                    Chart(Array(slices.enumerated()), id: \.element.id) { index, slice in
                        SectorMark(
                            angle: .value("Share", max(slice.percent, 0.01)),
                            innerRadius: .ratio(0.52),
                            angularInset: 1.2
                        )
                        .foregroundStyle(palette[index % palette.count])
                        .cornerRadius(2)
                    }
                    .frame(width: 128, height: 128)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Circle()
                                    .fill(palette[index % palette.count])
                                    .frame(width: 8, height: 8)
                                Text(slice.model)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Text(UsageAnalytics.formatPercent(slice.percent))
                                    .font(.caption2.weight(.semibold))
                                    .monospacedDigit()
                            }
                        }
                        if let day {
                            Divider().padding(.vertical, 2)
                            Text(
                                "\(l10n.t(.token)) \(UsageEvent.formatTokenCount(day.totalTokens, language: l10n.resolved))"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}

struct UsagePoolsView: View {
    let pools: [UsagePoolMetrics]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(pools) { pool in
                UsagePoolCard(pool: pool)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct UsagePoolCard: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let pool: UsagePoolMetrics

    var body: some View {
        VStack(spacing: 8) {
            Text(pool.localizedTitle(language: l10n.resolved))
                .font(.caption.weight(.semibold))
                .foregroundStyle(pool.id == "api" ? .orange : .purple)

            PlanUsageGauge(
                used: pool.usedCents,
                limit: pool.limitCents,
                percent: pool.percent,
                formatAsDollars: pool.id == "api"
            )

            if pool.id == "auto", let spend = pool.spendCents {
                Text(l10n.format(.spendAmount, spend / 100))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let message = pool.displayMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SpendingBreakdownChart: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let items: [SpendingBreakdownItem]

    var body: some View {
        if items.isEmpty {
            ChartEmptyState(message: l10n.t(.emptySpendShare))
        } else {
            VStack(spacing: 10) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.localizedLabel(language: l10n.resolved))
                                .font(.caption)
                            Spacer()
                            Text(UsageAnalytics.formatPercent(item.percent))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.12))
                                Capsule()
                                    .fill(color(for: item.colorName).gradient)
                                    .frame(width: geo.size.width * min(item.percent, 100) / 100)
                            }
                        }
                        .frame(height: 8)

                        if let cents = item.spendCents {
                            Text(l10n.format(.usedSpend, cents / 100))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func color(for name: String) -> Color {
        switch name {
        case "purple": return .purple
        case "orange": return .orange
        default: return .blue
        }
    }
}

struct PlanUsageGauge: View {
    let used: Double?
    let limit: Double?
    let percent: Double?
    var formatAsDollars: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            if let percent {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: min(percent, 100) / 100)
                        .stroke(gaugeColor(percent), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(UsageAnalytics.formatPercent(percent))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                .frame(width: 96, height: 96)
            }

            if let used, let limit {
                Text("\(formatValue(used)) / \(formatValue(limit))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func gaugeColor(_ percent: Double) -> Color {
        if percent >= 90 { return .red }
        if percent >= 70 { return .orange }
        return .green
    }

    private func formatValue(_ value: Double) -> String {
        if formatAsDollars {
            return String(format: "$%.2f", value / 100)
        }
        if value.rounded() == value { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}

struct ChartEmptyState: View {
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}

struct ChartLoadingState: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
    }
}

struct ChartErrorState: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
    }
}

struct ModelTokenUsageTable: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let summary: ModelTokenUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                tokenStat(l10n.t(.inputTokens), summary.totalInputTokens)
                tokenStat(l10n.t(.outputTokens), summary.totalOutputTokens)
            }
            HStack(spacing: 8) {
                tokenStat(l10n.t(.cacheRead), summary.totalCacheReadTokens)
                tokenStat(l10n.t(.cacheWrite), summary.totalCacheWriteTokens)
            }
            if let cost = summary.totalCostCents {
                Text(
                    "\(l10n.format(.totalTokensShort, UsageEvent.formatTokenCount(summary.totalTokens))) · \(String(format: "$%.2f", cost / 100))"
                )
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            }

            Divider()

            ForEach(summary.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.model)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                        Spacer()
                        if let usagePercent = row.usagePercent {
                            Text(UsageAnalytics.formatPercent(usagePercent))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Text(String(format: "$%.2f", row.totalCents / 100))
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                    }
                    HStack(spacing: 8) {
                        miniToken(l10n.t(.inputShort), row.inputTokens)
                        miniToken(l10n.t(.outputShort), row.outputTokens)
                        miniToken(l10n.t(.cacheReadShort), row.cacheReadTokens)
                        if row.cacheWriteTokens > 0 {
                            miniToken(l10n.t(.cacheWriteShort), row.cacheWriteTokens)
                        }
                        Spacer()
                        Text("\(UsageEvent.formatTokenCount(row.totalTokens)) tok")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func tokenStat(_ label: String, _ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(UsageEvent.formatTokenCount(count))
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func miniToken(_ label: String, _ count: Int) -> some View {
        Text("\(label) \(UsageEvent.formatTokenCount(count))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}
