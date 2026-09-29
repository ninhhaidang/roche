import Foundation

final nonisolated class MockTestMoleClient: MoleClientProtocol, @unchecked Sendable {
    var engineInfo: MoleEngineInfo {
        MoleEngineInfo(source: .embedded, executablePath: "/mock/bin/mo", version: "1.0.0")
    }

    var resultToReturn: CleanScanResult?
    var errorToThrow: (any Error)?
    var scanDelayNanoseconds: UInt64 = 0

    func fetchMetrics() async throws -> MetricsSnapshot {
        fatalError("Not needed for CleanEngine tests")
    }

    func scanCleanables() async throws -> CleanScanResult {
        if scanDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: scanDelayNanoseconds)
        }
        if let error = errorToThrow {
            throw error
        }
        return resultToReturn ?? CleanScanResult(categories: [], scannedAt: Date())
    }

    func performClean(categories: Set<CleanCategoryKind>) async throws -> CleanExecutionResult {
        CleanExecutionResult(reclaimedBytes: 100, cleanedCategories: Array(categories), itemsRemovedCount: 1, cleanedAt: Date(), message: "Cleaned")
    }
}

@MainActor
func testScanStateTransitionsFromIdleToScanningToReady() async throws {
    let mockClient = MockTestMoleClient()
    mockClient.scanDelayNanoseconds = 100_000_000 // 100ms
    let scanResult = CleanScanResult(
        categories: [
            CleanCategory(kind: .dev, items: [], isSelected: false)
        ],
        scannedAt: Date()
    )
    mockClient.resultToReturn = scanResult

    let engine = CleanEngine(client: mockClient)
    assert(engine.state == .idle, "Initial state must be .idle")
    assert(!engine.isScanning, "Initially isScanning must be false")

    let scanTask = Task { @MainActor in
        await engine.scan()
    }

    // Yield to allow task to start and enter scanning state
    try await Task.sleep(nanoseconds: 20_000_000)
    assert(engine.state == .scanning, "State must transition to .scanning")
    assert(engine.isScanning, "isScanning must be true during scan")

    await scanTask.value

    guard case .ready(let result, _) = engine.state else {
        assertionFailure("State must transition to .ready after successful scan, got: \(engine.state)")
        return
    }
    assert(result == scanResult, "Result must match mock scan result")
    print("✓ testScanStateTransitionsFromIdleToScanningToReady passed")
}

@MainActor
func testScanFailureTransitionsToFailedState() async throws {
    let mockClient = MockTestMoleClient()
    mockClient.errorToThrow = MoleError.executableNotFound

    let engine = CleanEngine(client: mockClient)
    assert(engine.state == .idle)

    await engine.scan()

    guard case .failed(let message) = engine.state else {
        assertionFailure("State must be .failed on scan error, got: \(engine.state)")
        return
    }
    assert(!message.isEmpty, "Failure message must not be empty")
    assert(engine.errorMessage == message, "errorMessage convenience property must match")
    print("✓ testScanFailureTransitionsToFailedState passed")
}

@MainActor
func testInvalidTransitionRejectedWhileScanning() async throws {
    let mockClient = MockTestMoleClient()
    mockClient.scanDelayNanoseconds = 200_000_000
    mockClient.resultToReturn = CleanScanResult(categories: [], scannedAt: Date())

    let engine = CleanEngine(client: mockClient)

    let task1 = Task { @MainActor in
        await engine.scan()
    }

    try await Task.sleep(nanoseconds: 30_000_000)
    assert(engine.state == .scanning)

    // Second scan call while already scanning should be safely ignored
    await engine.scan()
    assert(engine.state == .scanning, "Should remain in .scanning without error")

    await task1.value
    assert(engine.state != .scanning, "Should finish and transition to .ready")
    print("✓ testInvalidTransitionRejectedWhileScanning passed")
}
@MainActor
func testCancelScanTransitionsToIdle() async throws {
    let mockClient = MockTestMoleClient()
    mockClient.scanDelayNanoseconds = 500_000_000

    let engine = CleanEngine(client: mockClient)

    let scanTask = Task { @MainActor in
        await engine.scan()
    }

    try await Task.sleep(nanoseconds: 30_000_000)
    assert(engine.state == .scanning, "Should be scanning")

    engine.cancelScan()
    assert(engine.state == .idle, "Should transition to .idle after cancelScan")

    scanTask.cancel()
    await scanTask.value
    print("✓ testCancelScanTransitionsToIdle passed")
}

@MainActor
func testCleanCompletionSummaryPreservedAcrossScan() async throws {
    let mockClient = MockTestMoleClient()
    let initialResult = CleanScanResult(
        categories: [
            CleanCategory(kind: .trash, sizeBytes: 1024, itemCount: 1, items: [], isSelected: true)
        ],
        scannedAt: Date()
    )
    mockClient.resultToReturn = initialResult

    let engine = CleanEngine(client: mockClient)
    await engine.scan()

    assert(engine.scanResult != nil, "Must have scan result")
    await engine.cleanSelected()

    assert(engine.lastCleanResult != nil, "lastCleanResult must be preserved after cleanSelected")
    assert(engine.lastCleanResult?.reclaimedBytes == 100, "Must contain clean summary metrics")
    print("✓ testCleanCompletionSummaryPreservedAcrossScan passed")
}


func runCleanEngineTests() async throws {
    try await testScanStateTransitionsFromIdleToScanningToReady()
    try await testScanFailureTransitionsToFailedState()
    try await testInvalidTransitionRejectedWhileScanning()
    try await testCancelScanTransitionsToIdle()
    try await testCleanCompletionSummaryPreservedAcrossScan()
    print("All CleanEngine tests passed.")
}
