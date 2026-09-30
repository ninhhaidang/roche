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
