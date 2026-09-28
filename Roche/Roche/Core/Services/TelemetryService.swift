import Foundation
import Observation

public nonisolated enum AutoRefreshInterval: Double, CaseIterable, Identifiable, Codable, Sendable {
    case twoSeconds = 2.0
    case fiveSeconds = 5.0

    public var id: Double { rawValue }

    public var label: String {
        switch self {
        case .twoSeconds:
            return "2s"
        case .fiveSeconds:
            return "5s"
        }
    }

    public var detailedDescription: String {
        switch self {
        case .twoSeconds:
            return "2 giây (Thời gian thực - khuyến nghị cho Apple Silicon)"
        case .fiveSeconds:
            return "5 giây (Tiết kiệm năng lượng & CPU)"
        }
    }
}

@MainActor
@Observable
public final class TelemetryService {
    public private(set) var snapshot: MetricsSnapshot?
    public private(set) var isLoading: Bool = false
    public private(set) var isRefreshing: Bool = false
    public private(set) var errorMessage: String?

    public var isAutoRefreshEnabled: Bool = true {
        didSet {
            if isAutoRefreshEnabled {
                startPolling()
            } else {
                stopPolling()
            }
        }
    }

    public var interval: AutoRefreshInterval = .twoSeconds {
        didSet {
            if isAutoRefreshEnabled {
                startPolling()
            }
        }
    }

    private let client: MoleClientProtocol
    private var pollingTask: Task<Void, Never>?
    public var engineInfo: MoleEngineInfo {
        client.engineInfo
    }

    public init(client: MoleClientProtocol? = nil, autoStartPolling: Bool = true) {
        self.client = client ?? RealMoleClient()
        if autoStartPolling && self.isAutoRefreshEnabled {
            startPolling()
        }
    }

    public func refresh() async {
        if snapshot == nil {
            isLoading = true
        }
        isRefreshing = true
        errorMessage = nil

        do {
            let result = try await client.fetchMetrics()
            self.snapshot = result
            self.isLoading = false
            self.isRefreshing = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            self.isRefreshing = false
        }
    }

    public func toggleAutoRefresh() {
        isAutoRefreshEnabled.toggle()
    }

    public func setInterval(_ newInterval: AutoRefreshInterval) {
        self.interval = newInterval
    }

    public func startPolling() {
        stopPolling()
        let intervalNano = UInt64(interval.rawValue * 1_000_000_000)
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: intervalNano)
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
