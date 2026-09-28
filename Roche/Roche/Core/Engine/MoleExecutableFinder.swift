import Foundation

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

    public func findStatusExecutable() -> ExecutableTarget? {
        let fileManager = FileManager.default

        // 1. Direct status-go in App Bundle
        if let bundleStatusGo = Bundle.main.url(forResource: "status-go", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundleStatusGo.path) {
            return ExecutableTarget(url: bundleStatusGo, arguments: ["--json"])
        }

        // 2. Direct mo in App Bundle
        if let bundleMo = Bundle.main.url(forResource: "mo", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundleMo.path) {
            return ExecutableTarget(url: bundleMo, arguments: ["status", "--json"])
        }

        // 3. Homebrew status-go (fastest direct Mach-O execution)
        let homebrewStatusGoCandidates = [
            "/opt/homebrew/Cellar/mole/1.56.1/libexec/bin/status-go",
            "/usr/local/Cellar/mole/1.56.1/libexec/bin/status-go"
        ]
        for candidate in homebrewStatusGoCandidates {
            if fileManager.isExecutableFile(atPath: candidate) {
                return ExecutableTarget(url: URL(fileURLWithPath: candidate), arguments: ["--json"])
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

        return nil
    }
}
