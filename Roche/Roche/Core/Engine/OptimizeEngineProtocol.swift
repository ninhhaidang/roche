import Foundation

public protocol OptimizeEngineProtocol: Sendable {
    func diagnosePerformance() async throws -> SystemDiagnosis
    func runOptimization(dryRun: Bool) async throws -> [OptimizeTask]
    func runOptimization(dryRun: Bool) -> AsyncThrowingStream<OptimizeTaskEvent, Error>
}

extension OptimizeEngineProtocol {
    public func runOptimization(dryRun: Bool = true) async throws -> [OptimizeTask] {
        let diagnosis = try await diagnosePerformance()
        return diagnosis.tasks
    }
}
