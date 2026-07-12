import Foundation

enum UsageFailure: String, Equatable, Sendable {
    case executableNotFound = "executable-not-found"
    case notLoggedIn = "not-logged-in"
    case timedOut = "timed-out"
    case unsupportedResponse = "unsupported-response"
    case launchFailed = "launch-failed"
    case server

    init(_ error: Error) {
        guard let error = error as? CodexAppServerError else {
            self = .server
            return
        }

        switch error {
        case .executableNotFound:
            self = .executableNotFound
        case .notLoggedIn:
            self = .notLoggedIn
        case .timedOut:
            self = .timedOut
        case .invalidResponse:
            self = .unsupportedResponse
        case .launchFailed:
            self = .launchFailed
        case .server:
            self = .server
        }
    }
}
