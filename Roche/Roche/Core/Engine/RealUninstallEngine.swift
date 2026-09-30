import Foundation

// MARK: - Real Uninstall Engine

public final nonisolated class RealUninstallEngine: UninstallEngineProtocol, Sendable {
    private let finder: MoleExecutableFinder
    private let runner: any SubprocessRunning
    private let timeoutSeconds: TimeInterval

    public init(
        finder: MoleExecutableFinder = MoleExecutableFinder(),
        runner: any SubprocessRunning = SubprocessRunner(),
        timeoutSeconds: TimeInterval = 30.0
    ) {
        self.finder = finder
        self.runner = runner
        self.timeoutSeconds = timeoutSeconds
    }

    public func listInstalledApps() async throws -> [InstalledApp] {
        guard let target = finder.findUninstallExecutable(arguments: ["--list"]) else {
            throw MoleError.executableNotFound
        }

        let output = try await runner.execute(
            executableURL: target.url,
            arguments: target.arguments,
            environment: nil,
            timeout: timeoutSeconds
        )

        guard output.exitCode == 0 else {
            throw MoleError.processExecutionFailed(exitCode: output.exitCode, stderr: output.stderrString)
        }

        return try Self.parseInstalledApps(from: output.stdoutData)
    }

    public func inspectApp(app: InstalledApp) async throws -> AppUninstallPreview {
        let appTargetName = app.uninstallName.isEmpty ? app.name : app.uninstallName
        guard let target = finder.findUninstallExecutable(arguments: ["--dry-run", appTargetName]) else {
            throw MoleError.executableNotFound
        }

        // Send "y\n\e\n" to confirm initial prompt and escape the second prompt
        let stdinInput = "y\n\u{1B}\n".data(using: .utf8)

        let output = try await runner.execute(
            executableURL: target.url,
            arguments: target.arguments,
            environment: nil,
            timeout: timeoutSeconds,
            stdinData: stdinInput
        )

        return Self.parseDryRunOutput(output.stdoutString, for: app)
    }

    public func performUninstall(app: InstalledApp, permanent: Bool = false) async throws -> UninstallResult {
        let appTargetName = app.uninstallName.isEmpty ? app.name : app.uninstallName
        var args: [String] = []
        if permanent {
            args.append("--permanent")
        }
        args.append(appTargetName)

        guard let target = finder.findUninstallExecutable(arguments: args) else {
            throw MoleError.executableNotFound
        }

        // Send "y\n\n\n" to confirm initial prompt and any subsequent confirmations
        let stdinInput = "y\n\n\n".data(using: .utf8)

        let output = try await runner.execute(
            executableURL: target.url,
            arguments: target.arguments,
            environment: nil,
            timeout: timeoutSeconds,
            stdinData: stdinInput
        )

        guard output.exitCode == 0 else {
            let errorMsg = output.stderrString.trimmingCharacters(in: .whitespacesAndNewlines)
            throw MoleError.processExecutionFailed(
                exitCode: output.exitCode,
                stderr: errorMsg.isEmpty ? output.stdoutString : errorMsg
            )
        }

        return Self.parseUninstallResult(
            output: output.stdoutString,
            app: app,
            isPermanent: permanent
        )
    }

    public static func parseUninstallResult(output: String, app: InstalledApp, isPermanent: Bool) -> UninstallResult {
        let cleaned = stripAnsiCodes(output)
        var parsedBytes: UInt64?

        // Pattern matching: "freed <size>" or "would free <size>"
        if let match = cleaned.range(of: #"(?:freed|would free)\s+([0-9.]+\s*[KMGT]?B)"#, options: .regularExpression) {
            let matchedText = String(cleaned[match])
            if let sizeMatch = matchedText.range(of: #"[0-9.]+\s*[KMGT]?B"#, options: .regularExpression) {
                let sizeStr = String(matchedText[sizeMatch])
                let bytes = CleanListParser.parseByteString(sizeStr)
                if bytes > 0 {
                    parsedBytes = bytes
                }
            }
        }

        let reclaimed = parsedBytes ?? app.sizeBytes
        return UninstallResult(
            appName: app.name,
            reclaimedBytes: reclaimed,
            reclaimedFormatted: CleanModelsFormatter.formatBytes(reclaimed),
            isPermanent: isPermanent,
            success: true,
            errorMessage: nil
        )
    }

    // MARK: - Parsing Helpers

    public static func parseInstalledApps(from data: Data) throws -> [InstalledApp] {
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([InstalledApp].self, from: data) {
            return direct
        }

        guard let rawString = String(data: data, encoding: .utf8) else {
            throw MoleError.decodingFailed("Unable to read UTF-8 output from uninstaller")
        }

        let cleanString = stripAnsiCodes(rawString)
        if let startIdx = cleanString.firstIndex(of: "["),
           let endIdx = cleanString.lastIndex(of: "]"),
           startIdx <= endIdx {
            let jsonSubstring = String(cleanString[startIdx...endIdx])
            if let subData = jsonSubstring.data(using: .utf8) {
                return try decoder.decode([InstalledApp].self, from: subData)
            }
        }

        throw MoleError.decodingFailed("No valid JSON array found in uninstaller output")
    }

    public static func parseDryRunOutput(_ rawOutput: String, for app: InstalledApp) -> AppUninstallPreview {
        let cleaned = stripAnsiCodes(rawOutput)
        let lines = cleaned.components(separatedBy: .newlines)

        var residuals: [AppResidualItem] = []
        var inResidualSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("Files to be removed:") {
                inResidualSection = true
                continue
            }

            if inResidualSection && (trimmed.starts(with: "➤") || trimmed.starts(with: "====")) {
                break
            }

            if trimmed.contains("✓") {
                if let item = parseResidualLine(trimmed, defaultAppName: app.name) {
                    residuals.append(item)
                }
            }
        }

        // Fallback: If no residual items were parsed, provide the app binary as a fallback item
        if residuals.isEmpty {
            let fallbackName = (app.path as NSString).lastPathComponent
            let fallbackTitle = fallbackName.isEmpty ? "\(app.name).app" : fallbackName
            let fallbackBytes = app.sizeBytes == 0 ? CleanListParser.parseByteString(app.size) : app.sizeBytes
            residuals = [
                AppResidualItem(
                    title: fallbackTitle,
                    path: app.path,
                    sizeText: app.size,
                    sizeBytes: fallbackBytes,
                    kind: .binary,
                    isSelected: true
                )
            ]
        }

        return AppUninstallPreview(app: app, residuals: residuals)
    }

    public static func parseResidualLine(_ line: String, defaultAppName: String) -> AppResidualItem? {
        guard let checkRange = line.range(of: "✓") else { return nil }
        var remainder = String(line[checkRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Strip tags like "System: " or "Review only: "
        if remainder.starts(with: "System:") {
            remainder = String(remainder.dropFirst("System:".count)).trimmingCharacters(in: .whitespaces)
        } else if remainder.starts(with: "Review only:") {
            remainder = String(remainder.dropFirst("Review only:".count)).trimmingCharacters(in: .whitespaces)
        }

        var pathPart: String
        var sizePart: String

        // Split on comma separator: " , " or ","
        if let commaRange = remainder.range(of: " , ", options: .backwards) {
            pathPart = String(remainder[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            sizePart = String(remainder[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let commaRange = remainder.range(of: ",", options: .backwards) {
            pathPart = String(remainder[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            sizePart = String(remainder[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            pathPart = remainder
            sizePart = ""
        }

        guard !pathPart.isEmpty else { return nil }

        let kind = classifyKind(path: pathPart)
        let title = deriveTitle(path: pathPart, kind: kind)
        let sizeBytes = CleanListParser.parseByteString(sizePart)

        return AppResidualItem(
            title: title,
            path: pathPart,
            sizeText: sizePart.isEmpty ? CleanModelsFormatter.formatBytes(sizeBytes) : sizePart,
            sizeBytes: sizeBytes,
            kind: kind,
            isSelected: true
        )
    }

    public static func classifyKind(path: String) -> ResidualItemKind {
        let lower = path.lowercased()
        if lower.hasSuffix(".app") || lower.contains(".app/") {
            return .binary
        } else if lower.contains("/launchagents/") || lower.contains("/launchdaemons/") {
            return .launchAgent
        } else if lower.contains("/preferences/") || lower.hasSuffix(".plist") {
            return .preferences
        } else if lower.contains("/caches/") || lower.contains("/httpstorages/") {
            return .cache
        } else if lower.contains("/containers/") || lower.contains("/group containers/") {
            return .containers
        } else if lower.contains("/application support/") {
            return .applicationSupport
        } else if lower.contains("/logs/") || lower.contains("/diagnosticreports/") {
            return .logs
        } else {
            return .other
        }
    }

    public static func deriveTitle(path: String, kind: ResidualItemKind) -> String {
        let filename = (path as NSString).lastPathComponent
        switch kind {
        case .binary:
            return filename
        case .cache:
            return "Cache (\(filename))"
        case .preferences:
            return filename
        case .applicationSupport:
            return "App Support (\(filename))"
        case .launchAgent:
            return "Launch Agent (\(filename))"
        case .containers:
            return "Container (\(filename))"
        case .logs:
            return "Log (\(filename))"
        case .other:
            return filename.isEmpty ? path : filename
        }
    }

    public static func stripAnsiCodes(_ text: String) -> String {
        text.replacingOccurrences(of: #"\x1B\[[0-9;?]*[a-zA-Z]"#, with: "", options: .regularExpression)
    }
}
