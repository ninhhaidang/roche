import Foundation

func runMoleExecutableFinderTests() async throws {
    let finder = MoleExecutableFinder()

    // 1. Current environment should find a valid status executable
    guard let target = finder.findStatusExecutable() else {
        fatalError("Expected to find valid status executable on system")
    }

    assert(FileManager.default.isExecutableFile(atPath: target.url.path), "Target binary must be executable")
    assert(target.arguments.contains("--json"), "Status target arguments must contain --json")
    print("✓ testFindStatusExecutableReturnsValidTarget passed (found: \(target.url.path))")

    // 2. Engine info should report valid source and non-empty version
    let engineInfo = finder.currentEngineInfo()
    assert(engineInfo.source != .notFound, "Engine source should not be notFound")
    assert(!engineInfo.version.isEmpty, "Engine version should not be empty")
    print("✓ testCurrentEngineInfoReportsValidMetadata passed (source: \(engineInfo.source), ver: \(engineInfo.version))")

    // 3. Verify clean executable lookup
    guard let cleanTarget = finder.findCleanExecutable(dryRun: true) else {
        fatalError("Expected to find clean executable on system")
    }
    assert(FileManager.default.isExecutableFile(atPath: cleanTarget.url.path), "Clean binary must be executable")
    assert(cleanTarget.arguments.contains("--dry-run"), "Clean dry-run target must contain --dry-run")
    print("✓ testFindCleanExecutableReturnsValidTarget passed")

    // 4. Verify optimize executable lookup
    guard let optimizeTarget = finder.findOptimizeExecutable(dryRun: true) else {
        fatalError("Expected to find optimize executable on system")
    }
    assert(FileManager.default.isExecutableFile(atPath: optimizeTarget.url.path), "Optimize binary must be executable")
    assert(optimizeTarget.arguments.contains("--dry-run"), "Optimize dry-run target must contain --dry-run")
    print("✓ testFindOptimizeExecutableReturnsValidTarget passed")

    print("All MoleExecutableFinder tests passed.")
}
