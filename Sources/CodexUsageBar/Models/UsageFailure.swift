import Foundation

struct UsageFailure: Equatable, Sendable {
    enum Category: String, Equatable, Sendable {
        case executableNotFound = "executable-not-found"
        case notLoggedIn = "not-logged-in"
        case timedOut = "timed-out"
        case serviceStopped = "service-stopped"
        case unsupportedResponse = "unsupported-response"
        case launchFailed = "launch-failed"
        case server
    }

    let category: Category
    let phase: AppServerPhase?
    let serverCode: Int?

    init(_ error: Error) {
        guard let error = error as? CodexAppServerError else {
            category = .server
            phase = nil
            serverCode = nil
            return
        }

        switch error {
        case .executableNotFound:
            category = .executableNotFound
            phase = .launch
            serverCode = nil
        case .notLoggedIn:
            category = .notLoggedIn
            phase = .account
            serverCode = nil
        case .timedOut(let errorPhase):
            category = .timedOut
            phase = errorPhase
            serverCode = nil
        case .connectionClosed(let errorPhase):
            category = .serviceStopped
            phase = errorPhase
            serverCode = nil
        case .invalidResponse(let errorPhase):
            category = .unsupportedResponse
            phase = errorPhase
            serverCode = nil
        case .launchFailed:
            category = .launchFailed
            phase = .launch
            serverCode = nil
        case .server(let code, let errorPhase):
            category = .server
            phase = errorPhase
            serverCode = code
        }
    }
}
