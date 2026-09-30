import Foundation

func runOptimizeEngineStreamingTests() async throws {
    try await testStreamingEventParsingAndTaskOutcomes()
    try await testMockOptimizeEngineStreamingAllTasks()
    try await testStreamingCancellation()
    try await testStreamingErrorHandling()
    try await testSummaryCalculation()
    testResolveCompletedTaskEdgeCases()

    print("All OptimizeEngineStreaming tests passed.")
}

// MARK: - 1. Stream Parsing with MockPTYProcessRunner

func testStreamingEventParsingAndTaskOutcomes() async throws {
    let sampleStreamOutput = """
    Optimize
    → DRY RUN MODE, No files will be modified

    ⚙ System  11/16 GB RAM | 115/460 GB Disk | Uptime 0d

    Performance diagnosis
      ◎ Likely bottleneck: WindowServer (~38.9% CPU sustained)

    ➤ DNS & Spotlight Check
      → DNS cache flushed
      → Spotlight index verified

    ➤ Finder Cache Refresh
      ✓ QuickLook thumbnails refreshed
      → Icon services cache rebuilt

    ➤ Login Items
      ◎ Broken login item: BrokenApp (app not found)
      ⚠ Stale login item: OldService (app missing)

    ➤ Disk Health
      → Disk verify skipped (set MOLE_ENABLE_DISK_VERIFY=1 to enable)

    ======================================================================
    Dry Run Complete, No Changes Made
    Would apply 2 optimizations
    16 unchanged | 1 skipped | 1 need attention
    ======================================================================
    """

    let mockPTY = MockPTYProcessRunner(
        stubbedStreamEvents: [
            sampleStreamOutput
        ]
    )

    let engine = RealOptimizeEngine(
        runner: SubprocessRunner(),
        ptyRunner: mockPTY
    )

    var receivedEvents: [OptimizeTaskEvent] = []
    let stream: AsyncThrowingStream<OptimizeTaskEvent, Error> = engine.runOptimization(dryRun: true)

    for try await event in stream {
        receivedEvents.append(event)
    }

    // Verify events were emitted
    let startedEvents = receivedEvents.compactMap { event -> String? in
        if case .started(let taskName, _) = event { return taskName }
        return nil
    }
    assert(startedEvents.contains("DNS & Spotlight Check"), "Should contain DNS & Spotlight Check start")
    assert(startedEvents.contains("Finder Cache Refresh"), "Should contain Finder Cache Refresh start")
    assert(startedEvents.contains("Login Items"), "Should contain Login Items start")
    assert(startedEvents.contains("Disk Health"), "Should contain Disk Health start")

    let completedTasks = receivedEvents.compactMap { event -> OptimizeTask? in
        if case .completed(let task) = event { return task }
        return nil
    }
    assert(completedTasks.count == 4, "Should emit 4 completed tasks, got \(completedTasks.count)")

    let dnsTask = completedTasks.first { $0.id == "system_maintenance" }
    assert(dnsTask != nil, "DNS task should be mapped to canonical id system_maintenance")
    assert(dnsTask?.outcome == .applied, "DNS task should be .applied (contains 'flushed')")

    let finderTask = completedTasks.first { $0.id == "cache_refresh" }
    assert(finderTask != nil, "Finder task should be mapped to cache_refresh")
    assert(finderTask?.outcome == .applied, "Finder task should be .applied (contains ✓ and refreshed)")

    let loginTask = completedTasks.first { $0.id == "login_items_audit" }
    assert(loginTask != nil, "Login task should be mapped to login_items_audit")
    assert(loginTask?.outcome == .attention, "Login task should be .attention (contains 'broken' / '⚠')")

    let diskTask = completedTasks.first { $0.id == "disk_verify" }
    assert(diskTask != nil, "Disk task should be mapped to disk_verify")
    assert(diskTask?.outcome == .skipped, "Disk task should be .skipped (contains 'skipped'), got \(String(describing: diskTask?.outcome))")

    let finishEvent = receivedEvents.first { event in
        if case .finished = event { return true }
        return false
    }
    assert(finishEvent != nil, "Should emit .finished event")

    if case .finished(let summary) = finishEvent! {
        assert(summary.totalTasks == 4, "Summary total tasks should be 4, got \(summary.totalTasks)")
        assert(summary.appliedCount == 2, "Summary applied count should be 2, got \(summary.appliedCount)")
        assert(summary.attentionCount == 1, "Summary attention count should be 1, got \(summary.attentionCount)")
        assert(summary.skippedCount == 1, "Summary skipped count should be 1, got \(summary.skippedCount)")
        assert(summary.isDryRun == true, "Summary should reflect dryRun = true")
    }

    print("✓ testStreamingEventParsingAndTaskOutcomes passed")
}

// MARK: - 2. Mock Engine Streaming

