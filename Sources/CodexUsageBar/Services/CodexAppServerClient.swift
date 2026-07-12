import Foundation

enum AppServerPhase: String, Equatable, Sendable {
    case launch
    case initialize
    case account
    case rateLimits = "rate-limits"
}

enum CodexAppServerError: Error, Sendable {
    case executableNotFound
    case launchFailed
    case notLoggedIn
    case timedOut(phase: AppServerPhase)
    case connectionClosed(phase: AppServerPhase)
    case invalidResponse(phase: AppServerPhase)
    case server(code: Int?, phase: AppServerPhase)
}

struct CodexUsageReadResult: Sendable {
    let snapshot: RateLimitSnapshot
    let executable: ResolvedCodexExecutable
}

struct CodexAppServerClient: CodexUsageReading, Sendable {
    private let executableResolver: @Sendable () -> ResolvedCodexExecutable?
    private let requestTimeout: DispatchTimeInterval

    init(
        executableResolver: @escaping @Sendable () -> ResolvedCodexExecutable? = {
            CodexExecutableResolver.resolve()
        },
        requestTimeout: DispatchTimeInterval = .seconds(15)
    ) {
        self.executableResolver = executableResolver
        self.requestTimeout = requestTimeout
    }

    func readSnapshot() async throws -> CodexUsageReadResult {
        let processController = ProcessCancellationController()
        let operation = Task.detached(priority: .utility) {
            try readSnapshotSynchronously(processController: processController)
        }

        return try await withTaskCancellationHandler {
            try await operation.value
        } onCancel: {
            operation.cancel()
            processController.cancel()
        }
    }

    private func readSnapshotSynchronously(
        processController: ProcessCancellationController
    ) throws -> CodexUsageReadResult {
        guard let executable = executableResolver() else {
            throw CodexAppServerError.executableNotFound
        }

        let process = Process()
        let standardInput = Pipe()
        let standardOutput = Pipe()

        process.executableURL = executable.url
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = FileHandle.nullDevice
        processController.register(process)

        do {
            try processController.checkCancellation()
            try process.run()
            try processController.checkCancellationAfterLaunch()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CodexAppServerError.launchFailed
        }

        defer {
            try? standardInput.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
            processController.unregister(process)
        }

        do {
            let reader = JSONLineReader(handle: standardOutput.fileHandleForReading)
            let requestDeadline = DispatchTime.now() + requestTimeout

            try Self.write(
                [
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": [
                        "clientInfo": ["name": "codex-usage-bar", "version": AppSupport.version],
                        "capabilities": ["experimentalApi": true]
                    ]
                ],
                to: standardInput.fileHandleForWriting
            )

            _ = try Self.readResponse(
                id: 1,
                phase: .initialize,
                reader: reader,
                deadline: requestDeadline
            )

            try Self.write(
                ["jsonrpc": "2.0", "method": "initialized", "params": [:]],
                to: standardInput.fileHandleForWriting
            )
            try Self.write(
                [
                    "jsonrpc": "2.0",
                    "id": 2,
                    "method": "account/read",
                    "params": ["refreshToken": false]
                ],
                to: standardInput.fileHandleForWriting
            )

            let accountResponse = try Self.readResponse(
                id: 2,
                phase: .account,
                reader: reader,
                deadline: requestDeadline
            )
            try AccountResponseParser.validate(accountResponse)

            try Self.write(
                ["jsonrpc": "2.0", "id": 3, "method": "account/rateLimits/read", "params": NSNull()],
                to: standardInput.fileHandleForWriting
            )

            let response = try Self.readResponse(
                id: 3,
                phase: .rateLimits,
                reader: reader,
                deadline: requestDeadline
            )
            return CodexUsageReadResult(
                snapshot: try RateLimitResponseParser.parse(response),
                executable: executable
            )
        } catch {
            if processController.isCancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private static func write(_ object: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    static func readResponse(
        id: Int,
        phase: AppServerPhase,
        reader: any JSONLineReading,
        deadline: DispatchTime
    ) throws -> Data {
        while true {
            guard DispatchTime.now().uptimeNanoseconds < deadline.uptimeNanoseconds else {
                throw CodexAppServerError.timedOut(phase: phase)
            }

            let line: Data?
            do {
                line = try reader.nextLine(until: deadline)
            } catch JSONLineReaderError.timedOut {
                throw CodexAppServerError.timedOut(phase: phase)
            }

            guard let line else {
                throw CodexAppServerError.connectionClosed(phase: phase)
            }

            guard
                let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                let responseID = object["id"] as? Int,
                responseID == id
            else {
                continue
            }

            if object["error"] != nil {
                let envelope = try? JSONDecoder().decode(RPCErrorEnvelope.self, from: line)
                throw CodexAppServerError.server(code: envelope?.error?.code, phase: phase)
            }

            return line
        }
    }
}

private struct RPCErrorEnvelope: Decodable {
    let error: RPCErrorPayload?
}

private struct RPCErrorPayload: Decodable {
    let code: Int?
}

private final class ProcessCancellationController: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func register(_ process: Process) {
        let shouldTerminate = lock.withLock {
            self.process = process
            return cancelled
        }

        if shouldTerminate, process.isRunning {
            process.terminate()
        }
    }

    func unregister(_ process: Process) {
        lock.withLock {
            if self.process === process {
                self.process = nil
            }
        }
    }

    func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    func checkCancellationAfterLaunch() throws {
        guard isCancelled else { return }
        terminateIfRunning()
        throw CancellationError()
    }

    func cancel() {
        lock.withLock {
            cancelled = true
        }
        terminateIfRunning()
    }

    private func terminateIfRunning() {
        let process = lock.withLock { self.process }
        if let process, process.isRunning {
            process.terminate()
        }
    }
}

protocol JSONLineReading: AnyObject {
    func nextLine(until deadline: DispatchTime) throws -> Data?
}

enum JSONLineReaderError: Error {
    case timedOut
}

final class JSONLineReader: JSONLineReading {
    private enum ReadEvent {
        case line(Data)
        case waiting
        case endOfFile
    }

