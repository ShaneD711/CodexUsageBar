import Foundation
import XCTest
@testable import CodexUsageBar

final class AccountResponseParserTests: XCTestCase {
    func testAnyAccountObjectPermitsReadingRegardlessOfAuthMarker() throws {
        try AccountResponseParser.validate(response(account: "{}", auth: nil))
        try AccountResponseParser.validate(response(account: #"{"type":"future"}"#, auth: #""unexpected""#))
    }

    func testMissingAccountUsesStructuredAuthRequirement() throws {
        XCTAssertThrowsError(try AccountResponseParser.validate(response(account: "null", auth: "true"))) {
            XCTAssertEqual($0 as? CodexAppServerError, .notLoggedIn)
        }
        try AccountResponseParser.validate(response(account: nil, auth: "false"))
    }

    func testMissingAccountAndAuthMarkerIsAResponseChange() {
        assertChanged(response(account: nil, auth: nil), reason: .missingCriticalField)
        assertChanged(response(account: "null", auth: #""true""#), reason: .invalidCriticalType)
        assertChanged(response(account: "null", auth: "1"), reason: .invalidCriticalType)
    }

    func testScalarOrArrayAccountIsAResponseChange() {
        for account in [#""signed-in""#, "1", "true", "[]"] {
            assertChanged(response(account: account, auth: "true"), reason: .invalidCriticalType)
        }
    }

    func testNullResultHasStableReason() {
        assertChanged(Data(#"{"jsonrpc":"2.0","id":2,"result":null}"#.utf8), reason: .missingResult)
    }

    private func response(account: String?, auth: String?) -> Data {
        var fields: [String] = []
        if let account { fields.append(#""account":\#(account)"#) }
        if let auth { fields.append(#""requiresOpenaiAuth":\#(auth)"#) }
        return Data(
            #"{"jsonrpc":"2.0","id":2,"result":{\#(fields.joined(separator: ","))}}"#.utf8
        )
    }

    private func assertChanged(
        _ data: Data,
        reason: ResponseChangeReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try AccountResponseParser.validate(data), file: file, line: line) {
            XCTAssertEqual(
                $0 as? CodexAppServerError,
                .responseChanged(phase: .account, reason: reason),
                file: file,
                line: line
            )
        }
    }
}
