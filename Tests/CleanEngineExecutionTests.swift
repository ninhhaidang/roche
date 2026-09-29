import Foundation

final nonisolated class MockExecutionMoleClient: MoleClientProtocol, @unchecked Sendable {
    var engineInfo: MoleEngineInfo {
        MoleEngineInfo(source: .embedded, executablePath: "/mock/bin/mo", version: "1.0.0")
    }

    var scanCount = 0
    var cleanCount = 0
    var lastCleanedCategories: Set<CleanCategoryKind> = []
    var cleanErrorToThrow: (any Error)?
    var cleanDelayNanoseconds: UInt64 = 0

    func fetchMetrics() async throws -> MetricsSnapshot {
        fatalError("Not needed")
    }

    func scanCleanables() async throws -> CleanScanResult {
        scanCount += 1
        return CleanScanResult(
            categories: [
                CleanCategory(kind: .dev, sizeBytes: 5000, itemCount: 10, items: [], isSelected: true),
                CleanCategory(kind: .trash, sizeBytes: 2000, itemCount: 2, items: [], isSelected: true)
            ],
            scannedAt: Date()
        )
    }

    func performClean(categories: Set<CleanCategoryKind>) async throws -> CleanExecutionResult {
        if cleanDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: cleanDelayNanoseconds)
        }
        if let error = cleanErrorToThrow {
            throw error
        }
        cleanCount += 1
        lastCleanedCategories = categories
        return CleanExecutionResult(
            reclaimedBytes: 7000,
            cleanedCategories: Array(categories),
            itemsRemovedCount: 12,
            cleanedAt: Date(),
            message: "Dọn dẹp thành công"
        )
    }
}

@MainActor
func testCleanSelectedLifecycleAndAutoRescan() async throws {
    let mockClient = MockExecutionMoleClient()
    mockClient.cleanDelayNanoseconds = 100_000_000 // 100ms
    let engine = CleanEngine(client: mockClient)

    // 1. Initial Scan
    await engine.scan()
    assert(mockClient.scanCount == 1)
    guard case .ready = engine.state else {
        assertionFailure("Must be in .ready state")
        return
    }

    // 2. Trigger cleanSelected
    let cleanTask = Task { @MainActor in
        await engine.cleanSelected()
    }

    // Yield to let task begin
    try await Task.sleep(nanoseconds: 20_000_000)
    assert(engine.isCleaning == true, "Must be in cleaning state during execution")
    if case .cleaning(let selected) = engine.state {
        assert(selected.contains(.dev))
        assert(selected.contains(.trash))
    } else {
        assertionFailure("State must be .cleaning, got: \(engine.state)")
    }

    await cleanTask.value

    // 3. Verify clean was executed with selected categories
    assert(mockClient.cleanCount == 1)
    assert(mockClient.lastCleanedCategories.contains(.dev))
    assert(mockClient.lastCleanedCategories.contains(.trash))

    // 4. Verify auto-rescan was triggered post-cleanup (scanCount must be 2)
    assert(mockClient.scanCount == 2, "Automatic Clean Scan post-cleanup must be triggered")

    // 5. Verify state is .ready with preserved lastCleanResult
    assert(engine.lastCleanResult != nil, "lastCleanResult must be preserved")
    assert(engine.lastCleanResult?.reclaimedBytes == 7000)
    assert(engine.lastCleanResult?.itemsRemovedCount == 12)
    guard case .ready = engine.state else {
        assertionFailure("State should return to .ready after auto-rescan")
        return
    }

    print("✓ testCleanSelectedLifecycleAndAutoRescan passed")
}

@MainActor
func testCleanSelectedSafetyPrerequisiteRejectedWithoutPriorScan() async throws {
    let mockClient = MockExecutionMoleClient()
    let engine = CleanEngine(client: mockClient)

    assert(engine.state == .idle)

    // Must be rejected without prior completed scan
    await engine.cleanSelected()
    assert(mockClient.cleanCount == 0, "Clean Action must not run without prior completed Clean Scan")
    assert(engine.state == .idle)

    print("✓ testCleanSelectedSafetyPrerequisiteRejectedWithoutPriorScan passed")
}

@MainActor
func testCleanSelectedErrorTransitionsToFailedState() async throws {
    let mockClient = MockExecutionMoleClient()
    mockClient.cleanErrorToThrow = MoleError.processExecutionFailed(exitCode: 1, stderr: "Permission denied")

    let engine = CleanEngine(client: mockClient)
    await engine.scan()

    await engine.cleanSelected()

    guard case .failed(let message) = engine.state else {
        assertionFailure("Must transition to .failed on clean error, got \(engine.state)")
        return
    }
    assert(message.contains("Permission denied") || message.contains("1"))
    assert(engine.errorMessage != nil)

    print("✓ testCleanSelectedErrorTransitionsToFailedState passed")
}

func testCleanExecutionResultSummaryText() {
    let date = Date(timeIntervalSince1970: 1727500000)
    let result = CleanExecutionResult(
        reclaimedBytes: 1024 * 1024 * 50,
        cleanedCategories: [.dev, .logs],
        itemsRemovedCount: 25,
        cleanedAt: date,
        message: "Đã dọn dẹp"
    )

    assert(result.itemsRemovedCount == 25)
    assert(!result.formattedCleanedAt.isEmpty)
    assert(result.summaryText.contains("25 mục"))
    assert(result.summaryText.contains("Đã dọn dẹp"))
    print("✓ testCleanExecutionResultSummaryText passed")
}

func runCleanEngineExecutionTests() async throws {
    try await testCleanSelectedLifecycleAndAutoRescan()
    try await testCleanSelectedSafetyPrerequisiteRejectedWithoutPriorScan()
    try await testCleanSelectedErrorTransitionsToFailedState()
    testCleanExecutionResultSummaryText()
    print("All CleanEngineExecution tests passed.")
}
