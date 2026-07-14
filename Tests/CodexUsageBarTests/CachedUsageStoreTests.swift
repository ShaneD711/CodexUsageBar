import Foundation
import XCTest
@testable import CodexUsageBar

@MainActor
final class CachedUsageStoreTests: XCTestCase {
    func testLoadsSemanticallyValidSnapshot() throws {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let snapshot = makeSnapshot()
        defaults.set(try JSONEncoder().encode(snapshot), forKey: key)

        XCTAssertEqual(CachedUsageStore(defaults: defaults, key: key).load(), snapshot)
    }

    func testDeletesDecodableButSemanticallyInvalidSnapshot() throws {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let invalid = RateLimitSnapshot(
            primary: RateLimitWindow(
                usedPercent: 25,
                durationMinutes: 0,
                resetsAt: Date(timeIntervalSince1970: 2_000_000_000)
            ),
            secondary: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
        defaults.set(try JSONEncoder().encode(invalid), forKey: key)

        XCTAssertNil(CachedUsageStore(defaults: defaults, key: key).load())
        XCTAssertNil(defaults.data(forKey: key))
    }

    func testDeletesCorruptCacheData() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("broken".utf8), forKey: key)

        XCTAssertNil(CachedUsageStore(defaults: defaults, key: key).load())
        XCTAssertNil(defaults.data(forKey: key))
    }

    func testDoesNotSaveSemanticallyInvalidSnapshot() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let invalid = RateLimitSnapshot(
            primary: RateLimitWindow(
                usedPercent: 25,
                durationMinutes: -1,
                resetsAt: Date(timeIntervalSince1970: 2_000_000_000)
            ),
            secondary: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        CachedUsageStore(defaults: defaults, key: key).save(invalid)

        XCTAssertNil(defaults.data(forKey: key))
    }

    private let suiteName = "CachedUsageStoreTests"
    private let key = "snapshot"

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeSnapshot() -> RateLimitSnapshot {
        RateLimitSnapshot(
            primary: RateLimitWindow(
                usedPercent: 25,
                durationMinutes: 300,
                resetsAt: Date(timeIntervalSince1970: 2_000_000_000)
            ),
            secondary: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
    }
}
