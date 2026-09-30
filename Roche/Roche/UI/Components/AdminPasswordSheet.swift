import SwiftUI

/// A Liquid Bento modal sheet for administrator password authentication.
/// Serves as the fallback mechanism when Touch ID is unavailable, canceled,
/// or when a MacBook is running in clamshell mode (closed lid).
public struct AdminPasswordSheet: View {
    public let title: String
    public let subtitle: String
    public let errorMessage: String?
    public let onSubmit: (String) -> Void
    public let onCancel: () -> Void

    @State private var password: String = ""
    @FocusState private var isPasswordFocused: Bool
    @Environment(\.dismiss) private var dismiss

    public init(
        title: String = "Xác thực Quản trị viên",
        subtitle: String = "Nhập mật khẩu quản trị viên macOS để cấp quyền thực thi các tác vụ bảo trì hệ thống sâu khi Touch ID không khả dụng.",
        errorMessage: String? = nil,
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.title = title
        self.subtitle = subtitle
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        LiquidBentoCard(glowLevel: errorMessage != nil ? .critical : .elevated, cornerRadius: 24, glowAnchor: .top) {
            VStack(spacing: 22) {
                // MARK: - Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        (errorMessage != nil ? Color.red : Color.orange).opacity(0.35),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 68, height: 68)

                        Image(systemName: errorMessage != nil ? "lock.trianglebadge.exclamationmark.fill" : "lock.shield.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: errorMessage != nil ? [.white, .red] : [.white, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // MARK: - Input Field & Validation
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))

                        SecureField("Mật khẩu tài khoản macOS", text: $password)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .focused($isPasswordFocused)
                            .onSubmit {
                                submitPassword()
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .specularBorder(cornerRadius: 12, lineWidth: 1, opacity: 0.28)

                    if let errorMessage = errorMessage, !errorMessage.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11))
                            Text(errorMessage)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Color.red.opacity(0.9))
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // MARK: - Actions
                HStack(spacing: 12) {
                    Button {
                        onCancel()
                        dismiss()
                    } label: {
                        Text("Hủy")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        submitPassword()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                            Text("Xác thực")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(password.isEmpty ? Color.orange.opacity(0.4) : Color.orange)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(password.isEmpty)
                }
            }
            .padding(26)
        }
        .frame(width: 420)
        .onAppear {
            isPasswordFocused = true
        }
    }

    private func submitPassword() {
        guard !password.isEmpty else { return }
        onSubmit(password)
        dismiss()
    }
}

// MARK: - Previews

#if DEBUG
public struct AdminPasswordSheet_Previews: PreviewProvider {
    public static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AdminPasswordSheet(
                onSubmit: { _ in },
                onCancel: {}
            )
        }
        .previewDisplayName("Standard Prompt")

        ZStack {
            Color.black.ignoresSafeArea()
            AdminPasswordSheet(
                errorMessage: "Mật khẩu không chính xác. Vui lòng thử lại.",
                onSubmit: { _ in },
                onCancel: {}
            )
        }
        .previewDisplayName("With Error State")
    }
}
#endif
