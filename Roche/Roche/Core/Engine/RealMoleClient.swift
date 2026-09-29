import Foundation

public final nonisolated class RealMoleClient: MoleClientProtocol, Sendable {
    private let finder: MoleExecutableFinder
    private let runner: any SubprocessRunning
    private let parser: any CleanListParsing
    private let timeoutSeconds: TimeInterval
    private let scanTimeoutSeconds: TimeInterval

    public init(
        finder: MoleExecutableFinder = MoleExecutableFinder(),
        runner: any SubprocessRunning = SubprocessRunner(),
        parser: any CleanListParsing = CleanListParser(),
        timeoutSeconds: TimeInterval = 15.0,
        scanTimeoutSeconds: TimeInterval = 120.0
    ) {
        self.finder = finder
        self.runner = runner
        self.parser = parser
        self.timeoutSeconds = timeoutSeconds
        self.scanTimeoutSeconds = scanTimeoutSeconds
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
        _ = try await runProcess(target: target, timeout: scanTimeoutSeconds)

        // 2. Query Trash size and count
        let trashInfo = await fetchTrashInfo()

        // 3. Read and construct CleanCategories via CleanListParser
        let content = readCleanListContent()
        let trashCategory = CleanCategory(
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
        let categories = parser.parseCategories(content: content, trashCategory: trashCategory)
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
            let itemsByCat = loadCleanListItems()
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

    private func defaultEnvironment() -> [String: String] {
        var environment = Foundation.ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "en_US.UTF-8"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        return environment
    }

    private func runCommand(target: ExecutableTarget) async throws -> MetricsSnapshot {
        let output = try await runner.execute(
            executableURL: target.url,
            arguments: target.arguments,
            environment: defaultEnvironment(),
            timeout: timeoutSeconds
        )

        guard output.exitCode == 0 else {
            throw MoleError.processExecutionFailed(exitCode: output.exitCode, stderr: output.stderrString)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(MetricsSnapshot.self, from: output.stdoutData)
        } catch {
            let jsonPreview = String(data: output.stdoutData.prefix(200), encoding: .utf8) ?? ""
            throw MoleError.decodingFailed("\(error.localizedDescription) | Raw: \(jsonPreview)")
        }
    }

    private func runProcess(target: ExecutableTarget, timeout: TimeInterval) async throws -> String {
        let output = try await runner.execute(
            executableURL: target.url,
            arguments: target.arguments,
            environment: defaultEnvironment(),
            timeout: timeout
        )

        guard output.exitCode == 0 else {
            throw MoleError.processExecutionFailed(exitCode: output.exitCode, stderr: output.stderrString)
        }

        return output.stdoutString
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

    private func readCleanListContent() -> String {
        let cleanListPath = ("~/.config/mole/clean-list.txt" as NSString).expandingTildeInPath
        return (try? String(contentsOfFile: cleanListPath, encoding: .utf8)) ?? ""
    }

    private func loadCleanListItems() -> [CleanCategoryKind: [CleanItem]] {
        parser.parse(content: readCleanListContent())
    }

}
