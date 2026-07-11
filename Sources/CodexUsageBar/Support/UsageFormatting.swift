import Foundation

enum UsageFormatting {
    static func resetTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func resetDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day())
    }

    static func lastUpdated(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))

        if seconds < 60 {
            return "刚刚刷新"
        }

        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) 分钟前刷新"
        }

        let hours = Int(seconds / 3600)
        return "\(hours) 小时前刷新"
    }
}
