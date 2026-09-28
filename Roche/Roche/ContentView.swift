import SwiftUI

// MARK: - Data Models
struct MoleSystemReport: Codable {
    let host: String
    let uptime: String
    let healthScore: Int
    let healthScoreMsg: String
    let hardware: HardwareInfo
    let cpu: CPUDetails

    enum CodingKeys: String, CodingKey {
        case host, uptime
        case healthScore = "health_score"
        case healthScoreMsg = "health_score_msg"
        case hardware, cpu
    }
}

struct HardwareInfo: Codable {
    let model: String
    let cpuModel: String
    let totalRam: String
    let diskSize: String

    enum CodingKeys: String, CodingKey {
        case model
        case cpuModel = "cpu_model"
        case totalRam = "total_ram"
        case diskSize = "disk_size"
    }
}

struct CPUDetails: Codable {
    let usage: Double
    let logicalCpu: Int

    enum CodingKeys: String, CodingKey {
        case usage
        case logicalCpu = "logical_cpu"
    }
}

// MARK: - Main View
struct ContentView: View {
    @State private var report: MoleSystemReport?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ROCHE LIMIT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                        Text(report?.hardware.model ?? "Mac System")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()

                    if let report = report {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(report.healthScore)")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(scoreColor(report.healthScore))
                                Text("/100")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Text(report.healthScoreMsg.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(scoreColor(report.healthScore))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(scoreColor(report.healthScore).opacity(0.3), lineWidth: 1)
                        )
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Metrics Grid
                if let report = report {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        MetricCard(
                            title: "CPU USAGE",
                            value: String(format: "%.1f%%", report.cpu.usage),
                            subtitle: "\(report.hardware.cpuModel) (\(report.cpu.logicalCpu) Cores)",
                            accentColor: .orange
                        )

                        MetricCard(
                            title: "MEMORY",
                            value: report.hardware.totalRam,
                            subtitle: "Unified Memory",
                            accentColor: .purple
                        )

                        MetricCard(
                            title: "UPTIME",
                            value: report.uptime,
                            subtitle: "Host: \(report.host)",
                            accentColor: .blue
                        )

                        MetricCard(
                            title: "STORAGE CAPACITY",
                            value: report.hardware.diskSize,
                            subtitle: "Primary Drive",
                            accentColor: .green
                        )
                    }
                } else if isLoading {
                    Spacer()
                    ProgressView("Đang quét qua Mole engine...")
                        .foregroundStyle(.white)
                    Spacer()
                } else {
                    Spacer()
                    Text(errorMessage ?? "Nhấn nút bên dưới để bắt đầu kiểm tra.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Spacer()

                // Action Button
                Button {
                    fetchTelemetry()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(isLoading ? "Đang quét..." : "Làm mới dữ liệu")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isLoading)
            }
            .padding(24)
        }
        .frame(minWidth: 540, minHeight: 460)
        .onAppear {
            fetchTelemetry()
        }
    }

    private func fetchTelemetry() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let candidates = [
                "/opt/homebrew/bin/mo",
                "/usr/local/bin/mo",
                Bundle.main.path(forResource: "mo", ofType: nil) ?? ""
            ]
            let executable = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/mo"

            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["status", "--json"]
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let decoded = try JSONDecoder().decode(MoleSystemReport.self, from: data)

                DispatchQueue.main.async {
                    self.report = decoded
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Lỗi đọc dữ liệu: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? .green : (score >= 60 ? .orange : .red)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}
