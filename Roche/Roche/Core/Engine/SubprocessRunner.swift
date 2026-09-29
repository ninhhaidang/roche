import Foundation

public struct SubprocessOutput: Sendable, Equatable {
    public let stdoutData: Data
    public let stderrData: Data
    public let exitCode: Int32

    public init(stdoutData: Data, stderrData: Data, exitCode: Int32) {
        self.stdoutData = stdoutData
        self.stderrData = stderrData
        self.exitCode = exitCode
    }

    public var stdoutString: String {
        String(data: stdoutData, encoding: .utf8) ?? ""
    }

    public var stderrString: String {
        String(data: stderrData, encoding: .utf8) ?? ""
    }
}

public protocol SubprocessRunning: Sendable {
    func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval
    ) async throws -> SubprocessOutput

    func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        onSpawn: (@Sendable (pid_t) -> Void)?
    ) async throws -> SubprocessOutput
}

extension SubprocessRunning {
    public func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval
    ) async throws -> SubprocessOutput {
        try await execute(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            onSpawn: nil
        )
    }
}

public final nonisolated class SubprocessRunner: SubprocessRunning {
    private enum StreamPiece: Sendable {
        case stdout(Data)
        case stderr(Data)
        case exit(Int32)
    }

    public init() {}

    public func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60.0
    ) async throws -> SubprocessOutput {
        try await execute(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            onSpawn: nil
        )
    }

    public func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60.0,
        onSpawn: (@Sendable (pid_t) -> Void)? = nil
    ) async throws -> SubprocessOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let environment = environment {
            process.environment = environment
        }

        do {
            try process.run()
        } catch {
            throw MoleError.processExecutionFailed(exitCode: -1, stderr: error.localizedDescription)
        }

        onSpawn?(process.processIdentifier)

        let terminateProcess: @Sendable () -> Void = {
            if process.isRunning {
                process.terminate()
            }
        }

        do {
            return try await withTaskCancellationHandler {
                try await withThrowingTaskGroup(of: StreamPiece.self) { group in
                    // Timeout watchdog
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        terminateProcess()
                        throw MoleError.timeout
                    }

                    // Stdout concurrent drain
                    group.addTask {
                        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                        return .stdout(data)
                    }

                    // Stderr concurrent drain
                    group.addTask {
                        let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        return .stderr(data)
                    }

                    // Process exit observer
                    group.addTask {
                        process.waitUntilExit()
                        return .exit(process.terminationStatus)
                    }

                    var stdoutData: Data?
                    var stderrData: Data?
                    var exitCode: Int32?

                    while let piece = try await group.next() {
                        switch piece {
                        case .stdout(let data):
                            stdoutData = data
                        case .stderr(let data):
                            stderrData = data
                        case .exit(let code):
                            exitCode = code
                        }

                        if stdoutData != nil && stderrData != nil && exitCode != nil {
                            group.cancelAll()
                            break
                        }
                    }
                    try Task.checkCancellation()

                    return SubprocessOutput(
                        stdoutData: stdoutData ?? Data(),
                        stderrData: stderrData ?? Data(),
                        exitCode: exitCode ?? process.terminationStatus
                    )
                }
            } onCancel: {
                terminateProcess()
            }
        } catch {
            terminateProcess()
            throw error
        }
    }
}
