import Foundation

// MARK: - Mock Subprocess Runner for Uninstall Engine

private final class UninstallMockRunner: SubprocessRunning, @unchecked Sendable {
    var capturedExecutableUrl: URL?
    var capturedArguments: [String] = []
    var capturedStdinData: Data?
    var stdoutResponse: String = ""
    var exitCodeResponse: Int32 = 0

    init(stdoutResponse: String = "", exitCodeResponse: Int32 = 0) {
        self.stdoutResponse = stdoutResponse
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

        return SubprocessOutput(
            stdoutData: stdoutResponse.data(using: .utf8) ?? Data(),
            stderrData: Data(),
            exitCode: exitCodeResponse
        )
    }
}

// MARK: - Test Cases

func testInstalledAppsJsonDecodingWithFixture() throws {
    let fixture = """
    [
      {
        "name": "Docker",
        "bundle_id": "com.docker.docker",
        "source": "App",
        "uninstall_name": "Docker",
        "path": "/Applications/Docker.app",
        "size": "2.30GB"
      },
      {
        "name": "Visual Studio Code",
        "bundle_id": "com.microsoft.VSCode",
        "source": "App",
        "uninstall_name": "Code",
        "path": "/Applications/Visual Studio Code.app",
        "size": "898.0MB"
      },
      {
        "name": "Ghostty",
        "bundle_id": "com.mitchellh.ghostty",
        "source": "Homebrew",
        "uninstall_name": "ghostty",
        "path": "/Applications/Ghostty.app",
        "size": "65.0MB"
      }
    ]
    """

    guard let data = fixture.data(using: .utf8) else {
        fatalError("Failed to convert fixture to data")
    }

    let apps = try RealUninstallEngine.parseInstalledApps(from: data)
    assert(apps.count == 3, "Expected 3 apps, got \(apps.count)")

    let docker = apps[0]
    assert(docker.name == "Docker")
    assert(docker.bundleId == "com.docker.docker")
    assert(docker.source == "App")
    assert(docker.uninstallName == "Docker")
    assert(docker.path == "/Applications/Docker.app")
    assert(docker.size == "2.30GB")
    assert(docker.id == "com.docker.docker")
    assert(docker.sizeBytes > 2_000_000_000, "Docker sizeBytes should be > 2GB")
    assert(docker.iconName == "shippingbox.fill")

    let vscode = apps[1]
    assert(vscode.name == "Visual Studio Code")
    assert(vscode.uninstallName == "Code")
    assert(vscode.iconName == "chevron.left.forwardslash.chevron.right")

    let ghostty = apps[2]
    assert(ghostty.name == "Ghostty")
    assert(ghostty.source == "Homebrew")
    assert(ghostty.iconName == "terminal.fill")

    print("✓ testInstalledAppsJsonDecodingWithFixture passed")
}

func testInstalledAppsJsonDecodingWithAnsiAndNoise() throws {
    let noisyFixture = "\u{001B}[2J\u{001B}[H→ Scanning applications...\n" +
    """
    [
      {"name": "Tinycast", "bundle_id": "com.tinycast.app", "source": "App", "uninstall_name": "Tinycast", "path": "/Applications/Tinycast.app", "size": "13.9MB"}
    ]
    """ + "\n\u{001B}[0mDone.\n"

    guard let data = noisyFixture.data(using: .utf8) else {
        fatalError("Failed to convert noisy fixture to data")
    }

    let apps = try RealUninstallEngine.parseInstalledApps(from: data)
    assert(apps.count == 1, "Expected 1 app, got \(apps.count)")
    assert(apps[0].name == "Tinycast")
    assert(apps[0].bundleId == "com.tinycast.app")
    assert(apps[0].size == "13.9MB")
    print("✓ testInstalledAppsJsonDecodingWithAnsiAndNoise passed")
}

