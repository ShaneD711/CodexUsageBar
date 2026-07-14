import Foundation

enum AppServerPhase: String, Equatable, Sendable {
    case launch
    case initialize
    case account
    case rateLimits = "rate-limits"
}

enum ResponseChangeReason: String, Error, Equatable, Sendable {
    case malformedEnvelope = "malformed-envelope"
    case missingResult = "missing-result"
    case missingCodexLimits = "missing-codex-limits"
    case ambiguousCodexLimits = "ambiguous-codex-limits"
    case missingCriticalField = "missing-critical-field"
    case invalidCriticalType = "invalid-critical-type"
    case invalidCriticalValue = "invalid-critical-value"
    case noUsableWindow = "no-usable-window"

    fileprivate var priority: Int {
        switch self {
        case .malformedEnvelope: 0
        case .missingResult: 1
        case .missingCodexLimits: 2
        case .ambiguousCodexLimits: 3
        case .noUsableWindow: 4
        case .missingCriticalField: 5
        case .invalidCriticalType: 6
        case .invalidCriticalValue: 7
        }
    }
}

enum CodexAppServerError: Error, Equatable, Sendable {
    case executableNotFound
    case launchFailed
    case notLoggedIn
    case timedOut(phase: AppServerPhase)
    case connectionClosed(phase: AppServerPhase)
    case incompatible(code: Int, phase: AppServerPhase)
    case responseChanged(phase: AppServerPhase, reason: ResponseChangeReason)
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

            let object: [String: Any]
            do {
                guard let parsed = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                    throw changed(phase, .malformedEnvelope)
                }
                object = parsed
            } catch let error as CodexAppServerError {
                throw error
            } catch {
                throw changed(phase, .malformedEnvelope)
            }

            guard object.keys.contains("id") else {
                guard object["method"] is String else {
                    throw changed(phase, .malformedEnvelope)
                }
                continue
            }

            guard let responseID = strictInteger(object["id"]) else {
                throw changed(phase, .malformedEnvelope)
            }

            let hasResult = object.keys.contains("result")
            let hasError = object.keys.contains("error")
            guard hasResult != hasError else {
                throw changed(phase, .malformedEnvelope)
            }

            if hasError {
                guard
                    let error = object["error"] as? [String: Any],
                    let code = strictInteger(error["code"])
                else {
                    throw changed(phase, .malformedEnvelope)
                }

                guard responseID == id else { continue }
                if code == -32601 || code == -32602 {
                    throw CodexAppServerError.incompatible(code: code, phase: phase)
                }
                throw CodexAppServerError.server(code: code, phase: phase)
            }

            guard responseID == id else { continue }
            return line
        }
    }

    private static func changed(
        _ phase: AppServerPhase,
        _ reason: ResponseChangeReason
    ) -> CodexAppServerError {
        .responseChanged(phase: phase, reason: reason)
    }

    private static func strictInteger(_ value: Any?) -> Int? {
        guard let value, !isBoolean(value), let number = value as? NSNumber else {
            return nil
        }
        let decimal = number.decimalValue
        guard decimal.isFiniteInteger,
              decimal >= Decimal(Int.min),
              decimal <= Decimal(Int.max) else {
            return nil
        }
        return NSDecimalNumber(decimal: decimal).intValue
    }
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
            let envelope = try JSONObject.parse(data, phase: .account)
            guard envelope.keys.contains("result"), !(envelope["result"] is NSNull) else {
                throw changed(.missingResult)
            }
            guard let result = envelope["result"] as? [String: Any] else {
                throw changed(.invalidCriticalType)
            }

            if let account = result["account"], !(account is NSNull) {
                guard account is [String: Any] else {
                    throw changed(.invalidCriticalType)
                }
                return
            }

            guard result.keys.contains("requiresOpenaiAuth") else {
                throw changed(.missingCriticalField)
            }
            guard let authValue = result["requiresOpenaiAuth"],
                  isBoolean(authValue),
                  let requiresOpenaiAuth = authValue as? Bool else {
                throw changed(.invalidCriticalType)
            }
            if requiresOpenaiAuth {
                throw CodexAppServerError.notLoggedIn
            }
        } catch let error as CodexAppServerError {
            throw error
        } catch {
            throw changed(.malformedEnvelope)
        }
    }

    private static func changed(_ reason: ResponseChangeReason) -> CodexAppServerError {
        .responseChanged(phase: .account, reason: reason)
    }
}

