import Foundation

struct CursorAPIClient: Sendable {
    private let baseURL = URL(string: "https://cursor.com")!
    private let session: URLSession
    private let maxEventPages = 100
    static let defaultEventsPageSize = 20

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDashboardData(token: String) async -> DashboardSnapshot {
        var partialErrors: [String] = []

        async let summaryResult = catchError(.errorUsageSummary) { try await fetchUsageSummary(token: token) }
        async let periodResult = catchError(.errorSpendingData) { try await fetchCurrentPeriodUsage(token: token) }
        async let profileResult = catchError(.errorBillingProfile) { try await fetchUserProfile(token: token) }
        async let authResult = catchError(.errorAccount) { try await fetchAuthMe(token: token) }

        let (summary, summaryError) = await summaryResult
        let (periodUsage, periodError) = await periodResult
        let (userProfile, profileError) = await profileResult
        let (authMe, authError) = await authResult

        [summaryError, periodError, profileError, authError]
            .compactMap { $0 }
            .forEach { partialErrors.append($0) }

        let (start, end) = UsageAnalytics.billingCycleRange(summary: summary)
        let startMs = Int(start.timeIntervalSince1970 * 1000)
        let endMs = Int(end.timeIntervalSince1970 * 1000)
        let startMsString = String(startMs)
        let endMsString = String(endMs)

        async let aggregatedResult = catchError(.errorAggregatedUsage) {
            try await fetchAggregatedUsage(token: token, startMs: startMs, endMs: endMs)
        }

        let eventsResult = await fetchUsageEventsPage(
            token: token,
            startMs: startMsString,
            endMs: endMsString,
            page: 1,
            pageSize: Self.defaultEventsPageSize
        )
        if let error = eventsResult.error {
            partialErrors.append(error)
        }

        let (aggregatedUsage, aggregatedError) = await aggregatedResult
        if let aggregatedError {
            partialErrors.append(aggregatedError)
        }

        let events = eventsResult.page?.events ?? []
        let totalEventCount = eventsResult.page?.totalCount ?? events.count
        let usageLimit = UsageAnalytics.resolveBillingBaseline(
            summary: summary,
            period: periodUsage,
            aggregated: aggregatedUsage
        )
        let usagePools = UsageAnalytics.resolveUsagePools(summary: summary, period: periodUsage)
        let modelBreakdown = UsageAnalytics.modelBreakdown(from: aggregatedUsage, events: [])

        return DashboardSnapshot(
            summary: summary,
            periodUsage: periodUsage,
            aggregatedUsage: aggregatedUsage,
            userProfile: userProfile,
            authMe: authMe,
            events: events,
            totalEventCount: totalEventCount,
            usageLimit: usageLimit,
            usagePools: usagePools,
            dailySpend: [],
            quotaCurves: [],
            modelBreakdown: modelBreakdown,
            spendingBreakdown: UsageAnalytics.spendingBreakdown(from: periodUsage, summary: summary),
            todayStats: .empty,
            partialErrors: partialErrors,
            billingCycleStartMs: startMsString,
            billingCycleEndMs: endMsString,
            usageEventsPage: 1,
            usageEventsPageSize: Self.defaultEventsPageSize
        )
    }

    func fetchUsageEventsPage(
        token: String,
        startMs: String,
        endMs: String,
        page: Int,
        pageSize: Int = defaultEventsPageSize
    ) async -> (page: UsageEventsPage?, error: String?) {
        do {
            let result = try await requestUsageEventsPage(
                token: token,
                startMs: startMs,
                endMs: endMs,
                page: page,
                pageSize: pageSize
            )
            return (result, nil)
        } catch {
            let language = LocalizationManager.resolvedLanguage()
            let prefix = String(
                format: L10n.string(.usageEventsError, language: language),
                locale: language.locale,
                error.localizedDescription
            )
            return (nil, prefix)
        }
    }

    func fetchAllBillingCycleEvents(
        token: String,
        startMs: String,
        endMs: String
    ) async -> EventsFetchResult {
        await RequestPacer.shared.withBurst {
            await fetchBillingCycleEvents(token: token, startMs: startMs, endMs: endMs)
        }
    }

    private func requestUsageEventsPage(
        token: String,
        startMs: String,
        endMs: String,
        page: Int,
        pageSize: Int
    ) async throws -> UsageEventsPage {
        let response: UsageEventsResponse = try await post(
            path: "api/dashboard/get-filtered-usage-events",
            token: token,
            referer: "https://cursor.com/dashboard/usage",
            body: [
                "startDate": startMs,
                "endDate": endMs,
                "page": page,
                "pageSize": pageSize,
            ]
        )

        let events = response.usageEventsDisplay ?? []
        let totalCount = response.totalUsageEventsCount ?? events.count
        return UsageEventsPage(
            events: events,
            totalCount: totalCount,
            page: page,
            pageSize: pageSize
        )
    }

