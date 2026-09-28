import SwiftUI

public struct CleanerView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "bubbles.and.sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("DỌN DẸP HỆ THỐNG")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Quét và dọn rác Xcode DerivedData, Caches, Homebrew, và File tạm qua Mole Engine.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                Button {
                    // Cleaner action will be wired in next phase
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Bắt đầu Quét Rác (Dry-Run)")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(32)
        }
    }
}
