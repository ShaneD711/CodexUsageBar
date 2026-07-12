import XCTest
@testable import CodexUsageBar

final class UsageFailureTests: XCTestCase {
    func testMapsTransportErrorsToStableCategories() {
        XCTAssertEqual(UsageFailure(CodexAppServerError.executableNotFound), .executableNotFound)
        XCTAssertEqual(UsageFailure(CodexAppServerError.notLoggedIn), .notLoggedIn)
        XCTAssertEqual(UsageFailure(CodexAppServerError.timedOut), .timedOut)
        XCTAssertEqual(UsageFailure(CodexAppServerError.invalidResponse), .unsupportedResponse)
        XCTAssertEqual(UsageFailure(CodexAppServerError.launchFailed("private detail")), .launchFailed)
        XCTAssertEqual(UsageFailure(CodexAppServerError.server("private detail")), .server)
    }

    func testUnknownErrorsUseGenericServiceCategory() {
        XCTAssertEqual(UsageFailure(TestError()), .server)
    }

    private struct TestError: Error {}
}
