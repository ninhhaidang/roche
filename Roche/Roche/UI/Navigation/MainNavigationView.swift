import SwiftUI

public struct MainNavigationView: View {
    @State private var selectedItem: NavigationItem? = .dashboard
    @Bindable var service: TelemetryService
    @State private var cleanEngine: CleanEngine

    public init(service: TelemetryService, cleanerService: CleanEngine? = nil) {
        self.service = service
        _cleanEngine = State(initialValue: cleanerService ?? CleanEngine())
    }

    public var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                // App Brand
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                            .shadow(color: .orange.opacity(0.8), radius: 6, x: 0, y: 0)
                    }

                    Text("ROCHE")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(0.5)

                    Spacer()

                    Text("v1.0")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.04))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Navigation Items List
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(NavigationItem.allCases) { item in
                            let isSelected = selectedItem == item
                            Button {
                                selectedItem = item
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.iconName)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(isSelected ? Color.orange : Color.white.opacity(0.5))
                                        .frame(width: 20)

                                    Text(item.title)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(isSelected ? .white : .white.opacity(0.7))

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    ZStack {
                                        if isSelected {
                                            Color.orange.opacity(0.14)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(isSelected ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                }

                Spacer()

                // Engine Status Footer
                VStack(spacing: 10) {
                    // Engine Status Pill
                    HStack(spacing: 8) {
                        Circle()
                            .fill(service.snapshot != nil ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                            .shadow(color: (service.snapshot != nil ? Color.green : Color.orange).opacity(0.6), radius: 4)

                        Text(service.snapshot != nil ? "Mole CLI: Sẵn sàng" : "Đang kết nối...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer()
                    }

                    Divider().background(Color.white.opacity(0.06))

                    // Auto-refresh Row
                    AutoRefreshToggleControl(service: service, style: .sidebarRow)
                }
                .padding(14)
                .background(
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Color.white.opacity(0.02)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .specularBorder(cornerRadius: 14)
                .padding(10)
            }
            .background(Color.black.opacity(0.92))
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
        } detail: {
            Group {
                switch selectedItem ?? .dashboard {
                case .dashboard:
                    DashboardView(service: service)
                case .monitor:
                    SystemMonitorView(service: service)
                case .cleaner:
                    CleanerView(service: cleanEngine)
                case .settings:
                    SettingsView(telemetryService: service)
                }
            }
        }
    }
}
