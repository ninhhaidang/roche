import Foundation

public nonisolated final class MockMoleClient: MoleClientProtocol, Sendable {
    public let shouldThrowError: Bool
    public let mockSnapshot: MetricsSnapshot

    public init(
        shouldThrowError: Bool = false,
        mockSnapshot: MetricsSnapshot = MockMoleClient.sampleSnapshot
    ) {
        self.shouldThrowError = shouldThrowError
        self.mockSnapshot = mockSnapshot
    }

    public func fetchMetrics() async throws -> MetricsSnapshot {
        // Small artificial delay to simulate async fetching
        try await Task.sleep(nanoseconds: 300_000_000)

        if shouldThrowError {
            throw MoleError.executableNotFound
        }

        return mockSnapshot
    }

    public static let sampleSnapshot = MetricsSnapshot(
        collectedAt: "2026-09-29T00:00:00.000Z",
        host: "macbook-pro.local",
        platform: "darwin 27.0",
        uptime: "2d 5h",
        uptimeSeconds: 190800,
        procs: 482,
        hardware: HardwareInfo(
            model: "MacBook Pro (14-inch, 2021)",
            cpuModel: "Apple M1 Pro",
            totalRam: "16.0 GB",
            diskSize: "512.0 GB",
            osVersion: "macOS 27.0",
            refreshRate: "120Hz"
        ),
        healthScore: 94,
        healthScoreMsg: "Excellent",
        cpu: CPUStatus(
            usage: 14.8,
            perCore: [18.2, 12.4, 15.0, 11.2, 16.5, 9.8, 12.0, 4.2],
            perCoreEstimated: false,
            load1: 2.15,
            load5: 1.84,
            load15: 1.70,
            coreCount: 8,
            logicalCpu: 8,
            pCoreCount: 6,
            eCoreCount: 2
        ),
        gpu: [
            GPUStatus(
                name: "Apple M1 Pro GPU",
                usage: 8.5,
                memoryUsed: 1024,
                memoryTotal: 8192,
                coreCount: 14,
                note: nil
            )
        ],
        memory: MemoryStatus(
            used: 9_800_000_000,
            total: 17_179_869_184,
            available: 7_379_869_184,
            usedPercent: 57.0,
            swapUsed: 0,
            swapTotal: 2_147_483_648,
            cached: 4_200_000_000,
            pressure: "normal"
        ),
        disks: [
            DiskStatus(
                mount: "/",
                device: "/dev/disk3s1",
                used: 180_000_000_000,
                total: 494_000_000_000,
                usedPercent: 36.4,
                fstype: "apfs",
                external: false,
                smartStatus: "Verified",
                purgeable: 14_000_000_000
            )
        ],
        trashSize: 1_240_000_000,
        trashApprox: false,
        diskIo: DiskIOStatus(readRate: 1.2, writeRate: 0.8),
        network: [
            NetworkStatus(name: "en0 (Wi-Fi)", rxRateMBs: 1.4, txRateMBs: 0.3, ip: "192.168.1.50")
        ],
        batteries: [
            BatteryStatus(
                percent: 88.0,
                status: "Discharging",
                timeLeft: "5h 42m",
                health: "Normal",
                cycleCount: 142,
                capacity: 96
            )
        ],
        thermal: ThermalStatus(
            cpuTemp: 44.5,
            gpuTemp: 42.0,
            batteryTemp: 31.0,
            fanSpeed: 0,
            fanCount: 2,
            systemPower: 11.2,
            adapterPower: 0.0,
            batteryPower: 11.2
        ),
        topProcesses: [
            MoleProcessInfo(pid: 842, ppid: 1, name: "Xcode", command: "Xcode.app", cpu: 12.4, memory: 4.8, memoryBytes: 820_000_000),
            MoleProcessInfo(pid: 1290, ppid: 1, name: "WindowServer", command: "WindowServer", cpu: 8.2, memory: 3.1, memoryBytes: 530_000_000),
            MoleProcessInfo(pid: 3201, ppid: 1, name: "Safari", command: "Safari.app", cpu: 4.5, memory: 5.2, memoryBytes: 890_000_000)
        ],
        zombieCount: 0,
        zombieParents: [],
        processAlerts: []
    )
}
