import Foundation

/// 模型计费规则，来源：https://cursor.com/docs/models-and-pricing
enum ModelPricingCatalog {
    static let docsURL = URL(string: "https://cursor.com/docs/models-and-pricing")!

    enum Pool: String, Sendable {
        case firstParty
        case api

        func label(language: ResolvedLanguage) -> String {
            switch self {
            case .firstParty:
                return L10n.string(.poolFirstPartyLabel, language: language)
            case .api:
                return L10n.string(.poolApiLabel, language: language)
            }
        }

        func summary(language: ResolvedLanguage) -> String {
            switch self {
            case .firstParty:
                return L10n.string(.poolFirstPartySummary, language: language)
            case .api:
                return L10n.string(.poolApiSummary, language: language)
            }
        }

        var label: String {
            label(language: LocalizationManager.resolvedLanguage())
        }

        var summary: String {
            summary(language: LocalizationManager.resolvedLanguage())
        }
    }

    struct Rule: Sendable {
        let displayName: String
        let provider: String?
        let pool: Pool
        let inputPerMillion: Double?
        let cacheWritePerMillion: Double?
        let cacheReadPerMillion: Double?
        let outputPerMillion: Double?
        let notes: String?

        func applying(_ version: PricingVersion) -> Rule {
            Rule(
                displayName: displayName,
                provider: provider,
                pool: pool,
                inputPerMillion: version.inputPerMillion,
                cacheWritePerMillion: version.cacheWritePerMillion,
                cacheReadPerMillion: version.cacheReadPerMillion,
                outputPerMillion: version.outputPerMillion,
                notes: version.notes ?? notes
            )
        }

        func formattedRate(_ value: Double?) -> String {
            guard let value else { return "—" }
            if value < 1 {
                return String(format: "$%.3f / 1M", value)
            }
            return String(format: "$%.2f / 1M", value)
        }

        var rateLines: [String] {
            rateLines(language: LocalizationManager.resolvedLanguage())
        }

        func rateLines(language: ResolvedLanguage) -> [String] {
            var lines: [String] = []
            if pool == .firstParty, displayName == "Auto" {
                lines.append(
                    "\(L10n.string(.rateInputCacheWrite, language: language))：\(formattedRate(inputPerMillion))"
                )
            } else {
                lines.append("\(L10n.string(.rateInput, language: language))：\(formattedRate(inputPerMillion))")
                if cacheWritePerMillion != nil {
                    lines.append(
                        "\(L10n.string(.rateCacheWrite, language: language))：\(formattedRate(cacheWritePerMillion))"
                    )
                }
            }
            lines.append("\(L10n.string(.rateCacheRead, language: language))：\(formattedRate(cacheReadPerMillion))")
            lines.append("\(L10n.string(.rateOutput, language: language))：\(formattedRate(outputPerMillion))")
            return lines
        }

        private func localizedComponentLabel(_ key: L10n.Key, language: ResolvedLanguage) -> String {
            L10n.string(key, language: language)
        }

        func estimateCost(from tokenUsage: UsageEvent.TokenUsage, language: ResolvedLanguage) -> TokenCostEstimate? {
            var components: [TokenCostEstimate.Component] = []

            if let input = tokenUsage.inputTokens, input > 0, let rate = inputPerMillion {
                components.append(
                    .init(
                        label: localizedComponentLabel(.rateInput, language: language),
                        tokenCount: input,
                        ratePerMillion: rate
                    )
                )
            }

            if let output = tokenUsage.outputTokens, output > 0, let rate = outputPerMillion {
                components.append(
                    .init(
                        label: localizedComponentLabel(.rateOutput, language: language),
                        tokenCount: output,
                        ratePerMillion: rate
                    )
                )
            }

            if let cacheRead = tokenUsage.cacheReadTokens, cacheRead > 0, let rate = cacheReadPerMillion {
                components.append(
                    .init(
                        label: localizedComponentLabel(.rateCacheRead, language: language),
                        tokenCount: cacheRead,
                        ratePerMillion: rate
                    )
                )
            }

            if let cacheWrite = tokenUsage.cacheWriteTokens, cacheWrite > 0 {
                let rate: Double?
                if pool == .firstParty, displayName == "Auto" {
                    rate = inputPerMillion
                } else if let cacheWritePerMillion {
                    rate = cacheWritePerMillion
                } else if let inputPerMillion {
                    rate = inputPerMillion * 1.25
                } else {
                    rate = nil
                }
                if let rate {
                    components.append(
                        .init(
                            label: localizedComponentLabel(.rateCacheWrite, language: language),
                            tokenCount: cacheWrite,
                            ratePerMillion: rate
                        )
                    )
                }
            }

            guard !components.isEmpty else { return nil }
            let total = components.map(\.costDollars).reduce(0, +)
            return TokenCostEstimate(components: components, totalDollars: total)
        }

