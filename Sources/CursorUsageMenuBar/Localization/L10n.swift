import Foundation

enum L10n {
    static let allModelsMarker = "__ALL_MODELS__"

    enum Key: String, Sendable {
        // App shell
        case dashboardTitle
        case tabPicker
        case menuNotConfigured
        case refresh
        case settings
        case quitApp
        case updatedAt
        case getStarted
        case setupTokenHint
        case goToSettings

        // Tabs
        case tabOverview
        case tabCharts
        case tabIncluded
        case tabEvents
        case tabAccount

        // Today & cycle
        case today
        case todayBillingPercent
        case todayUsage
        case requestCount
        case spend
        case token
        case billingTotal
        case cycleUsage
        case cycleTotalSpend
        case apiUsed
        case autoBonusSpend
        case apiIncludedLimit
        case billingPeriod
        case totalEvents

        // Charts
        case quotaDeclineCurve
        case dailyUsagePercent
        case dailySpend
        case modelSpendDistribution
        case includedUsage
        case dailyModelShare
        case columnItem
        case columnTokens
        case columnUsage
        case emptyIncludedUsage
        case emptyDailyModelShare
        case dailyModelShareHint
        case dayFilter
        case dayFilterAll
        case dayStats
        case includedUsageCostHint
        case cycleUsagePercentShort
        case usageDetails
        case emptyQuotaCurve
        case emptyDailyUsage
        case emptyDailySpend
        case emptyModelDistribution
        case emptySpendShare
        case loadingChartData
        case chartLoadRetry
        case dailySpendLabelHint
        case dailyPercentFormula
        case quotaDeclineFormula
        case remainingQuotaPercent
        case spendAxis
        case percentOfBilling
        case noPercentData
        case cumulative
        case spendAmount
        case usedSpend
        case yourUsage
        case yourUsageSubtitle
        case groupByModelSpend
        case cumulativeSpendAxis
        case todayMarker
        case emptyCumulativeUsage
        case includedSpend
        case onDemandSpend

        // Spending tab
        case cycleSpending
        case spendShare
        case spendTrend
        case totalSpend
        case apiIncludedUsed

        // Billing tab
        case billingCycle
        case billingUsage
        case includedLimit
        case dualPoolStatus
        case apiPool
        case autoComposer
        case quotaExplanation
        case quotaExplanationBody
        case quotaUsage
        case modelTokenUsage
        case loadingAggregatedUsage
        case account
        case user
        case email
        case plan
        case handle
        case activeSessions
        case sessionTypeWeb
        case sessionTypeClient
        case sessionTypeMobile
        case sessionCreated
        case sessionExpires
        case sessionRevoke
        case sessionRevokeConfirm
        case sessionsEmpty
        case openWebSessions
        case cancel

        // Settings
        case settingsTitle
        case tokenInstruction
        case openDashboardLink
        case showToken
        case tokenSaved
        case sessionToken
        case save
        case clear
        case autoRefresh
        case requestInterval
        case requestIntervalValue
        case pacerHint
        case status
        case configured
        case notConfigured
        case lastRefresh
        case language
        case languageSystem
        case languageEnglish
        case languageChinese

        // Errors & API
        case tokenEmpty
        case fetchDataFailed
        case usageEventsError
        case apiErrorMissingToken
        case apiErrorInvalidResponse
        case apiErrorHttp
        case apiErrorDecode
        case keychainFailed
        case errorUsageSummary
        case errorSpendingData
        case errorBillingProfile
        case errorAccount
        case errorActiveSessions
        case errorAggregatedUsage
        case unknownError

        // Notifications
        case changeDefault
        case changeBannerTitle
        case notificationTitle
        case changeBilling
        case changeSpend
        case changeEvents
        case changeDailyChart

        // Pools & breakdown
        case poolApi
        case poolAuto
        case billingTotalLabel
        case spendingTotalLabel
        case othersModel
        case unknownModel
        case billingBaselineWithCost
        case billingBaseline

