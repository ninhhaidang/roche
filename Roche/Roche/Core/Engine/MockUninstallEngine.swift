import Foundation

// MARK: - Mock Uninstall Engine

public final nonisolated class MockUninstallEngine: UninstallEngineProtocol, @unchecked Sendable {
    public var mockApps: [InstalledApp]
    public var mockPreviews: [String: AppUninstallPreview]
    public var simulatedDelay: TimeInterval
    public var simulatedError: Error?

    public init(
        mockApps: [InstalledApp]? = nil,
        mockPreviews: [String: AppUninstallPreview]? = nil,
        simulatedDelay: TimeInterval = 0.0,
        simulatedError: Error? = nil
    ) {
        let apps = mockApps ?? Self.defaultSampleApps
        self.mockApps = apps
        self.mockPreviews = mockPreviews ?? Self.defaultSamplePreviews(for: apps)
        self.simulatedDelay = simulatedDelay
        self.simulatedError = simulatedError
    }

    public func listInstalledApps() async throws -> [InstalledApp] {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        if let error = simulatedError {
            throw error
        }
        return mockApps
    }

    public func inspectApp(app: InstalledApp) async throws -> AppUninstallPreview {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        if let error = simulatedError {
            throw error
        }

        if let existing = mockPreviews[app.id] ?? mockPreviews[app.name] {
            return existing
        }

        // Generate realistic dynamic residuals if app is not pre-canned
        let binaryItem = AppResidualItem(
            title: (app.path as NSString).lastPathComponent,
            path: app.path,
            sizeText: app.size,
            sizeBytes: app.sizeBytes,
            kind: .binary,
            isSelected: true
        )

        let cacheItem = AppResidualItem(
            title: "Caches (\(app.name))",
            path: "~/Library/Caches/\(app.bundleId.isEmpty ? app.name : app.bundleId)",
            sizeText: "12.5 MB",
            sizeBytes: 12_500_000,
            kind: .cache,
            isSelected: true
        )

        return AppUninstallPreview(
            app: app,
            residuals: [binaryItem, cacheItem]
        )
    }

    // MARK: - Pre-canned Mock Data

    public static let defaultSampleApps: [InstalledApp] = [
        InstalledApp(
            name: "Docker",
            bundleId: "com.docker.docker",
            source: "App",
            uninstallName: "Docker",
            path: "/Applications/Docker.app",
            size: "2.30 GB"
        ),
        InstalledApp(
            name: "Google Chrome",
            bundleId: "com.google.Chrome",
            source: "App",
            uninstallName: "Google Chrome",
            path: "/Applications/Google Chrome.app",
            size: "2.25 GB"
        ),
        InstalledApp(
            name: "Visual Studio Code",
            bundleId: "com.microsoft.VSCode",
            source: "App",
            uninstallName: "Code",
            path: "/Applications/Visual Studio Code.app",
            size: "898 MB"
        ),
        InstalledApp(
            name: "Ghostty",
            bundleId: "com.mitchellh.ghostty",
            source: "Homebrew",
            uninstallName: "ghostty",
            path: "/Applications/Ghostty.app",
            size: "65.0 MB"
        ),
        InstalledApp(
            name: "Keka",
            bundleId: "com.aone.keka",
            source: "App",
            uninstallName: "Keka",
            path: "/Applications/Keka.app",
            size: "38.3 MB"
        ),
        InstalledApp(
            name: "Tinycast",
            bundleId: "com.tinycast.app",
            source: "App",
            uninstallName: "Tinycast",
            path: "/Applications/Tinycast.app",
            size: "13.9 MB"
        )
    ]

    public static func defaultSamplePreviews(for apps: [InstalledApp]) -> [String: AppUninstallPreview] {
        var previews: [String: AppUninstallPreview] = [:]

        // Docker
        if let docker = apps.first(where: { $0.name == "Docker" }) {
            let dockerResiduals = [
                AppResidualItem(title: "Docker.app", path: "/Applications/Docker.app", sizeText: "2.10 GB", sizeBytes: 2_254_857_830, kind: .binary, isSelected: true),
                AppResidualItem(title: "Docker VM Caches", path: "~/Library/Caches/com.docker.docker", sizeText: "180 MB", sizeBytes: 188_743_680, kind: .cache, isSelected: true),
                AppResidualItem(title: "Containers & Volumes", path: "~/Library/Containers/com.docker.docker", sizeText: "20 MB", sizeBytes: 20_971_520, kind: .applicationSupport, isSelected: true),
                AppResidualItem(title: "Docker Helper plist", path: "~/Library/LaunchAgents/com.docker.helper.plist", sizeText: "4 KB", sizeBytes: 4_096, kind: .launchAgent, isSelected: true)
            ]
            previews[docker.id] = AppUninstallPreview(app: docker, residuals: dockerResiduals)
        }

        // Visual Studio Code
        if let vscode = apps.first(where: { $0.name == "Visual Studio Code" }) {
            let vscodeResiduals = [
                AppResidualItem(title: "Visual Studio Code.app", path: "/Applications/Visual Studio Code.app", sizeText: "420 MB", sizeBytes: 440_401_920, kind: .binary, isSelected: true),
                AppResidualItem(title: "Extension Caches", path: "~/Library/Caches/com.microsoft.VSCode", sizeText: "460 MB", sizeBytes: 482_344_960, kind: .cache, isSelected: true),
                AppResidualItem(title: "User Settings", path: "~/Library/Application Support/Code/User", sizeText: "18 MB", sizeBytes: 18_874_368, kind: .applicationSupport, isSelected: true)
            ]
            previews[vscode.id] = AppUninstallPreview(app: vscode, residuals: vscodeResiduals)
        }

        // Google Chrome
        if let chrome = apps.first(where: { $0.name == "Google Chrome" }) {
            let chromeResiduals = [
                AppResidualItem(title: "Google Chrome.app", path: "/Applications/Google Chrome.app", sizeText: "540 MB", sizeBytes: 566_231_040, kind: .binary, isSelected: true),
                AppResidualItem(title: "GPU & Service Cache", path: "~/Library/Caches/Google/Chrome", sizeText: "1.68 GB", sizeBytes: 1_803_886_264, kind: .cache, isSelected: true),
                AppResidualItem(title: "Profile Preferences", path: "~/Library/Application Support/Google/Chrome", sizeText: "30 MB", sizeBytes: 31_457_280, kind: .applicationSupport, isSelected: true)
            ]
            previews[chrome.id] = AppUninstallPreview(app: chrome, residuals: chromeResiduals)
        }

        // Ghostty
        if let ghostty = apps.first(where: { $0.name == "Ghostty" }) {
            let ghosttyResiduals = [
                AppResidualItem(title: "Ghostty.app", path: "/Applications/Ghostty.app", sizeText: "64.2 MB", sizeBytes: 67_318_579, kind: .binary, isSelected: true),
                AppResidualItem(title: "Config & Shaders", path: "~/Library/Application Support/com.mitchellh.ghostty", sizeText: "800 KB", sizeBytes: 819_200, kind: .applicationSupport, isSelected: true)
            ]
            previews[ghostty.id] = AppUninstallPreview(app: ghostty, residuals: ghosttyResiduals)
        }

        // Keka
        if let keka = apps.first(where: { $0.name == "Keka" }) {
            let kekaResiduals = [
                AppResidualItem(title: "Keka.app", path: "/Applications/Keka.app", sizeText: "37.5 MB", sizeBytes: 39_321_600, kind: .binary, isSelected: true),
                AppResidualItem(title: "Extraction Sandbox", path: "~/Library/Containers/com.aone.keka", sizeText: "800 KB", sizeBytes: 819_200, kind: .containers, isSelected: true)
            ]
            previews[keka.id] = AppUninstallPreview(app: keka, residuals: kekaResiduals)
        }

        // Tinycast
        if let tinycast = apps.first(where: { $0.name == "Tinycast" }) {
            let tinycastResiduals = [
                AppResidualItem(title: "Tinycast.app", path: "/Applications/Tinycast.app", sizeText: "13.9 MB", sizeBytes: 14_575_206, kind: .binary, isSelected: true)
            ]
            previews[tinycast.id] = AppUninstallPreview(app: tinycast, residuals: tinycastResiduals)
        }

        return previews
    }
}
