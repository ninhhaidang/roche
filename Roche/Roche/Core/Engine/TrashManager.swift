import Foundation

public protocol TrashManaging: Sendable {
    func fetchTrashInfo() async -> (sizeBytes: UInt64, itemCount: Int)
    func emptyTrash() async -> Bool
    func moveToTrash(path: String) async -> Bool
}

public struct SystemTrashManager: TrashManaging, Sendable {
    public init() {}

    public func fetchTrashInfo() async -> (sizeBytes: UInt64, itemCount: Int) {
        // First try reading trash metrics directly from disk
        let trashPath = ("~/.Trash" as NSString).expandingTildeInPath
        let size = calculateDirectorySize(atPath: trashPath)

        // Query item count via AppleScript with safe fallback
        var count = 0
        let script = "tell application \"Finder\" to count items of trash"
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            let output = appleScript.executeAndReturnError(&errorInfo)
            if errorInfo == nil, let countInt = output.stringValue, let val = Int(countInt) {
                count = val
            }
        }

        return (sizeBytes: size, itemCount: count)
    }

    public func emptyTrash() async -> Bool {
        let script = "tell application \"Finder\" to empty trash"
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
            return errorInfo == nil
        }
        return false
    }

    public func moveToTrash(path: String) async -> Bool {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        var resultingURL: NSURL?
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
            return true
        } catch {
            return false
        }
    }

    private func calculateDirectorySize(atPath path: String) -> UInt64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: []
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true,
               let fileSize = values.fileSize {
                total += UInt64(fileSize)
            }
        }
        return total
    }
}
