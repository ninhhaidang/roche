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

                Divider().background(Color.white.opacity(0.1))

                // Telemetry Metrics Grid
                if let snapshot = service.snapshot {
                    LiquidBentoDashboardView(snapshot: snapshot)
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
                if service.snapshot == nil {
                    Spacer()
                    // Action Button (only in error or initial empty state)
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
