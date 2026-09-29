import SwiftUI

// MARK: - Adaptive Glow Color State

public enum AdaptiveGlowLevel: Sendable {
    case nominal      // Cool cyan / emerald for normal load
    case elevated     // Warm amber / orange for medium load
    case critical     // Crimson / rose for heavy load or thermal warning

    public var primaryColor: Color {
        switch self {
        case .nominal: return .cyan
        case .elevated: return .orange
        case .critical: return .red
        }
    }

    public var secondaryColor: Color {
        switch self {
        case .nominal: return .teal
        case .elevated: return .yellow
        case .critical: return .purple
        }
    }

    public static func from(loadPercentage: Double) -> AdaptiveGlowLevel {
        if loadPercentage >= 75.0 {
            return .critical
        } else if loadPercentage >= 40.0 {
            return .elevated
        } else {
            return .nominal
        }
    }

    public static func from(healthScore: Int) -> AdaptiveGlowLevel {
        if healthScore >= 80 {
            return .nominal
        } else if healthScore >= 60 {
            return .elevated
        } else {
            return .critical
        }
    }
}

// MARK: - Specular Border View Modifier

public struct SpecularBorderModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let lineWidth: CGFloat
    public let opacity: Double

    public init(cornerRadius: CGFloat = 22, lineWidth: CGFloat = 1, opacity: Double = 0.22) {
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.opacity = opacity
    }

    public func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(opacity),
                                Color.white.opacity(opacity * 0.4),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            )
    }
}

public extension View {
    func specularBorder(cornerRadius: CGFloat = 22, lineWidth: CGFloat = 1, opacity: Double = 0.22) -> some View {
        modifier(SpecularBorderModifier(cornerRadius: cornerRadius, lineWidth: lineWidth, opacity: opacity))
    }
}

// MARK: - Liquid Bento Card Container

public struct LiquidBentoCard<Content: View>: View {
    public let glowLevel: AdaptiveGlowLevel
    public let cornerRadius: CGFloat
    public let glowAnchor: UnitPoint
    @ViewBuilder public let content: () -> Content

    public init(
        glowLevel: AdaptiveGlowLevel = .nominal,
        cornerRadius: CGFloat = 22,
        glowAnchor: UnitPoint = .topTrailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.glowLevel = glowLevel
        self.cornerRadius = cornerRadius
        self.glowAnchor = glowAnchor
        self.content = content
    }

    public var body: some View {
        content()
            .background(
                ZStack {
                    // Translucent frosted glass backing
                    Rectangle()
                        .fill(.ultraThinMaterial)

                    // Adaptive ambient glow
                    RadialGradient(
                        colors: [
                            glowLevel.primaryColor.opacity(0.18),
                            glowLevel.secondaryColor.opacity(0.06),
                            Color.clear
                        ],
                        center: glowAnchor,
                        startRadius: 8,
                        endRadius: 260
                    )
                }
            )
            .specularBorder(cornerRadius: cornerRadius)
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
            .animation(.snappy(duration: 0.35), value: glowLevel.primaryColor)
    }
}
