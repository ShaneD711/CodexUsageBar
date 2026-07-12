import Foundation

struct CachedUsageStore: UsageSnapshotCaching {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "lastSuccessfulRateLimitSnapshot"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> RateLimitSnapshot? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(RateLimitSnapshot.self, from: data)
    }

    func save(_ snapshot: RateLimitSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
