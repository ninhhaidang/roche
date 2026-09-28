import Foundation

public nonisolated struct BatteryStatus: Codable, Sendable {
    public let percent: Double
    public let status: String
    public let timeLeft: String?
    public let health: String?
    public let cycleCount: Int?
    public let capacity: Int?

    enum CodingKeys: String, CodingKey {
        case percent, status
        case timeLeft = "time_left"
        case health
        case cycleCount = "cycle_count"
        case capacity
    }
}

public nonisolated struct ThermalStatus: Codable, Sendable {
    public let cpuTemp: Double?
    public let gpuTemp: Double?
    public let batteryTemp: Double?
    public let fanSpeed: Int?
    public let fanCount: Int?
    public let systemPower: Double?
    public let adapterPower: Double?
    public let batteryPower: Double?

    enum CodingKeys: String, CodingKey {
        case cpuTemp = "cpu_temp"
        case gpuTemp = "gpu_temp"
        case batteryTemp = "battery_temp"
        case fanSpeed = "fan_speed"
        case fanCount = "fan_count"
        case systemPower = "system_power"
        case adapterPower = "adapter_power"
        case batteryPower = "battery_power"
    }
}

public nonisolated struct SensorReading: Codable, Sendable {
    public let label: String
    public let value: Double
}
