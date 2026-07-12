import Foundation
import XCTest
@testable import CodexUsageBar

final class CodexAppServerDeadlineTests: XCTestCase {
    func testReadResponseKeepsOneDeadlineAcrossUnrelatedMessages() throws {
        let reader = StubJSONLineReader(lines: [
            Data(#"{"jsonrpc":"2.0","method":"account/updated"}"#.utf8),
            Data(#"{"jsonrpc":"2.0","id":2,"result":{}}"#.utf8)
        ])
        let deadline = DispatchTime.now() + .seconds(15)

        _ = try CodexAppServerClient.readResponse(
            id: 2,
            phase: .account,
            reader: reader,
            deadline: deadline
        )

        XCTAssertEqual(reader.deadlines, [deadline.uptimeNanoseconds, deadline.uptimeNanoseconds])
    }

    func testReadResponseTimesOutEvenWhenBufferedMessagesRemain() {
        let reader = StubJSONLineReader(lines: [
            Data(#"{"jsonrpc":"2.0","method":"account/updated"}"#.utf8)
        ])
        let expiredDeadline = DispatchTime(uptimeNanoseconds: 1)

        XCTAssertThrowsError(
            try CodexAppServerClient.readResponse(
                id: 2,
                phase: .initialize,
                reader: reader,
                deadline: expiredDeadline
            )
        ) { error in
            guard case CodexAppServerError.timedOut(phase: .initialize) = error else {
                return XCTFail("Expected timedOut, got \(error)")
            }
        }

        XCTAssertTrue(reader.deadlines.isEmpty)
    }

    func testReadResponseReportsClosedOutputInsteadOfTimeout() {
        let reader = StubJSONLineReader(lines: [nil])

        XCTAssertThrowsError(
            try CodexAppServerClient.readResponse(
                id: 2,
                phase: .rateLimits,
                reader: reader,
                deadline: .now() + .seconds(15)
            )
        ) { error in
            guard case CodexAppServerError.connectionClosed(phase: .rateLimits) = error else {
                return XCTFail("Expected connectionClosed, got \(error)")
            }
        }
    }

    func testServerErrorKeepsCodeAndPhaseWithoutClassifyingEnglishMessage() {
        let reader = StubJSONLineReader(lines: [
            Data(#"{"jsonrpc":"2.0","id":3,"error":{"code":-32001,"message":"authentication login required","data":{"email":"private@example.com"}}}"#.utf8)
        ])

        XCTAssertThrowsError(
            try CodexAppServerClient.readResponse(
                id: 3,
                phase: .rateLimits,
                reader: reader,
                deadline: .now() + .seconds(15)
            )
        ) { error in
            guard case CodexAppServerError.server(code: -32001, phase: .rateLimits) = error else {
                return XCTFail("Expected structured server error, got \(error)")
            }
        }
    }

    func testJSONLineReaderReturnsEOFWithoutWaitingForDeadline() throws {
        let pipe = Pipe()
        let reader = JSONLineReader(handle: pipe.fileHandleForReading)
        try pipe.fileHandleForWriting.close()

        let startedAt = DispatchTime.now()
        let line = try reader.nextLine(until: .now() + .seconds(2))
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds) / 1_000_000_000

        XCTAssertNil(line)
        XCTAssertLessThan(elapsed, 0.5)
    }
}

private final class StubJSONLineReader: JSONLineReading {
    private var lines: [Data?]
    private(set) var deadlines: [UInt64] = []

    init(lines: [Data?]) {
        self.lines = lines
    }

    func nextLine(until deadline: DispatchTime) throws -> Data? {
        deadlines.append(deadline.uptimeNanoseconds)
        return lines.removeFirst()
    }
}
