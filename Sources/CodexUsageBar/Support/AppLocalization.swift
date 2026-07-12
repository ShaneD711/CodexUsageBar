import Foundation

enum AppLanguage: Equatable, Sendable {
    case simplifiedChinese
    case english

    static func resolve(preferredLanguages: [String]) -> AppLanguage {
        guard let identifier = preferredLanguages.first else {
            return .english
        }

        let components = identifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
            .split(separator: "-")

        guard components.first == "zh" else {
            return .english
        }

        if components.contains("hant") {
            return .english
        }

        if components.contains("hans") || components.contains("cn") || components.contains("sg") {
            return .simplifiedChinese
        }

        return .english
    }
}

struct AppLocalization: Equatable, Sendable {
    static var current: AppLocalization {
        AppLocalization(
            language: AppLanguage.resolve(preferredLanguages: Locale.preferredLanguages)
        )
    }

    let language: AppLanguage

    var headerTitle: String { text("Codex剩余用量", "Codex Usage Remaining") }
    var fiveHours: String { text("5 小时", "5 hours") }
    var oneWeek: String { text("1 周", "1 week") }
    var readingUsage: String { text("正在读取 Codex 用量…", "Reading Codex usage…") }
    var notRefreshed: String { text("尚未刷新", "Not refreshed yet") }
    var refresh: String { text("刷新", "Refresh") }
    var more: String { text("更多", "More") }
    var quit: String { text("退出", "Quit") }
    var showInFinder: String { text("在 Finder 中显示", "Show in Finder") }
    var copyDiagnostics: String { text("复制诊断信息", "Copy Diagnostics") }
    var copied: String { text("已复制", "Copied") }
    var staleAccessibilityLabel: String { text("用量数据可能已过期", "Usage data may be stale") }

    func windowTitle(durationMinutes: Int) -> String {
        switch durationMinutes {
        case 300:
            return fiveHours
        case 10_080:
            return oneWeek
        default:
            if durationMinutes > 0, durationMinutes.isMultiple(of: 1_440) {
                let days = durationMinutes / 1_440
                return text("\(days) 天", "\(days) day\(days == 1 ? "" : "s")")
            }

            if durationMinutes > 0, durationMinutes.isMultiple(of: 60) {
                let hours = durationMinutes / 60
                return text("\(hours) 小时", "\(hours) hour\(hours == 1 ? "" : "s")")
            }

            return text("\(durationMinutes) 分钟", "\(durationMinutes) min")
        }
    }

    func lastUpdated(seconds: TimeInterval) -> String {
        if seconds < 60 {
            return text("刚刚刷新", "Updated just now")
        }

        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return text("\(minutes) 分钟前刷新", "Updated \(minutes) minute\(minutes == 1 ? "" : "s") ago")
        }

        let hours = Int(seconds / 3600)
        return text("\(hours) 小时前刷新", "Updated \(hours) hour\(hours == 1 ? "" : "s") ago")
    }

    func staleStatus(lastUpdated: String) -> String {
        text("数据可能已过期 · \(lastUpdated)", "Data may be stale · \(lastUpdated)")
    }

    func cachedFailure(_ message: String) -> String {
        text("\(message) 正在显示上次数据。", "\(message) Showing the last available data.")
    }

    func failureMessage(_ failure: UsageFailure) -> String {
        switch failure.category {
        case .executableNotFound:
            return text(
                "未找到 Codex。请先安装 ChatGPT 或 Codex。",
                "Codex was not found. Install ChatGPT or Codex first."
            )
        case .notLoggedIn:
            return text(
                "Codex 尚未登录。请先打开 Codex 并登录。",
                "Codex is not signed in. Open Codex and sign in first."
            )
        case .timedOut:
            return text(
                "读取 Codex 用量超时，请稍后重试。",
                "Reading Codex usage timed out. Try again shortly."
            )
        case .serviceStopped:
            return text(
                "Codex 用量服务已意外退出，请重新刷新。",
                "The Codex usage service stopped unexpectedly. Refresh to try again."
            )
        case .unsupportedResponse:
            return text(
                "当前 Codex 版本返回了不支持的用量数据。",
                "This Codex version returned unsupported usage data."
            )
        case .launchFailed:
            return text(
                "无法启动 Codex 用量服务。",
                "The Codex usage service could not be started."
            )
        case .server:
            return text(
                "Codex 用量服务返回错误。",
                "The Codex usage service returned an error."
            )
        }
    }

    private func text(_ chinese: String, _ english: String) -> String {
        language == .simplifiedChinese ? chinese : english
    }
}
