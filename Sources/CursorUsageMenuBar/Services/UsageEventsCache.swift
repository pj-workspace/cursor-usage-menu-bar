import Foundation

/// 本账单周期用量明细的本地缓存，分页时优先读本地。
enum UsageEventsCache {
    struct Store: Codable, Sendable {
        let billingCycleStartMs: String
        let billingCycleEndMs: String
        let totalCount: Int
        let fetchedAt: Date
        let events: [UsageEvent]

        var isComplete: Bool {
            events.count >= totalCount
        }
    }

    private static let appFolderName = "CursorUsageMenuBar"
    private static let cacheFolderName = "usage-events-cache"

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(appFolderName, isDirectory: true)
            .appendingPathComponent(cacheFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(startMs: String, endMs: String) -> URL {
        cacheDirectory.appendingPathComponent("\(startMs)-\(endMs).json")
    }

    static func load(startMs: String, endMs: String) -> Store? {
        let url = fileURL(startMs: startMs, endMs: endMs)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Store.self, from: data)
    }

    static func save(events: [UsageEvent], totalCount: Int, startMs: String, endMs: String) {
        let store = Store(
            billingCycleStartMs: startMs,
            billingCycleEndMs: endMs,
            totalCount: totalCount,
            fetchedAt: Date(),
            events: events
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(store) else { return }
        try? data.write(to: fileURL(startMs: startMs, endMs: endMs), options: .atomic)
    }

    static func page(
        startMs: String,
        endMs: String,
        page: Int,
        pageSize: Int
    ) -> UsageEventsPage? {
        guard let store = load(startMs: startMs, endMs: endMs), !store.events.isEmpty else {
            return nil
        }
        return UsageEventsPage.slice(
            from: store.events,
            totalCount: store.totalCount,
            page: page,
            pageSize: pageSize
        )
    }

    static func canServePage(
        startMs: String,
        endMs: String,
        page: Int,
        pageSize: Int
    ) -> Bool {
        guard let store = load(startMs: startMs, endMs: endMs) else { return false }
        let startIndex = (page - 1) * pageSize
        if store.isComplete { return startIndex < store.totalCount }
        return startIndex + pageSize <= store.events.count
    }

    static func clear(startMs: String, endMs: String) {
        try? FileManager.default.removeItem(at: fileURL(startMs: startMs, endMs: endMs))
    }

    static func clearAll() {
        let dir = cacheDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files where file.pathExtension == "json" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
