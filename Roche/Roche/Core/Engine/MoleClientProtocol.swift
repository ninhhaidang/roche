import Foundation

public protocol MoleClientProtocol: Sendable {
    /// Thông tin nguồn và đường dẫn của Mole Engine
    var engineInfo: MoleEngineInfo { get }

    /// Thu thập toàn bộ telemetry hệ thống thời gian thực
    func fetchMetrics() async throws -> MetricsSnapshot

    /// Quét rác hệ thống ở chế độ Clean Scan (Dev, App Caches, Logs, Trash)
    func scanCleanables() async throws -> CleanScanResult

    /// Thực hiện dọn dẹp các danh mục đã chọn
    func performClean(categories: Set<CleanCategoryKind>) async throws -> CleanExecutionResult
}
