import Foundation
import XCTest
@testable import CodexUsageBar

final class AppSupportTests: XCTestCase {
    func testFindsNearestApplicationBundle() {
        let executable = URL(fileURLWithPath: "/Applications/CodexUsageBar.app/Contents/MacOS/CodexUsageBar")

        XCTAssertEqual(
            AppSupport.applicationBundleURL(containing: executable)?.path,
            "/Applications/CodexUsageBar.app"
        )
    }

    func testReturnsNilForUnbundledExecutable() {
        let executable = URL(fileURLWithPath: "/tmp/.build/debug/CodexUsageBar")

        XCTAssertNil(AppSupport.applicationBundleURL(containing: executable))
    }

    func testRedactsOnlyTheHomeDirectoryPrefix() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        XCTAssertEqual(
            AppSupport.redact(path: "/Users/example/.local/bin/codex", homeDirectory: home),
            "~/.local/bin/codex"
        )
        XCTAssertEqual(
            AppSupport.redact(path: "/Users/example-other/codex", homeDirectory: home),
            "/Users/example-other/codex"
        )
    }

    func testDiagnosticsContainSupportDataButNoUsageOrAuthenticationValues() {
        let diagnostic = AppDiagnostics(
            appVersion: "0.1.1",
            operatingSystem: "macOS 15.5",
            architecture: "arm64",
            executable: ResolvedCodexExecutable(
                url: URL(fileURLWithPath: "/Users/example/.local/bin/codex"),
                source: .localCLI
            ),
            snapshotState: .availableFresh,
            lastRefresh: Date(timeIntervalSince1970: 1_700_000_000),
            lastFailure: UsageFailure(
                CodexAppServerError.server(code: -32001, phase: .rateLimits)
            )
        )

        let report = AppSupport.diagnosticReport(
            diagnostic,
            homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true)
        )

        XCTAssertTrue(report.contains("CodexUsageBar: 0.1.1"))
        XCTAssertTrue(report.contains("Codex source: local-cli"))
        XCTAssertTrue(report.contains("Codex executable: ~/.local/bin/codex"))
        XCTAssertTrue(report.contains("Category: server"))
        XCTAssertTrue(report.contains("Phase: rate-limits"))
        XCTAssertTrue(report.contains("Error code: -32001"))
        XCTAssertFalse(report.contains("example"))
        XCTAssertFalse(report.localizedCaseInsensitiveContains("auth"))
        XCTAssertFalse(report.contains("private detail"))
        XCTAssertFalse(report.contains("75%"))
    }
}
