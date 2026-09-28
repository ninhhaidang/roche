import Foundation

public nonisolated final class MockMoleClient: MoleClientProtocol, Sendable {
    public let shouldThrowError: Bool
    public let mockSnapshot: MetricsSnapshot
    public let mockEngineInfo: MoleEngineInfo

    public init(
        shouldThrowError: Bool = false,
        mockSnapshot: MetricsSnapshot = MockMoleClient.sampleSnapshot,
        mockEngineInfo: MoleEngineInfo = MoleEngineInfo(
            source: .embedded,
            executablePath: "/Applications/Roche.app/Contents/Resources/mole/bin/status-go",
            version: "1.56.1 (Mock arm64)"
        )
    ) {
        self.shouldThrowError = shouldThrowError
        self.mockSnapshot = mockSnapshot
        self.mockEngineInfo = mockEngineInfo
    }

    public var engineInfo: MoleEngineInfo {
        mockEngineInfo
    }

    public func fetchMetrics() async throws -> MetricsSnapshot {
        // Small artificial delay to simulate async fetching
        try await Task.sleep(nanoseconds: 300_000_000)

        if shouldThrowError {
            throw MoleError.executableNotFound
        }

        return mockSnapshot
    }

    public func scanCleanables() async throws -> CleanScanResult {
        try await Task.sleep(nanoseconds: 400_000_000)
        if shouldThrowError {
            throw MoleError.executableNotFound
        }
        return MockMoleClient.sampleScanResult
    }

    public func performClean(categories: Set<CleanCategoryKind>) async throws -> CleanExecutionResult {
        try await Task.sleep(nanoseconds: 600_000_000)
        if shouldThrowError {
            throw MoleError.processExecutionFailed(exitCode: 1, stderr: "Mock cleaning error")
        }

        let reclaimed = MockMoleClient.sampleScanResult.categories
            .filter { categories.contains($0.type) }
            .reduce(UInt64(0)) { $0 + $1.sizeBytes }

        let itemsCount = MockMoleClient.sampleScanResult.categories
            .filter { categories.contains($0.type) }
            .reduce(0) { $0 + $1.itemCount }

        return CleanExecutionResult(
            reclaimedBytes: reclaimed,
            cleanedCategories: Array(categories),
            itemsRemovedCount: itemsCount,
            cleanedAt: Date(),
            message: "Đã dọn dẹp thành công \(itemsCount) mục và giải phóng dung lượng."
        )
    }

    public static let sampleScanResult = CleanScanResult(
        categories: [
            CleanCategory(
                type: .dev,
                sizeBytes: 3_670_000_000,
                itemCount: 84,
                items: [
                    CleanItem(path: "/Users/dev/Library/Developer/Xcode/DerivedData", name: "Xcode DerivedData", sizeBytes: 1_850_000_000, details: "7 projects"),
                    CleanItem(path: "/Users/dev/.npm/_cacache", name: "npm cache", sizeBytes: 1_210_000_000, details: "Content cache"),
                    CleanItem(path: "/Users/dev/.cargo/registry/cache", name: "Cargo cache", sizeBytes: 380_000_000, details: "Crates registry"),
                    CleanItem(path: "/var/folders/C/clang/ModuleCache", name: "Clang module cache", sizeBytes: 230_000_000, details: "C/C++ precompiled modules")
                ],
                isSelected: true
            ),
            CleanCategory(
                type: .appCaches,
                sizeBytes: 2_310_000_000,
                itemCount: 142,
                items: [
                    CleanItem(path: "/Users/dev/Library/Caches/Google/Chrome", name: "Google Chrome Cache", sizeBytes: 1_450_000_000, details: "Web caches & profiles"),
                    CleanItem(path: "/Users/dev/Library/Caches/GeoServices", name: "Maps GeoServices Tile Cache", sizeBytes: 520_000_000, details: "Offline map tiles"),
                    CleanItem(path: "/Users/dev/Library/Caches/com.apple.helpd", name: "macOS Help System Cache", sizeBytes: 340_000_000, details: "Help docs cache")
                ],
                isSelected: true
            ),
            CleanCategory(
                type: .logs,
                sizeBytes: 280_000_000,
                itemCount: 65,
                items: [
                    CleanItem(path: "/Users/dev/Library/Logs/DiagnosticReports", name: "Diagnostic & Crash Reports", sizeBytes: 145_000_000, details: "System crash logs"),
                    CleanItem(path: "/Users/dev/Library/Logs/CoreSimulator", name: "CoreSimulator Logs", sizeBytes: 85_000_000, details: "Simulator runtime logs"),
                    CleanItem(path: "/Users/dev/Library/Logs/CreativeCloud", name: "Creative Cloud Logs", sizeBytes: 50_000_000, details: "Updater logs")
                ],
                isSelected: true
            ),
            CleanCategory(
                type: .trash,
                sizeBytes: 1_240_000_000,
                itemCount: 18,
                items: [
                    CleanItem(path: "/Users/dev/.Trash/Old-Project-Backup.zip", name: "Old-Project-Backup.zip", sizeBytes: 780_000_000, details: "Zip archive"),
                    CleanItem(path: "/Users/dev/.Trash/Installer.dmg", name: "Installer.dmg", sizeBytes: 460_000_000, details: "Disk image")
                ],
                isSelected: true
            )
        ],
        totalSizeBytes: 7_500_000_000,
        totalItemsCount: 309,
        scannedAt: Date()
    )

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
