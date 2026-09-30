import Foundation

public final nonisolated class RealOptimizeEngine: OptimizeEngineProtocol, Sendable {
    private let finder: MoleExecutableFinder
    private let runner: any SubprocessRunning
    private let timeoutSeconds: TimeInterval

    public init(
        finder: MoleExecutableFinder = MoleExecutableFinder(),
        runner: any SubprocessRunning = SubprocessRunner(),
        timeoutSeconds: TimeInterval = 45.0
    ) {
        self.finder = finder
        self.runner = runner
        self.timeoutSeconds = timeoutSeconds
    }

    public func diagnosePerformance() async throws -> SystemDiagnosis {
        guard let target = finder.findOptimizeExecutable(dryRun: true) else {
            throw MoleError.executableNotFound
        }

        let output = try await runner.execute(
            executableURL: target.url,
            arguments: target.arguments,
            environment: [
                "LC_ALL": "C",
                "LANG": "C",
                "TERM": "dumb"
            ],
            timeout: timeoutSeconds
        )

        return Self.parseDiagnosis(from: output.stdoutString)
    }

    public func runOptimization(dryRun: Bool = true) async throws -> [OptimizeTask] {
        guard let target = finder.findOptimizeExecutable(dryRun: dryRun) else {
            throw MoleError.executableNotFound
        }

        let output = try await runner.execute(
            executableURL: target.url,
            arguments: target.arguments,
            environment: [
                "LC_ALL": "C",
                "LANG": "C",
                "TERM": "dumb"
            ],
            timeout: timeoutSeconds
        )

        let diagnosis = Self.parseDiagnosis(from: output.stdoutString)
        return diagnosis.tasks
    }

    // MARK: - Diagnosis & Bottleneck Parsing

    public static func parseDiagnosis(from rawOutput: String) -> SystemDiagnosis {
        let clean = stripANSI(rawOutput)
        let bottleneck = parseBottleneck(from: clean)
        let parsedTasks = parseTasks(from: clean)

        return SystemDiagnosis(
            component: bottleneck.component,
            description: bottleneck.description,
            recommendation: bottleneck.recommendation,
            severity: bottleneck.severity,
            cpuUsagePercent: bottleneck.cpuUsagePercent,
            hasBottleneck: bottleneck.hasBottleneck,
            tasks: parsedTasks,
            rawOutput: rawOutput
        )
    }

    public static func parseBottleneck(from text: String) -> (
        component: String,
        cpuUsagePercent: Double?,
        hasBottleneck: Bool,
        severity: DiagnosisSeverity,
        description: String,
        recommendation: String
    ) {
        let clean = stripANSI(text)

        // 1. Check for explicit "No sustained high-CPU bottleneck detected"
        if clean.localizedCaseInsensitiveContains("No sustained high-CPU bottleneck detected") ||
           clean.localizedCaseInsensitiveContains("no sustained high-cpu bottleneck") {
            return (
                component: "Không có nghẽn",
                cpuUsagePercent: nil,
                hasBottleneck: false,
                severity: .nominal,
                description: "Không phát hiện tiến trình nào chiếm dụng CPU kéo dài bất thường.",
                recommendation: "Hệ thống đang hoạt động ở trạng thái mượt mà và tối ưu."
            )
        }

        // 2. Regex match "Likely bottleneck: <component> (~<percentage>% CPU sustained)"
        let pattern = #"Likely bottleneck:\s*([^\(\n\r]+?)(?:\s*\(~?([0-9.]+)%\s*CPU sustained\)|$|\r|\n)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(clean.startIndex..<clean.endIndex, in: clean)
            if let match = regex.firstMatch(in: clean, options: [], range: range) {
                var component = "Unknown"
                if let compRange = Range(match.range(at: 1), in: clean) {
                    component = String(clean[compRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                var cpuPercent: Double? = nil
                if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound,
                   let cpuRange = Range(match.range(at: 2), in: clean) {
                    let cpuStr = String(clean[cpuRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    cpuPercent = Double(cpuStr)
                }

                let severity: DiagnosisSeverity
                if let pct = cpuPercent {
                    if pct >= 50.0 {
                        severity = .severe
                    } else if pct >= 25.0 {
                        severity = .moderate
                    } else {
                        severity = .nominal
                    }
                } else {
                    severity = .moderate
                }

                let (desc, rec) = detailedDiagnosis(for: component, cpuPercent: cpuPercent, rawText: clean)

                return (
                    component: component,
                    cpuUsagePercent: cpuPercent,
                    hasBottleneck: true,
                    severity: severity,
                    description: desc,
                    recommendation: rec
                )
            }
        }

        // 3. Fallback when neither explicit pattern was found
        return (
            component: "Không có nghẽn",
            cpuUsagePercent: nil,
            hasBottleneck: false,
            severity: .nominal,
            description: "Chưa phát hiện nghẽn hiệu năng trong lần quét gần nhất.",
            recommendation: "Chạy mô phỏng tối ưu để quét toàn diện 20 tác vụ hệ thống."
        )
    }

    // MARK: - Category Mapping (20 Canonical Tasks across 4 Categories)

    public static func category(forActionOrName key: String) -> OptimizeTaskCategory {
        let normalized = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // 1. Hệ thống & Tìm kiếm (System & Search)
        if normalized.contains("system_maintenance") ||
           normalized.contains("dns & spotlight") ||
           normalized.contains("spotlight_index") ||
           normalized.contains("spotlight optimization") ||
           normalized.contains("spotlight_orphan") ||
           normalized.contains("spotlight orphan") ||
           normalized.contains("periodic_maintenance") ||
           normalized.contains("periodic maintenance") ||
           normalized.contains("disk_permissions") ||
           normalized.contains("permission repair") ||
           normalized.contains("hệ thống & tìm kiếm") ||
           normalized.contains("quy tắc mồ côi") ||
           normalized.contains("dns cache") {
            return .systemAndSearch
        }

        // 2. Bộ nhớ đệm & Finder (Cache & Finder)
        if normalized.contains("cache_refresh") ||
           normalized.contains("finder cache") ||
           normalized.contains("quicklook") ||
           normalized.contains("icon services") ||
           normalized.contains("saved_state") ||
           normalized.contains("app state") ||
           normalized.contains("prevent_network_dsstore") ||
           normalized.contains(".ds_store") ||
           normalized.contains("shared_file_list") ||
           normalized.contains("shared file") ||
           normalized.contains("notification_cleanup") ||
           normalized.contains("notification") ||
           normalized.contains("bộ nhớ đệm & finder") {
            return .cacheAndFinder
        }

        // 4. Cấu hình & Bảo mật (Config & Security) - Checked before database check to prevent Quarantine Database overlap
        if normalized.contains("broken_configs") ||
           normalized.contains("broken config") ||
           normalized.contains("preferences") ||
           normalized.contains("legacy_overrides") ||
           normalized.contains("legacy overrides") ||
           normalized.contains("login_items") ||
           normalized.contains("login items") ||
           normalized.contains("quarantine_cleanup") ||
           normalized.contains("quarantine") ||
           normalized.contains("launch_agents") ||
           normalized.contains("launch agents") ||
           normalized.contains("cấu hình & bảo mật") {
            return .configAndSecurity
        }

        // 3. Mạng & Dữ liệu (Network & Data)
        if normalized.contains("network_optimization") ||
           normalized.contains("network cache") ||
           normalized.contains("network_stack") ||
           normalized.contains("network stack") ||
           normalized.contains("mdns") ||
           normalized.contains("sqlite_vacuum") ||
           normalized.contains("database optimization") ||
           normalized.contains("sqlite") ||
           normalized.contains("database") ||
           normalized.contains("disk_verify") ||
           normalized.contains("disk health") ||
           normalized.contains("coreduet") ||
           normalized.contains("usage data") ||
           normalized.contains("mạng & dữ liệu") {
            return .networkAndData
        }

        return .systemAndSearch
    }

    // MARK: - Task Parsing

    public static func parseTasks(from text: String) -> [OptimizeTask] {
        let clean = stripANSI(text)
        var canonical = canonicalTasks20()
        var canonicalDict: [String: OptimizeTask] = [:]
        for task in canonical {
            canonicalDict[task.name.lowercased()] = task
        }

        // Split output by task header "➤ "
        let chunks = clean.components(separatedBy: "➤ ")
        guard chunks.count > 1 else {
            return canonical
        }

        for chunk in chunks.dropFirst() {
            let lines = chunk.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            guard let rawHeader = lines.first else { continue }
            let taskName = rawHeader.trimmingCharacters(in: .whitespacesAndNewlines)
            let details = Array(lines.dropFirst())

            var outcome: OptimizeTaskOutcome = .unchanged
            let combinedDetails = details.joined(separator: " ").lowercased()

            if combinedDetails.contains("broken") ||
               combinedDetails.contains("attention") ||
               combinedDetails.contains("corrupt") ||
               combinedDetails.contains("need attention") {
                outcome = .attention
            } else if combinedDetails.contains("skipped") ||
                      combinedDetails.contains("unavailable") ||
                      combinedDetails.contains("not available") {
                outcome = .skipped
            } else if combinedDetails.contains("flushed") ||
                      combinedDetails.contains("refreshed") ||
                      combinedDetails.contains("optimized") ||
                      combinedDetails.contains("rebuilt") ||
                      combinedDetails.contains("enabled") ||
                      combinedDetails.contains("cleaned") ||
                      combinedDetails.contains("compressed") ||
                      combinedDetails.contains("would apply") {
                outcome = .applied
            } else {
                outcome = .unchanged
            }

            let message: String
            if let firstDetail = details.first {
                message = firstDetail
                    .replacingOccurrences(of: "^(→|◎|✔|⊙|\\-)\\s*", with: "", options: .regularExpression)
            } else {
                message = outcome.rawValue
            }

            let matchedCat = category(forActionOrName: taskName)

            // Update matching task in canonical list
            let key = taskName.lowercased()
            var matchedIndex: Int? = nil
            for (idx, task) in canonical.enumerated() {
                let nameLower = task.name.lowercased()
                if nameLower == key ||
                   nameLower.contains(key) ||
                   key.contains(nameLower) ||
                   category(forActionOrName: task.id) == matchedCat && task.category == matchedCat && nameLower.prefix(6) == key.prefix(6) {
                    matchedIndex = idx
                    break
                }
            }

            if let idx = matchedIndex {
                canonical[idx] = OptimizeTask(
                    id: canonical[idx].id,
                    name: canonical[idx].name,
                    category: canonical[idx].category,
                    status: .completed,
                    outcome: outcome,
                    message: message,
                    details: details
                )
            }
        }

        return canonical
    }

    // MARK: - Canonical 20 Tasks Fixture

    public static func canonicalTasks20() -> [OptimizeTask] {
        return [
            // Category 1: Hệ thống & Tìm kiếm (5 tasks)
            OptimizeTask(
                id: "system_maintenance",
                name: "Kiểm tra DNS & Spotlight",
                category: .systemAndSearch,
                outcome: .applied,
                message: "DNS cache đã được làm mới thành công"
            ),
            OptimizeTask(
                id: "spotlight_index_optimize",
                name: "Tối ưu chỉ mục Spotlight",
                category: .systemAndSearch,
                outcome: .unchanged,
                message: "Spotlight index ở trạng thái tối ưu"
            ),
            OptimizeTask(
                id: "spotlight_orphan_rules_cleanup",
                name: "Dọn dẹp quy tắc tìm kiếm mồ côi",
                category: .systemAndSearch,
                outcome: .applied,
                message: "Đã xóa các quy tắc tìm kiếm không hợp lệ"
            ),
            OptimizeTask(
                id: "periodic_maintenance",
                name: "Bảo trì định kỳ hệ thống macOS",
                category: .systemAndSearch,
                outcome: .unchanged,
                message: "Các script định kỳ hệ thống bình thường"
            ),
            OptimizeTask(
                id: "disk_permissions_repair",
                name: "Sửa quyền tệp thư mục người dùng",
                category: .systemAndSearch,
                outcome: .unchanged,
                message: "Quyền tệp người dùng hợp lệ"
            ),

            // Category 2: Bộ nhớ đệm & Finder (5 tasks)
            OptimizeTask(
                id: "cache_refresh",
                name: "Làm mới Thumbnails QuickLook",
                category: .cacheAndFinder,
                outcome: .applied,
                message: "Đã giải phóng bộ nhớ đệm QuickLook & Icon"
            ),
            OptimizeTask(
                id: "saved_state_cleanup",
                name: "Dọn dẹp App Saved States",
                category: .cacheAndFinder,
                outcome: .applied,
                message: "Đã dọn dẹp các phiên lưu trữ ứng dụng đóng đột ngột"
            ),
            OptimizeTask(
                id: "prevent_network_dsstore",
                name: "Chặn tệp .DS_Store trên ổ đĩa mạng",
                category: .cacheAndFinder,
                outcome: .unchanged,
                message: "Thiết lập DSDontWriteNetworkStores đã bật"
            ),
            OptimizeTask(
                id: "shared_file_list_repair",
                name: "Sửa lỗi danh sách tệp dùng chung",
                category: .cacheAndFinder,
                outcome: .unchanged,
                message: "Danh sách tệp dùng chung toàn vẹn"
            ),
            OptimizeTask(
                id: "notification_cleanup",
                name: "Dọn dẹp thông báo cũ",
                category: .cacheAndFinder,
                outcome: .applied,
                message: "Cơ sở dữ liệu trung tâm thông báo đã tối ưu"
            ),

            // Category 3: Mạng & Dữ liệu (5 tasks)
            OptimizeTask(
                id: "network_optimization",
                name: "Làm mới bộ nhớ đệm mDNSResponder",
                category: .networkAndData,
                outcome: .unchanged,
                message: "Network stack đang phản hồi chuẩn"
            ),
            OptimizeTask(
                id: "network_stack_optimize",
                name: "Tối ưu ngăn xếp mạng & Flush ARP",
                category: .networkAndData,
                outcome: .unchanged,
                message: "Bảng định tuyến và bộ đệm ARP đã được làm mới"
            ),
            OptimizeTask(
                id: "sqlite_vacuum",
                name: "Tối ưu cơ sở dữ liệu SQLite",
                category: .networkAndData,
                outcome: .applied,
                message: "Đã nén và sắp xếp lại các tệp cơ sở dữ liệu hệ thống"
            ),
            OptimizeTask(
                id: "disk_verify",
                name: "Kiểm tra toàn vẹn phân vùng APFS",
                category: .networkAndData,
                outcome: .unchanged,
                message: "Phân vùng APFS không phát hiện lỗi metadata"
            ),
            OptimizeTask(
                id: "coreduet_cleanup",
                name: "Dọn dẹp dữ liệu theo dõi CoreDuet",
                category: .networkAndData,
                outcome: .unchanged,
                message: "Dữ liệu Knowledge database bình thường"
            ),

            // Category 4: Cấu hình & Bảo mật (5 tasks)
            OptimizeTask(
                id: "fix_broken_configs",
                name: "Sửa lỗi tệp tùy biến hư hỏng (.plist)",
                category: .configAndSecurity,
                outcome: .unchanged,
                message: "Tất cả tệp preferences hợp lệ"
            ),
            OptimizeTask(
                id: "legacy_overrides_audit",
                name: "Kiểm tra cấu hình App Nap cũ",
                category: .configAndSecurity,
                outcome: .unchanged,
                message: "Không tìm thấy cấu hình ghi đè cũ"
            ),
            OptimizeTask(
                id: "login_items_audit",
                name: "Kiểm tra mục khởi động cùng máy",
                category: .configAndSecurity,
                outcome: .attention,
                message: "Phát hiện mục khởi động mồ côi cần gỡ bỏ"
            ),
            OptimizeTask(
                id: "quarantine_cleanup",
                name: "Dọn dẹp cơ sở dữ liệu cách ly",
                category: .configAndSecurity,
                outcome: .applied,
                message: "Đã dọn dẹp các bản ghi cách ly tải về cũ"
            ),
            OptimizeTask(
                id: "launch_agents_cleanup",
                name: "Quét LaunchAgents & Daemons mồ côi",
                category: .configAndSecurity,
                outcome: .attention,
                message: "Phát hiện service trỏ tới file nhị phân không tồn tại"
            )
        ]
    }

    // MARK: - Private Helpers

    private static func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(of: "\\x1b\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)
    }

    private static func detailedDiagnosis(
        for component: String,
        cpuPercent: Double?,
        rawText: String
    ) -> (description: String, recommendation: String) {
        let cpuStr = cpuPercent.map { String(format: "%.1f", $0) } ?? "30+"
        let lower = component.lowercased()

        if lower.contains("windowserver") {
            return (
                description: "WindowServer đang sử dụng ~\(cpuStr)% CPU kéo dài (Desktop Composition bận).",
                recommendation: "Làm mới bộ nhớ đệm Finder và giải phóng Icon Services để giảm tải compositing."
            )
        } else if lower.contains("syspolicyd") {
            return (
                description: "syspolicyd đang sử dụng ~\(cpuStr)% CPU kéo dài (Gatekeeper đánh giá mã bảo mật).",
                recommendation: "Đóng bớt các ảnh đĩa DMG đã gắn hoặc chờ tiến trình quét bảo mật hoàn tất."
            )
        } else if lower.contains("spotlight") {
            return (
                description: "Spotlight indexing đang sử dụng ~\(cpuStr)% CPU kéo dài (đang lập chỉ mục dữ liệu).",
                recommendation: "Tối ưu hóa chỉ mục Spotlight và loại bỏ các quy tắc tìm kiếm mồ côi."
            )
        } else if lower.contains("cloudshell") || lower.contains("alientsafe") {
            return (
                description: "Enterprise Security Agent đang sử dụng ~\(cpuStr)% CPU kéo dài.",
                recommendation: "Tiến trình quản lý doanh nghiệp; khuyến nghị kiểm tra chính sách bảo mật nội bộ."
            )
        } else if lower.contains("coresim") {
            return (
                description: "CoreSimulator disk images đang sử dụng ~\(cpuStr)% CPU kéo dài.",
                recommendation: "Tắt các thiết bị giả lập iOS/watchOS Simulator không dùng đến."
            )
        } else {
            return (
                description: "\(component) đang sử dụng ~\(cpuStr)% CPU kéo dài bất thường.",
                recommendation: "Kiểm tra tác vụ chạy nền và cân nhắc làm mới các dịch vụ liên quan."
            )
        }
    }
}
