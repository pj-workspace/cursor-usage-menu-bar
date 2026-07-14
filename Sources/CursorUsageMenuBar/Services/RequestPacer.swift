import Foundation

/// 在每次 API 请求前随机等待 10–20 秒，降低固定节奏触发风控的概率。
/// 同一操作内的连续分页（如图表全量拉取）可进入 burst 模式，页与页之间不再等待。
actor RequestPacer {
    static let shared = RequestPacer()

    private let minSeconds = 10.0
    private let maxSeconds = 20.0
    private var skipNextWait = true
    private var burstCount = 0

    func beginBurst() {
        burstCount += 1
    }

    func endBurst() {
        burstCount = max(0, burstCount - 1)
    }

    func withBurst<T>(_ operation: () async throws -> T) async rethrows -> T {
        burstCount += 1
        defer { burstCount = max(0, burstCount - 1) }
        return try await operation()
    }

    func waitBeforeRequest() async {
        if burstCount > 0 { return }
        if skipNextWait {
            skipNextWait = false
            return
        }
        let seconds = nextDelaySeconds()
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    func nextDelaySeconds() -> Double {
        Double.random(in: minSeconds...maxSeconds)
    }

    func sleepUntilNextCycle() async {
        let seconds = nextDelaySeconds()
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}
