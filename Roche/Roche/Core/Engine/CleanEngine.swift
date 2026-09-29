import Foundation
import Observation

public enum CleanState: Equatable, Sendable {
    case idle
    case scanning
    case ready(result: CleanScanResult, selectedCategories: Set<CleanCategoryKind>)
    case cleaning(selectedCategories: Set<CleanCategoryKind>)
    case completed(summary: CleanExecutionResult)
    case failed(message: String)
}

@MainActor
@Observable
public final class CleanEngine {
    public private(set) var state: CleanState = .idle
    public private(set) var lastCleanResult: CleanExecutionResult?
    private let client: any MoleClientProtocol

    public init(client: (any MoleClientProtocol)? = nil) {
        self.client = client ?? RealMoleClient()
    }

    public var isScanning: Bool {
        if case .scanning = state { return true }
        return false
    }

    public var isCleaning: Bool {
        if case .cleaning = state { return true }
        return false
    }

    public var scanResult: CleanScanResult? {
        if case .ready(let result, _) = state { return result }
        return nil
    }

    public var selectedCategories: Set<CleanCategoryKind> {
        if case .ready(_, let selected) = state { return selected }
        if case .cleaning(let selected) = state { return selected }
        return []
    }


    public var errorMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    public var selectedTotalBytes: UInt64 {
        guard let categories = scanResult?.categories else { return 0 }
        return categories
            .filter { selectedCategories.contains($0.kind) }
            .totalSizeBytes
    }

    public var formattedSelectedTotalSize: String {
        CleanModelsFormatter.formatBytes(selectedTotalBytes)
    }

    public func toggleCategory(_ category: CleanCategoryKind) {
        guard case .ready(let result, var selected) = state else { return }
        if selected.contains(category) {
            selected.remove(category)
        } else {
            selected.insert(category)
        }
        state = .ready(result: result, selectedCategories: selected)
    }

    public func selectAll() {
        guard case .ready(let result, _) = state else { return }
        let allKinds = Set(result.categories.map(\.kind))
        state = .ready(result: result, selectedCategories: allKinds)
    }

    public func deselectAll() {
        guard case .ready(let result, _) = state else { return }
        state = .ready(result: result, selectedCategories: [])
    }

    public func cancelScan() {
        if isScanning {
            state = .idle
        }
    }

    public func scan() async {
        // Reject invalid transition if already scanning or cleaning
        guard !isScanning && !isCleaning else { return }
        state = .scanning

        do {
            try Task.checkCancellation()
            let result = try await client.scanCleanables()
            try Task.checkCancellation()
            let detected = Set(result.categories.filter { $0.sizeBytes > 0 || $0.itemCount > 0 }.map(\.kind))
            let defaultSelected = detected.isEmpty ? Set(CleanCategoryKind.allCases) : detected
            state = .ready(result: result, selectedCategories: defaultSelected)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func cleanSelected() async {
        guard case .ready(_, let selected) = state, !selected.isEmpty else { return }

        state = .cleaning(selectedCategories: selected)

        do {
            let summary = try await client.performClean(categories: selected)
            self.lastCleanResult = summary
            state = .completed(summary: summary)
            // Auto rescan after cleanup to refresh reclaimable space
            await scan()
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func reset() {
        state = .idle
    }
}

public typealias CleanerService = CleanEngine
