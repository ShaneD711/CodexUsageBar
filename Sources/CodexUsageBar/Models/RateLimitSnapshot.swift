import Foundation

struct RateLimitWindow: Codable, Equatable, Sendable {
    let usedPercent: Double
    let durationMinutes: Int
    let resetsAt: Date

    var remainingPercent: Int {
        let remaining = 100 - usedPercent
        return min(100, max(0, Int(remaining.rounded())))
    }
}

struct RateLimitSnapshot: Codable, Equatable, Sendable {
    static let staleAfter: TimeInterval = 10 * 60

    let primary: RateLimitWindow
    let secondary: RateLimitWindow?
    let fetchedAt: Date

    func isStale(
        at date: Date = Date(),
        threshold: TimeInterval = staleAfter
    ) -> Bool {
        date.timeIntervalSince(fetchedAt) > threshold
    }
}
