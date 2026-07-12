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
    private var activeReadTask: Task<CodexUsageReadResult, Error>?
    private var refreshGeneration: UInt64 = 0
    private var freshnessTask: Task<Void, Never>?
    private var wakeObserver: SystemWakeObserver?

    var availability: UsageAvailability {
        UsageAvailability.resolve(
            hasSnapshot: snapshot != nil,
            isSnapshotStale: isSnapshotStale,
            isRefreshing: isRefreshing,
            lastFailure: lastFailure
        )
    }

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
        activeReadTask?.cancel()
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
        invalidateActiveRefresh()
        refreshTask = nil
        freshnessTask = nil
        wakeObserver = nil
    }

    func refresh() async {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        activeReadTask?.cancel()

        let readTask = Task { [client] in
            try await client.readSnapshot()
        }
        activeReadTask = readTask
        isRefreshing = true
        defer {
            if generation == refreshGeneration {
                activeReadTask = nil
                isRefreshing = false
            }
        }

        do {
            let result = try await withTaskCancellationHandler {
                try await readTask.value
            } onCancel: {
                readTask.cancel()
            }
            guard generation == refreshGeneration else { return }
            snapshot = result.snapshot
            resolvedExecutable = result.executable
            cache.save(result.snapshot)
            lastFailure = nil
            updateStaleness()
        } catch is CancellationError {
            guard generation == refreshGeneration else { return }
            updateStaleness()
        } catch {
            guard generation == refreshGeneration else { return }
            if resolvedExecutable == nil {
                resolvedExecutable = executableResolver()
            }
            lastFailure = UsageFailure(error)
            updateStaleness()
        }
    }

    private func invalidateActiveRefresh() {
        refreshGeneration &+= 1
        activeReadTask?.cancel()
        activeReadTask = nil
        isRefreshing = false
        updateStaleness()
    }

    private func updateStaleness(now: Date = Date()) {
        isSnapshotStale = snapshot?.isStale(at: now) ?? false
    }
}
