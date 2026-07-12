import XCTest
@testable import CodexUsageBar

final class UsageAvailabilityTests: XCTestCase {
    func testSnapshotAlwaysTakesPriorityOverRefreshFailures() {
        let failure = UsageFailure(CodexAppServerError.notLoggedIn)

        XCTAssertEqual(
            UsageAvailability.resolve(
                hasSnapshot: true,
                isSnapshotStale: false,
                isRefreshing: false,
                lastFailure: failure
            ),
            .availableFresh
        )
        XCTAssertEqual(
            UsageAvailability.resolve(
                hasSnapshot: true,
                isSnapshotStale: true,
                isRefreshing: false,
                lastFailure: failure
            ),
            .availableStale
        )
    }

    func testNoSnapshotMapsStableFailureCategories() {
        XCTAssertEqual(resolve(.notLoggedIn), .notLoggedIn)
        XCTAssertEqual(resolve(.executableNotFound), .executableNotFound)
        XCTAssertEqual(resolve(.unsupportedResponse), .incompatible)
        XCTAssertEqual(resolve(.timedOut), .temporarilyUnavailable)
        XCTAssertEqual(resolve(.serviceStopped), .temporarilyUnavailable)
        XCTAssertEqual(resolve(.launchFailed), .temporarilyUnavailable)
        XCTAssertEqual(resolve(.server), .temporarilyUnavailable)
    }

    func testInitialOrActiveFirstReadIsLoading() {
        XCTAssertEqual(
            UsageAvailability.resolve(
                hasSnapshot: false,
                isSnapshotStale: false,
                isRefreshing: false,
                lastFailure: nil
            ),
            .loading
        )
        XCTAssertEqual(
            UsageAvailability.resolve(
                hasSnapshot: false,
                isSnapshotStale: false,
                isRefreshing: true,
                lastFailure: UsageFailure(CodexAppServerError.notLoggedIn)
            ),
            .loading
        )
    }

    private func resolve(_ category: UsageFailure.Category) -> UsageAvailability {
        let failure: UsageFailure
        switch category {
        case .notLoggedIn:
            failure = UsageFailure(CodexAppServerError.notLoggedIn)
        case .executableNotFound:
            failure = UsageFailure(CodexAppServerError.executableNotFound)
        case .unsupportedResponse:
            failure = UsageFailure(CodexAppServerError.invalidResponse(phase: .rateLimits))
        case .timedOut:
            failure = UsageFailure(CodexAppServerError.timedOut(phase: .rateLimits))
        case .serviceStopped:
            failure = UsageFailure(CodexAppServerError.connectionClosed(phase: .rateLimits))
        case .launchFailed:
            failure = UsageFailure(CodexAppServerError.launchFailed)
        case .server:
            failure = UsageFailure(CodexAppServerError.server(code: nil, phase: .rateLimits))
        }

        return UsageAvailability.resolve(
            hasSnapshot: false,
            isSnapshotStale: false,
            isRefreshing: false,
            lastFailure: failure
        )
    }
}