    private let handle: FileHandle
    private let lock = NSLock()
    private let dataAvailable = DispatchSemaphore(value: 0)
    private var buffer = Data()
    private var reachedEnd = false

    init(handle: FileHandle) {
        self.handle = handle
        handle.readabilityHandler = { [weak self] readableHandle in
            self?.append(readableHandle.availableData)
        }
    }

    deinit {
        handle.readabilityHandler = nil
    }

    func nextLine(until deadline: DispatchTime) throws -> Data? {
        while true {
            switch takeEvent() {
            case .line(let line) where line.isEmpty:
                continue
            case .line(let line):
                return line
            case .endOfFile:
                return nil
            case .waiting:
                if dataAvailable.wait(timeout: deadline) == .timedOut {
                    throw JSONLineReaderError.timedOut
                }
            }
        }
    }

    private func append(_ data: Data) {
        lock.lock()
        if data.isEmpty {
            reachedEnd = true
        } else {
            buffer.append(data)
        }
        lock.unlock()
        dataAvailable.signal()
    }

    private func takeEvent() -> ReadEvent {
        lock.lock()
        defer { lock.unlock() }

        if let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newlineIndex])
            buffer.removeSubrange(...newlineIndex)
            return .line(line)
        }

        if reachedEnd {
            guard !buffer.isEmpty else {
                return .endOfFile
            }

            let remaining = buffer
            buffer.removeAll()
            return .line(remaining)
        }

        return .waiting
    }
}

enum AccountResponseParser {
    static func validate(_ data: Data) throws {
        do {
            let response = try JSONDecoder().decode(AccountRPCResponse.self, from: data)
            guard let result = response.result else {
                throw CodexAppServerError.invalidResponse(phase: .account)
            }

            if result.requiresOpenaiAuth, result.account == nil {
                throw CodexAppServerError.notLoggedIn
            }
        } catch let error as CodexAppServerError {
            throw error
        } catch {
            throw CodexAppServerError.invalidResponse(phase: .account)
        }
    }
}

private struct AccountRPCResponse: Decodable {
    let result: AccountReadResult?
}

private struct AccountReadResult: Decodable {
    let account: AccountMarker?
    let requiresOpenaiAuth: Bool
}

private struct AccountMarker: Decodable {}

enum RateLimitResponseParser {
    static func parse(_ data: Data, now: Date = Date()) throws -> RateLimitSnapshot {
        do {
            let response = try JSONDecoder().decode(RPCResponse.self, from: data)
            guard let result = response.result else {
                throw CodexAppServerError.invalidResponse(phase: .rateLimits)
            }

            let limits = result.rateLimitsByLimitId?["codex"] ?? result.rateLimits
            guard let primary = limits?.primary?.model else {
                throw CodexAppServerError.invalidResponse(phase: .rateLimits)
            }

            return RateLimitSnapshot(
                primary: primary,
                secondary: limits?.secondary?.model,
                fetchedAt: now
            )
        } catch let error as CodexAppServerError {
            throw error
        } catch {
            throw CodexAppServerError.invalidResponse(phase: .rateLimits)
        }
    }
}

private struct RPCResponse: Decodable {
    let result: RateLimitReadResult?
}

private struct RateLimitReadResult: Decodable {
    let rateLimits: RateLimitSet?
    let rateLimitsByLimitId: [String: RateLimitSet]?
}

private struct RateLimitSet: Decodable {
    let primary: RateLimitWindowDTO?
    let secondary: RateLimitWindowDTO?
}

private struct RateLimitWindowDTO: Decodable {
    let usedPercent: Double?
    let windowDurationMins: Int?
    let resetsAt: Double?

    var model: RateLimitWindow? {
        guard
            let usedPercent,
            let windowDurationMins,
            let resetsAt
        else {
            return nil
        }

        return RateLimitWindow(
            usedPercent: usedPercent,
            durationMinutes: windowDurationMins,
            resetsAt: Date(timeIntervalSince1970: resetsAt)
        )
    }
}
