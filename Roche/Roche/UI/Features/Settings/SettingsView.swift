import SwiftUI

public struct SettingsView: View {
    @Bindable var telemetryService: TelemetryService
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

                    // 4. System & App Info
                    hardwareAndAppInfoSection
                }
                .padding(24)
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CÀI ĐẶT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
            Text("Cấu Hình Ứng Dụng & Mole Engine")
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
    }

    private var autoRefreshSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TỰ ĐỘNG LÀM MỚI (AUTO-REFRESH TELEMETRY)")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.secondary)

            VStack(spacing: 14) {
                // Toggle row
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tự động cập nhật chỉ số hệ thống")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Định kỳ thu thập CPU, RAM, nhiệt độ, mạng và ổ đĩa theo thời gian thực")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $telemetryService.isAutoRefreshEnabled)
                        .toggleStyle(.switch)
                }

                if telemetryService.isAutoRefreshEnabled {
                    Divider().background(Color.white.opacity(0.05))

                    // Interval picker row
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tần số cập nhật (Interval)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(telemetryService.interval.detailedDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Picker("", selection: $telemetryService.interval) {
                            ForEach(AutoRefreshInterval.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }

                    Divider().background(Color.white.opacity(0.05))

                    // Status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Đang chạy ngầm mỗi \(telemetryService.interval.label)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.green)
                        Spacer()
                    }
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

    private var engineSection: some View {
        let engine = telemetryService.engineInfo
        return VStack(alignment: .leading, spacing: 14) {
            Text("TRẠNG THÁI MOLE ENGINE")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                HStack {
                    Text("Nguồn Engine").foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(engine.source == .notFound ? Color.red : Color.green)
                            .frame(width: 7, height: 7)
                        Text(engine.source.rawValue)
                            .foregroundStyle(.white)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }

                Divider().background(Color.white.opacity(0.05))

                HStack {
                    Text("Đường dẫn thực thi").foregroundStyle(.secondary)
                    Spacer()
                    Text(engine.executablePath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }

                Divider().background(Color.white.opacity(0.05))

                HStack {
                    Text("Phiên bản Mole Core").foregroundStyle(.secondary)
                    Spacer()
                    Text(engine.version)
                        .foregroundStyle(.white)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
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
                    infoRow(label: "Hệ điều hành", value: hw.osVersion)
                } else {
                    infoRow(label: "Hệ thống", value: "Apple Silicon Mac")
                }

                Divider().background(Color.white.opacity(0.05))

                infoRow(label: "Phiên bản Roche", value: "0.1.0 (Architecture: Deep Module)")
                infoRow(label: "Bản quyền", value: "MIT License • tw93/mole")
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).font(.system(size: 13))
            Spacer()
            Text(value).foregroundStyle(.white).font(.system(size: 13, weight: .medium))
        }
    }
}

#Preview("Settings View") {
    SettingsView(telemetryService: TelemetryService(client: MockMoleClient()))
}
