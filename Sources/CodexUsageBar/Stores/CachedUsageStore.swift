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
        guard let snapshot = try? JSONDecoder().decode(RateLimitSnapshot.self, from: data),
              snapshot.isSemanticallyValid else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: RateLimitSnapshot) {
        guard snapshot.isSemanticallyValid,
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
