import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: RateLimitSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?

    private let client: CodexAppServerClient
    private let cache: CachedUsageStore
    private var refreshTask: Task<Void, Never>?

    init(
        client: CodexAppServerClient = CodexAppServerClient(),
        cache: CachedUsageStore = CachedUsageStore()
    ) {
        self.client = client
        self.cache = cache
        snapshot = cache.load()

        refreshTask = Task { [weak self] in
            await self?.refresh()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
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
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法读取 Codex 用量。"
        }
    }
}
