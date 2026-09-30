import Foundation

public nonisolated enum MoleEngineSource: String, Sendable {
    case embedded = "Nhúng sẵn (App Bundle)"
    case homebrew = "Homebrew (/opt/homebrew)"
    case devVendor = "Thư mục vendor/mole"
    case notFound = "Chưa kết nối"
}

public nonisolated struct MoleEngineInfo: Sendable, Equatable {
    public let source: MoleEngineSource
    public let executablePath: String
    public let version: String

    public init(source: MoleEngineSource, executablePath: String, version: String = "1.56.1 (arm64)") {
        self.source = source
        self.executablePath = executablePath
        self.version = version
    }
}

public nonisolated struct ExecutableTarget: Sendable {
    public let url: URL
    public let arguments: [String]

    public init(url: URL, arguments: [String]) {
        self.url = url
        self.arguments = arguments
    }
}

public nonisolated struct MoleExecutableFinder: Sendable {
    public init() {}

    public func currentEngineInfo() -> MoleEngineInfo {
        MoleEngineInfo(
            source: detectEngineSource(),
            executablePath: resolvedExecutablePath(),
            version: detectVersion()
        )
    }

    public func detectEngineSource() -> MoleEngineSource {
        if let target = findStatusExecutable() {
            let path = target.url.path
            if path.contains(".app/Contents/Resources") {
                return .embedded
            } else if path.contains("homebrew") || path.contains("Cellar") {
                return .homebrew
            } else if path.contains("vendor/mole") {
                return .devVendor
            }
            return .embedded
        }
        return .notFound
    }

    public func resolvedExecutablePath() -> String {
        if let target = findStatusExecutable() {
            return target.url.path
        }
        return "Không tìm thấy"
    }

    public func detectVersion() -> String {
        let fileManager = FileManager.default
        let cellarRoots = ["/opt/homebrew/Cellar/mole", "/usr/local/Cellar/mole"]
        for cellar in cellarRoots {
            if let versions = try? fileManager.contentsOfDirectory(atPath: cellar),
               let latest = versions.sorted().reversed().first(where: { !$0.hasPrefix(".") }) {
                return "\(latest) (arm64)"
            }
        }
        return "1.56.1 (arm64)"
    }

    public func findStatusExecutable() -> ExecutableTarget? {
        let fileManager = FileManager.default

        // 1. Embedded inside App Bundle (mole/bin/status-go or mole/mo)
        if let resourceURL = Bundle.main.resourceURL {
            let bundledStatusGo = resourceURL.appendingPathComponent("mole/bin/status-go")
            if fileManager.isExecutableFile(atPath: bundledStatusGo.path) {
                return ExecutableTarget(url: bundledStatusGo, arguments: ["--json"])
            }

            let bundledMo = resourceURL.appendingPathComponent("mole/mo")
            let companionStatusGo = resourceURL.appendingPathComponent("mole/bin/status-go")
            if fileManager.isExecutableFile(atPath: bundledMo.path),
               fileManager.isExecutableFile(atPath: companionStatusGo.path) {
                return ExecutableTarget(url: bundledMo, arguments: ["status", "--json"])
            }
        }

        // 2. Direct status-go or mo in App Bundle root
        if let bundleStatusGo = Bundle.main.url(forResource: "status-go", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundleStatusGo.path) {
            return ExecutableTarget(url: bundleStatusGo, arguments: ["--json"])
        }

        if let bundleMo = Bundle.main.url(forResource: "mo", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundleMo.path),
           let bundleStatusGo = Bundle.main.url(forResource: "status-go", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundleStatusGo.path) {
            return ExecutableTarget(url: bundleMo, arguments: ["status", "--json"])
        }

        // 3. Dynamic Homebrew status-go in Cellar (any installed version)
        let cellarRoots = ["/opt/homebrew/Cellar/mole", "/usr/local/Cellar/mole"]
        for cellar in cellarRoots {
            if let versions = try? fileManager.contentsOfDirectory(atPath: cellar) {
                for ver in versions.sorted().reversed() {
                    let candidate = "\(cellar)/\(ver)/libexec/bin/status-go"
                    if fileManager.isExecutableFile(atPath: candidate) {
                        return ExecutableTarget(url: URL(fileURLWithPath: candidate), arguments: ["--json"])
                    }
                }
            }
        }

        // 4. Standard CLI installations (Homebrew symlink)
        let cliCandidates = [
            "/opt/homebrew/bin/mo",
            "/usr/local/bin/mo",
            "/opt/homebrew/bin/mole",
            "/usr/local/bin/mole"
        ]
        for candidate in cliCandidates {
            if fileManager.isExecutableFile(atPath: candidate) {
                return ExecutableTarget(url: URL(fileURLWithPath: candidate), arguments: ["status", "--json"])
            }
        }

        // 5. Local vendor/mole fallback (Development / Sandbox)
        let devVendorCandidates = [
            "vendor/mole/bin/status-go",
            "../vendor/mole/bin/status-go",
            "vendor/mole/mo",
            "../vendor/mole/mo"
        ]
        for candidate in devVendorCandidates {
            let resolvedPath = URL(fileURLWithPath: candidate).standardized.path
            if fileManager.isExecutableFile(atPath: resolvedPath) {
                let url = URL(fileURLWithPath: resolvedPath)
                if candidate.contains("status-go") {
                    return ExecutableTarget(url: url, arguments: ["--json"])
                } else {
                    let companion = candidate.replacingOccurrences(of: "mo", with: "bin/status-go")
                    let resolvedCompanion = URL(fileURLWithPath: companion).standardized.path
                    if fileManager.isExecutableFile(atPath: resolvedCompanion) {
                        return ExecutableTarget(url: url, arguments: ["status", "--json"])
                    }
                }
            }
        }

        return nil
    }

    public func findCleanExecutable(dryRun: Bool = false) -> ExecutableTarget? {
        let fileManager = FileManager.default
        let cleanArgs = dryRun ? ["clean", "--dry-run"] : ["clean"]

        // 1. Embedded inside App Bundle (mole/mo or mole/bin/clean.sh)
        if let resourceURL = Bundle.main.resourceURL {
            let bundledMo = resourceURL.appendingPathComponent("mole/mo")
            if fileManager.isExecutableFile(atPath: bundledMo.path) {
                return ExecutableTarget(url: bundledMo, arguments: cleanArgs)
            }

            let bundledCleanSh = resourceURL.appendingPathComponent("mole/bin/clean.sh")
            if fileManager.isExecutableFile(atPath: bundledCleanSh.path) {
                return ExecutableTarget(url: bundledCleanSh, arguments: dryRun ? ["--dry-run"] : [])
            }
        }

        // 2. Direct mo in App Bundle root
        if let bundleMo = Bundle.main.url(forResource: "mo", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundleMo.path) {
            return ExecutableTarget(url: bundleMo, arguments: cleanArgs)
        }

        // 3. Dynamic Homebrew clean in Cellar
        let cellarRoots = ["/opt/homebrew/Cellar/mole", "/usr/local/Cellar/mole"]
        for cellar in cellarRoots {
            if let versions = try? fileManager.contentsOfDirectory(atPath: cellar) {
                for ver in versions.sorted().reversed() {
                    let candidate = "\(cellar)/\(ver)/libexec/bin/clean.sh"
                    if fileManager.isExecutableFile(atPath: candidate) {
                        return ExecutableTarget(url: URL(fileURLWithPath: candidate), arguments: dryRun ? ["--dry-run"] : [])
                    }
                }
            }
        }

        // 4. Standard CLI installations (Homebrew symlink)
        let cliCandidates = [
            "/opt/homebrew/bin/mo",
            "/usr/local/bin/mo",
            "/opt/homebrew/bin/mole",
            "/usr/local/bin/mole"
        ]
        for candidate in cliCandidates {
            if fileManager.isExecutableFile(atPath: candidate) {
                return ExecutableTarget(url: URL(fileURLWithPath: candidate), arguments: cleanArgs)
            }
        }

        // 5. Local vendor/mole fallback (Development)
        let devVendorCandidates = [
            "vendor/mole/mo",
            "vendor/mole/bin/clean.sh",
            "../vendor/mole/mo",
            "../vendor/mole/bin/clean.sh"
        ]
        for candidate in devVendorCandidates {
            let resolvedPath = URL(fileURLWithPath: candidate).standardized.path
            if fileManager.isExecutableFile(atPath: resolvedPath) {
                let url = URL(fileURLWithPath: resolvedPath)
                if candidate.contains("clean.sh") {
                    return ExecutableTarget(url: url, arguments: dryRun ? ["--dry-run"] : [])
                } else {
                    return ExecutableTarget(url: url, arguments: cleanArgs)
                }
            }
        }

        return nil
    }

    public func findPurgeExecutable(dryRun: Bool = false) -> ExecutableTarget? {
        let fileManager = FileManager.default
        let purgeArgs = dryRun ? ["purge", "--dry-run"] : ["purge", "--yes"]

        // 1. Embedded inside App Bundle (mole/mo or mole/bin/purge.sh)
        if let resourceURL = Bundle.main.resourceURL {
            let bundledMo = resourceURL.appendingPathComponent("mole/mo")
            if fileManager.isExecutableFile(atPath: bundledMo.path) {
                return ExecutableTarget(url: bundledMo, arguments: purgeArgs)
            }

            let bundledPurgeSh = resourceURL.appendingPathComponent("mole/bin/purge.sh")
            if fileManager.isExecutableFile(atPath: bundledPurgeSh.path) {
                return ExecutableTarget(url: bundledPurgeSh, arguments: dryRun ? ["--dry-run"] : ["--yes"])
            }
        }

        // 2. Direct mo in App Bundle root
        if let bundleMo = Bundle.main.url(forResource: "mo", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundleMo.path) {
            return ExecutableTarget(url: bundleMo, arguments: purgeArgs)
        }

        // 3. Dynamic Homebrew purge in Cellar
        let cellarRoots = ["/opt/homebrew/Cellar/mole", "/usr/local/Cellar/mole"]
        for cellar in cellarRoots {
            if let versions = try? fileManager.contentsOfDirectory(atPath: cellar) {
                for ver in versions.sorted().reversed() {
                    let candidate = "\(cellar)/\(ver)/libexec/bin/purge.sh"
                    if fileManager.isExecutableFile(atPath: candidate) {
                        return ExecutableTarget(url: URL(fileURLWithPath: candidate), arguments: dryRun ? ["--dry-run"] : ["--yes"])
                    }
                }
            }
        }

        // 4. Standard CLI installations (Homebrew symlink)
        let cliCandidates = [
            "/opt/homebrew/bin/mo",
            "/usr/local/bin/mo",
            "/opt/homebrew/bin/mole",
            "/usr/local/bin/mole"
        ]
        for candidate in cliCandidates {
            if fileManager.isExecutableFile(atPath: candidate) {
                return ExecutableTarget(url: URL(fileURLWithPath: candidate), arguments: purgeArgs)
            }
        }

        // 5. Local vendor/mole fallback (Development)
        let devVendorCandidates = [
            "vendor/mole/mo",
            "vendor/mole/bin/purge.sh",
            "../vendor/mole/mo",
            "../vendor/mole/bin/purge.sh"
        ]
        for candidate in devVendorCandidates {
            let resolvedPath = URL(fileURLWithPath: candidate).standardized.path
            if fileManager.isExecutableFile(atPath: resolvedPath) {
                let url = URL(fileURLWithPath: resolvedPath)
                if candidate.contains("purge.sh") {
                    return ExecutableTarget(url: url, arguments: dryRun ? ["--dry-run"] : ["--yes"])
                } else {
                    return ExecutableTarget(url: url, arguments: purgeArgs)
                }
            }
        }

        return nil
    }

    public func findInstallerExecutable(dryRun: Bool = false) -> ExecutableTarget? {
        let fileManager = FileManager.default
        let installerArgs = dryRun ? ["installer", "--dry-run"] : ["installer"]

        // 1. Embedded inside App Bundle (mole/mo or mole/bin/installer.sh)
        if let resourceURL = Bundle.main.resourceURL {
            let bundledMo = resourceURL.appendingPathComponent("mole/mo")
            if fileManager.isExecutableFile(atPath: bundledMo.path) {
                return ExecutableTarget(url: bundledMo, arguments: installerArgs)
            }

            let bundledInstallerSh = resourceURL.appendingPathComponent("mole/bin/installer.sh")
            if fileManager.isExecutableFile(atPath: bundledInstallerSh.path) {
                return ExecutableTarget(url: bundledInstallerSh, arguments: dryRun ? ["--dry-run"] : [])
            }
        }

        // 2. Direct mo in App Bundle root
        if let bundleMo = Bundle.main.url(forResource: "mo", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundleMo.path) {
            return ExecutableTarget(url: bundleMo, arguments: installerArgs)
        }

        // 3. Dynamic Homebrew installer in Cellar
        let cellarRoots = ["/opt/homebrew/Cellar/mole", "/usr/local/Cellar/mole"]
        for cellar in cellarRoots {
            if let versions = try? fileManager.contentsOfDirectory(atPath: cellar) {
                for ver in versions.sorted().reversed() {
                    let candidate = "\(cellar)/\(ver)/libexec/bin/installer.sh"
                    if fileManager.isExecutableFile(atPath: candidate) {
                        return ExecutableTarget(url: URL(fileURLWithPath: candidate), arguments: dryRun ? ["--dry-run"] : [])
                    }
                }
            }
        }

        // 4. Standard CLI installations (Homebrew symlink)
        let cliCandidates = [
            "/opt/homebrew/bin/mo",
            "/usr/local/bin/mo",
            "/opt/homebrew/bin/mole",
            "/usr/local/bin/mole"
        ]
        for candidate in cliCandidates {
            if fileManager.isExecutableFile(atPath: candidate) {
                return ExecutableTarget(url: URL(fileURLWithPath: candidate), arguments: installerArgs)
            }
        }

        // 5. Local vendor/mole fallback (Development)
        let devVendorCandidates = [
            "vendor/mole/mo",
            "vendor/mole/bin/installer.sh",
            "../vendor/mole/mo",
            "../vendor/mole/bin/installer.sh"
        ]
        for candidate in devVendorCandidates {
            let resolvedPath = URL(fileURLWithPath: candidate).standardized.path
            if fileManager.isExecutableFile(atPath: resolvedPath) {
                let url = URL(fileURLWithPath: resolvedPath)
                if candidate.contains("installer.sh") {
                    return ExecutableTarget(url: url, arguments: dryRun ? ["--dry-run"] : [])
                } else {
                    return ExecutableTarget(url: url, arguments: installerArgs)
                }
            }
        }

        return nil
    }
}
