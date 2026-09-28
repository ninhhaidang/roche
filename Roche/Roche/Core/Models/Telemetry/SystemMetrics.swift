import Foundation

public nonisolated struct CPUStatus: Codable, Sendable {
    public let usage: Double
    public let perCore: [Double]?
    public let perCoreEstimated: Bool?
    public let load1: Double
    public let load5: Double
    public let load15: Double
    public let coreCount: Int
    public let logicalCpu: Int
    public let pCoreCount: Int?
    public let eCoreCount: Int?

    enum CodingKeys: String, CodingKey {
        case usage
        case perCore = "per_core"
        case perCoreEstimated = "per_core_estimated"
        case load1, load5, load15
        case coreCount = "core_count"
        case logicalCpu = "logical_cpu"
        case pCoreCount = "p_core_count"
        case eCoreCount = "e_core_count"
    }
}

public nonisolated struct GPUStatus: Codable, Sendable {
    public let name: String
    public let usage: Double
    public let memoryUsed: Double
    public let memoryTotal: Double
    public let coreCount: Int
    public let note: String?

    enum CodingKeys: String, CodingKey {
        case name, usage
        case memoryUsed = "memory_used"
        case memoryTotal = "memory_total"
        case coreCount = "core_count"
        case note
    }
}

public nonisolated struct MemoryStatus: Codable, Sendable {
    public let used: UInt64
    public let total: UInt64
    public let available: UInt64
    public let usedPercent: Double
    public let swapUsed: UInt64
    public let swapTotal: UInt64
    public let cached: UInt64
    public let pressure: String

    enum CodingKeys: String, CodingKey {
        case used, total, available
        case usedPercent = "used_percent"
        case swapUsed = "swap_used"
        case swapTotal = "swap_total"
        case cached, pressure
    }
}

public nonisolated struct DiskStatus: Codable, Sendable {
    public let mount: String
    public let device: String
    public let used: UInt64
    public let total: UInt64
    public let usedPercent: Double
    public let fstype: String
    public let external: Bool
    public let smartStatus: String?
    public let purgeable: UInt64?

    enum CodingKeys: String, CodingKey {
        case mount, device, used, total
        case usedPercent = "used_percent"
        case fstype, external
        case smartStatus = "smart_status"
        case purgeable
    }
}

public nonisolated struct DiskIOStatus: Codable, Sendable {
    public let readRate: Double
    public let writeRate: Double

    enum CodingKeys: String, CodingKey {
        case readRate = "read_rate"
        case writeRate = "write_rate"
    }
}

public nonisolated struct NetworkStatus: Codable, Sendable {
    public let name: String
    public let rxRateMBs: Double
    public let txRateMBs: Double
    public let ip: String?

    enum CodingKeys: String, CodingKey {
        case name
        case rxRateMBs = "rx_rate_mbs"
        case txRateMBs = "tx_rate_mbs"
        case ip
    }
}
