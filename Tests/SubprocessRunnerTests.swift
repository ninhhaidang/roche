import Foundation

private final class PidBox: @unchecked Sendable {
    var pid: pid_t = 0
}

func testConcurrentDrainingDoesNotDeadlock() async throws {
    let runner = SubprocessRunner()
    let script = "import sys; sys.stderr.write('E' * 100000); sys.stderr.flush(); sys.stdout.write('O' * 100000)"
    let output = try await runner.execute(
        executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
        arguments: ["-c", script],
        environment: nil,
        timeout: 5.0
    )

    assert(output.exitCode == 0, "Exit code should be 0")
    assert(output.stdoutData.count == 100000, "Stdout should have 100,000 bytes")
    assert(output.stderrData.count == 100000, "Stderr should have 100,000 bytes")
    print("✓ testConcurrentDrainingDoesNotDeadlock passed")
}
func testProcessTerminationOnTimeout() async throws {
    let runner = SubprocessRunner()
    let start = Date()
    let box = PidBox()
    do {
        _ = try await runner.execute(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["30"],
            timeout: 0.3,
            onSpawn: { pid in box.pid = pid }
        )
        assertionFailure("Expected MoleError.timeout to be thrown")
    } catch let error as MoleError {
        let elapsed = Date().timeIntervalSince(start)
        assert(error == .timeout, "Error should be .timeout")
        assert(elapsed < 2.0, "Should terminate swiftly on timeout, took \(elapsed)s")
        assert(box.pid > 0, "Process PID must have been captured")
        assert(Darwin.kill(box.pid, 0) == -1, "Child process must be terminated in OS")
        print("✓ testProcessTerminationOnTimeout passed in \(String(format: "%.2f", elapsed))s (child PID \(box.pid) dead)")
    } catch {
        assertionFailure("Unexpected error type: \(error)")
    }
}

func testProcessTerminationOnTaskCancellation() async throws {
    let runner = SubprocessRunner()
    let start = Date()
    let box = PidBox()

    let task = Task {
        try await runner.execute(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["30"],
            timeout: 30.0,
            onSpawn: { pid in box.pid = pid }
        )
    }
    // Cancel after 150ms
    _ = Task {
        try? await Task.sleep(nanoseconds: 150_000_000)
        task.cancel()
    }

    do {
        _ = try await task.value
        assertionFailure("Expected task to be cancelled")
    } catch is CancellationError {
        let elapsed = Date().timeIntervalSince(start)
        assert(elapsed < 2.0, "Should cancel promptly, took \(elapsed)s")
        assert(box.pid > 0, "Process PID must have been captured")
        assert(Darwin.kill(box.pid, 0) == -1, "Child process must be terminated in OS upon cancellation")
        print("✓ testProcessTerminationOnTaskCancellation passed in \(String(format: "%.2f", elapsed))s (child PID \(box.pid) dead)")
    } catch {
        assertionFailure("Expected CancellationError, got \(error)")
    }
}

func runSubprocessRunnerTests() async throws {
    try await testConcurrentDrainingDoesNotDeadlock()
    try await testProcessTerminationOnTimeout()
    try await testProcessTerminationOnTaskCancellation()
    print("All SubprocessRunner tests passed.")
}
