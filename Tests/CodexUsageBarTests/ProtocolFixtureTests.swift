import Foundation
import XCTest
@testable import CodexUsageBar

final class ProtocolFixtureTests: XCTestCase {
    func testSignedInAndSignedOutAccountFixtures() throws {
        XCTAssertNoThrow(try AccountResponseParser.validate(fixture("account-signed-in")))
        XCTAssertThrowsError(try AccountResponseParser.validate(fixture("account-signed-out"))) {
            XCTAssertEqual($0 as? CodexAppServerError, .notLoggedIn)
        }
    }

    func testHistoricalDualWindowFixture() throws {
        let snapshot = try RateLimitResponseParser.parse(fixture("rate-limits-dual-window"))

        XCTAssertEqual(snapshot.windows.map(\.durationMinutes), [300, 10_080])
    }

    func testCurrentWeeklyOnlyFixture() throws {
        let snapshot = try RateLimitResponseParser.parse(fixture("rate-limits-weekly-only"))

        XCTAssertEqual(snapshot.windows.map(\.durationMinutes), [10_080])
    }

    func testTopLevelFallbackAndUnknownFieldFixtures() throws {
        XCTAssertEqual(
            try RateLimitResponseParser.parse(fixture("rate-limits-top-level")).primary.durationMinutes,
            300
        )
        XCTAssertEqual(
            try RateLimitResponseParser.parse(fixture("rate-limits-unknown-fields")).primary.durationMinutes,
            480
        )
    }

    func testPlanMetadataNeverControlsQuotaSelection() throws {
        let planNames = [
            "free", "go", "plus", "pro", "prolite", "team", "business",
            "enterprise", "enterprise-edu", "edu", "unknown"
        ]

        for planName in planNames {
            let data = Data(
                #"{"jsonrpc":"2.0","id":3,"result":{"planType":"\#(planName)","rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":22.5,"windowDurationMins":10080,"resetsAt":2000600000}}}}}"#.utf8
            )
            XCTAssertEqual(
                try RateLimitResponseParser.parse(data).primary.durationMinutes,
                10_080,
                planName
            )
        }
    }

    private func fixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    private enum FixtureError: Error {
        case missing(String)
    }
}
