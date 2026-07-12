import XCTest
@testable import CodexUsageBar

final class UsageFailureTests: XCTestCase {
    func testMapsTransportErrorsToStableCategories() {
        XCTAssertEqual(UsageFailure(CodexAppServerError.executableNotFound).category, .executableNotFound)
        XCTAssertEqual(UsageFailure(CodexAppServerError.notLoggedIn).category, .notLoggedIn)
        XCTAssertEqual(UsageFailure(CodexAppServerError.timedOut(phase: .account)).category, .timedOut)
        XCTAssertEqual(UsageFailure(CodexAppServerError.connectionClosed(phase: .initialize)).category, .serviceStopped)
        XCTAssertEqual(UsageFailure(CodexAppServerError.invalidResponse(phase: .rateLimits)).category, .unsupportedResponse)
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
    }

    func testUnknownErrorsUseGenericServiceCategory() {
        let failure = UsageFailure(TestError())
        XCTAssertEqual(failure.category, .server)
        XCTAssertNil(failure.phase)
        XCTAssertNil(failure.serverCode)
    }

    private struct TestError: Error {}
}
