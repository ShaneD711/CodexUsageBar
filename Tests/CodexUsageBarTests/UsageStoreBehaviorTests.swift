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
        XCTAssertEqual(store.availability, .availableFresh)

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
        XCTAssertEqual(store.availability, .availableFresh)
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
        XCTAssertEqual(store.availability, .availableFresh)
        XCTAssertEqual(cache.savedSnapshots, [refreshed])
    }

    func testNoSnapshotFailureExposesStableAvailability() async {
        let reader = ScriptedUsageReader(outcomes: [.failure(.notLoggedIn)])
        let store = makeStore(reader: reader, cache: InMemoryUsageCache())

        await store.refresh()

        XCTAssertNil(store.snapshot)
        XCTAssertEqual(store.availability, .notLoggedIn)
        XCTAssertEqual(store.lastFailure?.category, .notLoggedIn)
    }

    func testLatestRefreshWinsWhenOlderSuccessReturnsLater() async throws {
        let older = makeSnapshot(usedPercent: 70, fetchedAt: Date().addingTimeInterval(-30))
        let newer = makeSnapshot(usedPercent: 20, fetchedAt: Date())
        let reader = GenerationControlledUsageReader()
        let cache = InMemoryUsageCache()
        let store = makeStore(reader: reader, cache: cache)

        let firstRefresh = Task { await store.refresh() }
        try await waitUntil { await reader.callCount == 1 }
        let secondRefresh = Task { await store.refresh() }
        try await waitUntil { await reader.callCount == 2 }
        try await waitUntil { await reader.cancelledRequestIDs.contains(0) }

        await reader.succeed(requestID: 1, with: makeResult(newer))
        await secondRefresh.value

        XCTAssertEqual(store.snapshot, newer)
        XCTAssertEqual(cache.savedSnapshots, [newer])
        XCTAssertFalse(store.isRefreshing)

        await reader.succeed(requestID: 0, with: makeResult(older))
        await firstRefresh.value

        XCTAssertEqual(store.snapshot, newer)
        XCTAssertEqual(cache.savedSnapshots, [newer])
        XCTAssertNil(store.lastFailure)
    }

    func testOlderFailureCannotOverwriteNewerSuccess() async throws {
        let newer = makeSnapshot(usedPercent: 15, fetchedAt: Date())
        let reader = GenerationControlledUsageReader()
        let store = makeStore(reader: reader, cache: InMemoryUsageCache())

        let firstRefresh = Task { await store.refresh() }
        try await waitUntil { await reader.callCount == 1 }
        let secondRefresh = Task { await store.refresh() }
        try await waitUntil { await reader.callCount == 2 }

        await reader.succeed(requestID: 1, with: makeResult(newer))
        await secondRefresh.value
        await reader.fail(
            requestID: 0,
            with: CodexAppServerError.server(code: -32001, phase: .rateLimits)
        )
        await firstRefresh.value

        XCTAssertEqual(store.snapshot, newer)
        XCTAssertNil(store.lastFailure)
        XCTAssertFalse(store.isRefreshing)
    }

    func testStopInvalidatesAndCancelsActiveRefresh() async throws {
        let ignored = makeSnapshot(usedPercent: 50, fetchedAt: Date())
        let reader = GenerationControlledUsageReader()
        let cache = InMemoryUsageCache()
        let store = makeStore(reader: reader, cache: cache)

        let refresh = Task { await store.refresh() }
        try await waitUntil { await reader.callCount == 1 }

        store.stop()
        try await waitUntil { await reader.cancelledRequestIDs.contains(0) }
        XCTAssertFalse(store.isRefreshing)

        await reader.succeed(requestID: 0, with: makeResult(ignored))
        await refresh.value

        XCTAssertNil(store.snapshot)
        XCTAssertTrue(cache.savedSnapshots.isEmpty)
        XCTAssertNil(store.lastFailure)
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
        XCTAssertEqual(store.availability, .loading)
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

private actor GenerationControlledUsageReader: CodexUsageReading {
    private(set) var callCount = 0
    private(set) var cancelledRequestIDs: Set<Int> = []
    private var continuations: [Int: CheckedContinuation<CodexUsageReadResult, Error>] = [:]

    func readSnapshot() async throws -> CodexUsageReadResult {
        let requestID = callCount
        callCount += 1

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                continuations[requestID] = continuation
            }
        } onCancel: {
            Task { await self.recordCancellation(requestID) }
        }
    }

    func succeed(requestID: Int, with result: CodexUsageReadResult) {
        continuations.removeValue(forKey: requestID)?.resume(returning: result)
    }

    func fail(requestID: Int, with error: Error) {
        continuations.removeValue(forKey: requestID)?.resume(throwing: error)
    }

    private func recordCancellation(_ requestID: Int) {
        cancelledRequestIDs.insert(requestID)
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
