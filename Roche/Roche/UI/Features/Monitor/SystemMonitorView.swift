import SwiftUI

public struct SystemMonitorView: View {
    @Bindable var service: TelemetryService

    public init(service: TelemetryService) {
        self.service = service
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.1))

                if let snapshot = service.snapshot {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Row 1: System Quick Metrics Overview (3 Bento Cards)
                            metricsSummaryRow(snapshot)

                            // Row 2: Per-Core Detailed Activity Grid
                            if let perCore = snapshot.cpu.perCore, !perCore.isEmpty {
                                perCoreSection(perCore, snapshot: snapshot)
                            }

                            // Row 3: Top Processes Glass Table
                            if let processes = snapshot.topProcesses, !processes.isEmpty {
                                topProcessesSection(processes)
                            }
                        }
                        .padding(24)
                    }
                } else if service.isLoading {
                    Spacer()
                    ProgressView("Đang tải dữ liệu giám sát...")
                        .foregroundStyle(.white)
                    Spacer()
                } else {
                    Spacer()
                    Text(service.errorMessage ?? "Chưa có dữ liệu.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("GIÁM SÁT HỆ THỐNG")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .tracking(0.5)
                Text("Phân Tích Chi Tiết Phần Cứng & Tiến Trình")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    Task {
                        await service.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(service.isLoading ? .orange : .white.opacity(0.7))
                        .padding(7)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(service.isLoading)

                AutoRefreshToggleControl(service: service, style: .headerCapsule)
            }
        }
    }

    private func metricsSummaryRow(_ snapshot: MetricsSnapshot) -> some View {
        HStack(spacing: 16) {
            // CPU Overall
            LiquidBentoCard(
                glowLevel: AdaptiveGlowLevel.from(loadPercentage: snapshot.cpu.usage),
                cornerRadius: 18,
                glowAnchor: .topLeading
            ) {
                HStack(spacing: 14) {
                    Image(systemName: "cpu")
                        .font(.system(size: 20))
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TỔNG TẢI CPU")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(String(format: "%.1f%%", snapshot.cpu.usage))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(16)
            }

            // RAM Memory
            LiquidBentoCard(
                glowLevel: snapshot.memory.usedPercent >= 80 ? .critical : .nominal,
                cornerRadius: 18,
                glowAnchor: .top
            ) {
                HStack(spacing: 14) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 20))
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RAM ĐANG DÙNG")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(String(format: "%.0f%%", snapshot.memory.usedPercent))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(16)
            }

            // Active Tasks
            LiquidBentoCard(
                glowLevel: .nominal,
                cornerRadius: 18,
                glowAnchor: .topTrailing
            ) {
                HStack(spacing: 14) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TIẾN TRÌNH HOẠT ĐỘNG")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(snapshot.procs) PROCS")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
    }

    private func perCoreSection(_ perCore: [Double], snapshot: MetricsSnapshot) -> some View {
        LiquidBentoCard(
            glowLevel: AdaptiveGlowLevel.from(loadPercentage: snapshot.cpu.usage),
            cornerRadius: 22,
            glowAnchor: .topLeading
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("TẢI TỪNG NHÂN CPU (\(perCore.count) CORES)", systemImage: "square.grid.2x2")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("Load: \(String(format: "%.2f, %.2f, %.2f", snapshot.cpu.load1, snapshot.cpu.load5, snapshot.cpu.load15))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.04))
                        .clipShape(Capsule())
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<perCore.count, id: \.self) { index in
                        let usage = perCore[index]
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Core \(index + 1)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                                Spacer()
                                Text(String(format: "%.0f%%", usage))
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(coreColor(usage))
                            }

                            // Capsule Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 5)
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [coreColor(usage).opacity(0.8), coreColor(usage)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * min(1.0, max(0.0, usage / 100.0)), height: 5)
                                        .shadow(color: coreColor(usage).opacity(0.4), radius: 3, x: 0, y: 0)
                                        .animation(.snappy(duration: 0.35), value: usage)
                                }
                            }
                            .frame(height: 5)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(20)
        }
    }

    private func topProcessesSection(_ processes: [MoleProcessInfo]) -> some View {
        LiquidBentoCard(
            glowLevel: .nominal,
            cornerRadius: 22,
            glowAnchor: .bottomLeading
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("TIẾN TRÌNH CHIẾM NHIỀU TÀI NGUYÊN NHẤT", systemImage: "list.bullet.rectangle")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("TOP \(min(processes.count, 8))")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }

                VStack(spacing: 4) {
                    // Header Row
                    HStack {
                        Text("PID").frame(width: 70, alignment: .leading)
                        Text("TÊN TIẾN TRÌNH").frame(maxWidth: .infinity, alignment: .leading)
                        Text("CPU").frame(width: 90, alignment: .trailing)
                        Text("BỘ NHỚ").frame(width: 90, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)

                    Divider().background(Color.white.opacity(0.08))

                    // Process Rows
                    ForEach(processes.prefix(8)) { proc in
                        HStack {
                            Text("\(proc.pid)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                                .frame(width: 70, alignment: .leading)

                            HStack(spacing: 8) {
                                Image(systemName: "app.dashed")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text(proc.name)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(String(format: "%.1f%%", proc.cpu))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(proc.cpu > 25.0 ? Color.orange : Color.white)
                                .frame(width: 90, alignment: .trailing)

                            Text(String(format: "%.1f%%", proc.memory))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.65))
                                .frame(width: 90, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(20)
        }
    }

    private func coreColor(_ usage: Double) -> Color {
        if usage >= 75.0 {
            return .red
        } else if usage >= 40.0 {
            return .orange
        } else {
            return .cyan
        }
    }
}
