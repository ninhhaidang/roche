import Foundation

public nonisolated enum CleanCategoryKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case dev = "dev"
    case appCaches = "app_caches"
    case logs = "logs"
    case trash = "trash"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dev:
            return "Developer Tools"
        case .appCaches:
            return "App Caches"
        case .logs:
            return "Hệ Thống & Logs"
        case .trash:
            return "Thùng Rác (Trash)"
        }
    }

    public var subtitle: String {
        switch self {
        case .dev:
            return "Xcode DerivedData, npm, cargo, pip, build caches"
        case .appCaches:
            return "Bộ nhớ đệm ứng dụng, web browser caches, media caches"
        case .logs:
            return "Nhật ký hệ thống, diagnostic reports, crash logs"
        case .trash:
            return "Tệp tin trong thư mục Thùng rác (~/.Trash)"
        }
    }

    public var iconName: String {
        switch self {
        case .dev:
            return "hammer.fill"
        case .appCaches:
            return "app.badge.fill"
        case .logs:
            return "doc.text.fill"
        case .trash:
            return "trash.fill"
        }
    }
}

public typealias CleanCategoryType = CleanCategoryKind

public nonisolated struct CleanItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let path: String
    public let name: String
    public let sizeBytes: UInt64
    public let details: String?

    public var formattedSize: String {
        CleanModelsFormatter.formatBytes(sizeBytes)
    }

    public init(id: String = UUID().uuidString, path: String, name: String? = nil, sizeBytes: UInt64, details: String? = nil) {
        self.id = id
        self.path = path
        self.name = name ?? (URL(fileURLWithPath: path).lastPathComponent)
        self.sizeBytes = sizeBytes
        self.details = details
    }
}

public nonisolated struct CleanCategory: Identifiable, Codable, Sendable, Equatable {
    public var id: CleanCategoryKind { kind }
    public let kind: CleanCategoryKind
    public var type: CleanCategoryKind { kind }
    public var name: String { kind.title }
    public var subtitle: String { kind.subtitle }
    public var iconName: String { kind.iconName }
    public let sizeBytes: UInt64
    public let itemCount: Int
    public let items: [CleanItem]
    public var isSelected: Bool

    public var formattedSize: String {
        CleanModelsFormatter.formatBytes(sizeBytes)
    }

    public init(
        kind: CleanCategoryKind,
        sizeBytes: UInt64? = nil,
        itemCount: Int? = nil,
        items: [CleanItem] = [],
        isSelected: Bool = true
    ) {
        self.kind = kind
        self.items = items
        self.sizeBytes = sizeBytes ?? items.totalSizeBytes
        self.itemCount = itemCount ?? items.count
        self.isSelected = isSelected
    }

    public init(
        type: CleanCategoryKind,
        sizeBytes: UInt64,
        itemCount: Int,
        items: [CleanItem] = [],
        isSelected: Bool = true
    ) {
        self.init(kind: type, sizeBytes: sizeBytes, itemCount: itemCount, items: items, isSelected: isSelected)
    }
}

public nonisolated struct CleanScanResult: Sendable, Equatable {
    public let categories: [CleanCategory]
    public let totalSizeBytes: UInt64
    public let totalItemsCount: Int
    public let scannedAt: Date

    public var formattedTotalSize: String {
        CleanModelsFormatter.formatBytes(totalSizeBytes)
    }

    public init(
        categories: [CleanCategory],
        totalSizeBytes: UInt64? = nil,
        totalItemsCount: Int? = nil,
        scannedAt: Date = Date()
    ) {
        self.categories = categories
        self.totalSizeBytes = totalSizeBytes ?? categories.totalSizeBytes
        self.totalItemsCount = totalItemsCount ?? categories.totalItemCount
        self.scannedAt = scannedAt
    }
}

public nonisolated struct CleanExecutionResult: Sendable, Equatable {
    public let reclaimedBytes: UInt64
    public let cleanedCategories: [CleanCategoryKind]
    public let itemsRemovedCount: Int
    public let cleanedAt: Date
    public let message: String

    public var formattedReclaimedSize: String {
        CleanModelsFormatter.formatBytes(reclaimedBytes)
    }

    public init(
        reclaimedBytes: UInt64,
        cleanedCategories: [CleanCategoryKind],
        itemsRemovedCount: Int,
        cleanedAt: Date = Date(),
        message: String = "Dọn dẹp hoàn tất thành công"
    ) {
        self.reclaimedBytes = reclaimedBytes
        self.cleanedCategories = cleanedCategories
        self.itemsRemovedCount = itemsRemovedCount
        self.cleanedAt = cleanedAt
        self.message = message
    }
}

public nonisolated enum CleanModelsFormatter: Sendable {
    public static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Collection Extensions (Encapsulate Size Aggregation)

extension Collection where Element == CleanItem {
    public nonisolated var totalSizeBytes: UInt64 {
        reduce(0) { $0 + $1.sizeBytes }
    }

    public nonisolated var formattedTotalSize: String {
        CleanModelsFormatter.formatBytes(totalSizeBytes)
    }
}

extension Collection where Element == CleanCategory {
    public nonisolated var totalSizeBytes: UInt64 {
        reduce(0) { $0 + $1.sizeBytes }
    }

    public nonisolated var totalItemCount: Int {
        reduce(0) { $0 + $1.itemCount }
    }

    public nonisolated var formattedTotalSize: String {
        CleanModelsFormatter.formatBytes(totalSizeBytes)
    }
}
