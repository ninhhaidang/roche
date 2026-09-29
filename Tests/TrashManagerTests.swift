import Foundation

final class MockTrashManager: TrashManaging, @unchecked Sendable {
    var initialSizeBytes: UInt64 = 2048
    var initialItemCount: Int = 3
    var emptyTrashCalled = false
    var emptyTrashResult = true

    func fetchTrashInfo() async -> (sizeBytes: UInt64, itemCount: Int) {
        if emptyTrashCalled {
            return (0, 0)
        }
        return (initialSizeBytes, initialItemCount)
    }

    func emptyTrash() async -> Bool {
        emptyTrashCalled = true
        return emptyTrashResult
    }
}

final class MockSubprocessRunner: SubprocessRunning, @unchecked Sendable {
    var executedUrls: [URL] = []

    func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        onSpawn: (@Sendable (pid_t) -> Void)?
    ) async throws -> SubprocessOutput {
        executedUrls.append(executableURL)
        return SubprocessOutput(stdoutData: Data(), stderrData: Data(), exitCode: 0)
    }
}

func testPerformCleanWithTrashCallsEmptyTrash() async throws {
    let mockTrash = MockTrashManager()
    let mockRunner = MockSubprocessRunner()
    let client = RealMoleClient(
        runner: mockRunner,
        trashManager: mockTrash
    )

    let result = try await client.performClean(categories: [.trash])

    assert(mockTrash.emptyTrashCalled == true, "emptyTrash must be called when .trash is selected")
    assert(result.reclaimedBytes == 2048, "Reclaimed bytes should match initial trash size")
    assert(result.itemsRemovedCount == 3, "Items removed should match initial trash items count")
    assert(result.cleanedCategories.contains(.trash))
    print("✓ testPerformCleanWithTrashCallsEmptyTrash passed")
}

func testPerformCleanWithoutTrashSkipsEmptyTrash() async throws {
    let mockTrash = MockTrashManager()
    let mockRunner = MockSubprocessRunner()
    let client = RealMoleClient(
        runner: mockRunner,
        trashManager: mockTrash
    )

    // Select only .dev (not .trash)
    let result = try await client.performClean(categories: [.dev])

    assert(mockTrash.emptyTrashCalled == false, "emptyTrash must NOT be called when .trash is not selected")
    assert(!result.cleanedCategories.contains(.trash))
    print("✓ testPerformCleanWithoutTrashSkipsEmptyTrash passed")
}
func testPerformCleanWithFailedEmptyTrashDoesNotReportReclaimed() async throws {
    let mockTrash = MockTrashManager()
    mockTrash.emptyTrashResult = false // Failed to empty trash (e.g. permission or locked file)
    // Trash size and count remain unchanged
    let mockRunner = MockSubprocessRunner()
    let client = RealMoleClient(
        runner: mockRunner,
        trashManager: mockTrash
    )

    let result = try await client.performClean(categories: [.trash])

    assert(mockTrash.emptyTrashCalled == true)
    assert(result.reclaimedBytes == 0, "Failed empty trash must report 0 reclaimed bytes")
    assert(result.itemsRemovedCount == 0, "Failed empty trash must report 0 items removed")
    print("✓ testPerformCleanWithFailedEmptyTrashDoesNotReportReclaimed passed")
}


func runTrashManagerTests() async throws {
    try await testPerformCleanWithTrashCallsEmptyTrash()
    try await testPerformCleanWithoutTrashSkipsEmptyTrash()
    try await testPerformCleanWithFailedEmptyTrashDoesNotReportReclaimed()
    print("All TrashManager tests passed.")
}
