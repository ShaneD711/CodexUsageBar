protocol CodexUsageReading: Sendable {
    func readSnapshot() async throws -> CodexUsageReadResult
}
