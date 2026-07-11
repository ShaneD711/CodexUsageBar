import Foundation
import XCTest
@testable import CodexUsageBar

final class RateLimitResponseParserTests: XCTestCase {
    func testParsesCodexLimitsAndCalculatesRemainingPercent() throws {
        let data = Data(
            """
            {
              "jsonrpc": "2.0",
              "id": 2,
              "result": {
                "rateLimitsByLimitId": {
                  "codex": {
                    "primary": {
                      "usedPercent": 23,
                      "windowDurationMins": 300,
                      "resetsAt": 1783756800
                    },
                    "secondary": {
                      "usedPercent": 4,
                      "windowDurationMins": 10080,
                      "resetsAt": 1784246400
                    }
                  }
                }
              }
            }
            """.utf8
        )

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = try RateLimitResponseParser.parse(data, now: now)

        XCTAssertEqual(snapshot.primary.remainingPercent, 77)
        XCTAssertEqual(snapshot.primary.durationMinutes, 300)
        XCTAssertEqual(snapshot.secondary?.remainingPercent, 96)
        XCTAssertEqual(snapshot.secondary?.durationMinutes, 10_080)
        XCTAssertEqual(snapshot.fetchedAt, now)
    }

    func testFallsBackToTopLevelRateLimits() throws {
        let data = Data(
            """
            {
              "jsonrpc": "2.0",
              "id": 2,
              "result": {
                "rateLimits": {
                  "primary": {
                    "usedPercent": 30.4,
                    "windowDurationMins": 300,
                    "resetsAt": 1783756800
                  }
                }
              }
            }
            """.utf8
        )

        let snapshot = try RateLimitResponseParser.parse(data)

        XCTAssertEqual(snapshot.primary.remainingPercent, 70)
        XCTAssertNil(snapshot.secondary)
    }
}

final class RateLimitSnapshotFreshnessTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testSnapshotIsFreshAtTenMinuteBoundary() {
        let snapshot = makeSnapshot()
        let tenMinutesLater = fetchedAt.addingTimeInterval(10 * 60)

        XCTAssertFalse(snapshot.isStale(at: tenMinutesLater))
    }

    func testSnapshotIsStaleAfterTenMinutes() {
        let snapshot = makeSnapshot()
        let tenMinutesAndOneSecondLater = fetchedAt.addingTimeInterval(10 * 60 + 1)

        XCTAssertTrue(snapshot.isStale(at: tenMinutesAndOneSecondLater))
    }

    private func makeSnapshot() -> RateLimitSnapshot {
        RateLimitSnapshot(
            primary: RateLimitWindow(
                usedPercent: 25,
                durationMinutes: 300,
                resetsAt: fetchedAt.addingTimeInterval(60 * 60)
            ),
            secondary: nil,
            fetchedAt: fetchedAt
        )
    }
}
