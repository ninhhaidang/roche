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
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
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
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
    }

    private var initialWelcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "bubbles.and.sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 10) {
                Text("DỌN DẸP AN TOÀN VỚI MOLE")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("Quét kiểm tra (Clean Scan) các tệp rác, bộ nhớ đệm ứng dụng, Xcode DerivedData và Thùng rác mà không xóa bất kỳ dữ liệu nào cho đến khi bạn xác nhận.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
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
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Spacer()
        }
        .padding(32)
    }

    private var scanningLoadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(.orange)

            VStack(spacing: 6) {
                Text("Đang quét rác hệ thống qua Mole Engine...")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Thực thi Clean Scan phân loại Dev, App Caches, Logs và Thùng rác...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var cleaningLoadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(.orange)

            VStack(spacing: 6) {
                Text("Đang tiến hành dọn dẹp...")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Xóa an toàn các tệp bộ nhớ đệm và dọn thùng rác...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    private func failureView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.red)
            }

            VStack(spacing: 8) {
                Text("Quét Rác Thất Bại")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            HStack(spacing: 12) {
                Button {
                    service.reset()
                } label: {
                    Text("Đóng")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                Button {
                    Task {
                        await service.scan()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Thử Lại")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

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
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(lastClean.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Summary Banner Card
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TỔNG RÁC PHÁT HIỆN")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(result.formattedTotalSize)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.orange)
                        }

                        Divider().frame(height: 36).background(Color.white.opacity(0.1))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("SỐ LƯỢNG MỤC")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("\(result.totalItemsCount)")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        Divider().frame(height: 36).background(Color.white.opacity(0.1))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("ĐÃ CHỌN ĐỂ DỌN")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(service.formattedSelectedTotalSize)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(service.selectedTotalBytes > 0 ? .green : .secondary)
                        }

                        Spacer()

                        // Selection Actions
                        HStack(spacing: 8) {
                            Button("Chọn tất cả") {
                                service.selectAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Bỏ chọn") {
                                service.deselectAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(service.formattedSelectedTotalSize)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
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
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!service.canCleanSelected)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.6))
        }
    }

    private func categoryCard(_ category: CleanCategory) -> some View {
        let isSelected = service.selectedCategories.contains(category.type)
        let isExpanded = expandedCategory == category.type

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Checkbox
                Button {
                    service.toggleCategory(category.type)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.orange : Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)

                // Category Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor(category.type).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: category.iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(categoryColor(category.type))
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(category.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Text("(\(category.itemCount) mục)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Text(category.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Size
                Text(category.formattedSize)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(category.sizeBytes > 0 ? .white : .secondary)

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
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 20, height: 20)
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
                                    .fill(categoryColor(category.type).opacity(0.6))
                                    .frame(width: 5, height: 5)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text(item.path)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(item.formattedSize)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }

                        if category.items.count > 12 {
                            Text("... và \(category.items.count - 12) mục khác")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.2))
                }
            }
        }
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.orange.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
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

#Preview("CleanerView Preview") {
    CleanerView(service: CleanerService(client: MockMoleClient()))
}
