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

    func testParsesCurrentWeeklyOnlyCodexBucket() throws {
        let snapshot = try parse(
            result: #"{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":18,"windowDurationMins":10080,"resetsAt":2000000000}}}}"#
        )

        XCTAssertEqual(snapshot.primary.durationMinutes, 10_080)
        XCTAssertNil(snapshot.secondary)
    }

    func testPromotesSecondaryOnlyWindowToDomainPrimary() throws {
        let snapshot = try parse(
            result: #"{"rateLimitsByLimitId":{"codex":{"primary":null,"secondary":{"usedPercent":18,"windowDurationMins":10080,"resetsAt":2000000000}}}}"#
        )

        XCTAssertEqual(snapshot.primary.durationMinutes, 10_080)
        XCTAssertNil(snapshot.secondary)
    }

    func testPreservesTransportOrderWhenWindowDurationsAreSwapped() throws {
        let snapshot = try parse(
            result: #"{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":18,"windowDurationMins":10080,"resetsAt":2000600000},"secondary":{"usedPercent":22,"windowDurationMins":300,"resetsAt":2000000000}}}}"#
        )

        XCTAssertEqual(snapshot.windows.map(\.durationMinutes), [10_080, 300])
        XCTAssertEqual(snapshot.menuBarWindow.durationMinutes, 300)
    }

    func testFindsCodexByInternalLimitID() throws {
        let snapshot = try parse(
            result: #"{"rateLimitsByLimitId":{"future-key":{"limitId":"codex","primary":{"usedPercent":18,"windowDurationMins":480,"resetsAt":2000000000}}}}"#
        )

        XCTAssertEqual(snapshot.primary.durationMinutes, 480)
    }

    func testRejectsAmbiguousInternalCodexBuckets() {
        assertChanged(
            result: #"{"rateLimitsByLimitId":{"a":{"limitId":"codex"},"b":{"limitId":"codex"}}}"#,
            reason: .ambiguousCodexLimits
        )
    }

    func testDoesNotTreatOnlyUnknownMappedBucketAsCodex() {
        assertChanged(
            result: #"{"rateLimitsByLimitId":{"other":{"limitId":"other","primary":{"usedPercent":18,"windowDurationMins":300,"resetsAt":2000000000}}}}"#,
            reason: .missingCodexLimits
        )
    }

    func testFallsBackWhenMappedBucketsExistButNoneBelongToCodex() throws {
        let snapshot = try parse(
            result: #"{"rateLimitsByLimitId":{"other":{"limitId":"other"}},"rateLimits":{"primary":{"usedPercent":18,"windowDurationMins":300,"resetsAt":2000000000}}}"#
        )

        XCTAssertEqual(snapshot.primary.durationMinutes, 300)
    }

    func testDamagedExactCodexBucketDoesNotFallBackToTopLevel() {
        assertChanged(
            result: #"{"rateLimitsByLimitId":{"codex":{"primary":{}}},"rateLimits":{"primary":{"usedPercent":18,"windowDurationMins":300,"resetsAt":2000000000}}}"#,
            reason: .missingCriticalField
        )
    }

    func testMissingAndNullWindowsProduceNoUsableWindow() {
        assertChanged(
            result: #"{"rateLimitsByLimitId":{"codex":{"primary":null}}}"#,
            reason: .noUsableWindow
        )
    }

    func testPresentWindowWithUnsupportedTypeIsRejected() {
        assertChanged(
            result: #"{"rateLimitsByLimitId":{"codex":{"primary":[]}}}"#,
            reason: .invalidCriticalType
        )
    }

    func testAcceptsExactJSONNumberStrings() throws {
        let snapshot = try parse(
            result: #"{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":"18.5","windowDurationMins":"3e2","resetsAt":"2000000000.0"}}}}"#
        )

        XCTAssertEqual(snapshot.primary.usedPercent, 18.5)
        XCTAssertEqual(snapshot.primary.durationMinutes, 300)
        XCTAssertEqual(snapshot.primary.resetsAt.timeIntervalSince1970, 2_000_000_000)
    }

    func testRejectsNonJSONNumberStringForms() {
        for value in [#""+300""#, #"" 300 ""#, #""03""#, #""300_000""#, #""NaN""#, #""Infinity""#] {
            assertChanged(
                result: #"{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":18,"windowDurationMins":\#(value),"resetsAt":2000000000}}}}"#,
                reason: .invalidCriticalValue
            )
        }
    }

    func testRejectsBooleanFractionalNegativeAndMillisecondCriticalValues() {
        assertChanged(result: window(duration: "true"), reason: .invalidCriticalType)
        assertChanged(result: window(duration: "300.5"), reason: .invalidCriticalValue)
        assertChanged(result: window(used: "-1"), reason: .invalidCriticalValue)
        assertChanged(result: window(reset: "2000000000000"), reason: .invalidCriticalValue)
    }

    func testResponseReasonUsesFixedPriorityAcrossFieldsAndWindows() {
        assertChanged(
            result: #"{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":"bad","windowDurationMins":300,"resetsAt":2000000000},"secondary":{}}}}"#,
            reason: .missingCriticalField
        )
        assertChanged(
            result: #"{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":"bad","windowDurationMins":300,"resetsAt":2000000000},"secondary":{"usedPercent":[],"windowDurationMins":300,"resetsAt":2000000000}}}}"#,
            reason: .invalidCriticalType
        )
    }

    func testResetTimestampAcceptsRepresentableUpperBoundAndRejectsNextSecond() throws {
        let upperBound = Int(Date.distantFuture.timeIntervalSince1970)
        XCTAssertEqual(
            try parse(result: window(reset: String(upperBound))).primary.resetsAt.timeIntervalSince1970,
            Double(upperBound)
        )
        assertChanged(
            result: window(reset: String(upperBound + 1)),
            reason: .invalidCriticalValue
        )
    }

    func testParserAcceptsUsageAboveOneHundredAndCalculatesZeroRemaining() throws {
        let snapshot = try parse(result: window(used: "1000000"))

        XCTAssertEqual(snapshot.primary.usedPercent, 1_000_000)
        XCTAssertEqual(snapshot.primary.remainingPercent, 0)
    }

    func testUnknownFieldsAndPlanNamesDoNotAffectQuotaParsing() throws {
        let plans = ["free", "go", "plus", "pro", "prolite", "team", "business", "enterprise", "edu", "unknown"]
        for plan in plans {
            let snapshot = try parse(
                result: #"{"planType":"\#(plan)","future":true,"rateLimitsByLimitId":{"codex":{"limitId":"codex","futureField":{"nested":1},"primary":{"usedPercent":18,"windowDurationMins":300,"resetsAt":2000000000,"extra":"ignored"}}}}"#
            )
            XCTAssertEqual(snapshot.primary.durationMinutes, 300, plan)
        }
    }

    func testNullResultAndMalformedEnvelopeHaveStableReasons() {
        assertChanged(data: Data(#"{"jsonrpc":"2.0","id":3,"result":null}"#.utf8), reason: .missingResult)
        assertChanged(data: Data("not-json".utf8), reason: .malformedEnvelope)
    }

    private func parse(result: String) throws -> RateLimitSnapshot {
        try RateLimitResponseParser.parse(
            Data(#"{"jsonrpc":"2.0","id":3,"result":\#(result)}"#.utf8),
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )
    }

    private func window(
        used: String = "18",
        duration: String = "300",
        reset: String = "2000000000"
    ) -> String {
        #"{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":\#(used),"windowDurationMins":\#(duration),"resetsAt":\#(reset)}}}}"#
    }

    private func assertChanged(
        result: String,
        reason: ResponseChangeReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertChanged(
            data: Data(#"{"jsonrpc":"2.0","id":3,"result":\#(result)}"#.utf8),
            reason: reason,
            file: file,
            line: line
        )
    }

    private func assertChanged(
        data: Data,
        reason: ResponseChangeReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try RateLimitResponseParser.parse(data), file: file, line: line) {
            XCTAssertEqual(
                $0 as? CodexAppServerError,
                .responseChanged(phase: .rateLimits, reason: reason),
                file: file,
                line: line
            )
        }
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

final class RateLimitWindowSafetyTests: XCTestCase {
    func testHugeUsedPercentValuesClampBeforeIntegerConversion() {
        for usedPercent in [101, 1_000_000, Double.greatestFiniteMagnitude] {
            let window = RateLimitWindow(
                usedPercent: usedPercent,
                durationMinutes: 300,
                resetsAt: Date(timeIntervalSince1970: 2_000_000_000)
            )
            XCTAssertEqual(window.remainingPercent, 0)
        }
    }

    func testSemanticValidationRejectsInvalidWindows() {
        let valid = RateLimitWindow(
            usedPercent: 25,
            durationMinutes: 300,
            resetsAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
        XCTAssertTrue(valid.isSemanticallyValid)
        XCTAssertFalse(RateLimitWindow(usedPercent: .nan, durationMinutes: 300, resetsAt: valid.resetsAt).isSemanticallyValid)
        XCTAssertFalse(RateLimitWindow(usedPercent: -1, durationMinutes: 300, resetsAt: valid.resetsAt).isSemanticallyValid)
        XCTAssertFalse(RateLimitWindow(usedPercent: 25, durationMinutes: 0, resetsAt: valid.resetsAt).isSemanticallyValid)
        XCTAssertFalse(RateLimitWindow(usedPercent: 25, durationMinutes: 300, resetsAt: .distantPast).isSemanticallyValid)
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
