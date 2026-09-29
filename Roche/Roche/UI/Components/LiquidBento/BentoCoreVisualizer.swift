import SwiftUI

public struct BentoCoreVisualizer: View {
    public let perCore: [Double]

    public init(perCore: [Double]) {
        self.perCore = perCore
    }

    public var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<min(perCore.count, 12), id: \.self) { index in
                let load = perCore[index]
                VStack(spacing: 4) {
                    Spacer(minLength: 0)

                    // Core activity fill bar
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(barGradient(for: load))
                        .frame(height: max(4, CGFloat(load) * 0.32))
                        .shadow(color: barColor(for: load).opacity(0.4), radius: 3, x: 0, y: 0)
                        .animation(.snappy(duration: 0.35), value: load)

                    Text("C\(index + 1)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: 44)
                .padding(.horizontal, 2)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
    }

    private func barColor(for load: Double) -> Color {
        if load >= 75.0 {
            return .red
        } else if load >= 40.0 {
            return .orange
        } else {
            return .cyan
        }
    }

    private func barGradient(for load: Double) -> LinearGradient {
        let color = barColor(for: load)
        return LinearGradient(
            colors: [color.opacity(0.9), color.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
