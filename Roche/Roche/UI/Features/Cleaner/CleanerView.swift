import SwiftUI

public struct CleanerView: View {
    @Bindable var service: CleanEngine
    @State private var showingConfirmation = false
    @State private var expandedCategory: CleanCategoryKind?

    public init(service: CleanEngine? = nil) {
        self.service = service ?? CleanEngine()
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.1))

                // Main Content
                if service.isScanning {
                    scanningLoadingView
                } else if service.isCleaning {
                    cleaningLoadingView
                } else if let result = service.scanResult {
                    scanResultsView(result)
                } else if case .failed(let message) = service.state {
                    failureView(message)
                } else {
                    initialWelcomeView
                }
            }
        }
        .confirmationDialog(
            "Xác nhận Dọn dẹp",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Dọn dẹp ngay (\(service.formattedSelectedTotalSize))", role: .destructive) {
                Task {
                    await service.cleanSelected()
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn dọn dẹp các mục đã chọn: \(service.selectedCategoriesSummary) (tổng cộng \(service.formattedSelectedTotalSize))? Thao tác này sẽ xóa an toàn và giải phóng dung lượng đĩa.")
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DỌN DẸP HỆ THỐNG")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .tracking(0.5)
                Text("Quét & Tối Ưu Hóa Bộ Nhớ Đệm")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            Spacer()

            if service.scanResult != nil && !service.isScanning && !service.isCleaning {
                Button {
                    Task {
                        await service.scan()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Quét lại")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var initialWelcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            LiquidBentoCard(glowLevel: .elevated, cornerRadius: 26, glowAnchor: .center) {
                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.16))
                            .frame(width: 90, height: 90)
                        Image(systemName: "bubbles.and.sparkles")
                            .font(.system(size: 42))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: .orange.opacity(0.5), radius: 8, x: 0, y: 0)
                    }

                    VStack(spacing: 8) {
                        Text("DỌN DẸP AN TOÀN VỚI MOLE")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Quét kiểm tra (Clean Scan) các tệp rác, bộ nhớ đệm ứng dụng, Xcode DerivedData và Thùng rác mà không xóa bất kỳ dữ liệu nào cho đến khi bạn xác nhận.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 440)
                    }

                    Button {
                        Task {
                            await service.scan()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                            Text("Bắt đầu Quét Rác (Clean Scan)")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .shadow(color: .orange.opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(32)
            }
            .frame(maxWidth: 540)

            Spacer()
        }
        .padding(32)
    }

    private var scanningLoadingView: some View {
        VStack(spacing: 20) {
            Spacer()

            LiquidBentoCard(glowLevel: .elevated, cornerRadius: 22, glowAnchor: .center) {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.orange)

                    VStack(spacing: 6) {
                        Text("Đang quét rác hệ thống qua Mole Engine...")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Thực thi Clean Scan phân loại Dev, App Caches, Logs và Thùng rác...")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(32)
            }
            .frame(maxWidth: 480)

            Spacer()
        }
    }

    private var cleaningLoadingView: some View {
        VStack(spacing: 20) {
            Spacer()

            LiquidBentoCard(glowLevel: .critical, cornerRadius: 22, glowAnchor: .center) {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.red)

                    VStack(spacing: 6) {
                        Text("Đang tiến hành dọn dẹp an toàn...")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Xóa an toàn các tệp bộ nhớ đệm và dọn Thùng rác theo yêu cầu...")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(32)
            }
            .frame(maxWidth: 480)

            Spacer()
        }
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            LiquidBentoCard(glowLevel: .critical, cornerRadius: 22, glowAnchor: .center) {
                VStack(spacing: 18) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.red)

                    VStack(spacing: 8) {
                        Text("Quét Rác Thất Bại")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                    }

                    HStack(spacing: 12) {
                        Button {
                            service.reset()
                        } label: {
                            Text("Đóng")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                await service.scan()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Thử Lại")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(28)
            }
            .frame(maxWidth: 480)

            Spacer()
        }
        .padding(32)
    }

    private func scanResultsView(_ result: CleanScanResult) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Success Banner if last clean executed
                    if let lastClean = service.lastCleanResult {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dọn dẹp thành công! Đã giải phóng \(lastClean.formattedReclaimedSize)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(lastClean.summaryText)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            ZStack {
                                Rectangle().fill(.ultraThinMaterial)
                                Color.green.opacity(0.12)
                            }
                        )
                        .specularBorder(cornerRadius: 14)
                    }

                    // Summary Bento Card
                    LiquidBentoCard(glowLevel: .elevated, cornerRadius: 20, glowAnchor: .topLeading) {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TỔNG RÁC PHÁT HIỆN")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(result.formattedTotalSize)
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.white, .orange], startPoint: .top, endPoint: .bottom)
                                    )
                            }

                            Divider().frame(height: 36).background(Color.white.opacity(0.1))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("SỐ LƯỢNG MỤC")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("\(result.totalItemsCount)")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            Divider().frame(height: 36).background(Color.white.opacity(0.1))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("DANH MỤC KHẢ DỤNG")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("\(result.categories.count)")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            // Selection Batch Controls
                            HStack(spacing: 8) {
                                Button("Chọn tất cả") {
                                    service.selectAll()
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                                .buttonStyle(.plain)

                                Button("Bỏ chọn") {
                                    service.deselectAll()
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.04))
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(18)
                    }

                    // Categories List
                    VStack(spacing: 12) {
                        ForEach(result.categories) { category in
                            categoryCard(category)
                        }
                    }
                }
                .padding(24)
            }

            // Bottom Action Bar
            Divider().background(Color.white.opacity(0.1))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dung lượng sẽ giải phóng:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(service.formattedSelectedTotalSize)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    showingConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Dọn Dẹp Ngay (\(service.formattedSelectedTotalSize))")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(service.canCleanSelected ? Color.orange : Color.gray.opacity(0.3))
                    .clipShape(Capsule())
                    .shadow(color: service.canCleanSelected ? .orange.opacity(0.4) : .clear, radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(!service.canCleanSelected)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Color.black.opacity(0.5)
                }
            )
        }
    }

    private func categoryCard(_ category: CleanCategory) -> some View {
        let isSelected = service.selectedCategories.contains(category.type)
        let isExpanded = expandedCategory == category.type
        let tint = categoryColor(category.type)

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Checkbox
                Button {
                    service.toggleCategory(category.type)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? tint : Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)

                // Category Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: category.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(category.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("(\(category.itemCount) mục)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Text(category.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                // Size
                Text(category.formattedSize)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(category.sizeBytes > 0 ? .white : .white.opacity(0.3))

                // Expand Items Disclosure Button
                if !category.items.isEmpty {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if expandedCategory == category.type {
                                expandedCategory = nil
                            } else {
                                expandedCategory = category.type
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)

            // Expanded Item List
            if isExpanded && !category.items.isEmpty {
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.06))

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(category.items.prefix(12)) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(tint.opacity(0.6))
                                    .frame(width: 5, height: 5)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text(item.path)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.35))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(item.formattedSize)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.vertical, 3)
                        }

                        if category.items.count > 12 {
                            Text("... và \(category.items.count - 12) mục khác")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.35))
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.3))
                }
            }
        }
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                if isSelected {
                    tint.opacity(0.04)
                }
            }
        )
        .specularBorder(cornerRadius: 14)
    }

    private func categoryColor(_ type: CleanCategoryKind) -> Color {
        switch type {
        case .dev:
            return .cyan
        case .appCaches:
            return .orange
        case .logs:
            return .purple
        case .trash:
            return .red
        }
    }
}