func testDryRunOutputResidualParsingWithMultiFiles() {
    let app = InstalledApp(
        name: "Visual Studio Code",
        bundleId: "com.microsoft.VSCode",
        source: "App",
        uninstallName: "Code",
        path: "/Applications/Visual Studio Code.app",
        size: "898.0MB"
    )

    let fixture = """
    \u{001B}[2J\u{001B}[H→ DRY RUN MODE, No app files or settings will be modified

    ◎ Matched 1 app(s):
    1. Code  898.0MB  |  Last: Today

    Proceed with uninstallation? [y/N]
    Files to be removed:

    ◎ Code , 1.74GB
      ✓ /Applications/Visual Studio Code.app , 898.0MB
      ✓ ~/Library/Caches/com.microsoft.VSCode , 283KB
      ✓ ~/Library/HTTPStorages/com.microsoft.VSCode , 82KB
      ✓ ~/Library/Preferences/com.microsoft.VSCode.plist , 4KB
      ✓ ~/Library/Preferences/ByHost/com.microsoft.VSCode.ShipIt.B8711B7E-5378-5306-8335-D0E258CE5386.plist , 4KB
      ✓ ~/Library/Caches/com.microsoft.VSCode.ShipIt , 16KB
      ✓ ~/.vscode , 600.7MB
      ✓ ~/Library/Application Support/Code , 237.1MB

    ➤ Remove 1 app, 1.74GB [Running]  Enter confirm, ESC cancel:
    """

    let preview = RealUninstallEngine.parseDryRunOutput(fixture, for: app)

    assert(preview.app.name == "Visual Studio Code")
    assert(preview.residuals.count == 8, "Expected 8 residuals, got \(preview.residuals.count)")

    // 1. Binary
    let binary = preview.residuals[0]
    assert(binary.path == "/Applications/Visual Studio Code.app")
    assert(binary.kind == .binary)
    assert(binary.sizeText == "898.0MB")
    assert(binary.isSelected == true)

    // 2. Cache
    let cacheItem = preview.residuals[1]
    assert(cacheItem.path == "~/Library/Caches/com.microsoft.VSCode")
    assert(cacheItem.kind == .cache)

    // 3. HTTPStorages (classified as cache)
    let httpStorage = preview.residuals[2]
    assert(httpStorage.path == "~/Library/HTTPStorages/com.microsoft.VSCode")
    assert(httpStorage.kind == .cache)

    // 4. Preferences plist
    let prefItem = preview.residuals[3]
    assert(prefItem.path == "~/Library/Preferences/com.microsoft.VSCode.plist")
    assert(prefItem.kind == .preferences)

    // 7. .vscode (classified as other)
    let dotVscode = preview.residuals[6]
    assert(dotVscode.path == "~/.vscode")
    assert(dotVscode.kind == .other)

    // 8. Application Support
    let appSupport = preview.residuals[7]
    assert(appSupport.path == "~/Library/Application Support/Code")
    assert(appSupport.kind == .applicationSupport)

    // Verify aggregate size calculation
    assert(preview.totalSizeBytes > 1_500_000_000, "Total size should be ~1.74GB")
    assert(preview.selectedSizeBytes == preview.totalSizeBytes, "All items selected by default")
    assert(preview.selectedItemCount == 8)

    print("✓ testDryRunOutputResidualParsingWithMultiFiles passed")
}

func testDryRunOutputResidualParsingWithSingleApp() {
    let app = InstalledApp(
        name: "Tinycast",
        bundleId: "com.tinycast.app",
        source: "App",
        uninstallName: "Tinycast",
        path: "/Applications/Tinycast.app",
        size: "13.9MB"
    )

    let fixture = """
    → DRY RUN MODE, No app files or settings will be modified

    ◎ Matched 1 app(s):
    1. Tinycast  13.9MB  |  Last: 1w ago

    Proceed with uninstallation? [y/N]
    Files to be removed:

    ◎ Tinycast , 13.9MB
      ✓ /Applications/Tinycast.app , 13.9MB

    ➤ Remove 1 app, 13.9MB  Enter confirm, ESC cancel:
    """

    let preview = RealUninstallEngine.parseDryRunOutput(fixture, for: app)

    assert(preview.residuals.count == 1)
    let item = preview.residuals[0]
    assert(item.path == "/Applications/Tinycast.app")
    assert(item.kind == .binary)
    assert(item.sizeText == "13.9MB")
    assert(preview.totalSizeBytes > 10_000_000)
    print("✓ testDryRunOutputResidualParsingWithSingleApp passed")
}

