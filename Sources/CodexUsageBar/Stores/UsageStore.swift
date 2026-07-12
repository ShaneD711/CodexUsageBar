import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: RateLimitSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSnapshotStale = false
    @Published private(set) var lastFailure: UsageFailure?
    @Published private(set) var resolvedExecutable: ResolvedCodexExecutable?

    private let client: CodexAppServerClient
    private let cache: CachedUsageStore
    private var refreshTask: Task<Void, Never>?
    private var freshnessTask: Task<Void, Never>?
    private var wakeObserver: SystemWakeObserver?

    init(
        client: CodexAppServerClient = CodexAppServerClient(),
        cache: CachedUsageStore = CachedUsageStore()
    ) {
        self.client = client
        self.cache = cache
        snapshot = cache.load()
        updateStaleness()

        refreshTask = Task { [weak self] in
            await self?.refresh()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }

        freshnessTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                self?.updateStaleness()
            }
        }

        wakeObserver = SystemWakeObserver { [weak self] in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        freshnessTask?.cancel()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let result = try await client.readSnapshot()
            snapshot = result.snapshot
            resolvedExecutable = result.executable
            cache.save(result.snapshot)
            lastFailure = nil
            updateStaleness()
        } catch {
            if resolvedExecutable == nil {
                resolvedExecutable = CodexExecutableResolver.resolve()
            }
            lastFailure = UsageFailure(error)
            updateStaleness()
        }
    }

    private func updateStaleness(now: Date = Date()) {
        isSnapshotStale = snapshot?.isStale(at: now) ?? false
    }
}