enum RateLimitResponseParser {
    static func parse(_ data: Data, now: Date = Date()) throws -> RateLimitSnapshot {
        do {
            let envelope = try JSONObject.parse(data, phase: .rateLimits)
            guard envelope.keys.contains("result"), !(envelope["result"] is NSNull) else {
                throw changed(.missingResult)
            }
            guard let result = envelope["result"] as? [String: Any] else {
                throw changed(.invalidCriticalType)
            }

            let limits = try selectLimits(in: result)
            let parsedWindows = try parseWindows(in: limits)
            guard let first = parsedWindows.first else {
                throw changed(.noUsableWindow)
            }

            let snapshot = RateLimitSnapshot(
                primary: first,
                secondary: parsedWindows.dropFirst().first,
                fetchedAt: now
            )
            guard snapshot.isSemanticallyValid else {
                throw changed(.invalidCriticalValue)
            }
            return snapshot
        } catch let error as CodexAppServerError {
            throw error
        } catch {
            throw changed(.malformedEnvelope)
        }
    }

    private static func selectLimits(in result: [String: Any]) throws -> [String: Any] {
        if let mappedValue = result["rateLimitsByLimitId"], !(mappedValue is NSNull) {
            guard let mapped = mappedValue as? [String: Any] else {
                throw changed(.invalidCriticalType)
            }

            if mapped.keys.contains("codex") {
                guard let exact = mapped["codex"] as? [String: Any] else {
                    throw changed(.invalidCriticalType)
                }
                return exact
            }

            let internalMatches = mapped.values.compactMap { value -> [String: Any]? in
                guard let candidate = value as? [String: Any],
                      let limitID = candidate["limitId"] as? String,
                      limitID == "codex" else {
                    return nil
                }
                return candidate
            }

            if internalMatches.count > 1 {
                throw changed(.ambiguousCodexLimits)
            }
            if let internalMatch = internalMatches.first {
                return internalMatch
            }
        }

        guard result.keys.contains("rateLimits"), !(result["rateLimits"] is NSNull) else {
            throw changed(.missingCodexLimits)
        }
        guard let fallback = result["rateLimits"] as? [String: Any] else {
            throw changed(.invalidCriticalType)
        }
        return fallback
    }

    private static func parseWindows(in limits: [String: Any]) throws -> [RateLimitWindow] {
        var foundTransportWindow = false
        var windows: [RateLimitWindow] = []
        var reasons: [ResponseChangeReason] = []

        for name in ["primary", "secondary"] {
            guard limits.keys.contains(name), let value = limits[name], !(value is NSNull) else {
                continue
            }

            foundTransportWindow = true
            guard let object = value as? [String: Any] else {
                reasons.append(.invalidCriticalType)
                continue
            }

            switch parseWindow(object) {
            case .success(let window):
                windows.append(window)
            case .failure(let reason):
                reasons.append(reason)
            }
        }

        guard foundTransportWindow else {
            throw changed(.noUsableWindow)
        }
        if let reason = reasons.min(by: { $0.priority < $1.priority }) {
            throw changed(reason)
        }
        return windows
    }

