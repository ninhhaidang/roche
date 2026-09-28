import SwiftUI

public struct SystemMonitorView: View {
    @Bindable var service: TelemetryService

    public init(service: TelemetryService) {
        self.service = service
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            if let snapshot = service.snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GIÁM SÁT HỆ THỐNG")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                            Text("Phân Tích Chi Tiết Phần Cứng & Tiến Trình")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }

                        Divider().background(Color.white.opacity(0.1))

                        // Per-Core CPU Section
                        if let perCore = snapshot.cpu.perCore, !perCore.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("TẢI TỪNG NHÂN CPU (\(perCore.count) CORES)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Load: \(String(format: "%.2f, %.2f, %.2f", snapshot.cpu.load1, snapshot.cpu.load5, snapshot.cpu.load15))")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                }

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(0..<perCore.count, id: \.self) { index in
                                        let usage = perCore[index]
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("Core \(index + 1)")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Text(String(format: "%.0f%%", usage))
                                                    .font(.caption2.monospaced())
                                                    .foregroundStyle(usage > 70 ? .red : (usage > 40 ? .orange : .green))
                                            }
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(Color.white.opacity(0.08))
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(usage > 70 ? Color.red : (usage > 40 ? Color.orange : Color.green))
                                                        .frame(width: geo.size.width * min(1.0, max(0.0, usage / 100.0)))
                                                }
                                            }
                                            .frame(height: 6)
                                        }
                                        .padding(10)
                                        .background(Color.white.opacity(0.03))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }

                        // Top Processes Section
                        if let processes = snapshot.topProcesses, !processes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("TIẾN TRÌNH CHIẾM TÀI NGUYÊN CAO")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                VStack(spacing: 6) {
                                    // Header
                                    HStack {
                                        Text("PID").frame(width: 60, alignment: .leading)
                                        Text("Tên Tiến Trình").frame(maxWidth: .infinity, alignment: .leading)
                                        Text("CPU %").frame(width: 80, alignment: .trailing)
                                        Text("RAM %").frame(width: 80, alignment: .trailing)
                                    }
                                    .font(.caption2.bold().monospaced())
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)

                                    Divider().background(Color.white.opacity(0.08))

                                    // Rows
                                    ForEach(processes.prefix(8)) { proc in
                                        HStack {
                                            Text("\(proc.pid)")
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                                .frame(width: 60, alignment: .leading)

                                            Text(proc.name)
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            Text(String(format: "%.1f%%", proc.cpu))
                                                .font(.caption.monospaced())
                                                .foregroundStyle(proc.cpu > 20 ? .orange : .white)
                                                .frame(width: 80, alignment: .trailing)

                                            Text(String(format: "%.1f%%", proc.memory))
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                                .frame(width: 80, alignment: .trailing)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.02))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(24)
                }
            } else if service.isLoading {
                ProgressView("Đang tải dữ liệu giám sát...")
                    .foregroundStyle(.white)
            } else {
                Text(service.errorMessage ?? "Chưa có dữ liệu.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
