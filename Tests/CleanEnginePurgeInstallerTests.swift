import Foundation

// MARK: - Test Doubles

private final class MockPurgeInstallerMoleClient: MoleClientProtocol, @unchecked Sendable {
    var engineInfo: MoleEngineInfo {
        MoleEngineInfo(source: .embedded, executablePath: "/mock/bin/mo", version: "1.56.1")
    }

    var scanResult: CleanScanResult
    var lastCleanedCategories: Set<CleanCategoryKind> = []

    init(scanResult: CleanScanResult) {
        self.scanResult = scanResult
    }

    func fetchMetrics() async throws -> MetricsSnapshot {
        fatalError("Not needed for CleanEnginePurgeInstallerTests")
    }

    func scanCleanables() async throws -> CleanScanResult {
        return scanResult
    }

    func performClean(categories: Set<CleanCategoryKind>) async throws -> CleanExecutionResult {
        lastCleanedCategories = categories
        let reclaimed = scanResult.categories
            .filter { categories.contains($0.kind) }
            .reduce(UInt64(0)) { $0 + $1.sizeBytes }
        let count = scanResult.categories
            .filter { categories.contains($0.kind) }
            .reduce(0) { $0 + $1.itemCount }
        return CleanExecutionResult(
            reclaimedBytes: reclaimed,
            cleanedCategories: Array(categories),
            itemsRemovedCount: count,
            cleanedAt: Date(),
            message: "Purge & Installer cleaned"
        )
    }
}

private final class MockPurgeInstallerTrashManager: TrashManaging, @unchecked Sendable {
    var trashSizeBytes: UInt64 = 0
    var trashItemCount: Int = 0
    var emptyTrashResult: Bool = true
    var emptyTrashCalled: Bool = false
    var movedToTrashPaths: [String] = []
    var moveToTrashResult: Bool = true

    func fetchTrashInfo() async -> (sizeBytes: UInt64, itemCount: Int) {
        (trashSizeBytes, trashItemCount)
    }

    func emptyTrash() async -> Bool {
        emptyTrashCalled = true
        return emptyTrashResult
    }

    func moveToTrash(path: String) async -> Bool {
        movedToTrashPaths.append(path)
        return moveToTrashResult
    }
}

private final class MockPurgeSubprocessRunner: SubprocessRunning, @unchecked Sendable {
    var executedCommands: [(url: URL, args: [String])] = []
    var purgeOutput: String = ""
    var installerOutput: String = ""
    var cleanOutput: String = ""

    func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        onSpawn: (@Sendable (pid_t) -> Void)?
    ) async throws -> SubprocessOutput {
        executedCommands.append((executableURL, arguments))
        let urlStr = executableURL.path
        let outStr: String
        if arguments.contains("purge") || urlStr.contains("purge") {
            outStr = purgeOutput
        } else if arguments.contains("installer") || urlStr.contains("installer") {
            outStr = installerOutput
        } else {
            outStr = cleanOutput
        }
        return SubprocessOutput(
            stdoutData: Data(outStr.utf8),
            stderrData: Data(),
            exitCode: 0
        )
    }
}

// MARK: - Test Cases

func testCategoryKindMetadata() {
    assert(CleanCategoryKind.projectArtifacts.rawValue == "project_artifacts")
    assert(CleanCategoryKind.installers.rawValue == "installers")
    assert(CleanCategoryKind.projectArtifacts.title == "Project Artifacts")
    assert(CleanCategoryKind.installers.title == "Installers & DMGs")
    assert(CleanCategoryKind.projectArtifacts.iconName == "curlybraces")
    assert(CleanCategoryKind.installers.iconName == "shippingbox")
    assert(!CleanCategoryKind.projectArtifacts.subtitle.isEmpty)
    assert(!CleanCategoryKind.installers.subtitle.isEmpty)
    print("✓ testCategoryKindMetadata passed")
}

func testPurgeOutputParsing() {
    let fixture = """
    → DRY RUN MODE, No project artifacts will be removed

    Purge Project Artifacts

    ✓ [DRY RUN] ~/aerospace/portfolio/node_modules, 379.4MB
    ✓ [DRY RUN] ~/aerospace/portfolio/.next, 63.1MB
    ✓ [DRY RUN] ~/aerospace/portfolio/dist, 770KB
    ✓ [DRY RUN] /Users/test/workspace/target, 1.5 GB

    ======================================================================
    Dry run complete - no changes made
    Would free approximately: 1.94GB | Items: 4 | Free: 344.16GB
    ======================================================================
    """

    let parser = CleanListParser()
    let items = parser.parsePurgeOutput(fixture)

    assert(items.count == 4, "Expected 4 parsed purge items, got \(items.count)")
    assert(items[0].name == "node_modules")
    assert(items[0].sizeBytes == UInt64((379.4 * 1024 * 1024).rounded()))
    assert(items[1].name == ".next")
    assert(items[2].name == "dist")
    assert(items[3].name == "target")
    assert(items[3].sizeBytes == UInt64((1.5 * 1024 * 1024 * 1024).rounded()))
    print("✓ testPurgeOutputParsing passed")
}

