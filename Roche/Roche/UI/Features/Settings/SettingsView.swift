import SwiftUI

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var customPurgePaths: [String] = []
    @Published public var newPurgePathInput: String = ""
    public let purgeManager: PurgePathsManager

    public init(purgeManager: PurgePathsManager = PurgePathsManager()) {
        self.purgeManager = purgeManager
        self.customPurgePaths = purgeManager.loadCustomPaths()
    }

    public func reload() {
        self.customPurgePaths = purgeManager.loadCustomPaths()
    }

    public func addPath() {
        let trimmed = newPurgePathInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? purgeManager.addPath(trimmed)
        self.customPurgePaths = purgeManager.loadCustomPaths()
        self.newPurgePathInput = ""
    }

    public func removePath(_ path: String) {
        try? purgeManager.removePath(path)
        self.customPurgePaths = purgeManager.loadCustomPaths()
    }
}

public struct SettingsView: View {
    @Bindable var telemetryService: TelemetryService
    @StateObject private var viewModel = SettingsViewModel()

    public init(telemetryService: TelemetryService? = nil) {
        self.telemetryService = telemetryService ?? TelemetryService()
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection

                    Divider().background(Color.white.opacity(0.1))

                    // 1. Auto-refresh section
                    autoRefreshSection

                    // 2. Mole Engine Section
                    engineSection

                    // 3. Cleaner & Whitelist Section
                    cleanerSettingsSection

                    // 4. Project Purge Paths Section
                    projectPurgePathsSection

                    // 5. System & App Info
                    hardwareAndAppInfoSection
                }
                .padding(24)
            }
        }
        .onAppear {
            viewModel.reload()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CÀI ĐẶT")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .tracking(0.5)
            Text("Tùy Chọn Ứng Dụng & Cấu Hình Engine")
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
    }

    private var autoRefreshSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TỰ ĐỘNG LÀM MỚI TELEMETRY")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tự động cập nhật dữ liệu phần cứng")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Polling định kỳ trạng thái CPU, Memory, Thermals và Disk từ Mole CLI.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                AutoRefreshToggleControl(
                    interval: Binding(
                        get: { telemetryService.refreshInterval },
                        set: { telemetryService.updateInterval($0) }
                    ),
                    isPolling: Binding(
                        get: { telemetryService.isPolling },
                        set: { if $0 { telemetryService.start() } else { telemetryService.stop() } }
                    )
                )
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // Manual Refresh
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Làm mới thủ công")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Text("Lấy snapshot số liệu hệ thống ngay lập tức.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await telemetryService.refresh()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Làm mới ngay")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var engineSection: some View {
        let engine = telemetryService.engineInfo
        return VStack(alignment: .leading, spacing: 14) {
            Text("THÔNG TIN MOLE ENGINE")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Trạng thái nhị phân CLI:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)

                            Text(engine.isAvailable ? "ĐÃ KẾT NỐI" : "KHÔNG TÌM THẤY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(engine.isAvailable ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .foregroundStyle(engine.isAvailable ? .green : .red)
                                .clipShape(Capsule())
                        }

                        if let path = engine.executablePath {
                            Text(path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Chưa tìm thấy executable 'mo' hoặc 'status-go' trên hệ thống.")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }

                    Spacer()
                }

                Divider().background(Color.white.opacity(0.05))

                HStack {
                    infoRow(label: "Nguồn nhị phân", value: engine.source.description)
                    Spacer()
                    infoRow(label: "Phiên bản CLI", value: engine.version ?? "Unknown")
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var cleanerSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BẢO VỆ & DANH MỤC DỌN DẸP")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Cơ chế phân loại và bảo vệ:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 8) {
                    bulletRow(icon: "hammer.fill", color: .cyan, title: "Developer Tools", desc: "Xcode DerivedData, npm cache, cargo, clang, pip, bun caches.")
                    bulletRow(icon: "app.badge.fill", color: .orange, title: "App Caches", desc: "Bộ nhớ đệm Chrome, Safari, ứng dụng và GeoServices.")
                    bulletRow(icon: "doc.text.fill", color: .purple, title: "Hệ Thống & Logs", desc: "Diagnostic reports, crash logs, app logs và simulator logs.")
                    bulletRow(icon: "trash.fill", color: .red, title: "Thùng Rác (~/.Trash)", desc: "Dọn dẹp an toàn qua Finder AppleScript chuẩn macOS.")
                }

                Divider().background(Color.white.opacity(0.05))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tệp cấu hình Whitelist bảo vệ:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("~/.config/mole/whitelist")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var projectPurgePathsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CẤU HÌNH ĐƯỜNG DẪN DỰ ÁN (PROJECT PURGE)")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thư mục quét Build Artifacts:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Mole quét các thư mục này để tìm node_modules, target, .build và giải phóng dung lượng.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Default paths badge row
                VStack(alignment: .leading, spacing: 6) {
                    Text("Đường dẫn mặc định của hệ thống:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PurgePathsManager.defaultPaths, id: \.self) { path in
                                Text(path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.06))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.05))

                // Custom paths list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Đường dẫn tùy chỉnh bổ sung (\(viewModel.customPurgePaths.count)):")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)

                    if viewModel.customPurgePaths.isEmpty {
                        Text("Chưa có thư mục tùy chỉnh nào được cấu hình.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(viewModel.customPurgePaths, id: \.self) { path in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(Color.cyan)
                                    .font(.system(size: 12))
                                Text(path)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.white)
                                Spacer()
                                Button {
                                    viewModel.removePath(path)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.red.opacity(0.8))
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Add custom path input
                    HStack(spacing: 8) {
                        TextField("Thêm đường dẫn mới (vd: /Volumes/Data/Repos)", text: $viewModel.newPurgePathInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )

                        Button {
                            viewModel.addPath()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Thêm")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.newPurgePathInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var hardwareAndAppInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("THÔNG TIN PHẦN CỨNG & HỆ THỐNG")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                if let hw = telemetryService.snapshot?.hardware {
                    infoRow(label: "Thiết bị", value: hw.model)
                    infoRow(label: "Bộ xử lý (CPU)", value: hw.cpuModel)
                    infoRow(label: "Bộ nhớ RAM", value: hw.totalRam)
                    infoRow(label: "Dung lượng đĩa", value: hw.diskSize)
                    infoRow(label: "macOS Build", value: hw.osVersion)
                } else {
                    Text("Đang tải dữ liệu phần cứng...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider().background(Color.white.opacity(0.05))

                infoRow(label: "Ứng dụng Roche", value: "v1.0.0 (Native GUI)")
                infoRow(label: "Giao thức Seam", value: "MoleClientProtocol (Swift 6)")
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func bulletRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
}

public struct SettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        SettingsView(telemetryService: TelemetryService(client: MockMoleClient()))
    }
}
