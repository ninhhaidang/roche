import Foundation

public nonisolated struct MetricsSnapshot: Codable, Sendable {
    public let collectedAt: String?
    public let host: String
    public let platform: String
    public let uptime: String
    public let uptimeSeconds: UInt64
    public let procs: UInt64
    public let hardware: HardwareInfo
    public let healthScore: Int
    public let healthScoreMsg: String

    public let cpu: CPUStatus
    public let gpu: [GPUStatus]?
    public let memory: MemoryStatus
    public let disks: [DiskStatus]?
    public let trashSize: UInt64?
    public let trashApprox: Bool?
    public let diskIo: DiskIOStatus?
    public let network: [NetworkStatus]?
    public let batteries: [BatteryStatus]?
    public let thermal: ThermalStatus?
    public let topProcesses: [MoleProcessInfo]?
    public let zombieCount: Int?
    public let zombieParents: [ZombieParent]?
    public let processAlerts: [ProcessAlert]?

    enum CodingKeys: String, CodingKey {
        case collectedAt = "collected_at"
        case host, platform, uptime
        case uptimeSeconds = "uptime_seconds"
        case procs, hardware
        case healthScore = "health_score"
        case healthScoreMsg = "health_score_msg"
        case cpu, gpu, memory, disks
        case trashSize = "trash_size"
        case trashApprox = "trash_approx"
        case diskIo = "disk_io"
        case network, batteries, thermal
        case topProcesses = "top_processes"
        case zombieCount = "zombie_count"
        case zombieParents = "zombie_parents"
        case processAlerts = "process_alerts"
    }
}

public nonisolated struct HardwareInfo: Codable, Sendable {
    public let model: String
    public let cpuModel: String
    public let totalRam: String
    public let diskSize: String
    public let osVersion: String
    public let refreshRate: String?

    enum CodingKeys: String, CodingKey {
        case model
        case cpuModel = "cpu_model"
        case totalRam = "total_ram"
        case diskSize = "disk_size"
        case osVersion = "os_version"
        case refreshRate = "refresh_rate"
    }
}
