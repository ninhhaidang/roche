import SwiftUI

public struct AutoRefreshToggleControl: View {
    public enum Style {
        case headerCapsule
        case sidebarRow
    }

    @Bindable var service: TelemetryService
    public let style: Style

    public init(service: TelemetryService, style: Style = .headerCapsule) {
        self.service = service
        self.style = style
    }

    public var body: some View {
        switch style {
        case .headerCapsule:
            headerCapsuleView
        case .sidebarRow:
            sidebarRowView
        }
    }

    private var headerCapsuleView: some View {
        HStack(spacing: 8) {
            Button {
                service.toggleAutoRefresh()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(service.isAutoRefreshEnabled ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text("Auto")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(service.isAutoRefreshEnabled ? .white : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if service.isAutoRefreshEnabled {
                Picker("", selection: $service.interval) {
                    ForEach(AutoRefreshInterval.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 84)
                .controlSize(.small)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var sidebarRowView: some View {
        HStack {
            Button {
                service.toggleAutoRefresh()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: service.isAutoRefreshEnabled ? "arrow.triangle.2.circlepath.circle.fill" : "pause.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(service.isAutoRefreshEnabled ? .orange : .secondary)
                    Text(service.isAutoRefreshEnabled ? "Auto (\(service.interval.label))" : "Auto: Tắt")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(service.isAutoRefreshEnabled ? .white : .secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Toggle("", isOn: $service.isAutoRefreshEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }
}
