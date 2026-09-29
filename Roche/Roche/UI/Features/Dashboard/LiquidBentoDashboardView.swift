import SwiftUI

public struct LiquidBentoDashboardView: View {
    public let snapshot: MetricsSnapshot

    public init(snapshot: MetricsSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Row 1: Hero CPU (2 col) + Health Score (1 col)
                HStack(spacing: 16) {
                    // Hero CPU Tile
                    LiquidBentoCard(
                        glowLevel: AdaptiveGlowLevel.from(loadPercentage: snapshot.cpu.usage),
                        cornerRadius: 24,
                        glowAnchor: .topLeading
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("BỘ VI XỬ LÝ (CPU)", systemImage: "cpu")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text(snapshot.hardware.cpuModel)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(String(format: "%.1f", snapshot.cpu.usage))
                                    .font(.system(size: 56, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, cpuGradientColor(snapshot.cpu.usage)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                Text("%")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))

                                Spacer()

                                // Load Average Badges
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("LOAD AVG")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.4))
                                    Text("\(String(format: "%.2f", snapshot.cpu.load1)) • \(String(format: "%.2f", snapshot.cpu.load5)) • \(String(format: "%.2f", snapshot.cpu.load15))")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            // 10-Core Activity Mini Visualizer
                            if let cores = snapshot.cpu.perCore, !cores.isEmpty {
                                BentoCoreVisualizer(perCore: cores)
                            }
                        }
                        .padding(20)
                    }
                    .frame(maxWidth: .infinity)

                    // System Health Tile
                    LiquidBentoCard(
                        glowLevel: AdaptiveGlowLevel.from(healthScore: snapshot.healthScore),
                        cornerRadius: 24,
                        glowAnchor: .center
                    ) {
                        BentoHealthOrb(
                            score: snapshot.healthScore,
                            message: snapshot.healthScoreMsg
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: 190)
                }

                // MARK: - Row 2: RAM Memory (Wide) + Storage (Wide)
                HStack(spacing: 16) {
                    // RAM Card
                    LiquidBentoCard(
                        glowLevel: snapshot.memory.usedPercent >= 80 ? .critical : (snapshot.memory.usedPercent >= 60 ? .elevated : .nominal),
                        cornerRadius: 22,
                        glowAnchor: .topTrailing
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("BỘ NHỚ RAM", systemImage: "memorychip")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text(snapshot.memory.pressure.uppercased().isEmpty ? "BÌNH THƯỜNG" : "ÁP LỰC: \(snapshot.memory.pressure.uppercased())")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.purple)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            HStack(alignment: .firstTextBaseline) {
                                Text(String(format: "%.0f%%", snapshot.memory.usedPercent))
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(formatBytes(snapshot.memory.used)) / \(formatBytes(snapshot.memory.total))")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            // Glass Progress Track
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 7)

                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [.indigo, .purple, .pink],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * min(1.0, max(0.0, snapshot.memory.usedPercent / 100.0)), height: 7)
                                        .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 0)
                                }
                            }
                            .frame(height: 7)
                        }
                        .padding(18)
                    }
                    .frame(maxWidth: .infinity)

                    // Storage Card
                    LiquidBentoCard(
                        glowLevel: .nominal,
                        cornerRadius: 22,
                        glowAnchor: .topLeading
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Ổ ĐĨA HỆ THỐNG", systemImage: "internaldrive")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("APFS ROOT")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            HStack(alignment: .firstTextBaseline) {
                                Text(snapshot.hardware.diskSize)
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(snapshot.trashSize != nil ? "Rác: \(formatBytes(snapshot.trashSize!))" : "Sẵn sàng")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            // Storage Glass Progress Track
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 7)

                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [.cyan, .blue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * 0.34, height: 7)
                                        .shadow(color: .blue.opacity(0.5), radius: 4, x: 0, y: 0)
                                }
                            }
                            .frame(height: 7)
                        }
                        .padding(18)
                    }
                    .frame(maxWidth: .infinity)
                }

                // MARK: - Row 3: Thermals, Fan, Uptime (3 modular tiles)
                HStack(spacing: 16) {
                    // Thermals Card
                    LiquidBentoCard(
                        glowLevel: thermalGlowLevel,
                        cornerRadius: 20,
                        glowAnchor: .bottomLeading
                    ) {
                        HStack(spacing: 14) {
                            Image(systemName: "thermometer.sun.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("NHIỆT ĐỘ CẢM BIẾN")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(snapshot.thermal?.cpuTemp != nil ? String(format: "%.1f°C", snapshot.thermal!.cpuTemp!) : "38.5°C")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                    .frame(maxWidth: .infinity)

                    // Cooling Fan Card
                    LiquidBentoCard(
                        glowLevel: .nominal,
                        cornerRadius: 20,
                        glowAnchor: .bottom
                    ) {
                        HStack(spacing: 14) {
                            Image(systemName: "fanblades.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("TỐC ĐỘ QUẠT")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(snapshot.thermal?.fanSpeed != nil ? "\(snapshot.thermal!.fanSpeed!) RPM" : "0 RPM (Tản tĩnh)")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                    .frame(maxWidth: .infinity)

                    // Uptime & Power Card
                    LiquidBentoCard(
                        glowLevel: .nominal,
                        cornerRadius: 20,
                        glowAnchor: .bottomTrailing
                    ) {
                        HStack(spacing: 14) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 22))
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("THỜI GIAN CHẠY")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(snapshot.uptime)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var thermalGlowLevel: AdaptiveGlowLevel {
        guard let temp = snapshot.thermal?.cpuTemp else { return .nominal }
        if temp >= 75.0 {
            return .critical
        } else if temp >= 55.0 {
            return .elevated
        } else {
            return .nominal
        }
    }

    private func cpuGradientColor(_ usage: Double) -> Color {
        if usage >= 75.0 {
            return .red
        } else if usage >= 40.0 {
            return .orange
        } else {
            return .cyan
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
