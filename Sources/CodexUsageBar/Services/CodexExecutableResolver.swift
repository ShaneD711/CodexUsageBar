import Foundation

enum CodexExecutableSource: String, Equatable, Sendable {
    case environmentOverride = "environment-override"
    case chatGPTApplication = "chatgpt-app"
    case codexApplication = "codex-app"
    case userChatGPTApplication = "user-chatgpt-app"
    case userCodexApplication = "user-codex-app"
    case localCLI = "local-cli"
    case homebrew
    case system
    case path
}

struct ResolvedCodexExecutable: Equatable, Sendable {
    let url: URL
    let source: CodexExecutableSource
}

enum CodexExecutableResolver {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)
    ) -> ResolvedCodexExecutable? {
        let home = homeDirectory.standardizedFileURL.path
        var candidates: [(path: String, source: CodexExecutableSource)] = []

        if let override = environment["CODEX_EXECUTABLE"], !override.isEmpty {
            candidates.append((override, .environmentOverride))
        }

        candidates.append(contentsOf: [
            ("/Applications/ChatGPT.app/Contents/Resources/codex", .chatGPTApplication),
            ("/Applications/Codex.app/Contents/Resources/codex", .codexApplication),
            ("\(home)/Applications/ChatGPT.app/Contents/Resources/codex", .userChatGPTApplication),
            ("\(home)/Applications/Codex.app/Contents/Resources/codex", .userCodexApplication),
            ("\(home)/.local/bin/codex", .localCLI),
            ("/opt/homebrew/bin/codex", .homebrew),
            ("/usr/local/bin/codex", .system)
        ])

        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { ("\($0)/codex", .path) })
        }

        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate.path).standardizedFileURL
            if isExecutable(url.path) {
                return ResolvedCodexExecutable(url: url, source: candidate.source)
            }
        }

        return nil
    }
}
