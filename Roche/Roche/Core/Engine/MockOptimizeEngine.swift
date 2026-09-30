import Foundation

public final nonisolated class MockOptimizeEngine: OptimizeEngineProtocol, @unchecked Sendable {
    public enum DiagnosisScenario: String, CaseIterable, Identifiable, Sendable {
        case windowServerBottleneck = "WindowServer Bottleneck"
        case syspolicydBottleneck = "syspolicyd Bottleneck"
        case nominalHealthy = "Hệ thống tối ưu"

        public var id: String { rawValue }
    }

    public var scenario: DiagnosisScenario
    public var simulatedDelay: TimeInterval

    public init(
        scenario: DiagnosisScenario = .windowServerBottleneck,
        simulatedDelay: TimeInterval = 0.0
    ) {
        self.scenario = scenario
        self.simulatedDelay = simulatedDelay
    }

    public func diagnosePerformance() async throws -> SystemDiagnosis {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        return Self.mockDiagnosis(scenario: scenario)
    }

    public func runOptimization(dryRun: Bool = true) async throws -> [OptimizeTask] {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        var tasks = Self.mockTasks20
        if !dryRun {
            for i in 0..<tasks.count {
                if tasks[i].outcome == .attention {
                    // Attention stays attention if manual user intervention required
                } else if tasks[i].outcome != .skipped {
                    tasks[i] = OptimizeTask(
                        id: tasks[i].id,
                        name: tasks[i].name,
                        category: tasks[i].category,
                        status: .completed,
                        outcome: .applied,
                        message: "Đã tối ưu thành công",
                        details: tasks[i].details
                    )
                }
            }
        }
        return tasks
    }

    public func runOptimization(dryRun: Bool = true) -> AsyncThrowingStream<OptimizeTaskEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let delay = self.simulatedDelay
                let canonicalTasks = Self.mockTasks20
                var completedTasks: [OptimizeTask] = []

                for canonical in canonicalTasks {
                    if Task.isCancelled { break }
                    continuation.yield(.started(taskName: canonical.name, category: canonical.category))
                    continuation.yield(.line(raw: "➤ \(canonical.name)"))

                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }

                    let outcome: OptimizeTaskOutcome
                    let message: String
                    if dryRun {
                        outcome = canonical.outcome
                        message = canonical.message
                    } else {
                        if canonical.outcome == .attention {
                            outcome = .attention
                            message = canonical.message
                        } else if canonical.outcome == .skipped {
                            outcome = .skipped
                            message = canonical.message
                        } else {
                            outcome = .applied
                            message = "Đã tối ưu thành công"
                        }
                    }

                    continuation.yield(.line(raw: "  → \(message)"))

                    let finishedTask = OptimizeTask(
                        id: canonical.id,
                        name: canonical.name,
                        category: canonical.category,
                        status: .completed,
                        outcome: outcome,
                        message: message,
                        details: [message]
                    )
                    completedTasks.append(finishedTask)
                    continuation.yield(.completed(task: finishedTask))
                }

                var applied = 0
                var unchanged = 0
                var attention = 0
                var skipped = 0
                var failed = 0

                for t in completedTasks {
                    switch t.outcome {
                    case .applied: applied += 1
                    case .unchanged: unchanged += 1
                    case .attention: attention += 1
                    case .skipped: skipped += 1
                    case .pending, .running: break
                    }
                    if t.status == .failed { failed += 1 }
                }

                let summary = OptimizeExecutionSummary(
                    totalTasks: completedTasks.count,
                    appliedCount: applied,
                    unchangedCount: unchanged,
                    attentionCount: attention,
                    skippedCount: skipped,
                    failedCount: failed,
                    isDryRun: dryRun
                )
                continuation.yield(.finished(summary: summary))
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Static Fixtures

    public static var mockTasks20: [OptimizeTask] {
        RealOptimizeEngine.canonicalTasks20()
    }

    public static func mockTasksByCategory() -> [OptimizeTaskCategory: [OptimizeTask]] {
        var dict: [OptimizeTaskCategory: [OptimizeTask]] = [:]
        for cat in OptimizeTaskCategory.allCases {
            dict[cat] = mockTasks20.filter { $0.category == cat }
        }
        return dict
    }

    public static func mockDiagnosis(scenario: DiagnosisScenario = .windowServerBottleneck) -> SystemDiagnosis {
        switch scenario {
        case .windowServerBottleneck:
            return SystemDiagnosis(
                id: "diag_windowserver",
                component: "WindowServer",
                description: "WindowServer đang sử dụng ~31.2% CPU kéo dài (Desktop Composition bận).",
                recommendation: "Làm mới bộ nhớ đệm Finder và giải phóng Icon Services để giảm tải compositing.",
                severity: .moderate,
                cpuUsagePercent: 31.2,
                hasBottleneck: true,
                tasks: mockTasks20,
                rawOutput: "Likely bottleneck: WindowServer (~31.2% CPU sustained)\nDesktop composition is busy."
            )

        case .syspolicydBottleneck:
            return SystemDiagnosis(
                id: "diag_syspolicyd",
                component: "syspolicyd",
                description: "syspolicyd đang sử dụng ~68.5% CPU kéo dài (Gatekeeper đánh giá mã bảo mật).",
                recommendation: "Đóng bớt các ảnh đĩa DMG đã gắn hoặc chờ tiến trình quét bảo mật hoàn tất.",
                severity: .severe,
                cpuUsagePercent: 68.5,
                hasBottleneck: true,
                tasks: mockTasks20,
                rawOutput: "Likely bottleneck: syspolicyd (~68.5% CPU sustained)\nGatekeeper activity is elevated."
            )

        case .nominalHealthy:
            let healthyTasks = mockTasks20.map { task in
                OptimizeTask(
                    id: task.id,
                    name: task.name,
                    category: task.category,
                    status: .completed,
                    outcome: task.outcome == .attention ? .unchanged : task.outcome,
                    message: "Hệ thống ở trạng thái tối ưu",
                    details: task.details
                )
            }
            return SystemDiagnosis(
                id: "diag_nominal",
                component: "Không có nghẽn",
                description: "Không phát hiện tiến trình nào chiếm dụng CPU kéo dài bất thường.",
                recommendation: "Hệ thống đang hoạt động ở trạng thái mượt mà và tối ưu.",
                severity: .nominal,
                cpuUsagePercent: nil,
                hasBottleneck: false,
                tasks: healthyTasks,
                rawOutput: "No sustained high-CPU bottleneck detected"
            )
        }
    }
}
