import SwiftUI

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CÀI ĐẶT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text("Cấu Hình Ứng Dụng & Mole CLI")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

                Divider().background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 14) {
                    Text("THÔNG TIN HỆ THỐNG")
                        .font(.caption.bold().monospaced())
                        .foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        HStack {
                            Text("Engine").foregroundStyle(.secondary)
                            Spacer()
                            Text("Mole CLI").foregroundStyle(.white).bold()
                        }
                        Divider().background(Color.white.opacity(0.05))
                        HStack {
                            Text("Repository").foregroundStyle(.secondary)
                            Spacer()
                            Text("github.com/tw93/mole").foregroundStyle(.orange)
                        }
                        Divider().background(Color.white.opacity(0.05))
                        HStack {
                            Text("Phiên bản Roche").foregroundStyle(.secondary)
                            Spacer()
                            Text("0.1.0 (Alpha)").foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer()
            }
            .padding(24)
        }
    }
}
