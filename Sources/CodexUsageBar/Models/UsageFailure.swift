import Foundation

struct UsageFailure: Equatable, Sendable {
    enum Category: String, Equatable, Sendable {
        case executableNotFound = "executable-not-found"
        case notLoggedIn = "not-logged-in"
        case timedOut = "timed-out"
        case serviceStopped = "service-stopped"
        case incompatible
        case responseChanged = "response-changed"
        case launchFailed = "launch-failed"
        case server
    }

    let category: Category
    let phase: AppServerPhase?
    let serverCode: Int?
    let responseChangeReason: ResponseChangeReason?

    init(_ error: Error) {
        guard let error = error as? CodexAppServerError else {
            category = .server
            phase = nil
            serverCode = nil
            responseChangeReason = nil
            return
        }

        switch error {
        case .executableNotFound:
            category = .executableNotFound
            phase = .launch
            serverCode = nil
            responseChangeReason = nil
        case .notLoggedIn:
            category = .notLoggedIn
            phase = .account
            serverCode = nil
            responseChangeReason = nil
        case .timedOut(let errorPhase):
            category = .timedOut
            phase = errorPhase
            serverCode = nil
            responseChangeReason = nil
        case .connectionClosed(let errorPhase):
            category = .serviceStopped
            phase = errorPhase
            serverCode = nil
            responseChangeReason = nil
        case .incompatible(let code, let errorPhase):
            category = .incompatible
            phase = errorPhase
            serverCode = code
            responseChangeReason = nil
        case .responseChanged(let errorPhase, let reason):
            category = .responseChanged
            phase = errorPhase
            serverCode = nil
            responseChangeReason = reason
        case .launchFailed:
            category = .launchFailed
            phase = .launch
            serverCode = nil
            responseChangeReason = nil
        case .server(let code, let errorPhase):
            category = .server
            phase = errorPhase
            serverCode = code
            responseChangeReason = nil
        }
    }
}
