import SwiftUI

public nonisolated enum NavigationItem: String, CaseIterable, Identifiable, Sendable {
    case dashboard
    case monitor
    case cleaner
    case uninstaller
    case optimizer
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "Tổng quan"
        case .monitor: return "Giám sát"
        case .cleaner: return "Dọn dẹp"
        case .uninstaller: return "Gỡ ứng dụng"
        case .optimizer: return "Tối ưu hóa"
        case .settings: return "Cài đặt"
        }
    }

    public var iconName: String {
        switch self {
        case .dashboard: return "gauge.with.needle"
        case .monitor: return "cpu"
        case .cleaner: return "bubbles.and.sparkles"
        case .uninstaller: return "trash"
        case .optimizer: return "bolt.fill"
        case .settings: return "gearshape"
        }
    }
}