        // Usage events list
        case allModels
        case searchAll
        case searchPage
        case filterStatus
        case waitingCache
        case listStatus
        case noUsageEvents
        case noMatchingEvents
        case noPageRecords
        case loadingFullDetails
        case pageNumber
        case firstPage
        case lastPage
        case pricingRules
        case officialDocs
        case model
        case provider
        case billingPool
        case teamsTokenFee
        case calculatedPrice
        case calculatedTotal
        case actualCharge
        case fullModel
        case type
        case subscription
        case conversationId
        case inputTokens
        case outputTokens
        case cacheRead
        case cacheWrite
        case tokenFee
        case tokenTotal
        case tokenBasedBilling
        case usageBasedCosts
        case yes
        case no
        case totalTokensShort
        case inputShort
        case outputShort
        case cacheReadShort
        case cacheWriteShort

        // Pricing catalog
        case poolFirstPartyLabel
        case poolFirstPartySummary
        case poolApiLabel
        case poolApiSummary
        case rateInput
        case rateOutput
        case rateCacheRead
        case rateCacheWrite
        case rateInputCacheWrite
        case unknownModelNotes

        // Event kinds
        case kindProPlus
        case kindPro
        case kindBusiness
        case kindUsageBased
        case kindFree

        // Billing context
        case billingContextProPlus
        case billingContextPro
        case billingContextBusiness
        case billingContextUsageBased
        case billingContextFree
    }

    static func string(_ key: Key, language: ResolvedLanguage) -> String {
        switch language {
        case .english:
            return english[key] ?? key.rawValue
        case .chinese:
            return chinese[key] ?? english[key] ?? key.rawValue
        }
    }

    // MARK: - English (primary)

