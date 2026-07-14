import Foundation

enum MenuBarDisplayMode: String, CaseIterable, Equatable, Identifiable, Sendable {
    static let storageKey = "menuBarDisplayMode"

    case standard
    case compact

    var id: String { rawValue }

    static func resolve(storedValue: String?) -> MenuBarDisplayMode {
        storedValue.flatMap(MenuBarDisplayMode.init(rawValue:)) ?? .standard
    }
}

struct MenuBarPresentation: Equatable, Sendable {
    let mode: MenuBarDisplayMode
    let availability: UsageAvailability
    let displayText: String
    let labelWidth: CGFloat
    let showsStaleWarning: Bool
    let tooltip: String
    let accessibilityLabel: String
}

enum MenuBarPresentationBuilder {
    private static let compactWidth: CGFloat = 44
    private static let standardShortTimeWidth: CGFloat = 82
    private static let standardLongTimeWidth: CGFloat = 104

    static func build(
        snapshot: RateLimitSnapshot?,
        availability: UsageAvailability,
        mode: MenuBarDisplayMode,
        localization: AppLocalization,
        resetTextProvider: (RateLimitWindow) -> String = UsageFormatting.resetText
    ) -> MenuBarPresentation {
        let isStale = availability.isStale
        let percentageText: String
        let resetTimeText: String?

        if let window = snapshot?.menuBarWindow {
            percentageText = "\(window.remainingPercent)%"
            resetTimeText = mode == .standard ? resetTextProvider(window) : nil
        } else {
            percentageText = "--%"
            resetTimeText = mode == .standard ? "--" : nil
        }

        let description: String
        switch availability {
        case .availableFresh, .availableStale:
            description = localization.menuBarDescription(
                percentage: percentageText,
                resetTime: resetTimeText,
                isStale: isStale
            )
        case .loading, .notLoggedIn, .executableNotFound, .incompatible, .responseChanged,
             .temporarilyUnavailable:
            description = localization.availabilityMessage(availability)
        }

        return MenuBarPresentation(
            mode: mode,
            availability: availability,
            displayText: displayText(
                percentage: percentageText,
                resetTime: resetTimeText,
                isStale: isStale,
                mode: mode
            ),
            labelWidth: labelWidth(mode: mode, resetTime: resetTimeText),
            showsStaleWarning: isStale,
            tooltip: description,
            accessibilityLabel: description
        )
    }

    private static func displayText(
        percentage: String,
        resetTime: String?,
        isStale: Bool,
        mode: MenuBarDisplayMode
    ) -> String {
        let warning = isStale ? " !" : ""

        guard mode == .standard else {
            return "\(percentage)\(warning)"
        }

        return "\(percentage) \(resetTime ?? "--")\(warning)"
    }

    private static func labelWidth(
        mode: MenuBarDisplayMode,
        resetTime: String?
    ) -> CGFloat {
        guard mode == .standard else {
            return compactWidth
        }
        return (resetTime?.count ?? 0) > 5
            ? standardLongTimeWidth
            : standardShortTimeWidth
    }
}