func testDryRunOutputWithSystemAndReviewOnlyTags() {
    let app = InstalledApp(
        name: "SomeApp",
        bundleId: "com.someapp",
        source: "App",
        uninstallName: "SomeApp",
        path: "/Applications/SomeApp.app",
        size: "80.0MB"
    )

    let fixture = """
    Files to be removed:

    ◎ SomeApp , 120.0MB
      ✓ /Applications/SomeApp.app , 80.0MB
      ✓ ~/Library/Caches/com.someapp , 30.0MB
      ✓ System: /Library/LaunchDaemons/com.someapp.helper.plist , 10KB
      ✓ Review only: /Library/Application Support/SomeApp , 10.0MB
    """

    let preview = RealUninstallEngine.parseDryRunOutput(fixture, for: app)

    assert(preview.residuals.count == 4, "Expected 4 residuals, got \(preview.residuals.count)")

    let systemItem = preview.residuals[2]
    assert(systemItem.path == "/Library/LaunchDaemons/com.someapp.helper.plist", "Prefix System: should be stripped from path")
    assert(systemItem.kind == .launchAgent)
    assert(systemItem.sizeText == "10KB")

    let reviewItem = preview.residuals[3]
    assert(reviewItem.path == "/Library/Application Support/SomeApp", "Prefix Review only: should be stripped from path")
    assert(reviewItem.kind == .applicationSupport)

    print("✓ testDryRunOutputWithSystemAndReviewOnlyTags passed")
}

func testClassifyKindAndDeriveTitle() {
    assert(RealUninstallEngine.classifyKind(path: "/Applications/Test.app") == .binary)
    assert(RealUninstallEngine.classifyKind(path: "~/Library/Caches/com.test") == .cache)
    assert(RealUninstallEngine.classifyKind(path: "~/Library/HTTPStorages/com.test") == .cache)
    assert(RealUninstallEngine.classifyKind(path: "~/Library/Preferences/com.test.plist") == .preferences)
    assert(RealUninstallEngine.classifyKind(path: "~/Library/LaunchAgents/com.test.agent.plist") == .launchAgent)
    assert(RealUninstallEngine.classifyKind(path: "/Library/LaunchDaemons/com.test.daemon.plist") == .launchAgent)
    assert(RealUninstallEngine.classifyKind(path: "~/Library/Application Support/TestApp") == .applicationSupport)
    assert(RealUninstallEngine.classifyKind(path: "~/Library/Containers/com.test.sandbox") == .containers)
    assert(RealUninstallEngine.classifyKind(path: "~/Library/Logs/TestApp.log") == .logs)
    assert(RealUninstallEngine.classifyKind(path: "~/.config/test") == .other)

    let binaryTitle = RealUninstallEngine.deriveTitle(path: "/Applications/Test.app", kind: .binary)
    assert(binaryTitle == "Test.app")

    let cacheTitle = RealUninstallEngine.deriveTitle(path: "~/Library/Caches/com.test", kind: .cache)
    assert(cacheTitle == "Cache (com.test)")

    print("✓ testClassifyKindAndDeriveTitle passed")
}

func testAppUninstallPreviewSelectionCalculations() {
    let app = InstalledApp(name: "Demo", uninstallName: "Demo", path: "/Applications/Demo.app", size: "100 MB")
    let item1 = AppResidualItem(title: "Demo.app", path: "/Applications/Demo.app", sizeText: "70 MB", sizeBytes: 70 * 1024 * 1024, kind: .binary, isSelected: true)
    let item2 = AppResidualItem(title: "Caches", path: "~/Library/Caches/Demo", sizeText: "30 MB", sizeBytes: 30 * 1024 * 1024, kind: .cache, isSelected: true)

    var preview = AppUninstallPreview(app: app, residuals: [item1, item2])
    assert(preview.selectedSizeBytes == 100 * 1024 * 1024)
    assert(preview.selectedItemCount == 2)

    // Deselect cache
    preview.residuals[1].isSelected = false
    assert(preview.selectedSizeBytes == 70 * 1024 * 1024)
    assert(preview.selectedItemCount == 1)

    // Deselect all
    preview.residuals[0].isSelected = false
    assert(preview.selectedSizeBytes == 0)
    assert(preview.selectedItemCount == 0)

    print("✓ testAppUninstallPreviewSelectionCalculations passed")
}

