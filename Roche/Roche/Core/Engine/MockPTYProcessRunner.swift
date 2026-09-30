import Foundation

/// In-memory mock for `PTYProcessRunning` to support previewing and unit testing.
public final class MockPTYProcessRunner: PTYProcessRunning, @unchecked Sendable {
    public struct PTYExecutionRecord: Sendable, Equatable {
        public let executableURL: URL
        public let arguments: [String]
        public let environment: [String: String]?
        public let timeout: TimeInterval
        public let inputData: Data?

        public init(
            executableURL: URL,
            arguments: [String],
            environment: [String: String]?,
            timeout: TimeInterval,
            inputData: Data?
        ) {
            self.executableURL = executableURL
            self.arguments = arguments
            self.environment = environment
            self.timeout = timeout
            self.inputData = inputData
        }
    }

    public var stubbedOutput: SubprocessOutput
    public var stubbedStreamEvents: [String]
    public var shouldThrowError: Error?
    public var delay: TimeInterval
    public var mockPID: pid_t
    public private(set) var recordedExecutions: [PTYExecutionRecord] = []
    public var onExecute: (@Sendable (PTYExecutionRecord) async throws -> SubprocessOutput)?

    public init(
        stubbedOutput: SubprocessOutput = SubprocessOutput(stdoutData: Data(), stderrData: Data(), exitCode: 0),
        stubbedStreamEvents: [String] = [],
        shouldThrowError: Error? = nil,
        delay: TimeInterval = 0.0,
        mockPID: pid_t = 12345
    ) {
        self.stubbedOutput = stubbedOutput
        self.stubbedStreamEvents = stubbedStreamEvents
        self.shouldThrowError = shouldThrowError
        self.delay = delay
        self.mockPID = mockPID
    }

    public func reset() {
        recordedExecutions.removeAll()
    }

    public func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        inputData: Data?,
        onSpawn: (@Sendable (pid_t) -> Void)?,
        onOutputChunk: (@Sendable (Data) -> Void)?
    ) async throws -> SubprocessOutput {
        let record = PTYExecutionRecord(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            inputData: inputData
        )
        recordedExecutions.append(record)

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if let error = shouldThrowError {
            throw error
        }

        onSpawn?(mockPID)

        if let onExecute = onExecute {
            let result = try await onExecute(record)
            if !result.stdoutData.isEmpty {
                onOutputChunk?(result.stdoutData)
            }
            return result
        }

        if !stubbedOutput.stdoutData.isEmpty {
            onOutputChunk?(stubbedOutput.stdoutData)
        }

        return stubbedOutput
    }

    public func stream(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        onSpawn: (@Sendable (pid_t) -> Void)?
    ) -> AsyncThrowingStream<String, Error> {
        let record = PTYExecutionRecord(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            inputData: nil
        )
        recordedExecutions.append(record)

        return AsyncThrowingStream { continuation in
            let events = self.stubbedStreamEvents
            let error = self.shouldThrowError
            let delay = self.delay
            let pid = self.mockPID

            let task = Task {
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }

                onSpawn?(pid)

                for event in events {
                    try Task.checkCancellation()
                    continuation.yield(event)
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
