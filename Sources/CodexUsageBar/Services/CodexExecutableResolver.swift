import Foundation

enum CodexExecutableResolver {
    static func resolve() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        var candidates: [String] = []

        if let override = environment["CODEX_EXECUTABLE"], !override.isEmpty {
            candidates.append(override)
        }

        candidates.append(contentsOf: [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/.local/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ])

        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/codex" })
        }

        return candidates
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
