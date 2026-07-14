import Foundation

enum UsageAvailability: String, Equatable, Sendable {
    case loading
    case availableFresh = "available-fresh"
    case availableStale = "available-stale"
    case notLoggedIn = "not-logged-in"
    case executableNotFound = "executable-not-found"
    case incompatible
    case responseChanged = "response-changed"
    case temporarilyUnavailable = "temporarily-unavailable"

    var isStale: Bool {
        self == .availableStale
    }

    static func resolve(
        hasSnapshot: Bool,
        isSnapshotStale: Bool,
        isRefreshing: Bool,
        lastFailure: UsageFailure?
    ) -> UsageAvailability {
        if hasSnapshot {
            return isSnapshotStale ? .availableStale : .availableFresh
        }

        if isRefreshing || lastFailure == nil {
            return .loading
        }

        switch lastFailure?.category {
        case .notLoggedIn:
            return .notLoggedIn
        case .executableNotFound:
            return .executableNotFound
        case .incompatible:
            return .incompatible
        case .responseChanged:
            return .responseChanged
        case .timedOut, .serviceStopped, .launchFailed, .server, .none:
            return .temporarilyUnavailable
        }
    }
}
