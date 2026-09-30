import Foundation

public func runPurgePathsManagerTests() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    let configFile = tempDir.appendingPathComponent("purge_paths")
    let manager = PurgePathsManager(configURL: configFile)

    // Test 1: Empty file defaults
    let initialCustom = manager.loadCustomPaths()
    assert(initialCustom.isEmpty, "Initial custom paths should be empty")
    let initialAll = manager.allScanPaths()
    assert(initialAll.count == PurgePathsManager.defaultPaths.count, "Default paths should match")
    print("✓ testEmptyFileDefaults passed")

    // Test 2: Add path
    try manager.addPath("~/my-workspace")
    var custom = manager.loadCustomPaths()
    assert(custom.count == 1, "Should have 1 custom path")
    assert(custom.first == "~/my-workspace", "Path should match added path")
    print("✓ testAddPath passed")

    // Test 3: Deduplication
    try manager.addPath("~/my-workspace")
    custom = manager.loadCustomPaths()
    assert(custom.count == 1, "Duplicate paths should be ignored")
    print("✓ testDeduplication passed")

    // Test 4: All scan paths combines defaults with custom
    let all = manager.allScanPaths()
    assert(all.contains("~/my-workspace"), "allScanPaths should include custom path")
    assert(all.contains("~/Projects"), "allScanPaths should include default paths")
    print("✓ testAllScanPathsCombines passed")

    // Test 5: Remove path
    try manager.removePath("~/my-workspace")
    custom = manager.loadCustomPaths()
    assert(custom.isEmpty, "Custom paths should be empty after removal")
    print("✓ testRemovePath passed")
}