        func estimateCost(from tokenUsage: UsageEvent.TokenUsage) -> TokenCostEstimate? {
            estimateCost(from: tokenUsage, language: LocalizationManager.resolvedLanguage())
        }
    }

    struct TokenCostEstimate: Sendable {
        struct Component: Sendable, Identifiable {
            let id: String
            let label: String
            let tokenCount: Int
            let ratePerMillion: Double
            let costDollars: Double

            init(label: String, tokenCount: Int, ratePerMillion: Double) {
                self.id = label
                self.label = label
                self.tokenCount = tokenCount
                self.ratePerMillion = ratePerMillion
                self.costDollars = Double(tokenCount) / 1_000_000.0 * ratePerMillion
            }

            var formulaText: String {
                let tokens = UsageEvent.formatTokenCount(tokenCount)
                let rate = TokenCostEstimate.formatRate(ratePerMillion)
                let cost = TokenCostEstimate.formatDollars(costDollars)
                return "\(tokens) × \(rate) = \(cost)"
            }
        }

        let components: [Component]
        let totalDollars: Double

        var formattedTotal: String { Self.formatDollars(totalDollars) }

        static func formatRate(_ value: Double) -> String {
            if value < 1 { return String(format: "$%.3f/M", value) }
            return String(format: "$%.2f/M", value)
        }

        static func formatDollars(_ value: Double) -> String {
            if value < 0.01 { return String(format: "$%.4f", value) }
            return String(format: "$%.2f", value)
        }
    }

    struct PricingVersion: Sendable {
        let effectiveFrom: Date
        let inputPerMillion: Double?
        let cacheWritePerMillion: Double?
        let cacheReadPerMillion: Double?
        let outputPerMillion: Double?
        let notes: String?
    }

