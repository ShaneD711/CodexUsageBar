import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: RateLimitSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSnapshotStale = false
    @Published private(set) var errorMessage: String?

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
            let newSnapshot = try await client.readSnapshot()
            snapshot = newSnapshot
            cache.save(newSnapshot)
            errorMessage = nil
            updateStaleness()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法读取 Codex 用量。"
            updateStaleness()
        }
    }

    private func updateStaleness(now: Date = Date()) {
        isSnapshotStale = snapshot?.isStale(at: now) ?? false
    }
}
