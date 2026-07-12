import Foundation

enum UsageFormatting {
    static func resetTime(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func resetDate(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }

    static func lastUpdated(
        _ date: Date,
        now: Date = Date(),
        localization: AppLocalization = .current
    ) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        return localization.lastUpdated(seconds: seconds)
    }
}