    /// OpenAI GPT-5.6 Luna/Terra 降价生效日（UTC，与 Cursor 官网一致）
    private static let gpt56PriceCutUTC: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 7
        components.day = 30
        return components.date ?? .distantPast
    }()

    /// Claude Sonnet 5 促销结束日（UTC）：2026-09-01 起恢复标准价
    private static let claudeSonnet5PromoEndUTC: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 9
        components.day = 1
        return components.date ?? .distantFuture
    }()

    static func estimatedCost(
        for model: String?,
        tokenUsage: UsageEvent.TokenUsage?,
        at date: Date? = nil
    ) -> TokenCostEstimate? {
        guard let tokenUsage else { return nil }
        return rule(for: model, at: date).estimateCost(from: tokenUsage)
    }

    private static let entries: [(slugs: [String], rule: Rule)] = [
        (["auto", "default"], Rule(
            displayName: "Auto",
            provider: "Cursor",
            pool: .firstParty,
            inputPerMillion: 1.25,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.25,
            outputPerMillion: 6.0,
            notes: "输入与缓存写入合并计费 $1.25/1M；由 Cursor 自动选模型。事件里常见 model=default。"
        )),
        (["composer-2.5", "composer-2", "composer-2.5-fast"], Rule(
            displayName: "Composer 2.5",
            provider: "Cursor",
            pool: .firstParty,
            inputPerMillion: 0.5,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.2,
            outputPerMillion: 2.5,
            notes: "Cursor 自研 Agent 模型，走第一方模型池。"
        )),
        (["agent_review", "agent-review"], Rule(
            displayName: "Agent Review",
            provider: "Cursor",
            pool: .api,
            inputPerMillion: nil,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: nil,
            outputPerMillion: nil,
            notes: "走 API 池（与 Cursor 官网 Included Usage 一致）。"
        )),
        (["composer-1"], Rule(
            displayName: "Composer 1",
            provider: "Cursor",
            pool: .api,
            inputPerMillion: 1.25,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.125,
            outputPerMillion: 10.0,
            notes: nil
        )),
        (["grok-4.5", "cursor-grok-4.5"], Rule(
            displayName: "Grok 4.5",
            provider: "Cursor × SpaceXAI",
            pool: .firstParty,
            inputPerMillion: 2.0,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.5,
            outputPerMillion: 6.0,
            notes: "第一方模型池；欧盟地区暂不可用。"
        )),
        (["claude-4-sonnet", "claude-sonnet-4"], Rule(
            displayName: "Claude 4 Sonnet",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 3.0,
            cacheWritePerMillion: 3.75,
            cacheReadPerMillion: 0.3,
            outputPerMillion: 15.0,
            notes: "Thinking 变体在旧按次计费方案中计 2 次请求。"
        )),
        (["claude-4-sonnet-1m"], Rule(
            displayName: "Claude 4 Sonnet 1M",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 6.0,
            cacheWritePerMillion: 7.5,
            cacheReadPerMillion: 0.6,
            outputPerMillion: 22.5,
            notes: "超大上下文窗口，输入超 200k 时费用翻倍。"
        )),
        (["claude-4.5-haiku", "claude-haiku-4.5"], Rule(
            displayName: "Claude 4.5 Haiku",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 1.0,
            cacheWritePerMillion: 1.25,
            cacheReadPerMillion: 0.1,
            outputPerMillion: 5.0,
            notes: nil
        )),
        (["claude-4.5-opus", "claude-opus-4.5"], Rule(
            displayName: "Claude 4.5 Opus",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 5.0,
            cacheWritePerMillion: 6.25,
            cacheReadPerMillion: 0.5,
            outputPerMillion: 25.0,
            notes: "旧按次方案需开启 Max Mode。"
        )),
        (["claude-4.5-sonnet", "claude-sonnet-4.5"], Rule(
            displayName: "Claude 4.5 Sonnet",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 3.0,
            cacheWritePerMillion: 3.75,
            cacheReadPerMillion: 0.3,
            outputPerMillion: 15.0,
            notes: "Max Mode 下支持最高 1M 上下文，单价不变。"
        )),
        (["claude-4.6-opus", "claude-opus-4.6"], Rule(
            displayName: "Claude 4.6 Opus",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 5.0,
            cacheWritePerMillion: 6.25,
            cacheReadPerMillion: 0.5,
            outputPerMillion: 25.0,
            notes: nil
        )),
        (["claude-4.6-sonnet", "claude-sonnet-4.6"], Rule(
            displayName: "Claude 4.6 Sonnet",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 3.0,
            cacheWritePerMillion: 3.75,
            cacheReadPerMillion: 0.3,
            outputPerMillion: 15.0,
            notes: nil
        )),
        (["claude-4.7-opus", "claude-opus-4.7"], Rule(
            displayName: "Claude 4.7 Opus",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 5.0,
            cacheWritePerMillion: 6.25,
            cacheReadPerMillion: 0.5,
            outputPerMillion: 25.0,
            notes: nil
        )),
        (["claude-opus-4.7-fast", "claude-4.7-opus-fast"], Rule(
            displayName: "Claude Opus 4.7 (Fast)",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 30.0,
            cacheWritePerMillion: 37.5,
            cacheReadPerMillion: 3.0,
            outputPerMillion: 150.0,
            notes: "快速模式，限量研究预览。"
        )),
        (["claude-opus-4.8", "claude-4.8-opus"], Rule(
            displayName: "Claude Opus 4.8",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 5.0,
            cacheWritePerMillion: 6.25,
            cacheReadPerMillion: 0.5,
            outputPerMillion: 25.0,
            notes: "Fast 模式单价为 Opus 4.7 Fast 的 1/3。"
        )),
        (["claude-sonnet-5"], Rule(
            displayName: "Claude Sonnet 5",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 3.0,
            cacheWritePerMillion: 3.75,
            cacheReadPerMillion: 0.3,
            outputPerMillion: 15.0,
            notes: "标准价；2026-08-31 前促销价为 $2/$10。"
        )),
        (["claude-fable-5"], Rule(
            displayName: "Claude Fable 5",
            provider: "Anthropic",
            pool: .api,
            inputPerMillion: 10.0,
            cacheWritePerMillion: 12.5,
            cacheReadPerMillion: 1.0,
            outputPerMillion: 50.0,
            notes: "约为 Claude Opus 4.8 的 2 倍价格；企业需数据留存审批。"
        )),
        (["gemini-2.5-flash"], Rule(
            displayName: "Gemini 2.5 Flash",
            provider: "Google",
            pool: .api,
            inputPerMillion: 0.3,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.03,
            outputPerMillion: 2.5,
            notes: nil
        )),
        (["gemini-3-flash"], Rule(
            displayName: "Gemini 3 Flash",
            provider: "Google",
            pool: .api,
            inputPerMillion: 0.5,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.05,
            outputPerMillion: 3.0,
            notes: nil
        )),
        (["gemini-3-pro"], Rule(
            displayName: "Gemini 3 Pro",
            provider: "Google",
            pool: .api,
            inputPerMillion: 2.0,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.2,
            outputPerMillion: 12.0,
            notes: nil
        )),
        (["gemini-3.1-pro"], Rule(
            displayName: "Gemini 3.1 Pro",
            provider: "Google",
            pool: .api,
            inputPerMillion: 2.0,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.2,
            outputPerMillion: 12.0,
            notes: nil
        )),
        (["gemini-3.5-flash"], Rule(
            displayName: "Gemini 3.5 Flash",
            provider: "Google",
            pool: .api,
            inputPerMillion: 1.5,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.15,
            outputPerMillion: 9.0,
            notes: nil
        )),
        (["gemini-3.6-flash"], Rule(
            displayName: "Gemini 3.6 Flash",
            provider: "Google",
            pool: .api,
            inputPerMillion: 1.5,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.15,
            outputPerMillion: 7.5,
            notes: nil
        )),
        (["gpt-5"], Rule(
            displayName: "GPT-5",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 1.25,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.125,
            outputPerMillion: 10.0,
            notes: nil
        )),
        (["gpt-5-fast"], Rule(
            displayName: "GPT-5 Fast",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 2.5,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.25,
            outputPerMillion: 20.0,
            notes: "速度更快，价格为标准版 2 倍。"
        )),
        (["gpt-5-mini"], Rule(
            displayName: "GPT-5 Mini",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 0.25,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.025,
            outputPerMillion: 2.0,
            notes: nil
        )),
        (["gpt-5-codex", "gpt-5.1-codex", "gpt-5.1-codex-max"], Rule(
            displayName: "GPT-5 Codex",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 1.25,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.125,
            outputPerMillion: 10.0,
            notes: nil
        )),
        (["gpt-5.1-codex-mini"], Rule(
            displayName: "GPT-5.1 Codex Mini",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 0.25,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.025,
            outputPerMillion: 2.0,
            notes: "限流为 Codex 标准的 4 倍。"
        )),
        (["gpt-5.2", "gpt-5.2-codex"], Rule(
            displayName: "GPT-5.2",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 1.75,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.175,
            outputPerMillion: 14.0,
            notes: nil
        )),
        (["gpt-5.3-codex"], Rule(
            displayName: "GPT-5.3 Codex",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 1.75,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.175,
            outputPerMillion: 14.0,
            notes: nil
        )),
        (["gpt-5.4"], Rule(
            displayName: "GPT-5.4",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 2.5,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.25,
            outputPerMillion: 15.0,
            notes: "缓存输入 90% 折扣；Fast 模式价格 2 倍；Max 超 1M 输入 2 倍。"
        )),
        (["gpt-5.4-mini"], Rule(
            displayName: "GPT-5.4 Mini",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 0.75,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.075,
            outputPerMillion: 4.5,
            notes: nil
        )),
        (["gpt-5.4-nano"], Rule(
            displayName: "GPT-5.4 Nano",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 0.2,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.02,
            outputPerMillion: 1.25,
            notes: nil
        )),
        (["gpt-5.5"], Rule(
            displayName: "GPT-5.5",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 5.0,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.5,
            outputPerMillion: 30.0,
            notes: "Max 超 1M 输入 2 倍；Fast 模式价格更高。"
        )),
        (["gpt-5.6-luna"], Rule(
            displayName: "GPT-5.6 Luna",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 0.2,
            cacheWritePerMillion: 0.25,
            cacheReadPerMillion: 0.02,
            outputPerMillion: 1.2,
            notes: "2026-07-30 降价 80%；缓存写入按未缓存输入价的 1.25 倍；Fast 模式价格 2 倍。"
        )),
        (["gpt-5.6-sol"], Rule(
            displayName: "GPT-5.6 Sol",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 5.0,
            cacheWritePerMillion: 6.25,
            cacheReadPerMillion: 0.5,
            outputPerMillion: 30.0,
            notes: "缓存写入按未缓存输入价的 1.25 倍；Fast 模式价格 2 倍；Max 超 1M 输入 2 倍。"
        )),
        (["gpt-5.6-terra"], Rule(
            displayName: "GPT-5.6 Terra",
            provider: "OpenAI",
            pool: .api,
            inputPerMillion: 2.0,
            cacheWritePerMillion: 2.5,
            cacheReadPerMillion: 0.2,
            outputPerMillion: 12.0,
            notes: "2026-07-30 降价 20%；缓存写入按未缓存输入价的 1.25 倍；Fast 模式价格 2 倍。"
        )),
        (["glm-5.2"], Rule(
            displayName: "GLM 5.2",
            provider: "Z.ai",
            pool: .api,
            inputPerMillion: 1.4,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.26,
            outputPerMillion: 4.4,
            notes: nil
        )),
        (["kimi-k2.7-code"], Rule(
            displayName: "Kimi K2.7 Code",
            provider: "Moonshot",
            pool: .api,
            inputPerMillion: 0.95,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: 0.19,
            outputPerMillion: 4.0,
            notes: nil
        )),
    ]

    /// 按生效日维护的历史单价；未列出的模型始终使用 entries 中的当前价
    private static let versionSchedules: [String: [PricingVersion]] = [
        "gpt-5.6-luna": [
            PricingVersion(
                effectiveFrom: .distantPast,
                inputPerMillion: 1.0,
                cacheWritePerMillion: 1.25,
                cacheReadPerMillion: 0.1,
                outputPerMillion: 6.0,
                notes: "2026-07-30 前单价；缓存写入按未缓存输入价的 1.25 倍。"
            ),
            PricingVersion(
                effectiveFrom: gpt56PriceCutUTC,
                inputPerMillion: 0.2,
                cacheWritePerMillion: 0.25,
                cacheReadPerMillion: 0.02,
                outputPerMillion: 1.2,
                notes: "2026-07-30 起降价 80%；缓存写入按未缓存输入价的 1.25 倍；Fast 模式价格 2 倍。"
            ),
        ],
        "gpt-5.6-terra": [
            PricingVersion(
                effectiveFrom: .distantPast,
                inputPerMillion: 2.5,
                cacheWritePerMillion: 3.125,
                cacheReadPerMillion: 0.25,
                outputPerMillion: 15.0,
                notes: "2026-07-30 前单价；缓存写入按未缓存输入价的 1.25 倍。"
            ),
            PricingVersion(
                effectiveFrom: gpt56PriceCutUTC,
                inputPerMillion: 2.0,
                cacheWritePerMillion: 2.5,
                cacheReadPerMillion: 0.2,
                outputPerMillion: 12.0,
                notes: "2026-07-30 起降价 20%；缓存写入按未缓存输入价的 1.25 倍；Fast 模式价格 2 倍。"
            ),
        ],
        "claude-sonnet-5": [
            PricingVersion(
                effectiveFrom: .distantPast,
                inputPerMillion: 2.0,
                cacheWritePerMillion: 2.5,
                cacheReadPerMillion: 0.2,
                outputPerMillion: 10.0,
                notes: "促销至 2026-08-31：输入 $2/M、输出 $10/M。"
            ),
            PricingVersion(
                effectiveFrom: claudeSonnet5PromoEndUTC,
                inputPerMillion: 3.0,
                cacheWritePerMillion: 3.75,
                cacheReadPerMillion: 0.3,
                outputPerMillion: 15.0,
                notes: "2026-09-01 起恢复标准价。"
            ),
        ],
    ]

    static func rule(for model: String?) -> Rule {
        rule(for: model, at: Date())
    }

    static func rule(for model: String?, at date: Date?) -> Rule {
        guard let model, !model.isEmpty else { return unknownRule(for: "未知模型") }

        let lookupDate = date ?? Date()
        let (baseRule, canonicalSlug) = resolveBaseRule(for: model)
        return applyVersionSchedule(to: baseRule, canonicalSlug: canonicalSlug, at: lookupDate)
    }

    private static func resolveBaseRule(for model: String) -> (Rule, String?) {
        let normalized = normalizeSlug(model)

        for entry in entries {
            for slug in entry.slugs {
                let normalizedSlug = normalizeSlug(slug)
                if normalized == normalizedSlug
                    || normalized.hasPrefix(normalizedSlug + "-")
                    || normalizedSlug.hasPrefix(normalized + "-") {
                    return (entry.rule, normalizedSlug)
                }
            }
        }

        for entry in entries {
            for slug in entry.slugs {
                let normalizedSlug = normalizeSlug(slug)
                if normalized.contains(normalizedSlug) || normalizedSlug.contains(normalized) {
                    return (entry.rule, normalizedSlug)
                }
            }
        }

        return (unknownRule(for: model), nil)
    }

    private static func applyVersionSchedule(to rule: Rule, canonicalSlug: String?, at date: Date) -> Rule {
        guard let canonicalSlug,
              let versions = versionSchedules[canonicalSlug],
              !versions.isEmpty
        else {
            return rule
        }

        let version = versions.last(where: { $0.effectiveFrom <= date }) ?? versions[0]
        return rule.applying(version)
    }

    static func billingContext(for event: UsageEvent) -> String? {
        billingContext(for: event, language: LocalizationManager.resolvedLanguage())
    }

    static func billingContext(for event: UsageEvent, language: ResolvedLanguage) -> String? {
        guard let kind = event.kind else { return nil }
        switch kind {
        case "USAGE_EVENT_KIND_INCLUDED_IN_PRO_PLUS":
            return L10n.string(.billingContextProPlus, language: language)
        case "USAGE_EVENT_KIND_INCLUDED_IN_PRO":
            return L10n.string(.billingContextPro, language: language)
        case "USAGE_EVENT_KIND_INCLUDED_IN_BUSINESS":
            return L10n.string(.billingContextBusiness, language: language)
        case "USAGE_EVENT_KIND_USAGE_BASED":
            return L10n.string(.billingContextUsageBased, language: language)
        case "USAGE_EVENT_KIND_FREE":
            return L10n.string(.billingContextFree, language: language)
        default:
            return nil
        }
    }

    private static func unknownRule(for model: String) -> Rule {
        let language = LocalizationManager.resolvedLanguage()
        return Rule(
            displayName: model,
            provider: nil,
            pool: .api,
            inputPerMillion: nil,
            cacheWritePerMillion: nil,
            cacheReadPerMillion: nil,
            outputPerMillion: nil,
            notes: L10n.string(.unknownModelNotes, language: language)
        )
    }

    private static func normalizeSlug(_ model: String) -> String {
        var slug = model.lowercased()
        if slug.hasPrefix("cursor-") {
            slug = String(slug.dropFirst("cursor-".count))
        }

        let removableSuffixes = [
            "-thinking-high",
            "-thinking",
            "-high-fast",
            "-low-fast",
            "-high",
            "-medium",
            "-low",
            "-fast",
        ]
        var changed = true
        while changed {
            changed = false
            for suffix in removableSuffixes where slug.hasSuffix(suffix) {
                slug = String(slug.dropLast(suffix.count))
                changed = true
                break
            }
        }

        return slug
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }
}
