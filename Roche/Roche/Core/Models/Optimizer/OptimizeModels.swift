import Foundation

// MARK: - Optimize Task Category

public nonisolated enum OptimizeTaskCategory: String, CaseIterable, Identifiable, Equatable, Codable, Sendable {
    case systemAndSearch = "Hệ thống & Tìm kiếm"
    case cacheAndFinder = "Bộ nhớ đệm & Finder"
    case networkAndData = "Mạng & Dữ liệu"
    case configAndSecurity = "Cấu hình & Bảo mật"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public var iconName: String {
        switch self {
        case .systemAndSearch: return "magnifyingglass.circle.fill"
        case .cacheAndFinder: return "internaldrive.fill"
        case .networkAndData: return "network"
        case .configAndSecurity: return "lock.shield.fill"
        }
    }

    public static func from(identifier: String) -> OptimizeTaskCategory? {
        let normalized = identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch normalized {
        case "systemandsearch", "system_and_search", "system_search", "system":
            return .systemAndSearch
        case "cacheandfinder", "cache_and_finder", "cache_finder", "cache":
            return .cacheAndFinder
        case "networkanddata", "network_and_data", "network_data", "network":
            return .networkAndData
        case "configandsecurity", "config_and_security", "config_security", "config", "security":
            return .configAndSecurity
        default:
            return OptimizeTaskCategory(rawValue: identifier)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let match = OptimizeTaskCategory(rawValue: raw) ?? OptimizeTaskCategory.from(identifier: raw) {
            self = match
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown OptimizeTaskCategory value: '\(raw)'"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Optimize Task Outcome

public nonisolated enum OptimizeTaskOutcome: String, CaseIterable, Identifiable, Equatable, Codable, Sendable {
    case pending = "Chờ xử lý"
    case running = "Đang chạy..."
    case applied = "Đã tối ưu"
    case unchanged = "Đã tối ưu sẵn"
    case attention = "Cần chú ý"
    case skipped = "Bỏ qua"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public var iconName: String {
        switch self {
        case .pending: return "circle.dotted"
        case .running: return "arrow.triangle.2.circlepath"
        case .applied: return "checkmark.circle.fill"
        case .unchanged: return "circle.inset.filled"
        case .attention: return "exclamationmark.triangle.fill"
        case .skipped: return "slash.circle"
        }
    }

    public static func from(keyword: String) -> OptimizeTaskOutcome? {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "applied", "apply", "would apply", "đã tối ưu":
            return .applied
        case "unchanged", "optimal", "already", "đã tối ưu sẵn":
            return .unchanged
        case "attention", "warning", "broken", "cần chú ý":
            return .attention
        case "skipped", "skip", "unavailable", "bỏ qua":
            return .skipped
        case "running", "đang chạy...":
            return .running
        case "pending", "idle", "chờ xử lý":
            return .pending
        default:
            return OptimizeTaskOutcome(rawValue: keyword)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let match = OptimizeTaskOutcome(rawValue: raw) ?? OptimizeTaskOutcome.from(keyword: raw) {
            self = match
        } else {
            self = .pending
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Optimize Task Status

public nonisolated enum OptimizeTaskStatus: String, CaseIterable, Identifiable, Equatable, Codable, Sendable {
    case idle = "idle"
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .idle: return "Chờ thực hiện"
        case .pending: return "Đang chờ"
        case .running: return "Đang chạy"
        case .completed: return "Hoàn tất"
        case .failed: return "Lỗi"
        case .skipped: return "Bỏ qua"
        }
    }
}

// MARK: - Optimize Task

public nonisolated struct OptimizeTask: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let name: String
    public let category: OptimizeTaskCategory
    public var status: OptimizeTaskStatus
    public var outcome: OptimizeTaskOutcome
    public let message: String
    public let details: [String]

    public init(
        id: String = UUID().uuidString,
        name: String,
        category: OptimizeTaskCategory,
        status: OptimizeTaskStatus = .completed,
        outcome: OptimizeTaskOutcome = .unchanged,
        message: String = "",
        details: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.status = status
        self.outcome = outcome
        self.message = message
        self.details = details
    }
}

// MARK: - Optimize Streaming Event & Execution Summary

public nonisolated enum OptimizeTaskEvent: Sendable, Equatable {
    case started(taskName: String, category: OptimizeTaskCategory)
    case line(raw: String)
    case completed(task: OptimizeTask)
    case finished(summary: OptimizeExecutionSummary)
}

public nonisolated struct OptimizeExecutionSummary: Sendable, Equatable, Codable {
    public let totalTasks: Int
    public let appliedCount: Int
    public let unchangedCount: Int
    public let attentionCount: Int
    public let skippedCount: Int
    public let failedCount: Int
    public let isDryRun: Bool

    public init(
        totalTasks: Int = 20,
        appliedCount: Int = 0,
        unchangedCount: Int = 0,
        attentionCount: Int = 0,
        skippedCount: Int = 0,
        failedCount: Int = 0,
        isDryRun: Bool = false
    ) {
        self.totalTasks = totalTasks
        self.appliedCount = appliedCount
        self.unchangedCount = unchangedCount
        self.attentionCount = attentionCount
        self.skippedCount = skippedCount
        self.failedCount = failedCount
        self.isDryRun = isDryRun
    }

    public var displayText: String {
        if isDryRun {
            return "Mô phỏng hoàn tất: \(appliedCount) có thể tối ưu, \(unchangedCount) đã tối ưu sẵn, \(attentionCount) cần chú ý, \(skippedCount) bỏ qua"
        } else {
            return "Tối ưu hóa hoàn tất: \(appliedCount) đã tối ưu, \(unchangedCount) đã tối ưu sẵn, \(attentionCount) cần chú ý, \(skippedCount) bỏ qua\(failedCount > 0 ? ", \(failedCount) lỗi" : "")"
        }
    }
}

// MARK: - Diagnosis Severity

public nonisolated enum DiagnosisSeverity: String, CaseIterable, Identifiable, Equatable, Codable, Sendable {
    case nominal = "nominal"
    case moderate = "moderate"
    case severe = "severe"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .nominal: return "Bình thường"
        case .moderate: return "Đáng chú ý"
        case .severe: return "Nghiêm trọng"
        }
    }
}

// MARK: - System Diagnosis

public nonisolated struct SystemDiagnosis: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let component: String
    public let description: String
    public let recommendation: String
    public let severity: DiagnosisSeverity
    public let cpuUsagePercent: Double?
    public let hasBottleneck: Bool
    public let tasks: [OptimizeTask]
    public let rawOutput: String?

    public init(
        id: String = UUID().uuidString,
        component: String,
        description: String,
        recommendation: String,
        severity: DiagnosisSeverity,
        cpuUsagePercent: Double? = nil,
        hasBottleneck: Bool = false,
        tasks: [OptimizeTask] = [],
        rawOutput: String? = nil
    ) {
        self.id = id
        self.component = component
        self.description = description
        self.recommendation = recommendation
        self.severity = severity
        self.cpuUsagePercent = cpuUsagePercent
        self.hasBottleneck = hasBottleneck
        self.tasks = tasks
        self.rawOutput = rawOutput
    }

    public func with(tasks: [OptimizeTask]) -> SystemDiagnosis {
        SystemDiagnosis(
            id: id,
            component: component,
            description: description,
            recommendation: recommendation,
            severity: severity,
            cpuUsagePercent: cpuUsagePercent,
            hasBottleneck: hasBottleneck,
            tasks: tasks,
            rawOutput: rawOutput
        )
    }
}
