import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Protocol defining process execution within a pseudo-terminal (PTY) environment.
/// This enables interactive TTY emulation, PAM Touch ID authorization (via `pam_tid.so`),
/// and streaming I/O.
public protocol PTYProcessRunning: SubprocessRunning, Sendable {
    /// Executes a process connected to a pseudo-terminal master/slave pair.
    func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        inputData: Data?,
        onSpawn: (@Sendable (pid_t) -> Void)?,
        onOutputChunk: (@Sendable (Data) -> Void)?
    ) async throws -> SubprocessOutput

    /// Streams output chunks asynchronously from a process running in a PTY.
    func stream(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        onSpawn: (@Sendable (pid_t) -> Void)?
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Convenience Default Overloads

extension PTYProcessRunning {
    public func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60.0,
        inputData: Data? = nil,
        onSpawn: (@Sendable (pid_t) -> Void)? = nil,
        onOutputChunk: (@Sendable (Data) -> Void)? = nil
    ) async throws -> SubprocessOutput {
        try await execute(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            inputData: inputData,
            onSpawn: onSpawn,
            onOutputChunk: onOutputChunk
        )
    }

    public func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        onSpawn: (@Sendable (pid_t) -> Void)?
    ) async throws -> SubprocessOutput {
        try await execute(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            inputData: nil,
            onSpawn: onSpawn,
            onOutputChunk: nil
        )
    }

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
            inputData: nil,
            onSpawn: nil,
            onOutputChunk: nil
        )
    }

    public func stream(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60.0
    ) -> AsyncThrowingStream<String, Error> {
        stream(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            onSpawn: nil
        )
    }
}

// MARK: - Native PTY Process Runner Implementation

public final nonisolated class PTYProcessRunner: PTYProcessRunning {
    private enum StreamPiece: Sendable {
        case output(Data)
        case exit(Int32)
    }

    public init() {}

    public func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60.0,
        inputData: Data? = nil,
        onSpawn: (@Sendable (pid_t) -> Void)? = nil,
        onOutputChunk: (@Sendable (Data) -> Void)? = nil
    ) async throws -> SubprocessOutput {
        var masterFD: Int32 = 0
        var slaveFD: Int32 = 0

        guard openpty(&masterFD, &slaveFD, nil, nil, nil) == 0 else {
            let err = errno
            let errStr = String(cString: strerror(err))
            throw MoleError.processExecutionFailed(exitCode: -1, stderr: "Failed to allocate pseudo-terminal: \(errStr)")
        }

        // Set master FD to non-blocking mode
        let flags = fcntl(masterFD, F_GETFL, 0)
        if flags != -1 {
            _ = fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        var env = environment ?? ProcessInfo.processInfo.environment
        if env["TERM"] == nil {
            env["TERM"] = "xterm-256color"
        }
        process.environment = env

        do {
            try process.run()
        } catch {
            close(slaveFD)
            close(masterFD)
            throw MoleError.processExecutionFailed(exitCode: -1, stderr: error.localizedDescription)
        }

        // Immediately close parent's reference to slave FD so EOF triggers when child exits
        close(slaveFD)

        let pid = process.processIdentifier
        onSpawn?(pid)

        // Write initial standard input if provided
        if let inputData = inputData, !inputData.isEmpty {
            inputData.withUnsafeBytes { raw in
                if let ptr = raw.baseAddress {
                    _ = Darwin.write(masterFD, ptr, raw.count)
                }
            }
        }

        let terminateProcess: @Sendable () -> Void = {
            if process.isRunning {
                Darwin.kill(pid, SIGTERM)
                process.terminate()

                // If process doesn't exit after grace period, enforce SIGKILL
                Task.detached {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Darwin.kill(pid, 0) == 0 {
                        Darwin.kill(pid, SIGKILL)
                    }
                }
            }
        }

        do {
            return try await withTaskCancellationHandler {
                try await withThrowingTaskGroup(of: StreamPiece.self) { group in
                    // 1. Timeout watchdog
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        terminateProcess()
                        throw MoleError.timeout
                    }

                    // 2. Process exit observer
                    group.addTask {
                        process.waitUntilExit()
                        return .exit(process.terminationStatus)
                    }

                    // 3. Non-blocking asynchronous reader on master FD
                    group.addTask {
                        var accumulated = Data()
                        var buffer = [UInt8](repeating: 0, count: 4096)
                        defer {
                            close(masterFD)
                        }

                        while !Task.isCancelled {
                            var pfd = pollfd(fd: masterFD, events: Int16(POLLIN), revents: 0)
                            let pollResult = poll(&pfd, 1, 40)

                            if pollResult > 0 {
                                if (pfd.revents & Int16(POLLIN)) != 0 {
                                    let bytesRead = Darwin.read(masterFD, &buffer, buffer.count)
                                    if bytesRead > 0 {
                                        let chunk = Data(buffer[0..<bytesRead])
                                        accumulated.append(chunk)
                                        onOutputChunk?(chunk)
                                    } else if bytesRead == 0 {
                                        // Standard EOF
                                        break
                                    } else {
                                        let err = errno
                                        if err == EAGAIN || err == EWOULDBLOCK {
                                            continue
                                        }
                                        if err == EIO {
                                            // Slave descriptor was closed by child process
                                            break
                                        }
                                        break
                                    }
                                } else if (pfd.revents & (Int16(POLLHUP) | Int16(POLLERR))) != 0 {
                                    // Drain any final data before exiting
                                    let bytesRead = Darwin.read(masterFD, &buffer, buffer.count)
                                    if bytesRead > 0 {
                                        let chunk = Data(buffer[0..<bytesRead])
                                        accumulated.append(chunk)
                                        onOutputChunk?(chunk)
                                    }
                                    break
                                }
                            } else if pollResult == 0 {
                                // Poll timed out, check if process already exited
                                if !process.isRunning {
                                    while true {
                                        let bytesRead = Darwin.read(masterFD, &buffer, buffer.count)
                                        if bytesRead > 0 {
                                            let chunk = Data(buffer[0..<bytesRead])
                                            accumulated.append(chunk)
                                            onOutputChunk?(chunk)
                                        } else {
                                            break
                                        }
                                    }
                                    break
                                }
                            } else {
                                if errno == EINTR {
                                    continue
                                }
                                break
                            }
                        }

                        return .output(accumulated)
                    }

                    var outputData: Data?
                    var exitCode: Int32?

                    while let piece = try await group.next() {
                        switch piece {
                        case .output(let data):
                            outputData = data
                        case .exit(let code):
                            exitCode = code
                        }

                        if outputData != nil && exitCode != nil {
                            group.cancelAll()
                            break
                        }
                    }

                    try Task.checkCancellation()

                    return SubprocessOutput(
                        stdoutData: outputData ?? Data(),
                        stderrData: Data(),
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

    public func stream(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60.0,
        onSpawn: (@Sendable (pid_t) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    _ = try await execute(
                        executableURL: executableURL,
                        arguments: arguments,
                        environment: environment,
                        timeout: timeout,
                        inputData: nil,
                        onSpawn: onSpawn,
                        onOutputChunk: { chunk in
                            if let text = String(data: chunk, encoding: .utf8), !text.isEmpty {
                                continuation.yield(text)
                            }
                        }
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