func testMockOptimizeEngineStreamingAllTasks() async throws {
    let mock = MockOptimizeEngine(simulatedDelay: 0.0)

    var taskNames: [String] = []
    var completedCount = 0
    var finalSummary: OptimizeExecutionSummary? = nil

    let stream: AsyncThrowingStream<OptimizeTaskEvent, Error> = mock.runOptimization(dryRun: true)

    for try await event in stream {
        switch event {
        case .started(let taskName, _):
            taskNames.append(taskName)
        case .completed:
            completedCount += 1
        case .finished(let summary):
            finalSummary = summary
        case .line:
            break
        }
    }

    assert(taskNames.count == 20, "Mock engine should stream exactly 20 canonical tasks, got \(taskNames.count)")
    assert(completedCount == 20, "Mock engine should complete 20 tasks, got \(completedCount)")
    assert(finalSummary != nil, "Mock engine should produce final summary")
    assert(finalSummary?.totalTasks == 20, "Total tasks in summary must be 20")

    print("✓ testMockOptimizeEngineStreamingAllTasks passed")
}

// MARK: - 3. Stream Cancellation

func testStreamingCancellation() async throws {
    let mockPTY = MockPTYProcessRunner(
        stubbedStreamEvents: [
            "➤ Task 1\n  ✓ done\n",
            "➤ Task 2\n  ✓ done\n",
            "➤ Task 3\n  ✓ done\n"
        ],
        delay: 0.2
    )

    let engine = RealOptimizeEngine(
        runner: SubprocessRunner(),
        ptyRunner: mockPTY
    )

    let task = Task { () -> Int in
        var count = 0
        let stream: AsyncThrowingStream<OptimizeTaskEvent, Error> = engine.runOptimization(dryRun: false)
        for try await _ in stream {
            count += 1
            if count == 1 {
                // Cancel consumption early
                break
            }
        }
        return count
    }

    let count = try await task.value
    assert(count == 1, "Cancellation should stop stream processing immediately")

    print("✓ testStreamingCancellation passed")
}

// MARK: - 4. Error Handling

func testStreamingErrorHandling() async throws {
    let mockPTY = MockPTYProcessRunner(
        stubbedStreamEvents: [],
        shouldThrowError: MoleError.processExecutionFailed(exitCode: 1, stderr: "PTY broken")
    )

    let engine = RealOptimizeEngine(
        runner: SubprocessRunner(),
        ptyRunner: mockPTY
    )

    do {
        let stream: AsyncThrowingStream<OptimizeTaskEvent, Error> = engine.runOptimization(dryRun: false)
        for try await _ in stream {
            // Should not yield successfully
        }
        assertionFailure("Stream should throw error when process runner fails")
    } catch {
        // Expected error
        print("✓ testStreamingErrorHandling passed")
    }
}

// MARK: - 5. Summary Calculation

func testSummaryCalculation() async throws {
    let summaryDryRun = OptimizeExecutionSummary(
        totalTasks: 20,
        appliedCount: 5,
        unchangedCount: 12,
        attentionCount: 2,
        skippedCount: 1,
        failedCount: 0,
        isDryRun: true
    )

    assert(summaryDryRun.displayText.contains("Mô phỏng"), "Dry run summary should indicate simulation")
    assert(summaryDryRun.displayText.contains("5"), "Should contain applied count 5")

    let summaryReal = OptimizeExecutionSummary(
        totalTasks: 20,
        appliedCount: 18,
        unchangedCount: 1,
        attentionCount: 1,
        skippedCount: 0,
        failedCount: 0,
        isDryRun: false
    )

    assert(summaryReal.displayText.contains("Tối ưu hóa hoàn tất"), "Real run summary should indicate completion")

    print("✓ testSummaryCalculation passed")
}

// MARK: - 6. Task Resolution Edge Cases

func testResolveCompletedTaskEdgeCases() {
    let canonical = RealOptimizeEngine.canonicalTasks20()

    // Test ✓ marker
    let task1 = RealOptimizeEngine.resolveCompletedTask(
        taskName: "DNS & Spotlight Check",
        category: .systemAndSearch,
        details: ["✓ All caches refreshed successfully"],
        canonicalTasks: canonical
    )
    assert(task1.outcome == .applied, "✓ should mark outcome as .applied")
    assert(task1.id == "system_maintenance", "DNS check should map to system_maintenance")

    // Test ⚠ warning marker
    let task2 = RealOptimizeEngine.resolveCompletedTask(
        taskName: "Login Items",
        category: .configAndSecurity,
        details: ["⚠ 1 orphaned entry found"],
        canonicalTasks: canonical
    )
    assert(task2.outcome == .attention, "⚠ should mark outcome as .attention")
    assert(task2.id == "login_items_audit", "Login items should map to login_items_audit")

    // Test ✗ error marker
    let task3 = RealOptimizeEngine.resolveCompletedTask(
        taskName: "Custom Unknown Task",
        category: .cacheAndFinder,
        details: ["✗ Permission denied while clearing cache"],
        canonicalTasks: canonical
    )
    assert(task3.outcome == .attention, "✗ should mark outcome as .attention")
    assert(task3.name == "Custom Unknown Task", "Non-canonical name should be retained")

    // Test unchanged / optimal
    let task4 = RealOptimizeEngine.resolveCompletedTask(
        taskName: "Spotlight Optimization",
        category: .systemAndSearch,
        details: ["→ Spotlight index already optimal"],
        canonicalTasks: canonical
    )
    assert(task4.outcome == .unchanged, "Optimal should be marked as .unchanged")

    print("✓ testResolveCompletedTaskEdgeCases passed")
}
