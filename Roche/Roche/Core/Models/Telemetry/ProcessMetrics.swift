import Foundation

public nonisolated struct MoleProcessInfo: Codable, Sendable, Identifiable {
    public var id: Int { pid }
    public let pid: Int
    public let ppid: Int
    public let name: String
    public let command: String
    public let cpu: Double
    public let memory: Double
    public let memoryBytes: UInt64?

    enum CodingKeys: String, CodingKey {
        case pid, ppid, name, command, cpu, memory
        case memoryBytes = "memory_bytes"
    }
}

public nonisolated struct ProcessAlert: Codable, Sendable, Identifiable {
    public var id: String { "\(pid)-\(reason)" }
    public let pid: Int
    public let name: String
    public let reason: String
}

public nonisolated struct ZombieParent: Codable, Sendable, Identifiable {
    public var id: Int { pid }
    public let pid: Int
    public let name: String
    public let count: Int
}
