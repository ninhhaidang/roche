import Foundation

public struct PurgePathsManager: Sendable {
    public static let defaultPaths: [String] = [
        "~/Projects",
        "~/dev",
        "~/GitHub",
        "~/Workspace",
        "~/Code",
        "~/Development"
    ]

    private let configURL: URL

    public init(configURL: URL? = nil) {
        if let configURL = configURL {
            self.configURL = configURL
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.configURL = home.appendingPathComponent(".config/mole/purge_paths")
        }
    }

    public func loadCustomPaths() -> [String] {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return []
        }
        guard let content = try? String(contentsOf: configURL, encoding: .utf8) else {
            return []
        }
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    public func allScanPaths() -> [String] {
        let custom = loadCustomPaths()
        if custom.isEmpty {
            return Self.defaultPaths
        }
        var combined = Self.defaultPaths
        for path in custom where !combined.contains(path) {
            combined.append(path)
        }
        return combined
    }

    public func saveCustomPaths(_ paths: [String]) throws {
        let folderURL = configURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        let cleanPaths = paths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        let content = """
        # Mole Purge Paths - Directories to scan for project artifacts
        # Configured via Roche GUI Settings
        \(cleanPaths.joined(separator: "\n"))
        """

        try content.write(to: configURL, atomically: true, encoding: .utf8)
    }

    public func addPath(_ path: String) throws {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var current = loadCustomPaths()
        if !current.contains(trimmed) {
            current.append(trimmed)
            try saveCustomPaths(current)
        }
    }

    public func removePath(_ path: String) throws {
        var current = loadCustomPaths()
        current.removeAll { $0 == path }
        try saveCustomPaths(current)
    }
}
