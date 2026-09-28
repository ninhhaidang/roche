import Foundation
import Observation

@MainActor
@Observable
public final class CleanerService {
    public private(set) var scanResult: CleanScanResult?
    public private(set) var isScanning: Bool = false
    public private(set) var isCleaning: Bool = false
    public var selectedCategories: Set<CleanCategoryKind> = Set(CleanCategoryKind.allCases)
    public private(set) var lastCleanResult: CleanExecutionResult?
    public private(set) var errorMessage: String?

    private let client: MoleClientProtocol

    public init(client: MoleClientProtocol? = nil) {
        self.client = client ?? RealMoleClient()
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
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    public func selectAll() {
        selectedCategories = Set(CleanCategoryKind.allCases)
    }

    public func deselectAll() {
        selectedCategories.removeAll()
    }

    public func scan() async {
        isScanning = true
        errorMessage = nil
        lastCleanResult = nil

        do {
            let result = try await client.scanCleanables()
            self.scanResult = result
            // Auto-select all detected categories that have items/size
            self.selectedCategories = Set(result.categories.filter { $0.sizeBytes > 0 || $0.itemCount > 0 }.map(\.kind))
            if self.selectedCategories.isEmpty {
                self.selectedCategories = Set(CleanCategoryKind.allCases)
            }
            self.isScanning = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isScanning = false
        }
    }

    public func cleanSelected() async {
        guard !selectedCategories.isEmpty else { return }

        isCleaning = true
        errorMessage = nil

        do {
            let result = try await client.performClean(categories: selectedCategories)
            self.lastCleanResult = result
            self.isCleaning = false

            // Automatically re-scan after cleanup to refresh reclaimable space
            await scan()
        } catch {
            self.errorMessage = error.localizedDescription
            self.isCleaning = false
        }
    }
}
