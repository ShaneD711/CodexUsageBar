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
    var menuBarDisplay: String { text("菜单栏显示", "Menu Bar Display") }
    var standardDisplay: String { text("标准", "Standard") }
    var compactDisplay: String { text("紧凑", "Compact") }
    var staleAccessibilityLabel: String { text("用量数据可能已过期", "Usage data may be stale") }

    func availabilityMessage(_ availability: UsageAvailability) -> String {
        switch availability {
        case .loading:
            return readingUsage
        case .availableFresh:
            return text("Codex 用量可用", "Codex usage is available")
        case .availableStale:
            return staleAccessibilityLabel
        case .notLoggedIn:
            return text(
                "Codex 尚未登录。请先打开 Codex 并登录。",
                "Codex is not signed in. Open Codex and sign in first."
            )
        case .executableNotFound:
            return text(
                "未找到 Codex。请先安装 ChatGPT 或 Codex。",
                "Codex was not found. Install ChatGPT or Codex first."
            )
        case .incompatible:
            return text(
                "当前 Codex 版本与本应用不兼容。",
                "This Codex version is incompatible with the app."
            )
        case .responseChanged:
            return text(
                "Codex 返回格式发生变化，已停止使用本次数据。",
                "The Codex response format changed, so this data was not used."
            )
        case .temporarilyUnavailable:
            return text(
                "暂时无法读取 Codex 用量，请稍后重试。",
                "Codex usage is temporarily unavailable. Try again shortly."
            )
        }
    }

    func menuBarDescription(
        percentage: String,
        resetTime: String?,
        isStale: Bool
    ) -> String {
        let description: String
        if let resetTime {
            description = text(
                "Codex 剩余用量：\(percentage)，重置时间 \(resetTime)",
                "Codex usage remaining: \(percentage), resets at \(resetTime)"
            )
        } else {
            description = text(
                "Codex 剩余用量：\(percentage)",
                "Codex usage remaining: \(percentage)"
            )
        }

        guard isStale else {
            return description
        }
        return text(
            "\(description)。\(staleAccessibilityLabel)",
            "\(description). \(staleAccessibilityLabel)"
        )
    }

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
        case .incompatible:
            return text(
                "当前 Codex 版本与本应用不兼容。",
                "This Codex version is incompatible with the app."
            )
        case .responseChanged:
            return text(
                "Codex 返回格式发生变化，已保留上次可信数据。",
                "The Codex response format changed. The last trusted data was kept."
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