func testMockUninstallEngine() async throws {
    let mock = MockUninstallEngine()
    let apps = try await mock.listInstalledApps()
    assert(!apps.isEmpty, "Mock should return apps list")
    assert(apps.contains { $0.name == "Docker" })
    assert(apps.contains { $0.name == "Visual Studio Code" })

    let dockerApp = apps.first { $0.name == "Docker" }!
    let preview = try await mock.inspectApp(app: dockerApp)
    assert(preview.app.name == "Docker")
    assert(preview.residuals.count == 4)
    assert(preview.residuals.contains { $0.kind == .binary })
    assert(preview.residuals.contains { $0.kind == .cache })
    assert(preview.residuals.contains { $0.kind == .applicationSupport })
    assert(preview.residuals.contains { $0.kind == .launchAgent })

    print("✓ testMockUninstallEngine passed")
}

func testRealUninstallEngineWithMockRunner() async throws {
    let listJson = """
    [
      {"name": "Ghostty", "bundle_id": "com.mitchellh.ghostty", "source": "Homebrew", "uninstall_name": "ghostty", "path": "/Applications/Ghostty.app", "size": "65.0MB"}
    ]
    """

    let dryRunOutput = """
    Files to be removed:

    ◎ Ghostty , 65.0MB
      ✓ /Applications/Ghostty.app , 64.2MB
      ✓ ~/Library/Application Support/Ghostty , 800KB
    """

    let mockRunner = UninstallMockRunner(stdoutResponse: listJson, exitCodeResponse: 0)
    let finder = MoleExecutableFinder()
    let engine = RealUninstallEngine(finder: finder, runner: mockRunner)

    // 1. List apps
    let apps = try await engine.listInstalledApps()
    assert(apps.count == 1)
    assert(apps[0].name == "Ghostty")
    assert(mockRunner.capturedArguments.contains("--list"))

    // 2. Inspect app
    mockRunner.stdoutResponse = dryRunOutput
    let preview = try await engine.inspectApp(app: apps[0])
    assert(preview.residuals.count == 2)
    assert(mockRunner.capturedArguments.contains("--dry-run"))
    assert(mockRunner.capturedArguments.contains("ghostty"))
    assert(mockRunner.capturedStdinData != nil, "inspectApp must pass stdin confirmation data")

    print("✓ testRealUninstallEngineWithMockRunner passed")
}

func testRealUninstallEngineFallbackOnEmptyDryRun() async throws {
    let mockRunner = UninstallMockRunner(stdoutResponse: "", exitCodeResponse: 0)
    let engine = RealUninstallEngine(finder: MoleExecutableFinder(), runner: mockRunner)

    let app = InstalledApp(
        name: "CustomApp",
        bundleId: "com.custom.app",
        source: "App",
        uninstallName: "CustomApp",
        path: "/Applications/CustomApp.app",
        size: "45.0MB"
    )

    let preview = try await engine.inspectApp(app: app)
    assert(preview.residuals.count == 1, "Fallback should contain the app binary")
    assert(preview.residuals[0].path == "/Applications/CustomApp.app")
    assert(preview.residuals[0].kind == .binary)
    assert(preview.residuals[0].sizeText == "45.0MB")

    print("✓ testRealUninstallEngineFallbackOnEmptyDryRun passed")
}

func testSubprocessRunnerWithStdinData() async throws {
    let runner = SubprocessRunner()
    let inputData = "Hello from Roche Stdin\n".data(using: .utf8)!

    let output = try await runner.execute(
        executableURL: URL(fileURLWithPath: "/bin/cat"),
        arguments: [],
        environment: nil,
        timeout: 5.0,
        stdinData: inputData
    )

    assert(output.exitCode == 0, "Cat exit code should be 0")
    assert(output.stdoutString == "Hello from Roche Stdin\n", "Output should match stdin data")
    print("✓ testSubprocessRunnerWithStdinData passed")
}

// MARK: - Test Suite Runner

func runUninstallEngineTests() async throws {
    try testInstalledAppsJsonDecodingWithFixture()
    try testInstalledAppsJsonDecodingWithAnsiAndNoise()
    testDryRunOutputResidualParsingWithMultiFiles()
    testDryRunOutputResidualParsingWithSingleApp()
    testDryRunOutputWithSystemAndReviewOnlyTags()
    testClassifyKindAndDeriveTitle()
    testAppUninstallPreviewSelectionCalculations()
    try await testMockUninstallEngine()
    try await testRealUninstallEngineWithMockRunner()
    try await testRealUninstallEngineFallbackOnEmptyDryRun()
    try await testSubprocessRunnerWithStdinData()
    print("All UninstallEngine tests passed.")
}