    private static let english: [Key: String] = [
        .dashboardTitle: "Cursor Dashboard",
        .tabPicker: "Section",
        .menuNotConfigured: "Setup",
        .refresh: "Refresh",
        .settings: "Settings",
        .quitApp: "Quit",
        .updatedAt: "Updated %@",
        .getStarted: "Get Started",
        .setupTokenHint: "Add your session token to view usage, spending, and billing charts.",
        .goToSettings: "Open Settings",

        .tabOverview: "Overview",
        .tabCharts: "Charts",
        .tabIncluded: "Included",
        .tabEvents: "Events",
        .tabAccount: "Account",

        .today: "Today",
        .todayBillingPercent: "Today vs Billing 100%",
        .todayUsage: "Today's usage",
        .requestCount: "Requests",
        .spend: "Spend",
        .token: "Token",
        .billingTotal: "Billing total",
        .cycleUsage: "Current cycle",
        .cycleTotalSpend: "Cycle spend",
        .apiUsed: "API used",
        .autoBonusSpend: "Auto bonus spend",
        .apiIncludedLimit: "API included allowance",
        .billingPeriod: "Billing period",
        .totalEvents: "Total events",

        .quotaDeclineCurve: "Quota decline",
        .dailyUsagePercent: "Daily usage vs Billing 100%",
        .dailySpend: "Daily spend",
        .modelSpendDistribution: "Spend by model",
        .includedUsage: "Included Usage",
        .dailyModelShare: "Daily model share",
        .columnItem: "Item",
        .columnTokens: "Tokens",
        .columnUsage: "Usage",
        .emptyIncludedUsage: "No included usage data yet",
        .emptyDailyModelShare: "No daily model share data yet",
        .dailyModelShareHint: "Pie chart for the selected day (thinking levels kept separate)",
        .dayFilter: "Day",
        .dayFilterAll: "Full cycle",
        .dayStats: "Day stats",
        .includedUsageCostHint: "Same as Cursor’s site: API group = api%, First-party = auto%. Model % = pool% × (model spend ÷ pool spend). API has no ready-made model%; the website calculates this too.",
        .cycleUsagePercentShort: "Cycle %@",
        .usageDetails: "Usage details",
        .emptyQuotaCurve: "No quota curve data yet",
        .emptyDailyUsage: "No daily usage data yet",
        .emptyDailySpend: "No daily spend data yet",
        .emptyModelDistribution: "No model breakdown yet",
        .emptySpendShare: "No spending breakdown yet",
        .loadingChartData: "Loading full-cycle chart data…",
        .chartLoadRetry: "Couldn't load chart data. Try again later.",
        .dailySpendLabelHint: "Bar labels show daily spend in USD",
        .dailyPercentFormula: "Daily % = billing total % × (day spend ÷ cycle spend)",
        .quotaDeclineFormula: "Remaining % = 100% − prorated used %. Total / API / Auto follow each pool's spend pace.",
        .remainingQuotaPercent: "Remaining %",
        .spendAxis: "Spend ($)",
        .percentOfBilling: "Of Billing 100%",
        .noPercentData: "Can't compute share (billing baseline unavailable)",
        .cumulative: "Cumulative %@",
        .spendAmount: "Spend $%.2f",
        .usedSpend: "Used $%.2f",
        .yourUsage: "Your Usage",
        .yourUsageSubtitle: "Cumulative spend per day across this billing period",
        .groupByModelSpend: "Model · Spend",
        .cumulativeSpendAxis: "Cumulative Spend ($)",
        .todayMarker: "Today",
        .emptyCumulativeUsage: "No cumulative usage data yet",
        .includedSpend: "Included",
        .onDemandSpend: "On-demand",

        .cycleSpending: "Cycle spending",
        .spendShare: "Spend breakdown",
        .spendTrend: "Spend trend",
        .totalSpend: "Total spend",
        .apiIncludedUsed: "API included used",

        .billingCycle: "Billing cycle",
        .billingUsage: "Billing usage",
        .includedLimit: "Included allowance",
        .dualPoolStatus: "Dual pools",
        .apiPool: "API pool",
        .autoComposer: "Auto + Composer",
        .quotaExplanation: "Allowance note",
        .quotaExplanationBody: "This means your API included allowance ($%@) is exhausted — not that overall billing usage is full. Current billing usage is about %@.",
        .quotaUsage: "Allowance usage",
        .modelTokenUsage: "Token usage by model",
        .loadingAggregatedUsage: "Loading aggregated usage…",
        .account: "Account",
        .user: "User",
        .email: "Email",
        .plan: "Plan",
        .handle: "Handle",
        .activeSessions: "Active Sessions",
        .sessionTypeWeb: "Web",
        .sessionTypeClient: "Desktop",
        .sessionTypeMobile: "Mobile",
        .sessionCreated: "Created",
        .sessionExpires: "Expires",
        .sessionRevoke: "Revoke",
        .sessionRevokeConfirm: "Revoke this session? You may need to sign in again on that device.",
        .sessionsEmpty: "No active sessions returned.",
        .openWebSessions: "Manage on cursor.com",
        .cancel: "Cancel",

        .settingsTitle: "Settings",
        .tokenInstruction: "Sign in to the dashboard in your browser and copy the token from Cookies.",
        .openDashboardLink: "Open cursor.com/dashboard/usage",
        .showToken: "Show token",
        .tokenSaved: "Saved",
        .sessionToken: "Session Token",
        .save: "Save",
        .clear: "Clear",
        .autoRefresh: "Auto refresh",
        .requestInterval: "Request interval",
        .requestIntervalValue: "10–20s random",
        .pacerHint: "Each API call and refresh cycle waits a random interval to avoid fixed traffic patterns.",
        .status: "Status",
        .configured: "Configured",
        .notConfigured: "Not configured",
        .lastRefresh: "Last refresh",
        .language: "Language",
        .languageSystem: "System",
        .languageEnglish: "English",
        .languageChinese: "中文",

        .tokenEmpty: "Token cannot be empty.",
        .fetchDataFailed: "Couldn't fetch data. Check whether your token is valid.",
        .usageEventsError: "Usage events: %@",
        .apiErrorMissingToken: "Session token not configured. Paste WorkosCursorSessionToken in Settings.",
        .apiErrorInvalidResponse: "The server returned an invalid response.",
        .apiErrorHttp: "Request failed (HTTP %d): %@",
        .apiErrorDecode: "Failed to parse data: %@",
        .keychainFailed: "Keychain operation failed (code %d).",
        .errorUsageSummary: "Usage summary",
        .errorSpendingData: "Spending data",
        .errorBillingProfile: "Billing profile",
        .errorAccount: "Account info",
        .errorActiveSessions: "Active sessions",
        .errorAggregatedUsage: "Aggregated usage",
        .unknownError: "Unknown error",

        .changeDefault: "Usage data updated.",
        .changeBannerTitle: "Usage updated",
        .notificationTitle: "Cursor usage update",
        .changeBilling: "Billing %@ → %@",
        .changeSpend: "Spend %@ → %@",
        .changeEvents: "Events %d → %d",
        .changeDailyChart: "Daily chart updated (%d days)",

        .poolApi: "API",
        .poolAuto: "Auto + Composer",
        .billingTotalLabel: "Billing total",
        .spendingTotalLabel: "Spending total",
        .othersModel: "Other",
        .unknownModel: "Unknown model",
        .billingBaselineWithCost: "Billing total %@ · spend $%@",
        .billingBaseline: "Billing total %@",

        .allModels: "All models",
        .searchAll: "Search all…",
        .searchPage: "Search this page…",
        .filterStatus: "%d matches · page %d/%d",
        .waitingCache: "%d total · waiting for full cache…",
        .listStatus: "%d total · page %d/%d",
        .noUsageEvents: "No usage events yet",
        .noMatchingEvents: "No matching events",
        .noPageRecords: "No records on this page",
        .loadingFullDetails: "Loading full event cache for global model filter…",
        .pageNumber: "Page %d",
        .firstPage: "First",
        .lastPage: "Last",
        .pricingRules: "Pricing rules",
        .officialDocs: "Official docs",
        .model: "Model",
        .provider: "Provider",
        .billingPool: "Billing pool",
        .teamsTokenFee: "Non–first-party third-party models on Teams also incur Cursor token fee $0.25/1M.",
        .calculatedPrice: "Estimated from rules",
        .calculatedTotal: "Calculated total",
        .actualCharge: "Actual charge",
        .fullModel: "Full model ID",
        .type: "Type",
        .subscription: "Subscription",
        .conversationId: "Conversation ID",
        .inputTokens: "Input tokens",
        .outputTokens: "Output tokens",
        .cacheRead: "Cache read",
        .cacheWrite: "Cache write",
        .tokenFee: "Token fee",
        .tokenTotal: "Token total",
        .tokenBasedBilling: "Token-based billing",
        .usageBasedCosts: "Usage-based costs",
        .yes: "Yes",
        .no: "No",
        .totalTokensShort: "Total %@ tok",
        .inputShort: "In",
        .outputShort: "Out",
        .cacheReadShort: "Read",
        .cacheWriteShort: "Write",

        .poolFirstPartyLabel: "First-party pool (Auto + Composer)",
        .poolFirstPartySummary: "Auto, Composer 2.5, Grok 4.5 use this pool with more generous included allowance.",
        .poolApiLabel: "API pool (public API pricing)",
        .poolApiSummary: "Manually selected third-party models bill from the API allowance at listed rates.",
        .rateInput: "Input",
        .rateOutput: "Output",
        .rateCacheRead: "Cache read",
        .rateCacheWrite: "Cache write",
        .rateInputCacheWrite: "Input + cache write",
        .unknownModelNotes: "Model not in catalog. See official docs for latest rates.",

        .kindProPlus: "Pro+ included",
        .kindPro: "Pro included",
        .kindBusiness: "Business included",
        .kindUsageBased: "Usage-based",
        .kindFree: "Free",

        .billingContextProPlus: "Deducted from Pro+ included allowance (first-party pool).",
        .billingContextPro: "Deducted from Pro included allowance.",
        .billingContextBusiness: "Deducted from Business included allowance.",
        .billingContextUsageBased: "Usage-based charge beyond included allowance at API rates.",
        .billingContextFree: "Free tier — not charged.",
    ]

