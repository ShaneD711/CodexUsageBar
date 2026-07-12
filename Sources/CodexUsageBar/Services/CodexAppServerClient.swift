import Foundation

enum CodexAppServerError: Error, Sendable {
    case executableNotFound
    case launchFailed(String)
    case notLoggedIn
    case timedOut
    case invalidResponse
    case server(String)

}

struct CodexUsageReadResult: Sendable {
    let snapshot: RateLimitSnapshot
    let executable: ResolvedCodexExecutable
}

struct CodexAppServerClient: Sendable {
    func readSnapshot() async throws -> CodexUsageReadResult {
        try await Task.detached(priority: .utility) {
            try Self.readSnapshotSynchronously()
        }.value
    }

    private static func readSnapshotSynchronously() throws -> CodexUsageReadResult {
        guard let executable = CodexExecutableResolver.resolve() else {
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

        do {
            try process.run()
        } catch {
            throw CodexAppServerError.launchFailed(error.localizedDescription)
        }

        defer {
            try? standardInput.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
        }

        let reader = JSONLineReader(handle: standardOutput.fileHandleForReading)

        try write(
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

        _ = try readResponse(id: 1, reader: reader)

        try write(
            ["jsonrpc": "2.0", "method": "initialized", "params": [:]],
            to: standardInput.fileHandleForWriting
        )
        try write(
            ["jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read", "params": NSNull()],
            to: standardInput.fileHandleForWriting
        )

        let response = try readResponse(id: 2, reader: reader)
        return CodexUsageReadResult(
            snapshot: try RateLimitResponseParser.parse(response),
            executable: executable
        )
    }

    private static func write(_ object: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private static func readResponse(id: Int, reader: JSONLineReader) throws -> Data {
        while let line = try reader.nextLine() {
            guard
                let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                let responseID = object["id"] as? Int,
                responseID == id
            else {
                continue
            }

            if let error = object["error"] as? [String: Any] {
                let message = error["message"] as? String ?? ""
                let normalized = message.lowercased()
                if normalized.contains("login") || normalized.contains("auth") {
                    throw CodexAppServerError.notLoggedIn
                }
                throw CodexAppServerError.server(message)
            }

            return line
        }

        throw CodexAppServerError.invalidResponse
    }
}

private final class JSONLineReader {
    let handle: FileHandle
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

    func nextLine(timeout: TimeInterval = 15) throws -> Data? {
        let deadline = Date().addingTimeInterval(timeout)

        while true {
            if let line = takeLine() {
                return line
            }

            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                throw CodexAppServerError.timedOut
            }

            if dataAvailable.wait(timeout: .now() + remaining) == .timedOut {
                throw CodexAppServerError.timedOut
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

    private func takeLine() -> Data? {
        lock.lock()
        defer { lock.unlock() }

        if let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newlineIndex])
            buffer.removeSubrange(...newlineIndex)
            return line.isEmpty ? takeLineLocked() : line
        }

        if reachedEnd, !buffer.isEmpty {
            defer { buffer.removeAll() }
            return buffer
        }

        return nil
    }

    private func takeLineLocked() -> Data? {
        guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
            return nil
        }
        let line = Data(buffer[..<newlineIndex])
        buffer.removeSubrange(...newlineIndex)
        return line.isEmpty ? takeLineLocked() : line
    }
}

enum RateLimitResponseParser {
    static func parse(_ data: Data, now: Date = Date()) throws -> RateLimitSnapshot {
        let response = try JSONDecoder().decode(RPCResponse.self, from: data)
        guard let result = response.result else {
            throw CodexAppServerError.invalidResponse
        }

        let limits = result.rateLimitsByLimitId?["codex"] ?? result.rateLimits
        guard let primary = limits?.primary?.model else {
            throw CodexAppServerError.invalidResponse
        }

        return RateLimitSnapshot(
            primary: primary,
            secondary: limits?.secondary?.model,
            fetchedAt: now
        )
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
