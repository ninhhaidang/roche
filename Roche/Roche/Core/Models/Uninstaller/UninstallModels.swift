import Foundation

// MARK: - Residual Item Kind

public nonisolated enum ResidualItemKind: String, Sendable, Identifiable, Equatable, Codable, CaseIterable {
    case binary = "binary"
    case applicationSupport = "application_support"
    case cache = "cache"
    case preferences = "preferences"
    case launchAgent = "launch_agent"
    case containers = "containers"
    case logs = "logs"
    case other = "other"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .binary: return "Ứng dụng chính"
        case .applicationSupport: return "Dữ liệu hỗ trợ"
        case .cache: return "Bộ nhớ đệm"
        case .preferences: return "Thiết lập cài đặt"
        case .launchAgent: return "Khởi chạy tự động"
        case .containers: return "Dữ liệu vùng chứa"
        case .logs: return "Nhật ký & Báo cáo"
        case .other: return "Tệp liên quan khác"
        }
    }

    public var iconName: String {
        switch self {
        case .binary: return "app.fill"
        case .applicationSupport: return "folder.fill"
        case .cache: return "archivebox.fill"
        case .preferences: return "slider.horizontal.3"
        case .launchAgent: return "gearshape.arrow.triangle.2.circlepath"
        case .containers: return "shippingbox.fill"
        case .logs: return "doc.text.fill"
        case .other: return "doc.fill"
        }
    }
}

// MARK: - Installed Application

public nonisolated struct InstalledApp: Identifiable, Sendable, Equatable, Codable {
    public var id: String {
        bundleId.isEmpty ? path : bundleId
    }

    public let name: String
    public let bundleId: String
    public let source: String // "App", "Homebrew"
    public let uninstallName: String
    public let path: String
    public let size: String

    public var sizeBytes: UInt64 {
        CleanListParser.parseByteString(size)
    }

    public var iconName: String {
        let lower = name.lowercased()
        if lower.contains("code") || lower.contains("studio") {
            return "chevron.left.forwardslash.chevron.right"
        } else if lower.contains("docker") {
            return "shippingbox.fill"
        } else if lower.contains("chrome") || lower.contains("browser") || lower.contains("safari") {
            return "globe"
        } else if lower.contains("ghostty") || lower.contains("terminal") || lower.contains("iterm") {
            return "terminal.fill"
        } else if lower.contains("keka") || lower.contains("zip") || lower.contains("archive") {
            return "archivebox.fill"
        } else if lower.contains("telegram") || lower.contains("chat") || lower.contains("slack") {
            return "bubble.left.and.bubble.right.fill"
        } else if lower.contains("xcode") {
            return "hammer.fill"
        } else if lower.contains("testflight") {
            return "airplane"
        } else {
            return "app.fill"
        }
    }

    public init(
        name: String,
        bundleId: String = "",
        source: String = "App",
        uninstallName: String = "",
        path: String,
        size: String
    ) {
        self.name = name
        self.bundleId = bundleId
        self.source = source
        self.uninstallName = uninstallName.isEmpty ? name : uninstallName
        self.path = path
        self.size = size
    }

    enum CodingKeys: String, CodingKey {
        case name
        case bundleId = "bundle_id"
        case source
        case uninstallName = "uninstall_name"
        case path
        case size
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.bundleId = try container.decodeIfPresent(String.self, forKey: .bundleId) ?? ""
        self.source = try container.decodeIfPresent(String.self, forKey: .source) ?? "App"
        let rawUninstall = try container.decodeIfPresent(String.self, forKey: .uninstallName) ?? ""
        self.uninstallName = rawUninstall.isEmpty ? self.name : rawUninstall
        self.path = try container.decode(String.self, forKey: .path)
        self.size = try container.decode(String.self, forKey: .size)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(bundleId, forKey: .bundleId)
        try container.encode(source, forKey: .source)
        try container.encode(uninstallName, forKey: .uninstallName)
        try container.encode(path, forKey: .path)
        try container.encode(size, forKey: .size)
    }
}

// MARK: - App Residual Item

public nonisolated struct AppResidualItem: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let title: String
    public let path: String
    public let sizeText: String
    public let sizeBytes: UInt64
    public let kind: ResidualItemKind
    public var isSelected: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        path: String,
        sizeText: String,
        sizeBytes: UInt64 = 0,
        kind: ResidualItemKind,
        isSelected: Bool = true
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.sizeText = sizeText
        self.sizeBytes = sizeBytes == 0 ? CleanListParser.parseByteString(sizeText) : sizeBytes
        self.kind = kind
        self.isSelected = isSelected
    }
}

// MARK: - App Uninstall Preview

public nonisolated struct AppUninstallPreview: Identifiable, Sendable, Equatable, Codable {
    public var id: String { app.id }
    public let app: InstalledApp
    public var residuals: [AppResidualItem]
    public let totalSizeBytes: UInt64
    public let totalSizeText: String

    public var selectedSizeBytes: UInt64 {
        residuals.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }

    public var selectedSizeText: String {
        CleanModelsFormatter.formatBytes(selectedSizeBytes)
    }

    public var selectedItemCount: Int {
        residuals.filter { $0.isSelected }.count
    }

    public init(
        app: InstalledApp,
        residuals: [AppResidualItem],
        totalSizeBytes: UInt64? = nil,
        totalSizeText: String? = nil
    ) {
        self.app = app
        self.residuals = residuals
        let computedBytes = residuals.reduce(UInt64(0)) { $0 + $1.sizeBytes }
        self.totalSizeBytes = totalSizeBytes ?? computedBytes
        self.totalSizeText = totalSizeText ?? CleanModelsFormatter.formatBytes(self.totalSizeBytes)
    }

    enum CodingKeys: String, CodingKey {
        case app
        case residuals
        case totalSizeBytes
        case totalSizeText
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.app = try container.decode(InstalledApp.self, forKey: .app)
        self.residuals = try container.decode([AppResidualItem].self, forKey: .residuals)
        self.totalSizeBytes = try container.decode(UInt64.self, forKey: .totalSizeBytes)
        self.totalSizeText = try container.decode(String.self, forKey: .totalSizeText)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(app, forKey: .app)
        try container.encode(residuals, forKey: .residuals)
        try container.encode(totalSizeBytes, forKey: .totalSizeBytes)
        try container.encode(totalSizeText, forKey: .totalSizeText)
    }
}
