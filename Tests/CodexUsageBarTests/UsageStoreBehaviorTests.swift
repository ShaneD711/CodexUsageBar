import Foundation
import XCTest
@testable import CodexUsageBar

@MainActor
final class UsageStoreBehaviorTests: XCTestCase {
    func testCachedSnapshotIsVisibleBeforeBackgroundRefreshReplacesIt() async throws {
        let cached = makeSnapshot(usedPercent: 80, fetchedAt: Date().addingTimeInterval(-60))
        let refreshed = makeSnapshot(usedPercent: 20, fetchedAt: Date())
        let reader = ScriptedUsageReader(outcomes: [.success(makeResult(refreshed))])
        let cache = InMemoryUsageCache(snapshot: cached)
        let store = makeStore(reader: reader, cache: cache)

        XCTAssertEqual(store.snapshot, cached)

        store.start(observeSystemWake: false)
        try await waitUntil { store.snapshot == refreshed }
        store.stop()

        XCTAssertEqual(cache.snapshot, refreshed)
    }

    func testRefreshFailurePreservesCachedSnapshotAndSetsFailure() async {
        let cached = makeSnapshot(usedPercent: 60, fetchedAt: Date())
        let reader = ScriptedUsageReader(outcomes: [.failure(.timedOut(phase: .rateLimits))])
        let cache = InMemoryUsageCache(snapshot: cached)
        let store = makeStore(reader: reader, cache: cache)

        await store.refresh()

        XCTAssertEqual(store.snapshot, cached)
        XCTAssertEqual(store.lastFailure?.category, .timedOut)
        XCTAssertEqual(store.lastFailure?.phase, .rateLimits)
        XCTAssertEqual(cache.savedSnapshots.count, 0)
    }

    func testSuccessfulRetryClearsFailureAndReplacesSnapshot() async {
        let cached = makeSnapshot(usedPercent: 70, fetchedAt: Date().addingTimeInterval(-60))
        let refreshed = makeSnapshot(usedPercent: 10, fetchedAt: Date())
        let reader = ScriptedUsageReader(outcomes: [
            .failure(.timedOut(phase: .rateLimits)),
            .success(makeResult(refreshed))
        ])
        let cache = InMemoryUsageCache(snapshot: cached)
        let store = makeStore(reader: reader, cache: cache)

        await store.refresh()
        XCTAssertEqual(store.lastFailure?.category, .timedOut)

        await store.refresh()

        XCTAssertNil(store.lastFailure)
        XCTAssertEqual(store.snapshot, refreshed)
        XCTAssertEqual(cache.savedSnapshots, [refreshed])
    }

    func testConcurrentRefreshesRunOnlyOneReaderRequest() async throws {
        let refreshed = makeSnapshot(usedPercent: 25, fetchedAt: Date())
        let reader = ControlledUsageReader()
        let store = makeStore(reader: reader, cache: InMemoryUsageCache())

        let firstRefresh = Task { await store.refresh() }
        try await waitUntil { store.isRefreshing }
        try await waitUntil { await reader.callCount == 1 }

        await store.refresh()
        let callCount = await reader.callCount
        XCTAssertEqual(callCount, 1)

        await reader.succeed(with: makeResult(refreshed))
        await firstRefresh.value

        XCTAssertEqual(store.snapshot, refreshed)
        XCTAssertFalse(store.isRefreshing)
    }

    func testCancelledRefreshDoesNotCreateFailure() async throws {
        let reader = CancellableUsageReader()
        let store = makeStore(reader: reader, cache: InMemoryUsageCache())

        let refresh = Task { await store.refresh() }
        try await waitUntil { store.isRefreshing }
        refresh.cancel()
        await refresh.value

        XCTAssertFalse(store.isRefreshing)
        XCTAssertNil(store.lastFailure)
        XCTAssertNil(store.snapshot)
    }

    func testCorruptedCachedDataIsIgnored() {
        let suiteName = "CodexUsageBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: "snapshot")

        let cache = CachedUsageStore(defaults: defaults, key: "snapshot")

        XCTAssertNil(cache.load())
    }

    private func makeStore(
        reader: any CodexUsageReading,
        cache: any UsageSnapshotCaching
    ) -> UsageStore {
        UsageStore(
            client: reader,
            cache: cache,
            executableResolver: { nil },
            startsAutomatically: false
        )
    }

    private func makeSnapshot(
        usedPercent: Double,
        fetchedAt: Date
    ) -> RateLimitSnapshot {
        RateLimitSnapshot(
            primary: RateLimitWindow(
                usedPercent: usedPercent,
                durationMinutes: 300,
                resetsAt: fetchedAt.addingTimeInterval(60 * 60)
            ),
            secondary: nil,
            fetchedAt: fetchedAt
        )
    }

    private func makeResult(_ snapshot: RateLimitSnapshot) -> CodexUsageReadResult {
        CodexUsageReadResult(
            snapshot: snapshot,
            executable: ResolvedCodexExecutable(
                url: URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources/codex"),
                source: .codexApplication
            )
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        _ condition: @escaping @MainActor () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !(await condition()) {
            guard clock.now < deadline else {
                throw WaitError.timedOut
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private enum WaitError: Error {
        case timedOut
    }
}

private actor ScriptedUsageReader: CodexUsageReading {
    enum Outcome: Sendable {
        case success(CodexUsageReadResult)
        case failure(CodexAppServerError)
    }

    private var outcomes: [Outcome]

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func readSnapshot() async throws -> CodexUsageReadResult {
        guard !outcomes.isEmpty else {
            throw CodexAppServerError.server(code: nil, phase: .rateLimits)
        }

        switch outcomes.removeFirst() {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

private actor ControlledUsageReader: CodexUsageReading {
    private(set) var callCount = 0
    private var continuation: CheckedContinuation<CodexUsageReadResult, Error>?

    func readSnapshot() async throws -> CodexUsageReadResult {
        callCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func succeed(with result: CodexUsageReadResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

private actor CancellableUsageReader: CodexUsageReading {
    func readSnapshot() async throws -> CodexUsageReadResult {
        try await Task.sleep(for: .seconds(60))
        throw CodexAppServerError.server(code: nil, phase: .rateLimits)
    }
}

private final class InMemoryUsageCache: UsageSnapshotCaching {
    private(set) var snapshot: RateLimitSnapshot?
    private(set) var savedSnapshots: [RateLimitSnapshot] = []

    init(snapshot: RateLimitSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() -> RateLimitSnapshot? {
        snapshot
    }

    func save(_ snapshot: RateLimitSnapshot) {
        self.snapshot = snapshot
        savedSnapshots.append(snapshot)
    }
}