    private static func parseWindow(
        _ object: [String: Any]
    ) -> Result<RateLimitWindow, ResponseChangeReason> {
        var reasons: [ResponseChangeReason] = []

        let usedPercent = capture(reasons: &reasons) {
            let value = try scalar(named: "usedPercent", in: object).finiteDouble()
            guard value >= 0 else { throw ResponseChangeReason.invalidCriticalValue }
            return value
        }
        let durationMinutes = capture(reasons: &reasons) {
            try scalar(named: "windowDurationMins", in: object).positiveInteger()
        }
        let resetTimestamp = capture(reasons: &reasons) {
            let value = try scalar(named: "resetsAt", in: object).positiveInteger()
            guard Double(value) <= Date.distantFuture.timeIntervalSince1970 else {
                throw ResponseChangeReason.invalidCriticalValue
            }
            return value
        }

        if let reason = reasons.min(by: { $0.priority < $1.priority }) {
            return .failure(reason)
        }

        guard let usedPercent, let durationMinutes, let resetTimestamp else {
            return .failure(.invalidCriticalValue)
        }
        return .success(
            RateLimitWindow(
                usedPercent: usedPercent,
                durationMinutes: durationMinutes,
                resetsAt: Date(timeIntervalSince1970: TimeInterval(resetTimestamp))
            )
        )
    }

    private static func scalar(named name: String, in object: [String: Any]) throws -> ExactJSONNumber {
        guard object.keys.contains(name) else {
            throw ResponseChangeReason.missingCriticalField
        }
        guard let value = object[name], !(value is NSNull) else {
            throw ResponseChangeReason.invalidCriticalType
        }
        guard !isBoolean(value), value is NSNumber || value is String else {
            throw ResponseChangeReason.invalidCriticalType
        }
        guard let number = ExactJSONNumber(value) else {
            throw ResponseChangeReason.invalidCriticalValue
        }
        return number
    }

    private static func capture<T>(
        reasons: inout [ResponseChangeReason],
        _ operation: () throws -> T
    ) -> T? {
        do {
            return try operation()
        } catch let reason as ResponseChangeReason {
            reasons.append(reason)
            return nil
        } catch {
            reasons.append(.invalidCriticalValue)
            return nil
        }
    }

    private static func changed(_ reason: ResponseChangeReason) -> CodexAppServerError {
        .responseChanged(phase: .rateLimits, reason: reason)
    }
}

private enum JSONObject {
    static func parse(_ data: Data, phase: AppServerPhase) throws -> [String: Any] {
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CodexAppServerError.responseChanged(phase: phase, reason: .malformedEnvelope)
            }
            return object
        } catch let error as CodexAppServerError {
            throw error
        } catch {
            throw CodexAppServerError.responseChanged(phase: phase, reason: .malformedEnvelope)
        }
    }
}

private struct ExactJSONNumber {
    private static let syntax = try! NSRegularExpression(
        pattern: #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#
    )

    let decimal: Decimal

    init?(_ value: Any) {
        let text: String
        if let string = value as? String {
            text = string
        } else if let number = value as? NSNumber, !isBoolean(number) {
            text = number.stringValue
        } else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard Self.syntax.firstMatch(in: text, range: range)?.range == range,
              let decimal = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        self.decimal = decimal
    }

    func finiteDouble() throws -> Double {
        let value = NSDecimalNumber(decimal: decimal).doubleValue
        guard value.isFinite else {
            throw ResponseChangeReason.invalidCriticalValue
        }
        return value
    }

    func positiveInteger() throws -> Int {
        guard decimal.isFiniteInteger,
              decimal > 0,
              decimal <= Decimal(Int.max) else {
            throw ResponseChangeReason.invalidCriticalValue
        }
        return NSDecimalNumber(decimal: decimal).intValue
    }
}

private extension Decimal {
    var isFiniteInteger: Bool {
        guard !isNaN else { return false }
        var source = self
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return rounded == self
    }
}

private func isBoolean(_ value: Any) -> Bool {
    guard let number = value as? NSNumber else { return false }
    return CFGetTypeID(number) == CFBooleanGetTypeID()
}
