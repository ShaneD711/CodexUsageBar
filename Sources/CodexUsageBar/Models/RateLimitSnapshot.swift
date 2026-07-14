import Foundation

struct RateLimitWindow: Codable, Equatable, Sendable {
    let usedPercent: Double
    let durationMinutes: Int
    let resetsAt: Date

    var remainingPercent: Int {
        let remaining = 100 - usedPercent
        if remaining <= 0 { return 0 }
        if remaining >= 100 { return 100 }
        return Int(remaining.rounded())
    }

    var isSemanticallyValid: Bool {
        let resetTimestamp = resetsAt.timeIntervalSince1970
        return usedPercent.isFinite
            && usedPercent >= 0
            && durationMinutes > 0
            && resetTimestamp.isFinite
            && resetTimestamp > 0
            && resetTimestamp <= Date.distantFuture.timeIntervalSince1970
    }
}

struct RateLimitSnapshot: Codable, Equatable, Sendable {
    static let staleAfter: TimeInterval = 10 * 60

    let primary: RateLimitWindow
    let secondary: RateLimitWindow?
    let fetchedAt: Date

    var windows: [RateLimitWindow] {
        [primary] + (secondary.map { [$0] } ?? [])
    }

    var menuBarWindow: RateLimitWindow {
        windows.first { $0.durationMinutes == 300 } ?? primary
    }

    var isSemanticallyValid: Bool {
        let fetchTimestamp = fetchedAt.timeIntervalSince1970
        return fetchTimestamp.isFinite
            && fetchTimestamp > 0
            && windows.allSatisfy(\.isSemanticallyValid)
    }

    func isStale(
        at date: Date = Date(),
        threshold: TimeInterval = staleAfter
    ) -> Bool {
        date.timeIntervalSince(fetchedAt) > threshold
    }
}
