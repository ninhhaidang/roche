import Foundation

private final class TestPidBox: @unchecked Sendable {
    var pid: pid_t = 0
}

func testPTYCreationAndStdoutCapture() async throws {
    let runner = PTYProcessRunner()
    let output = try await runner.execute(
        executableURL: URL(fileURLWithPath: "/bin/echo"),
        arguments: ["hello-from-pty"],
        environment: nil,
        timeout: 5.0
    )

    assert(output.exitCode == 0, "Exit code should be 0")
    let text = output.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
    assert(text == "hello-from-pty", "Stdout should capture 'hello-from-pty', got '\(text)'")
    print("✓ testPTYCreationAndStdoutCapture passed")
}

func testPTYExitCodeHandling() async throws {
    let runner = PTYProcessRunner()
    let output = try await runner.execute(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "exit 42"],
        environment: nil,
        timeout: 5.0
    )

    assert(output.exitCode == 42, "Exit code should be 42, got \(output.exitCode)")
    print("✓ testPTYExitCodeHandling passed")
}

func testPTYStreamingChunks() async throws {
    let runner = PTYProcessRunner()
    var receivedChunks: [String] = []

    let stream = runner.stream(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "echo line1; echo line2"],
        environment: nil,
        timeout: 5.0
    )

    for try await chunk in stream {
        receivedChunks.append(chunk)
    }

    let joined = receivedChunks.joined()
    assert(joined.contains("line1"), "Stream should contain line1")
    assert(joined.contains("line2"), "Stream should contain line2")
    print("✓ testPTYStreamingChunks passed")
}

func testPTYProcessTimeout() async throws {
    let runner = PTYProcessRunner()
    let start = Date()
    let box = TestPidBox()

    do {
        _ = try await runner.execute(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["30"],
            timeout: 0.25,
            onSpawn: { pid in box.pid = pid }
        )
        assertionFailure("Expected MoleError.timeout to be thrown")
    } catch let error as MoleError {
        let elapsed = Date().timeIntervalSince(start)
        assert(error == .timeout, "Error should be .timeout")
        assert(elapsed < 2.0, "Should terminate swiftly on timeout, took \(elapsed)s")
        assert(box.pid > 0, "Process PID must have been captured")
        assert(Darwin.kill(box.pid, 0) == -1, "Child process must be dead in OS")
        print("✓ testPTYProcessTimeout passed in \(String(format: "%.2f", elapsed))s (PID \(box.pid) terminated)")
    } catch {
        assertionFailure("Unexpected error type: \(error)")
    }
}

func testPTYProcessCancellation() async throws {
    let runner = PTYProcessRunner()
    let start = Date()
    let box = TestPidBox()

    let task = Task {
        try await runner.execute(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["30"],
            timeout: 30.0,
            onSpawn: { pid in box.pid = pid }
        )
    }

    _ = Task {
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
    }

    do {
        _ = try await task.value
        assertionFailure("Expected task to be cancelled")
    } catch is CancellationError {
        let elapsed = Date().timeIntervalSince(start)
        assert(elapsed < 2.0, "Should cancel promptly, took \(elapsed)s")
        assert(box.pid > 0, "Process PID must have been captured")
        assert(Darwin.kill(box.pid, 0) == -1, "Child process must be terminated upon cancellation")
        print("✓ testPTYProcessCancellation passed in \(String(format: "%.2f", elapsed))s (PID \(box.pid) dead)")
    } catch {
        assertionFailure("Expected CancellationError, got \(error)")
    }
}

func testPTYInputDataWriting() async throws {
    let runner = PTYProcessRunner()
    let input = Data("input-to-pty\n".utf8)

    let output = try await runner.execute(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "read input_line; echo \"received: $input_line\""],
        environment: nil,
        timeout: 5.0,
        inputData: input
    )

    assert(output.exitCode == 0, "Exit code should be 0")
    assert(output.stdoutString.contains("received: input-to-pty"), "Output should contain 'received: input-to-pty', got '\(output.stdoutString)'")
    print("✓ testPTYInputDataWriting passed")
}

func testMockPTYProcessRunner() async throws {
    let mock = MockPTYProcessRunner(
        stubbedOutput: SubprocessOutput(
            stdoutData: Data("mocked-output\n".utf8),
            stderrData: Data(),
            exitCode: 0
        ),
        stubbedStreamEvents: ["event1", "event2"]
    )

    let output = try await mock.execute(
        executableURL: URL(fileURLWithPath: "/usr/local/bin/mo"),
        arguments: ["optimize", "--dry-run"],
        environment: ["TEST": "1"],
        timeout: 10.0
    )

    assert(output.stdoutString == "mocked-output\n", "Mock should return stubbed output")
    assert(mock.recordedExecutions.count == 1, "Mock should record execution")
    assert(mock.recordedExecutions[0].arguments == ["optimize", "--dry-run"], "Arguments should match")

    var streamEvents: [String] = []
    for try await chunk in mock.stream(executableURL: URL(fileURLWithPath: "/test"), arguments: []) {
        streamEvents.append(chunk)
    }
    assert(streamEvents == ["event1", "event2"], "Stream should return stubbed stream events")
    print("✓ testMockPTYProcessRunner passed")
}

func runPTYProcessRunnerTests() async throws {
    try await testPTYCreationAndStdoutCapture()
    try await testPTYExitCodeHandling()
    try await testPTYStreamingChunks()
    try await testPTYProcessTimeout()
    try await testPTYProcessCancellation()
    try await testPTYInputDataWriting()
    try await testMockPTYProcessRunner()
    print("All PTYProcessRunner tests passed.")
}
