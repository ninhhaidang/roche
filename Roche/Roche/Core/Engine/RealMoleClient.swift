import Foundation

public final nonisolated class RealMoleClient: MoleClientProtocol, Sendable {
    private let finder: MoleExecutableFinder
    private let timeoutSeconds: TimeInterval

    public init(
        finder: MoleExecutableFinder = MoleExecutableFinder(),
        timeoutSeconds: TimeInterval = 10.0
    ) {
        self.finder = finder
        self.timeoutSeconds = timeoutSeconds
    }

    public func fetchMetrics() async throws -> MetricsSnapshot {
        guard let target = finder.findStatusExecutable() else {
            throw MoleError.executableNotFound
        }

        return try await runCommand(target: target)
    }

    private func runCommand(target: ExecutableTarget) async throws -> MetricsSnapshot {
        try await withThrowingTaskGroup(of: MetricsSnapshot.self) { group in
            group.addTask {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = target.url
                process.arguments = target.arguments
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                // Add standard environment variables
                var environment = Foundation.ProcessInfo.processInfo.environment
                environment["LC_ALL"] = "en_US.UTF-8"
                environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
                process.environment = environment

                do {
                    try process.run()
                } catch {
                    throw MoleError.processExecutionFailed(exitCode: -1, stderr: error.localizedDescription)
                }

                let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    let stderr = String(data: errorData, encoding: .utf8) ?? "Unknown process error"
                    throw MoleError.processExecutionFailed(exitCode: process.terminationStatus, stderr: stderr)
                }

                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(MetricsSnapshot.self, from: outputData)
                } catch {
                    let jsonPreview = String(data: outputData.prefix(200), encoding: .utf8) ?? ""
                    throw MoleError.decodingFailed("\(error.localizedDescription) | Raw: \(jsonPreview)")
                }
            }

            // Timeout watchdog
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeoutSeconds * 1_000_000_000))
                throw MoleError.timeout
            }

            guard let result = try await group.next() else {
                throw MoleError.timeout
            }
            group.cancelAll()
            return result
        }
    }
}
