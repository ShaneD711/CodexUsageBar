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

final class RateLimitSnapshotWindowSelectionTests: XCTestCase {
    func testWindowsExposeEveryParsedWindowInSourceOrder() {
        let primary = makeWindow(durationMinutes: 10_080)
        let secondary = makeWindow(durationMinutes: 300)
        let snapshot = RateLimitSnapshot(
            primary: primary,
            secondary: secondary,
            fetchedAt: Date()
        )

        XCTAssertEqual(snapshot.windows, [primary, secondary])
    }

    func testMenuBarPrefersFiveHourWindowWhenOrderChanges() {
        let weekly = makeWindow(durationMinutes: 10_080)
        let fiveHour = makeWindow(durationMinutes: 300)
        let snapshot = RateLimitSnapshot(
            primary: weekly,
            secondary: fiveHour,
            fetchedAt: Date()
        )

        XCTAssertEqual(snapshot.menuBarWindow, fiveHour)
    }

    func testMenuBarFallsBackToPrimaryForUnknownDurations() {
        let primary = makeWindow(durationMinutes: 480)
        let secondary = makeWindow(durationMinutes: 20_160)
        let snapshot = RateLimitSnapshot(
            primary: primary,
            secondary: secondary,
            fetchedAt: Date()
        )

        XCTAssertEqual(snapshot.menuBarWindow, primary)
    }

    func testResetFormattingUsesDurationRatherThanWindowPosition() {
        let date = Date(timeIntervalSince1970: 1_783_756_800)
        let shortWindow = RateLimitWindow(
            usedPercent: 20,
            durationMinutes: 480,
            resetsAt: date
        )
        let longWindow = RateLimitWindow(
            usedPercent: 20,
            durationMinutes: 20_160,
            resetsAt: date
        )

        XCTAssertEqual(
            UsageFormatting.resetText(for: shortWindow),
            UsageFormatting.resetTime(date, locale: .autoupdatingCurrent)
        )
        XCTAssertEqual(
            UsageFormatting.resetText(for: longWindow),
            UsageFormatting.resetDate(date, locale: .autoupdatingCurrent)
        )
    }

    private func makeWindow(durationMinutes: Int) -> RateLimitWindow {
        RateLimitWindow(
            usedPercent: 25,
            durationMinutes: durationMinutes,
            resetsAt: Date(timeIntervalSince1970: 1_783_756_800)
        )
    }
}
