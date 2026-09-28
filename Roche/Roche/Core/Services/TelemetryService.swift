import Foundation
import Observation

@MainActor
@Observable
public final class TelemetryService {
    public private(set) var snapshot: MetricsSnapshot?
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    private let client: MoleClientProtocol
    private var pollingTask: Task<Void, Never>?

    public init(client: MoleClientProtocol? = nil) {
        self.client = client ?? RealMoleClient()
    }

    public func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await client.fetchMetrics()
            self.snapshot = result
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    public func startPolling(intervalSeconds: UInt64 = 3) {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