    // MARK: - Chinese

    private static let chinese: [Key: String] = [
        .dashboardTitle: "Cursor 仪表盘",
        .tabPicker: "页面",
        .menuNotConfigured: "未配置",
        .refresh: "刷新",
        .settings: "设置",
        .quitApp: "退出",
        .updatedAt: "更新 %@",
        .getStarted: "开始使用",
        .setupTokenHint: "配置 Token 后可查看用量、花费、账单图表。",
        .goToSettings: "前往设置",

        .tabOverview: "概览",
        .tabCharts: "图表",
        .tabIncluded: "包含",
        .tabEvents: "明细",
        .tabAccount: "账户",

        .today: "今日",
        .todayBillingPercent: "今日占 Billing 100%",
        .todayUsage: "今日用量",
        .requestCount: "请求数",
        .spend: "花费",
        .token: "Token",
        .billingTotal: "Billing 总计",
        .cycleUsage: "本周期用量",
        .cycleTotalSpend: "本周期总花费",
        .apiUsed: "API 已用",
        .autoBonusSpend: "Auto Bonus 花费",
        .apiIncludedLimit: "API 包含额度",
        .billingPeriod: "账单周期",
        .totalEvents: "事件总数",

        .quotaDeclineCurve: "额度下降曲线",
        .dailyUsagePercent: "每日用量占 Billing 100%",
        .dailySpend: "每日花费",
        .modelSpendDistribution: "模型花费分布",
        .includedUsage: "包含用量",
        .dailyModelShare: "每日模型占比",
        .columnItem: "项目",
        .columnTokens: "Token",
        .columnUsage: "用量",
        .emptyIncludedUsage: "暂无包含用量数据",
        .emptyDailyModelShare: "暂无每日模型占比数据",
        .dailyModelShareHint: "仅展示所选日期的模型 Token 占比（保留 medium / high 等思考档位）",
        .dayFilter: "日期",
        .dayFilterAll: "整个周期",
        .dayStats: "当日统计",
        .includedUsageCostHint: "与官网同算法（非爬虫）：API 组合计=api%，第一方=auto%；模型%=池%×(模型花费÷池花费)。接口不返回现成模型%，官网也是前端算的。",
        .cycleUsagePercentShort: "本周期 %@",
        .usageDetails: "用量明细",
        .emptyQuotaCurve: "暂无额度曲线数据",
        .emptyDailyUsage: "暂无每日用量数据",
        .emptyDailySpend: "暂无每日花费数据",
        .emptyModelDistribution: "暂无模型分布数据",
        .emptySpendShare: "暂无花费占比数据",
        .loadingChartData: "正在加载全周期图表数据…",
        .chartLoadRetry: "未能加载图表数据，请稍后重试。",
        .dailySpendLabelHint: "柱顶标签为当日花费金额（美元）",
        .dailyPercentFormula: "每日占比 = Billing总百分比 × (当日花费 ÷ 本周期总花费)",
        .quotaDeclineFormula: "剩余额度 % = 100% − 按日累计分摊的已用%。Total / API / Auto 各自按本池花费节奏估算。",
        .remainingQuotaPercent: "剩余额度 %",
        .spendAxis: "花费 ($)",
        .percentOfBilling: "占 Billing 100%",
        .noPercentData: "无法计算占比（未获取到本周期总额度）",
        .cumulative: "累计 %@",
        .spendAmount: "花费 $%.2f",
        .usedSpend: "已用 $%.2f",
        .yourUsage: "Your Usage",
        .yourUsageSubtitle: "本账单周期内按日累计花费（按模型）",
        .groupByModelSpend: "模型 · 花费",
        .cumulativeSpendAxis: "累计花费 ($)",
        .todayMarker: "今天",
        .emptyCumulativeUsage: "暂无累计用量图数据",
        .includedSpend: "包含用量",
        .onDemandSpend: "按需用量",

        .cycleSpending: "本周期花费 (Spending)",
        .spendShare: "花费占比",
        .spendTrend: "花费趋势",
        .totalSpend: "总花费",
        .apiIncludedUsed: "API 包含已用",

        .billingCycle: "账单周期",
        .billingUsage: "Billing 用量",
        .includedLimit: "包含额度",
        .dualPoolStatus: "双池状态",
        .apiPool: "API 池",
        .autoComposer: "Auto + Composer",
        .quotaExplanation: "额度说明",
        .quotaExplanationBody: "这是 API 包含额度（$%@）用尽的提示，不代表 Billing 总用量已满。当前 Billing 总用量约 %@。",
        .quotaUsage: "额度使用",
        .modelTokenUsage: "模型 Token 用量",
        .loadingAggregatedUsage: "正在加载聚合用量数据…",
        .account: "账户",
        .user: "用户",
        .email: "邮箱",
        .plan: "套餐",
        .handle: "Handle",
        .activeSessions: "活跃会话",
        .sessionTypeWeb: "网页",
        .sessionTypeClient: "桌面客户端",
        .sessionTypeMobile: "移动端",
        .sessionCreated: "创建",
        .sessionExpires: "过期",
        .sessionRevoke: "撤销",
        .sessionRevokeConfirm: "撤销此会话？该设备可能需要重新登录。",
        .sessionsEmpty: "未返回活跃会话。",
        .openWebSessions: "在 cursor.com 管理",
        .cancel: "取消",

        .settingsTitle: "设置",
        .tokenInstruction: "在浏览器登录 Dashboard，从 Cookies 复制 Token。",
        .openDashboardLink: "打开 cursor.com/dashboard/usage",
        .showToken: "显示 Token",
        .tokenSaved: "已保存",
        .sessionToken: "Session Token",
        .save: "保存",
        .clear: "清除",
        .autoRefresh: "自动刷新",
        .requestInterval: "请求间隔",
        .requestIntervalValue: "10–20 秒随机",
        .pacerHint: "每次 API 请求与自动刷新轮次之间都会随机等待，降低固定访问节奏。",
        .status: "状态",
        .configured: "已配置",
        .notConfigured: "未配置",
        .lastRefresh: "上次刷新",
        .language: "语言",
        .languageSystem: "跟随系统",
        .languageEnglish: "English",
        .languageChinese: "中文",

        .tokenEmpty: "Token 不能为空。",
        .fetchDataFailed: "无法获取数据，请检查 Token 是否有效。",
        .usageEventsError: "用量事件：%@",
        .apiErrorMissingToken: "未配置 Session Token，请在设置中粘贴 WorkosCursorSessionToken。",
        .apiErrorInvalidResponse: "服务器返回了无效响应。",
        .apiErrorHttp: "请求失败（HTTP %d）：%@",
        .apiErrorDecode: "解析数据失败：%@",
        .keychainFailed: "Keychain 操作失败（错误码 %d）。",
        .errorUsageSummary: "用量摘要",
        .errorSpendingData: "花费数据",
        .errorBillingProfile: "账单资料",
        .errorAccount: "账户信息",
        .errorActiveSessions: "活跃会话",
        .errorAggregatedUsage: "聚合用量",
        .unknownError: "未知错误",

        .changeDefault: "用量数据已更新。",
        .changeBannerTitle: "用量数据已更新",
        .notificationTitle: "Cursor 用量更新",
        .changeBilling: "Billing %@ → %@",
        .changeSpend: "花费 %@ → %@",
        .changeEvents: "事件 %d → %d",
        .changeDailyChart: "每日图表已更新（%d 天）",

        .poolApi: "API",
        .poolAuto: "Auto + Composer",
        .billingTotalLabel: "Billing 总计",
        .spendingTotalLabel: "Spending 总计",
        .othersModel: "其他",
        .unknownModel: "未知模型",
        .billingBaselineWithCost: "Billing 总计 %@ · 花费 $%@",
        .billingBaseline: "Billing 总计 %@",

        .allModels: "全部模型",
        .searchAll: "搜索全部…",
        .searchPage: "搜索本页…",
        .filterStatus: "筛选 %d 条 · 第 %d/%d 页",
        .waitingCache: "共 %d 条 · 等待全量缓存…",
        .listStatus: "共 %d 条 · 第 %d/%d 页",
        .noUsageEvents: "暂无用量明细",
        .noMatchingEvents: "没有匹配的用量记录",
        .noPageRecords: "本页没有记录",
        .loadingFullDetails: "正在加载全量明细，完成后可按模型筛选全部记录",
        .pageNumber: "第 %d 页",
        .firstPage: "首页",
        .lastPage: "末页",
        .pricingRules: "计费规则",
        .officialDocs: "官方文档",
        .model: "模型",
        .provider: "提供商",
        .billingPool: "计费池",
        .teamsTokenFee: "Teams 非第一方第三方模型另收 Cursor Token 费率 $0.25/1M。",
        .calculatedPrice: "规则计算价格",
        .calculatedTotal: "计算合计",
        .actualCharge: "实际扣费",
        .fullModel: "完整模型",
        .type: "类型",
        .subscription: "订阅",
        .conversationId: "会话 ID",
        .inputTokens: "输入 Token",
        .outputTokens: "输出 Token",
        .cacheRead: "缓存读取",
        .cacheWrite: "缓存写入",
        .tokenFee: "Token 费用",
        .tokenTotal: "Token 合计",
        .tokenBasedBilling: "Token 计费",
        .usageBasedCosts: "按量费用",
        .yes: "是",
        .no: "否",
        .totalTokensShort: "合计 %@ tok",
        .inputShort: "入",
        .outputShort: "出",
        .cacheReadShort: "读",
        .cacheWriteShort: "写",

        .poolFirstPartyLabel: "第一方模型池 (Auto + Composer)",
        .poolFirstPartySummary: "Auto、Composer 2.5、Grok 4.5 使用此池，套餐内含额度更充裕。",
        .poolApiLabel: "API 池（按模型公开 API 价）",
        .poolApiSummary: "手动选择第三方模型时，按下方单价从 API 额度池扣费。",
        .rateInput: "输入",
        .rateOutput: "输出",
        .rateCacheRead: "缓存读取",
        .rateCacheWrite: "缓存写入",
        .rateInputCacheWrite: "输入 + 缓存写入",
        .unknownModelNotes: "未收录该模型_slug，请参考官方文档获取最新单价。",

        .kindProPlus: "Pro+ 包含",
        .kindPro: "Pro 包含",
        .kindBusiness: "Business 包含",
        .kindUsageBased: "按量计费",
        .kindFree: "免费",

        .billingContextProPlus: "本条从 Pro+ 包含额度扣减（第一方模型池）。",
        .billingContextPro: "本条从 Pro 包含额度扣减。",
        .billingContextBusiness: "本条从 Business 包含额度扣减。",
        .billingContextUsageBased: "本条为按量计费，超出包含额度后按 API 价扣费。",
        .billingContextFree: "本条为免费额度，不计费。",
    ]
}

extension DashboardTab {
    func title(language: ResolvedLanguage) -> String {
        switch self {
        case .overview: return L10n.string(.tabOverview, language: language)
        case .charts: return L10n.string(.tabCharts, language: language)
        case .included: return L10n.string(.tabIncluded, language: language)
        case .events: return L10n.string(.tabEvents, language: language)
        case .account: return L10n.string(.tabAccount, language: language)
        }
    }
}

extension SpendingBreakdownItem {
    func localizedLabel(language: ResolvedLanguage) -> String {
        switch id {
        case "total":
            return L10n.string(.billingTotalLabel, language: language)
        case "auto":
            return L10n.string(.poolAuto, language: language)
        case "api":
            return L10n.string(.poolApi, language: language)
        default:
            return label
        }
    }
}
