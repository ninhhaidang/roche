import SwiftUI

public struct DashboardView: View {
    @Bindable var service: TelemetryService

    public init(service: TelemetryService) {
        self.service = service
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ROCHE LIMIT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                        Text(service.snapshot?.hardware.model ?? "Mac System")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()

                    AutoRefreshToggleControl(service: service, style: .headerCapsule)

                    if let snapshot = service.snapshot {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(snapshot.healthScore)")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(scoreColor(snapshot.healthScore))
                                Text("/100")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Text(snapshot.healthScoreMsg.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(scoreColor(snapshot.healthScore))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(scoreColor(snapshot.healthScore).opacity(0.3), lineWidth: 1)
                        )
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Telemetry Metrics Grid
                if let snapshot = service.snapshot {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            MetricCard(
                                title: "CPU USAGE",
                                value: String(format: "%.1f%%", snapshot.cpu.usage),
                                subtitle: "\(snapshot.hardware.cpuModel) (\(snapshot.cpu.logicalCpu) Cores)",
                                accentColor: .orange
                            )

                            MetricCard(
                                title: "MEMORY",
                                value: snapshot.hardware.totalRam,
                                subtitle: "Áp lực: \(snapshot.memory.pressure.uppercased()) (\(String(format: "%.0f%%", snapshot.memory.usedPercent)))",
                                accentColor: .purple
                            )

                            if let thermal = snapshot.thermal, let cpuTemp = thermal.cpuTemp {
                                MetricCard(
                                    title: "THERMALS",
                                    value: String(format: "%.1f°C", cpuTemp),
                                    subtitle: thermal.fanSpeed != nil ? "Quạt: \(thermal.fanSpeed!) RPM" : "Công suất: \(String(format: "%.1fW", thermal.systemPower ?? 0))",
                                    accentColor: .red
                                )
                            } else {
                                MetricCard(
                                    title: "THERMALS",
                                    value: "Bình thường",
                                    subtitle: "Cảm biến ổn định",
                                    accentColor: .red
                                )
                            }

                            if let battery = snapshot.batteries?.first {
                                MetricCard(
                                    title: "BATTERY",
                                    value: String(format: "%.0f%%", battery.percent),
                                    subtitle: "\(battery.status) • \(battery.cycleCount ?? 0) chu kỳ",
                                    accentColor: .yellow
                                )
                            } else {
                                MetricCard(
                                    title: "POWER",
                                    value: "AC Power",
                                    subtitle: "Nguồn điện trực tiếp",
                                    accentColor: .yellow
                                )
                            }

                            MetricCard(
                                title: "STORAGE",
                                value: snapshot.hardware.diskSize,
                                subtitle: snapshot.trashSize != nil ? "Rác: \(formatBytes(snapshot.trashSize!))" : "Primary Drive",
                                accentColor: .green
                            )

                            MetricCard(
                                title: "UPTIME",
                                value: snapshot.uptime,
                                subtitle: "Host: \(snapshot.host)",
                                accentColor: .blue
                            )
                        }
                    }
                } else if service.isLoading {
                    Spacer()
                    ProgressView("Đang quét qua Mole engine...")
                        .foregroundStyle(.white)
                    Spacer()
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Text(service.errorMessage ?? "Chưa có dữ liệu.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }

                Spacer()

                // Action Button
                Button {
                    Task {
                        await service.refresh()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(service.isLoading ? "Đang quét..." : "Làm mới dữ liệu")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(service.isLoading)
            }
            .padding(24)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? .green : (score >= 60 ? .orange : .red)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
