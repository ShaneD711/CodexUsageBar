import Foundation
import XCTest
@testable import CodexUsageBar

final class CodexAppServerProcessTests: XCTestCase {
    func testProcessExitReportsClosedOutputImmediately() async throws {
        let fixture = try ScriptFixture(
            body: """
            IFS= read -r line
            exit 0
            """
        )
        defer { fixture.remove() }
        let client = makeClient(executable: fixture.executable, timeout: .seconds(2))
        let startedAt = DispatchTime.now()

        do {
            _ = try await client.readSnapshot()
            XCTFail("Expected connectionClosed")
        } catch {
            guard case CodexAppServerError.connectionClosed(phase: .initialize) = error else {
                return XCTFail("Expected connectionClosed, got \(error)")
            }
        }

        XCTAssertLessThan(elapsedSeconds(since: startedAt), 1.5)
    }

    func testContinuousNotificationsRespectTotalRequestDeadline() async throws {
        let fixture = try ScriptFixture(
            body: """
            while :; do
              printf '%s\\n' '{"jsonrpc":"2.0","method":"tick"}'
              /bin/sleep 0.01
            done
            """
        )
        defer { fixture.remove() }
        let client = makeClient(executable: fixture.executable, timeout: .milliseconds(150))
        let startedAt = DispatchTime.now()

        do {
            _ = try await client.readSnapshot()
            XCTFail("Expected timedOut")
        } catch {
            guard case CodexAppServerError.timedOut(phase: .initialize) = error else {
                return XCTFail("Expected timedOut, got \(error)")
            }
        }

        XCTAssertLessThan(elapsedSeconds(since: startedAt), 1)
    }

    func testCancellingReadTerminatesChildProcess() async throws {
        let fixture = try ScriptFixture(body: "")
        let startedMarker = fixture.directory.appendingPathComponent("started")
        let terminatedMarker = fixture.directory.appendingPathComponent("terminated")
        try fixture.replaceBody(
            """
            printf started > "\(startedMarker.path)"
            trap 'printf terminated > "\(terminatedMarker.path)"; exit 0' TERM INT
            while :; do
              /bin/sleep 0.05
            done
            """
        )
        defer { fixture.remove() }
        let client = makeClient(executable: fixture.executable, timeout: .seconds(5))
        let readTask = Task { try await client.readSnapshot() }

        try await waitUntil { FileManager.default.fileExists(atPath: startedMarker.path) }
        let cancelledAt = DispatchTime.now()
        readTask.cancel()

        do {
            _ = try await readTask.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        try await waitUntil { FileManager.default.fileExists(atPath: terminatedMarker.path) }
        XCTAssertLessThan(elapsedSeconds(since: cancelledAt), 2)
    }

    func testSignedOutAccountResponseStopsBeforeRateLimitRequest() async throws {
        let fixture = try ScriptFixture(
            body: """
            IFS= read -r initialize
            printf '%s\\n' '{"jsonrpc":"2.0","id":1,"result":{}}'
            IFS= read -r initialized
            IFS= read -r account
            case "$account" in
              *'account'*'read'*) ;;
              *) exit 21 ;;
            esac
            printf '%s\\n' '{"jsonrpc":"2.0","id":2,"result":{"account":null,"requiresOpenaiAuth":true}}'
            if IFS= read -r unexpected; then
              exit 22
            fi
            """
        )
        defer { fixture.remove() }
        let client = makeClient(executable: fixture.executable, timeout: .seconds(2))

        do {
            _ = try await client.readSnapshot()
            XCTFail("Expected notLoggedIn")
        } catch {
            guard case CodexAppServerError.notLoggedIn = error else {
                return XCTFail("Expected notLoggedIn, got \(error)")
            }
        }
    }

    func testSignedInAccountContinuesToRateLimitRequest() async throws {
        let fixture = try ScriptFixture(
            body: """
            IFS= read -r initialize
            printf '%s\\n' '{"jsonrpc":"2.0","id":1,"result":{}}'
            IFS= read -r initialized
            IFS= read -r account
            case "$account" in
              *'account'*'read'*) ;;
              *) exit 31 ;;
            esac
            printf '%s\\n' '{"jsonrpc":"2.0","id":2,"result":{"account":{"type":"chatgpt","email":"private@example.com","planType":"pro"},"requiresOpenaiAuth":true}}'
            IFS= read -r rate_limits
            case "$rate_limits" in
              *'account'*'rateLimits'*'read'*) ;;
              *) exit 32 ;;
            esac
            printf '%s\\n' '{"jsonrpc":"2.0","id":3,"result":{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":2000000000}}}}'
            """
        )
        defer { fixture.remove() }
        let client = makeClient(executable: fixture.executable, timeout: .seconds(2))

        let result = try await client.readSnapshot()

        XCTAssertEqual(result.snapshot.primary.usedPercent, 25)
        XCTAssertEqual(result.snapshot.primary.durationMinutes, 300)
    }

    private func makeClient(
        executable: URL,
        timeout: DispatchTimeInterval
    ) -> CodexAppServerClient {
        let resolved = ResolvedCodexExecutable(url: executable, source: .environmentOverride)
        return CodexAppServerClient(
            executableResolver: { resolved },
            requestTimeout: timeout
        )
    }

    private func elapsedSeconds(since start: DispatchTime) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: @escaping () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !condition() {
            guard clock.now < deadline else {
                throw WaitError.timedOut
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private enum WaitError: Error {
        case timedOut
    }
}

private final class ScriptFixture: @unchecked Sendable {
    let directory: URL
    let executable: URL

    init(body: String) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexUsageBarTests-\(UUID().uuidString)", isDirectory: true)
        executable = directory.appendingPathComponent("fake-codex")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try replaceBody(body)
    }

    func replaceBody(_ body: String) throws {
        let script = "#!/bin/sh\nset -eu\n\(body)\n"
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
