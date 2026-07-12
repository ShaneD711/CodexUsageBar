import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: RateLimitSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSnapshotStale = false
    @Published private(set) var lastFailure: UsageFailure?
    @Published private(set) var resolvedExecutable: ResolvedCodexExecutable?

    private let client: any CodexUsageReading
    private let cache: any UsageSnapshotCaching
    private let executableResolver: @Sendable () -> ResolvedCodexExecutable?
    private var refreshTask: Task<Void, Never>?
    private var freshnessTask: Task<Void, Never>?
    private var wakeObserver: SystemWakeObserver?

    init(
        client: any CodexUsageReading = CodexAppServerClient(),
        cache: (any UsageSnapshotCaching)? = nil,
        executableResolver: @escaping @Sendable () -> ResolvedCodexExecutable? = {
            CodexExecutableResolver.resolve()
        },
        startsAutomatically: Bool = true
    ) {
        self.client = client
        self.cache = cache ?? CachedUsageStore()
        self.executableResolver = executableResolver
        snapshot = self.cache.load()
        updateStaleness()

        if startsAutomatically {
            start()
        }
    }

    deinit {
        refreshTask?.cancel()
        freshnessTask?.cancel()
    }

    func start(observeSystemWake: Bool = true) {
        guard refreshTask == nil else { return }

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

        if observeSystemWake {
            wakeObserver = SystemWakeObserver { [weak self] in
                Task { @MainActor in
                    await self?.refresh()
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        freshnessTask?.cancel()
        refreshTask = nil
        freshnessTask = nil
        wakeObserver = nil
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
        } catch is CancellationError {
            updateStaleness()
        } catch {
            if resolvedExecutable == nil {
                resolvedExecutable = executableResolver()
            }
            lastFailure = UsageFailure(error)
            updateStaleness()
        }
    }

    private func updateStaleness(now: Date = Date()) {
        isSnapshotStale = snapshot?.isStale(at: now) ?? false
    }
}