    func fetchUsageSummary(token: String) async throws -> UsageSummary {
        try await get(path: "api/usage-summary", token: token)
    }

    /// CursorHub 使用的聚合接口，teamId = -1 表示个人账号
    func fetchAggregatedUsage(token: String, startMs: Int, endMs: Int) async throws -> AggregatedUsageResponse {
        try await post(
            path: "api/dashboard/get-aggregated-usage-events",
            token: token,
            referer: "https://cursor.com/dashboard/usage",
            body: [
                "teamId": -1,
                "startDate": startMs,
                "endDate": endMs,
            ]
        )
    }

    func fetchCurrentPeriodUsage(token: String) async throws -> PeriodUsageResponse {
        try await post(
            path: "api/dashboard/get-current-period-usage",
            token: token,
            referer: "https://cursor.com/dashboard/spending",
            body: [:]
        )
    }

    func fetchUserProfile(token: String) async throws -> UserProfileResponse {
        try await post(
            path: "api/dashboard/get-user-profile",
            token: token,
            referer: "https://cursor.com/dashboard/billing",
            body: ["includeActivitySummary": false]
        )
    }

    func fetchAuthMe(token: String) async throws -> AuthMeResponse {
        try await get(path: "api/auth/me", token: token)
    }

    struct EventsFetchResult: Sendable {
        let events: [UsageEvent]
        let totalCount: Int
        let error: String?
    }

    private func fetchBillingCycleEvents(
        token: String,
        startMs: String,
        endMs: String
    ) async -> EventsFetchResult {
        var allEvents: [UsageEvent] = []
        var totalCount = 0

        do {
            for page in 1 ... maxEventPages {
                if Task.isCancelled { break }

                let response: UsageEventsResponse = try await post(
                    path: "api/dashboard/get-filtered-usage-events",
                    token: token,
                    referer: "https://cursor.com/dashboard/usage",
                    body: [
                        "startDate": startMs,
                        "endDate": endMs,
                        "page": page,
                        "pageSize": 100,
                    ]
                )

                let pageEvents = response.usageEventsDisplay ?? []
                if let total = response.totalUsageEventsCount {
                    totalCount = total
                }
                allEvents.append(contentsOf: pageEvents)

                if pageEvents.count < 100 { break }
                if totalCount > 0, allEvents.count >= totalCount { break }
            }
            return EventsFetchResult(events: allEvents, totalCount: max(totalCount, allEvents.count), error: nil)
        } catch {
            let language = LocalizationManager.resolvedLanguage()
            let message = String(
                format: L10n.string(.usageEventsError, language: language),
                locale: language.locale,
                error.localizedDescription
            )
            return EventsFetchResult(events: allEvents, totalCount: allEvents.count, error: message)
        }
    }

    private func get<T: Decodable>(path: String, token: String) async throws -> T {
        await RequestPacer.shared.waitBeforeRequest()
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader(token), forHTTPHeaderField: "Cookie")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decode(T.self, from: data)
    }

    private func post<T: Decodable>(
        path: String,
        token: String,
        referer: String,
        body: [String: Any]
    ) async throws -> T {
        await RequestPacer.shared.waitBeforeRequest()
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue(cookieHeader(token), forHTTPHeaderField: "Cookie")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decode(T.self, from: data)
    }

    private func catchError<T>(
        _ key: L10n.Key,
        _ operation: () async throws -> T
    ) async -> (T?, String?) {
        do {
            return (try await operation(), nil)
        } catch {
            let language = LocalizationManager.resolvedLanguage()
            let label = L10n.string(key, language: language)
            let detail = (error as? CursorAPIError)?.message(language: language) ?? error.localizedDescription
            return (nil, "\(label): \(detail)")
        }
    }

    private func cookieHeader(_ token: String) -> String {
        "WorkosCursorSessionToken=\(token)"
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CursorAPIError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let language = LocalizationManager.resolvedLanguage()
            let message = String(data: data, encoding: .utf8)
                ?? L10n.string(.unknownError, language: language)
            throw CursorAPIError.httpError(statusCode: http.statusCode, message: message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            throw CursorAPIError.decodingFailed(error.localizedDescription)
        }
    }
}
