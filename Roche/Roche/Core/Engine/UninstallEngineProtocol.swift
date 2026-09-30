import Foundation

// MARK: - Uninstall Engine Protocol

/// Seam declaring discovery and inspection capabilities for installed applications.
public protocol UninstallEngineProtocol: Sendable {
    /// Discovers all installed applications on the macOS system.
    func listInstalledApps() async throws -> [InstalledApp]

    /// Inspects an installed application and itemizes all associated residual files.
    func inspectApp(app: InstalledApp) async throws -> AppUninstallPreview
}
