import AppKit
import Foundation

struct AppDiagnostics: Sendable {
    enum SnapshotState: String, Sendable {
        case unavailable
        case availableFresh = "available, fresh"
        case availableStale = "available, stale"
    }

    let appVersion: String
    let operatingSystem: String
    let architecture: String
    let executable: ResolvedCodexExecutable?
    let snapshotState: SnapshotState
    let lastRefresh: Date?
    let lastFailure: UsageFailure?
}

enum AppSupport {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Development"
    }

    static var operatingSystem: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    static var runningApplicationURL: URL? {
        applicationBundleURL(containing: Bundle.main.bundleURL)
    }

    static func applicationBundleURL(containing url: URL) -> URL? {
        var candidate = url.standardizedFileURL

        while candidate.path != "/" {
            if candidate.pathExtension.lowercased() == "app" {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        return nil
    }

    static func redact(path: String, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> String {
        let home = homeDirectory.standardizedFileURL.path
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path

        if standardizedPath == home {
            return "~"
        }
        if standardizedPath.hasPrefix(home + "/") {
            return "~" + standardizedPath.dropFirst(home.count)
        }
        return standardizedPath
    }

    static func diagnosticReport(
        _ diagnostic: AppDiagnostics,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        let executableSource = diagnostic.executable?.source.rawValue ?? "not-found"
        let executablePath = diagnostic.executable.map {
            redact(path: $0.url.path, homeDirectory: homeDirectory)
        } ?? "not-found"
        let refreshDate = diagnostic.lastRefresh.map {
            ISO8601DateFormatter().string(from: $0)
        } ?? "never"
        let category = diagnostic.lastFailure?.category.rawValue ?? "none"
        let phase = diagnostic.lastFailure?.phase?.rawValue ?? "none"
        let serverCode = diagnostic.lastFailure?.serverCode.map(String.init) ?? "none"

        return [
            "CodexUsageBar: \(diagnostic.appVersion)",
            "macOS: \(diagnostic.operatingSystem.replacingOccurrences(of: "macOS ", with: ""))",
            "Architecture: \(diagnostic.architecture)",
            "Codex source: \(executableSource)",
            "Codex executable: \(executablePath)",
            "Snapshot: \(diagnostic.snapshotState.rawValue)",
            "Last refresh: \(refreshDate)",
            "Category: \(category)",
            "Phase: \(phase)",
            "Error code: \(serverCode)"
        ].joined(separator: "\n")
    }

    @MainActor
    static func revealInFinder(_ applicationURL: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([applicationURL])
    }

    @MainActor
    static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
