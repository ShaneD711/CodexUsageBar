import Foundation
import XCTest
@testable import CodexUsageBar

final class CodexExecutableResolverTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

    func testEnvironmentOverrideHasHighestPriority() {
        let resolved = resolve(
            environment: ["CODEX_EXECUTABLE": "/custom/codex", "PATH": "/path/bin"],
            executablePaths: ["/custom/codex", "/Applications/ChatGPT.app/Contents/Resources/codex"]
        )

        XCTAssertEqual(resolved?.url.path, "/custom/codex")
        XCTAssertEqual(resolved?.source, .environmentOverride)
    }

    func testApplicationCandidatesKeepExpectedOrder() {
        let resolved = resolve(
            executablePaths: [
                "/Applications/Codex.app/Contents/Resources/codex",
                "/Applications/ChatGPT.app/Contents/Resources/codex",
                "/opt/homebrew/bin/codex"
            ]
        )

        XCTAssertEqual(resolved?.source, .chatGPTApplication)
    }

    func testFallsBackThroughUserAppLocalCLIHomebrewAndPath() {
        let cases: [(String, CodexExecutableSource)] = [
            ("/Users/example/Applications/Codex.app/Contents/Resources/codex", .userCodexApplication),
            ("/Users/example/.local/bin/codex", .localCLI),
            ("/opt/homebrew/bin/codex", .homebrew),
            ("/path/bin/codex", .path)
        ]

        for (path, source) in cases {
            let resolved = resolve(environment: ["PATH": "/path/bin"], executablePaths: [path])
            XCTAssertEqual(resolved?.url.path, path)
            XCTAssertEqual(resolved?.source, source)
        }
    }

    func testReturnsNilWhenNoCandidateIsExecutable() {
        XCTAssertNil(resolve(executablePaths: []))
    }

    private func resolve(
        environment: [String: String] = [:],
        executablePaths: Set<String>
    ) -> ResolvedCodexExecutable? {
        CodexExecutableResolver.resolve(
            environment: environment,
            homeDirectory: home,
            isExecutable: { executablePaths.contains($0) }
        )
    }
}
