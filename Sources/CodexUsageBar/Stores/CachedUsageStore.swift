import Foundation

struct CachedUsageStore: Sendable {
    private let key = "lastSuccessfulRateLimitSnapshot"

    func load() -> RateLimitSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(RateLimitSnapshot.self, from: data)
    }

    func save(_ snapshot: RateLimitSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
