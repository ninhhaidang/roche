import Foundation

// MARK: - Mock Subprocess Runner for Execution Tests

private final class ExecutionMockRunner: SubprocessRunning, @unchecked Sendable {
    var capturedExecutableUrl: URL?
    var capturedArguments: [String] = []
    var capturedStdinData: Data?
    var stdoutResponse: String = ""
    var stderrResponse: String = ""
    var exitCodeResponse: Int32 = 0
    var executionCount: Int = 0

    init(
        stdoutResponse: String = "",
        stderrResponse: String = "",
        exitCodeResponse: Int32 = 0
    ) {
        self.stdoutResponse = stdoutResponse
        self.stderrResponse = stderrResponse
        self.exitCodeResponse = exitCodeResponse
    }

    func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        stdinData: Data?,
        onSpawn: (@Sendable (pid_t) -> Void)?
    ) async throws -> SubprocessOutput {
        self.capturedExecutableUrl = executableURL
        self.capturedArguments = arguments
        self.capturedStdinData = stdinData
        self.executionCount += 1

        return SubprocessOutput(
            stdoutData: stdoutResponse.data(using: .utf8) ?? Data(),
            stderrData: stderrResponse.data(using: .utf8) ?? Data(),
            exitCode: exitCodeResponse
        )
    }
}

// MARK: - Unit Tests

func testPerformUninstallDefaultTrashRouting() async throws {
    let mockOutput = """
    Files to be removed:
    ◎ Slack , 145.0MB
      ✓ /Applications/Slack.app
      ✓ ~/Library/Application Support/Slack

    Removed 1 app, freed 145.0MB
    """
    let runner = ExecutionMockRunner(stdoutResponse: mockOutput, exitCodeResponse: 0)
    let finder = MoleExecutableFinder()
    let engine = RealUninstallEngine(finder: finder, runner: runner)

    let app = InstalledApp(
        name: "Slack",
        bundleId: "com.tinyspeck.slackmacgap",
        source: "App",
        uninstallName: "slack",
        path: "/Applications/Slack.app",
        size: "145.0MB"
    )

    let result = try await engine.performUninstall(app: app, permanent: false)

    assert(result.appName == "Slack")
    assert(result.isPermanent == false, "Default uninstallation must route safely to macOS Trash")
    assert(result.success == true)
    assert(result.reclaimedBytes > 0)
    assert(result.errorMessage == nil)

    // Verify arguments do NOT include --permanent
    assert(!runner.capturedArguments.contains("--permanent"), "Trash uninstall must not contain --permanent")
    assert(runner.capturedArguments.contains("slack"), "Arguments must contain the target app name")
    assert(runner.capturedStdinData != nil, "performUninstall must send confirmation via stdin")

    print("✓ testPerformUninstallDefaultTrashRouting passed")
}

func testPerformUninstallPermanentFlag() async throws {
    let mockOutput = """
    Removed 1 app, freed 85.5MB
    """
    let runner = ExecutionMockRunner(stdoutResponse: mockOutput, exitCodeResponse: 0)
    let finder = MoleExecutableFinder()
    let engine = RealUninstallEngine(finder: finder, runner: runner)

    let app = InstalledApp(
        name: "Zoom",
        bundleId: "us.zoom.xos",
        source: "App",
        uninstallName: "zoom",
        path: "/Applications/zoom.us.app",
        size: "85.5MB"
    )

    let result = try await engine.performUninstall(app: app, permanent: true)

    assert(result.appName == "Zoom")
    assert(result.isPermanent == true, "Permanent uninstallation must flag isPermanent")
    assert(result.success == true)
    assert(result.reclaimedBytes > 0)

    // Verify arguments include --permanent
    assert(runner.capturedArguments.contains("--permanent"), "Permanent uninstall must include --permanent flag")
    assert(runner.capturedArguments.contains("zoom"))

    print("✓ testPerformUninstallPermanentFlag passed")
}

func testPerformUninstallErrorHandling() async throws {
    let runner = ExecutionMockRunner(
        stdoutResponse: "",
        stderrResponse: "Permission denied removing system directory",
        exitCodeResponse: 1
    )
    let finder = MoleExecutableFinder()
    let engine = RealUninstallEngine(finder: finder, runner: runner)

    let app = InstalledApp(
        name: "BrokenApp",
        bundleId: "com.broken.app",
        source: "App",
        uninstallName: "brokenapp",
        path: "/Applications/BrokenApp.app",
        size: "10.0MB"
    )

    do {
        _ = try await engine.performUninstall(app: app, permanent: false)
        assertionFailure("performUninstall must throw an error when runner exits non-zero")
    } catch MoleError.processExecutionFailed(let exitCode, let stderr) {
        assert(exitCode == 1)
        assert(stderr.contains("Permission denied"))
    } catch {
        assertionFailure("Unexpected error type: \(error)")
    }

    print("✓ testPerformUninstallErrorHandling passed")
}

func testUninstallResultModelCodableAndFormatting() throws {
    let result = UninstallResult(
        appName: "Ghostty",
        reclaimedBytes: 67_108_864, // 64 MB
        reclaimedFormatted: "64 MB",
        isPermanent: false,
        success: true,
        errorMessage: nil
    )

    assert(result.id == "Ghostty-false-true")
    assert(result.appName == "Ghostty")
    assert(result.reclaimedBytes == 67_108_864)
    assert(result.reclaimedFormatted == "64 MB")
    assert(result.isPermanent == false)
    assert(result.success == true)

    // Test Codable roundtrip
    let encoder = JSONEncoder()
    let data = try encoder.encode(result)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(UninstallResult.self, from: data)

    assert(decoded == result)

    print("✓ testUninstallResultModelCodableAndFormatting passed")
}

func testMockUninstallEnginePerformUninstall() async throws {
    let mock = MockUninstallEngine()
    let initialCount = mock.mockApps.count
    guard let targetApp = mock.mockApps.first else {
        assertionFailure("Mock engine must have default sample apps")
        return
    }

    let result = try await mock.performUninstall(app: targetApp, permanent: false)
    assert(result.appName == targetApp.name)
    assert(result.isPermanent == false)
    assert(result.success == true)
    assert(mock.mockApps.count == initialCount - 1, "App must be removed from mockApps list")
    assert(!mock.mockApps.contains(where: { $0.id == targetApp.id }))

    print("✓ testMockUninstallEnginePerformUninstall passed")
}

// MARK: - Test Suite Runner

func runUninstallEngineExecutionTests() async throws {
    try await testPerformUninstallDefaultTrashRouting()
    try await testPerformUninstallPermanentFlag()
    try await testPerformUninstallErrorHandling()
    try testUninstallResultModelCodableAndFormatting()
    try await testMockUninstallEnginePerformUninstall()
}
