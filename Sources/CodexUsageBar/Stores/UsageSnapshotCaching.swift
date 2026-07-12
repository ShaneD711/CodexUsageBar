@MainActor
protocol UsageSnapshotCaching {
    func load() -> RateLimitSnapshot?
    func save(_ snapshot: RateLimitSnapshot)
}
