import SwiftUI

public struct MetricCard: View {
    public let title: String
    public let value: String
    public let subtitle: String
    public let accentColor: Color

    public init(
        title: String,
        value: String,
        subtitle: String,
        accentColor: Color = .orange
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.accentColor = accentColor
    }

    public var body: some View {
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
