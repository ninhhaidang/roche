import Foundation

public protocol CleanListParsing: Sendable {
    func parse(content: String) -> [CleanCategoryKind: [CleanItem]]
    func parseCategories(content: String, trashCategory: CleanCategory?) -> [CleanCategory]
    func parsePurgeOutput(_ output: String) -> [CleanItem]
    func parseInstallerOutput(_ output: String) -> [CleanItem]
}

extension CleanListParsing {
    public func parseCategories(content: String) -> [CleanCategory] {
        parseCategories(content: content, trashCategory: nil)
    }
}

public struct CleanListParser: CleanListParsing, Sendable {
    public init() {}

    public func parse(content: String) -> [CleanCategoryKind: [CleanItem]] {
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

            guard let hashRange = trimmed.range(of: " # ", options: .backwards) else { continue }
            let itemPath = String(trimmed[..<hashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let sizePart = String(trimmed[hashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let bytes = Self.parseByteString(sizePart)

            let kind = Self.classify(path: itemPath, section: currentSection)
            let details = currentSection
                .replacingOccurrences(of: "===", with: "")
                .trimmingCharacters(in: .whitespaces)

            let item = CleanItem(
                path: itemPath,
                name: URL(fileURLWithPath: itemPath).lastPathComponent,
                sizeBytes: bytes,
                details: details.isEmpty ? nil : details
            )

            results[kind, default: []].append(item)
        }

        return results
    }

    public func parseCategories(content: String, trashCategory: CleanCategory? = nil) -> [CleanCategory] {
        let itemsByKind = parse(content: content)

        let devItems = itemsByKind[.dev] ?? []
        let cacheItems = itemsByKind[.appCaches] ?? []
        let logItems = itemsByKind[.logs] ?? []

        var categories: [CleanCategory] = [
            CleanCategory(
                kind: .dev,
                items: devItems,
                isSelected: devItems.totalSizeBytes > 0
            ),
            CleanCategory(
                kind: .appCaches,
                items: cacheItems,
                isSelected: cacheItems.totalSizeBytes > 0
            ),
            CleanCategory(
                kind: .logs,
                items: logItems,
                isSelected: logItems.totalSizeBytes > 0
            )
        ]

        if let trash = trashCategory {
            categories.append(trash)
        }

        return categories
    }

    public static func classify(path: String, section: String) -> CleanCategoryKind {
        let isDevSection = section.localizedCaseInsensitiveContains("Developer") ||
                           section.localizedCaseInsensitiveContains("Dev") ||
                           section.localizedCaseInsensitiveContains("Xcode")

        let isLogSection = section.localizedCaseInsensitiveContains("Logs") ||
                           section.localizedCaseInsensitiveContains("Diagnostic") ||
                           section.localizedCaseInsensitiveContains("Crash")

        if isDevSection {
            return .dev
        }

        if isLogSection {
            return .logs
        }

        let isDevPath = path.contains("DerivedData") ||
                        path.contains(".npm") ||
                        path.contains(".cargo") ||
                        path.contains("clang") ||
                        path.contains("Xcode") ||
                        path.contains("VS Code") ||
                        path.contains("Code/CachedData") ||
                        path.contains(".vscode") ||
                        path.contains("claude/versions") ||
                        path.contains("opencode") ||
                        path.contains("codex") ||
                        path.contains("swiftpm") ||
                        path.contains("__pycache__") ||
                        path.contains("turbopack") ||
                        path.contains("Homebrew/downloads") ||
                        path.contains(".gradle") ||
                        path.contains(".m2")

        if isDevPath {
            return .dev
        }

        let isLogPath = path.contains("/Logs/") ||
                        path.contains("/logs/") ||
                        path.hasSuffix(".log") ||
                        path.hasSuffix(".log.gz") ||
                        path.hasSuffix(".dmp") ||
                        path.contains("CrashReporter") ||
                        path.contains("DiagnosticReports")

        if isLogPath {
            return .logs
        }

        return .appCaches
    }

    public static func parseByteString(_ str: String) -> UInt64 {
        let clean = str.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return 0 }

        var numStr = ""
        var unitStr = ""
        for ch in clean {
            if ch.isNumber || ch == "." {
                numStr.append(ch)
            } else if ch.isLetter {
                unitStr.append(ch)
            }
        }
        guard let value = Double(numStr), value >= 0 else { return 0 }

        switch unitStr {
        case "TB", "T":
            return UInt64((value * 1024 * 1024 * 1024 * 1024).rounded())
        case "GB", "G":
            return UInt64((value * 1024 * 1024 * 1024).rounded())
        case "MB", "M":
            return UInt64((value * 1024 * 1024).rounded())
        case "KB", "K":
            return UInt64((value * 1024).rounded())
        case "B", "BYTES", "BYTE", "":
            return UInt64(value.rounded())
        default:
            return 0
        }
    }

    public func parsePurgeOutput(_ output: String) -> [CleanItem] {
        var items: [CleanItem] = []
        // Pattern matching: ✓ [DRY RUN] <path>, <size>
        // Or without checkmark/bracket: [DRY RUN] <path>, <size>
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.contains("[DRY RUN]") else { continue }
            guard let commaIdx = trimmed.lastIndex(of: ",") else { continue }
            guard let dryRunIdx = trimmed.range(of: "[DRY RUN]")?.upperBound else { continue }

            let rawPath = String(trimmed[dryRunIdx..<commaIdx]).trimmingCharacters(in: .whitespaces)
            let sizePart = String(trimmed[trimmed.index(after: commaIdx)...]).trimmingCharacters(in: .whitespaces)

            // Ignore empty or summary lines if any
            if rawPath.isEmpty || sizePart.isEmpty { continue }

            let expandedPath = (rawPath as NSString).expandingTildeInPath
            let name = URL(fileURLWithPath: expandedPath).lastPathComponent
            let sizeBytes = Self.parseByteString(sizePart)

            items.append(
                CleanItem(
                    path: expandedPath,
                    name: name.isEmpty ? rawPath : name,
                    sizeBytes: sizeBytes,
                    details: "Dự án cũ: \(rawPath)"
                )
            )
        }
        return items
    }

    public func parseInstallerOutput(_ output: String) -> [CleanItem] {
        var items: [CleanItem] = []
        // Pattern matching installer menu row:
        // e.g. "➤ ○ Tinycast-0.11.3.dmg                         6.8MB | Downloads"
        // or   "  ○ Docker.dmg                                 500.0MB | Downloads"
        let home = NSHomeDirectory()
        let sourceToDir: [String: String] = [
            "Downloads": "\(home)/Downloads",
            "Desktop": "\(home)/Desktop",
            "Documents": "\(home)/Documents",
            "Public": "\(home)/Public",
            "Homebrew": "\(home)/Library/Caches/Homebrew"
        ]

        for line in output.components(separatedBy: .newlines) {
            // Strip ANSI escape sequences if present
            let cleanLine = line.replacingOccurrences(of: "\u{001B}\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            guard cleanLine.contains("○") || cleanLine.contains("●") else { continue }
            guard let pipeIdx = cleanLine.firstIndex(of: "|") else { continue }

            let beforePipe = String(cleanLine[..<pipeIdx]).trimmingCharacters(in: .whitespaces)
            let sourcePart = String(cleanLine[cleanLine.index(after: pipeIdx)...]).trimmingCharacters(in: .whitespaces)

            // Extract marker
            var rowText = beforePipe
            if let circleIdx = rowText.firstIndex(where: { $0 == "○" || $0 == "●" }) {
                rowText = String(rowText[rowText.index(after: circleIdx)...]).trimmingCharacters(in: .whitespaces)
            }

            // rowText now has "<filename>       <size>"
            let components = rowText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 2 else { continue }

            let sizePart = components.last!
            let fileName = components.dropLast().joined(separator: " ")

            let sizeBytes = Self.parseByteString(sizePart)
            let dir = sourceToDir[sourcePart] ?? "\(home)/\(sourcePart)"
            let fullPath = "\(dir)/\(fileName)"

            items.append(
                CleanItem(
                    path: fullPath,
                    name: fileName,
                    sizeBytes: sizeBytes,
                    details: "Thư mục: \(sourcePart)"
                )
            )
        }
        return items
    }
}
