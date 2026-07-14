import XCTest
@testable import CodexUsageBar

final class UsageFailureTests: XCTestCase {
    func testMapsTransportErrorsToStableCategories() {
        XCTAssertEqual(UsageFailure(CodexAppServerError.executableNotFound).category, .executableNotFound)
        XCTAssertEqual(UsageFailure(CodexAppServerError.notLoggedIn).category, .notLoggedIn)
        XCTAssertEqual(UsageFailure(CodexAppServerError.timedOut(phase: .account)).category, .timedOut)
        XCTAssertEqual(UsageFailure(CodexAppServerError.connectionClosed(phase: .initialize)).category, .serviceStopped)
        XCTAssertEqual(
            UsageFailure(CodexAppServerError.incompatible(code: -32601, phase: .rateLimits)).category,
            .incompatible
        )
        XCTAssertEqual(
            UsageFailure(
                CodexAppServerError.responseChanged(
                    phase: .rateLimits,
                    reason: .missingCriticalField
                )
            ).category,
            .responseChanged
        )
        XCTAssertEqual(UsageFailure(CodexAppServerError.launchFailed).category, .launchFailed)
        XCTAssertEqual(UsageFailure(CodexAppServerError.server(code: -32001, phase: .rateLimits)).category, .server)
    }

    func testKeepsOnlySafeStructuredFailureContext() {
        let timedOut = UsageFailure(CodexAppServerError.timedOut(phase: .account))
        XCTAssertEqual(timedOut.phase, .account)
        XCTAssertNil(timedOut.serverCode)

        let server = UsageFailure(CodexAppServerError.server(code: -32001, phase: .rateLimits))
        XCTAssertEqual(server.phase, .rateLimits)
        XCTAssertEqual(server.serverCode, -32001)

        let changed = UsageFailure(
            CodexAppServerError.responseChanged(
                phase: .rateLimits,
                reason: .invalidCriticalValue
            )
        )
        XCTAssertEqual(changed.phase, .rateLimits)
        XCTAssertEqual(changed.responseChangeReason, .invalidCriticalValue)
        XCTAssertNil(changed.serverCode)
    }

    func testUnknownErrorsUseGenericServiceCategory() {
        let failure = UsageFailure(TestError())
        XCTAssertEqual(failure.category, .server)
        XCTAssertNil(failure.phase)
        XCTAssertNil(failure.serverCode)
        XCTAssertNil(failure.responseChangeReason)
    }

    private struct TestError: Error {}
}