func testInstallerOutputParsing() {
    let fixture = """
    → DRY RUN MODE, No installer files will be removed


    Select Installers to Remove , 0B, 0 selected



    ➤ ○ Tinycast-0.11.3.dmg                         6.8MB | Downloads 
      ○ Docker-arm64.dmg                          550.0MB | Downloads 
      ○ Node-v20.pkg                               45.2MB | Desktop 



































    ↑↓  |  Space Select  |  Enter Confirm  |  A All  |  I Invert  |  Q Quit
    """

    let parser = CleanListParser()
    let items = parser.parseInstallerOutput(fixture)

    assert(items.count == 3, "Expected 3 parsed installer items, got \(items.count)")
    assert(items[0].name == "Tinycast-0.11.3.dmg")
    assert(items[0].sizeBytes == UInt64((6.8 * 1024 * 1024).rounded()))
    assert(items[0].path.hasSuffix("/Downloads/Tinycast-0.11.3.dmg"))

    assert(items[1].name == "Docker-arm64.dmg")
    assert(items[1].sizeBytes == UInt64((550.0 * 1024 * 1024).rounded()))

    assert(items[2].name == "Node-v20.pkg")
    assert(items[2].sizeBytes == UInt64((45.2 * 1024 * 1024).rounded()))
    assert(items[2].path.hasSuffix("/Desktop/Node-v20.pkg"))

    print("✓ testInstallerOutputParsing passed")
}

@MainActor
func testDefaultSelectionExcludesProjectArtifactsAndIncludesInstallers() async throws {
    let scanResult = CleanScanResult(
        categories: [
            CleanCategory(kind: .dev, sizeBytes: 1000, itemCount: 1, items: [], isSelected: true),
            CleanCategory(kind: .projectArtifacts, sizeBytes: 50_000, itemCount: 5, items: [], isSelected: false),
            CleanCategory(kind: .installers, sizeBytes: 20_000, itemCount: 2, items: [], isSelected: true),
            CleanCategory(kind: .trash, sizeBytes: 0, itemCount: 0, items: [], isSelected: false)
        ],
        scannedAt: Date()
    )

    let client = MockPurgeInstallerMoleClient(scanResult: scanResult)
    let engine = CleanEngine(client: client)

    await engine.scan()

    // 1. Initial scan selection must NOT contain projectArtifacts, MUST contain installers and dev
    assert(!engine.selectedCategories.contains(.projectArtifacts), "projectArtifacts must be UNCHECKED by default")
    assert(engine.selectedCategories.contains(.installers), "installers must be selected by default when it has items")
    assert(engine.selectedCategories.contains(.dev), "dev must be selected by default when it has items")
    assert(!engine.selectedCategories.contains(.trash), "Empty trash must not be selected")

    // 2. selectAll() must also exclude projectArtifacts for developer safety
    engine.deselectAll()
    assert(engine.selectedCategories.isEmpty)

    engine.selectAll()
    assert(!engine.selectedCategories.contains(.projectArtifacts), "selectAll() must NOT select projectArtifacts")
    assert(engine.selectedCategories.contains(.installers), "selectAll() must select installers")
    assert(engine.selectedCategories.contains(.dev), "selectAll() must select dev")

    // 3. User can explicitly toggle projectArtifacts
    engine.toggleCategory(.projectArtifacts)
    assert(engine.selectedCategories.contains(.projectArtifacts), "User can explicitly select projectArtifacts")

    print("✓ testDefaultSelectionExcludesProjectArtifactsAndIncludesInstallers passed")
}

func testTrashExecutionForPurgeAndInstallers() async throws {
    let mockRunner = MockPurgeSubprocessRunner()
    let mockTrash = MockPurgeInstallerTrashManager()

    mockRunner.purgeOutput = """
    ✓ [DRY RUN] /tmp/proj1/node_modules, 100MB
    ✓ [DRY RUN] /tmp/proj2/.venv, 50MB
    """

    mockRunner.installerOutput = """
    ➤ ○ TestApp.dmg                         25.0MB | Downloads
    """

    let client = RealMoleClient(
        runner: mockRunner,
        trashManager: mockTrash
    )

    let result = try await client.performClean(categories: [.projectArtifacts, .installers])
    assert(mockTrash.movedToTrashPaths.contains("/tmp/proj1/node_modules"))
    assert(mockTrash.movedToTrashPaths.contains("/tmp/proj2/.venv"))
    assert(mockTrash.movedToTrashPaths.contains { $0.hasSuffix("/Downloads/TestApp.dmg") })
    assert(mockTrash.movedToTrashPaths.count == 3)
    let expectedBytes = UInt64(100 * 1024 * 1024) +
                        UInt64(50 * 1024 * 1024) +
                        UInt64(25 * 1024 * 1024)
    assert(result.reclaimedBytes == expectedBytes, "Reclaimed bytes should match total trashed items")
    assert(result.itemsRemovedCount == 3, "Items removed count should be 3")
    assert(result.cleanedCategories.contains(.projectArtifacts))
    assert(result.cleanedCategories.contains(.installers))
    assert(result.message.contains("project artifacts"))
    assert(result.message.contains("bộ cài đặt"))

    print("✓ testTrashExecutionForPurgeAndInstallers passed")
}

func runCleanEnginePurgeInstallerTests() async throws {
    testCategoryKindMetadata()
    testPurgeOutputParsing()
    testInstallerOutputParsing()
    try await testDefaultSelectionExcludesProjectArtifactsAndIncludesInstallers()
    try await testTrashExecutionForPurgeAndInstallers()
    print("All CleanEnginePurgeInstaller tests passed.")
}
