import SwiftUI

public struct BentoHealthOrb: View {
    public let score: Int
    public let message: String

    public init(score: Int, message: String) {
        self.score = score
        self.message = message
    }

    private var scoreColor: Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    public var body: some View {
        VStack(spacing: 10) {
            Text("CHỈ SỐ SỨC KHỎE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(0.5)

            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 7)
                    .frame(width: 82, height: 82)

                // Neon Meter Arc
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100.0)
                    .stroke(
                        AngularGradient(
                            colors: [scoreColor.opacity(0.6), scoreColor, .cyan],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: 82, height: 82)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: scoreColor.opacity(0.6), radius: 8, x: 0, y: 0)
                    .animation(.snappy(duration: 0.35), value: score)

                // Center Metrics
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ 100")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Status Pill
            Text(message.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(scoreColor)
                .clipShape(Capsule())
                .shadow(color: scoreColor.opacity(0.5), radius: 6, x: 0, y: 2)
        }
        .padding(18)
    }
}
