import Foundation

public protocol MoleClientProtocol: Sendable {
    /// Thu thập toàn bộ telemetry hệ thống thời gian thực
    func fetchMetrics() async throws -> MetricsSnapshot
}
