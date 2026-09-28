import Foundation

public final nonisolated class RealMoleClient: MoleClientProtocol, Sendable {
    private let finder: MoleExecutableFinder
    private let timeoutSeconds: TimeInterval

    public init(
        finder: MoleExecutableFinder = MoleExecutableFinder(),
        timeoutSeconds: TimeInterval = 15.0
    ) {
        self.finder = finder
        self.timeoutSeconds = timeoutSeconds
    }

    public var engineInfo: MoleEngineInfo {
        finder.currentEngineInfo()
    }
    public func fetchMetrics() async throws -> MetricsSnapshot {
        guard let target = finder.findStatusExecutable() else {
            throw MoleError.executableNotFound
        }

        return try await runCommand(target: target)
    }

    public func scanCleanables() async throws -> CleanScanResult {
        // 1. Run mo clean --dry-run
        guard let target = finder.findCleanExecutable(dryRun: true) else {
            throw MoleError.executableNotFound
        }
        _ = try await runProcess(target: target, timeout: 120.0)

        // 2. Query Trash size and count
        let trashInfo = await fetchTrashInfo()

        // 3. Read and parse ~/.config/mole/clean-list.txt
        let cleanListPath = ("~/.config/mole/clean-list.txt" as NSString).expandingTildeInPath
        let itemsByCat = parseCleanList(atPath: cleanListPath)

        // 4. Construct CleanCategories using collection extensions
        let devItems = itemsByCat[.dev] ?? []
        let appCacheItems = itemsByCat[.appCaches] ?? []
        let logItems = itemsByCat[.logs] ?? []

        let categories: [CleanCategory] = [
            CleanCategory(
                kind: .dev,
                items: devItems,
                isSelected: devItems.totalSizeBytes > 0
            ),
            CleanCategory(
                kind: .appCaches,
                items: appCacheItems,
                isSelected: appCacheItems.totalSizeBytes > 0
            ),
            CleanCategory(
                kind: .logs,
                items: logItems,
                isSelected: logItems.totalSizeBytes > 0
            ),
            CleanCategory(
                kind: .trash,
                sizeBytes: trashInfo.sizeBytes,
                itemCount: trashInfo.itemCount,
                items: trashInfo.itemCount > 0 ? [
                    CleanItem(
                        path: ("~/.Trash" as NSString).expandingTildeInPath,
                        name: "Thùng rác macOS (~/.Trash)",
                        sizeBytes: trashInfo.sizeBytes,
                        details: "\(trashInfo.itemCount) mục đang chờ dọn"
                    )
                ] : [],
                isSelected: trashInfo.sizeBytes > 0 || trashInfo.itemCount > 0
            )
        ]

        return CleanScanResult(categories: categories, scannedAt: Date())
    }

    public func performClean(categories: Set<CleanCategoryKind>) async throws -> CleanExecutionResult {
        var reclaimedTotal: UInt64 = 0
        var itemsCleanedTotal = 0
        var statusNotes: [String] = []

        // 1. Clean Trash if selected
        if categories.contains(.trash) {
            let trashBefore = await fetchTrashInfo()
            emptyTrashViaFinder()
            let trashAfter = await fetchTrashInfo()
            let reclaimedTrash = trashBefore.sizeBytes > trashAfter.sizeBytes ? (trashBefore.sizeBytes - trashAfter.sizeBytes) : trashBefore.sizeBytes
            reclaimedTotal += reclaimedTrash
            itemsCleanedTotal += trashBefore.itemCount
            statusNotes.append("Đã dọn Thùng rác")
        }

        // 2. Clean Mole categories (Dev, App Caches, Logs) via Mole CLI
        let moleCategories: Set<CleanCategoryKind> = [.dev, .appCaches, .logs]
        let selectedMoleCategories = categories.intersection(moleCategories)

        if !selectedMoleCategories.isEmpty {
            guard let target = finder.findCleanExecutable(dryRun: false) else {
                throw MoleError.executableNotFound
            }

            // Tally estimated reclaimable bytes and items from the clean scan
            let cleanListPath = ("~/.config/mole/clean-list.txt" as NSString).expandingTildeInPath
            let itemsByCat = parseCleanList(atPath: cleanListPath)
            let selectedMoleItems = selectedMoleCategories.flatMap { itemsByCat[$0] ?? [] }

            _ = try await runProcess(target: target, timeout: 180.0)
            reclaimedTotal += selectedMoleItems.totalSizeBytes
            itemsCleanedTotal += selectedMoleItems.count
            statusNotes.append("Đã dọn dẹp qua Mole Engine")
        }

        return CleanExecutionResult(
            reclaimedBytes: reclaimedTotal,
            cleanedCategories: Array(categories),
            itemsRemovedCount: itemsCleanedTotal,
            cleanedAt: Date(),
            message: statusNotes.joined(separator: " • ")
        )
    }

    // MARK: - Private Helpers

    private func runCommand(target: ExecutableTarget) async throws -> MetricsSnapshot {
        try await withThrowingTaskGroup(of: MetricsSnapshot.self) { group in
            group.addTask {
                let outputData = try await self.executeProcess(target: target)
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(MetricsSnapshot.self, from: outputData)
                } catch {
                    let jsonPreview = String(data: outputData.prefix(200), encoding: .utf8) ?? ""
                    throw MoleError.decodingFailed("\(error.localizedDescription) | Raw: \(jsonPreview)")
                }
            }

            // Timeout watchdog
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeoutSeconds * 1_000_000_000))
                throw MoleError.timeout
            }

            guard let result = try await group.next() else {
                throw MoleError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    private func runProcess(target: ExecutableTarget, timeout: TimeInterval) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let data = try await self.executeProcess(target: target)
                return String(data: data, encoding: .utf8) ?? ""
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw MoleError.timeout
            }

            guard let result = try await group.next() else {
                throw MoleError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    private func executeProcess(target: ExecutableTarget) async throws -> Data {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = target.url
        process.arguments = target.arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Add standard environment variables
        var environment = Foundation.ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "en_US.UTF-8"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw MoleError.processExecutionFailed(exitCode: -1, stderr: error.localizedDescription)
        }

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderr = String(data: errorData, encoding: .utf8) ?? "Unknown process error"
            throw MoleError.processExecutionFailed(exitCode: process.terminationStatus, stderr: stderr)
        }

        return outputData
    }

    private func fetchTrashInfo() async -> (sizeBytes: UInt64, itemCount: Int) {
        // First try reading trash metrics from snapshot
        var size: UInt64 = 0
        if let snapshot = try? await fetchMetrics() {
            size = snapshot.trashSize ?? 0
        }

        // Query item count via AppleScript to avoid TCC permission dialogs
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

    private func emptyTrashViaFinder() {
        let script = "tell application \"Finder\" to empty trash"
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
        }
    }

    private func parseCleanList(atPath path: String) -> [CleanCategoryKind: [CleanItem]] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return [:]
        }

        var results: [CleanCategoryKind: [CleanItem]] = [
            .dev: [],
            .appCaches: [],
            .logs: []
        ]

        var currentSection = ""

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("=== ") && trimmed.hasSuffix(" ===") {
                currentSection = trimmed
                continue
            }
            if trimmed.contains(", counted under ") {
                continue
            }
            let parts = trimmed.components(separatedBy: " # ")
            guard parts.count == 2 else { continue }
            let itemPath = parts[0].trimmingCharacters(in: .whitespaces)
            let sizePart = parts[1].trimmingCharacters(in: .whitespaces)
            let bytes = parseByteString(sizePart)

            let isLog = itemPath.contains("/Logs/") ||
                        itemPath.contains("/logs/") ||
                        itemPath.hasSuffix(".log") ||
                        itemPath.hasSuffix(".log.gz") ||
                        itemPath.hasSuffix(".dmp") ||
                        itemPath.contains("CrashReporter") ||
                        itemPath.contains("DiagnosticReports")

            let isDev = currentSection.contains("Developer tools") ||
                        itemPath.contains("DerivedData") ||
                        itemPath.contains(".npm") ||
                        itemPath.contains(".cargo") ||
                        itemPath.contains("clang") ||
                        itemPath.contains("Xcode") ||
                        itemPath.contains("VS Code") ||
                        itemPath.contains("Code/CachedData") ||
                        itemPath.contains(".vscode") ||
                        itemPath.contains("claude/versions") ||
                        itemPath.contains("opencode") ||
                        itemPath.contains("codex") ||
                        itemPath.contains("swiftpm") ||
                        itemPath.contains("__pycache__") ||
                        itemPath.contains("turbopack") ||
                        itemPath.contains("Homebrew/downloads")

            let item = CleanItem(
                path: itemPath,
                name: URL(fileURLWithPath: itemPath).lastPathComponent,
                sizeBytes: bytes,
                details: currentSection.replacingOccurrences(of: "===", with: "").trimmingCharacters(in: .whitespaces)
            )

            if isLog {
                results[.logs]?.append(item)
            } else if isDev {
                results[.dev]?.append(item)
            } else {
                results[.appCaches]?.append(item)
            }
        }

        return results
    }

    private func parseByteString(_ str: String) -> UInt64 {
        let clean = str.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var numStr = ""
        var unitStr = ""
        for ch in clean {
            if ch.isNumber || ch == "." {
                numStr.append(ch)
            } else if ch.isLetter {
                unitStr.append(ch)
            }
        }
        guard let value = Double(numStr) else { return 0 }
        if unitStr.contains("TB") {
            return UInt64(value * 1024 * 1024 * 1024 * 1024)
        } else if unitStr.contains("GB") {
            return UInt64(value * 1024 * 1024 * 1024)
        } else if unitStr.contains("MB") {
            return UInt64(value * 1024 * 1024)
        } else if unitStr.contains("KB") {
            return UInt64(value * 1024)
        } else {
            return UInt64(value)
        }
    }
}
