import SwiftUI

public struct MainNavigationView: View {
    @State private var selectedItem: NavigationItem? = .dashboard
    @Bindable var service: TelemetryService

    public init(service: TelemetryService) {
        self.service = service
    }

    public var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                // App Brand
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                    Text("ROCHE")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Navigation List
                List(NavigationItem.allCases, selection: $selectedItem) { item in
                    NavigationLink(value: item) {
                        Label {
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                        } icon: {
                            Image(systemName: item.iconName)
                                .font(.system(size: 14))
                                .foregroundStyle(selectedItem == item ? .orange : .secondary)
                        }
                    }
                }
                .listStyle(.sidebar)

                Spacer()

                // Engine Status Footer
                HStack(spacing: 8) {
                    Circle()
                        .fill(service.snapshot != nil ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(service.snapshot != nil ? "Mole CLI: Sẵn sàng" : "Đang kết nối...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.02))
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch selectedItem ?? .dashboard {
                case .dashboard:
                    DashboardView(service: service)
                case .monitor:
                    SystemMonitorView(service: service)
                case .cleaner:
                    CleanerView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}
