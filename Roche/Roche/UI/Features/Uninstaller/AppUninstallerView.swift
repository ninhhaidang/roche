import SwiftUI

// MARK: - App Uninstaller View

public struct AppUninstallerView: View {
    private let engine: any UninstallEngineProtocol

    @State private var apps: [InstalledApp] = []
    @State private var selectedAppId: String?
    @State private var preview: AppUninstallPreview?
    @State private var searchFilter: String = ""
    @State private var isLoadingApps: Bool = false
    @State private var isInspectingApp: Bool = false
    @State private var isUninstalling: Bool = false
    @State private var errorMessage: String?
    @State private var showTrashConfirm: Bool = false
    @State private var showPermanentConfirm: Bool = false
    @State private var showSuccessToast: Bool = false
    @State private var lastResult: UninstallResult?
    @State private var toastMessage: String = ""

    public init(engine: any UninstallEngineProtocol = RealUninstallEngine()) {
        self.engine = engine
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header Section
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.1))

                // Split Bento Inspector (Master-Detail)
                HStack(spacing: 16) {
                    // Left Master List (260px) with Search Bar
                    masterAppListSection
                        .frame(width: 260)

                    // Right Detail Panel (Hero Tile & Itemized Residuals Bento)
                    detailInspectorSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(20)
            }

            // Loading Overlay during Uninstallation
            if isUninstalling {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.red)
                        Text("Đang thực thi gỡ bỏ ứng dụng...")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        if let selected = selectedApp {
                            Text(selected.name)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(32)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .specularBorder(cornerRadius: 16)
                    .shadow(color: Color.black.opacity(0.5), radius: 20)
                }
                .transition(.opacity)
            }

            // Success Toast Notification
            if showSuccessToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.55))
                        Text(toastMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.9))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.5), radius: 10, y: 5)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task {
            await loadInstalledApps()
        }
        .confirmationDialog(
            "Xác nhận gỡ bỏ ứng dụng",
            isPresented: $showTrashConfirm,
            titleVisibility: .visible
        ) {
            Button("Chuyển vào Thùng Rác (An toàn)", role: .destructive) {
                if let selected = selectedApp {
                    Task {
                        await executeUninstall(app: selected, permanent: false)
                    }
                }
            }
            Button("Xóa vĩnh viễn...", role: .destructive) {
                showPermanentConfirm = true
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            if let selected = selectedApp {
                let sizeStr = preview?.selectedSizeText ?? selected.size
                Text("Bạn có chắc chắn muốn gỡ bỏ \(selected.name) (\(sizeStr)) và chuyển \(preview?.selectedItemCount ?? 0) tệp đã chọn vào Thùng Rác?")
            }
        }
        .alert(
            "Cảnh báo: Xóa vĩnh viễn",
            isPresented: $showPermanentConfirm
        ) {
            Button("Xóa vĩnh viễn ngay", role: .destructive) {
                if let selected = selectedApp {
                    Task {
                        await executeUninstall(app: selected, permanent: true)
                    }
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            if let selected = selectedApp {
                Text("Hành động này sẽ xóa vĩnh viễn \(selected.name) mà KHÔNG chuyển vào Thùng Rác. Dữ liệu sẽ không thể khôi phục. Bạn có chắc chắn muốn tiếp tục?")
            }
        }
        .alert(
            "Lỗi gỡ bỏ ứng dụng",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("Đóng", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.cyan)
                    Text("App Uninstaller")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text("Khám phá ứng dụng đã cài đặt và bóc tách tệp thừa, bộ nhớ đệm còn sót lại")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if let totalApps = apps.count as Int?, totalApps > 0 {
                Text("\(totalApps) Ứng dụng")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.18))
                    .foregroundStyle(Color.cyan)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
            }
        }
    }

    // MARK: - Master App List Section (260px)

    private var masterAppListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))

                TextField("Tìm kiếm ứng dụng...", text: $searchFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)

                if !searchFilter.isEmpty {
                    Button {
                        searchFilter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Subheader
            HStack {
                Text("Ứng dụng đã cài đặt (\(filteredApps.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Button {
                    Task { await loadInstalledApps() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(isLoadingApps)
            }

            // Scrollable App Items
            if isLoadingApps && apps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.cyan)
                    Text("Đang quét ứng dụng...")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filteredApps.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(searchFilter.isEmpty ? "Không tìm thấy ứng dụng" : "Không có kết quả")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredApps) { app in
                            let isSelected = app.id == selectedAppId
                            Button {
                                selectApp(app)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: app.iconName)
                                        .font(.system(size: 16))
                                        .foregroundStyle(isSelected ? Color.cyan : Color.white.opacity(0.8))
                                        .frame(width: 32, height: 32)
                                        .background(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(app.source)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }

                                    Spacer()

                                    Text(app.size)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(isSelected ? Color.cyan : .white.opacity(0.8))
                                }
                                .padding(8)
                                .background(isSelected ? Color.cyan.opacity(0.12) : Color.white.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? Color.cyan.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .specularBorder(cornerRadius: 16)
    }

    // MARK: - Detail Inspector Section

    @ViewBuilder
    private var detailInspectorSection: some View {
        if isInspectingApp {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .controlSize(.regular)
                    .tint(Color.cyan)
                Text("Đang phân tích và bóc tách tệp thừa...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .specularBorder(cornerRadius: 18)
        } else if let preview = preview, let selectedApp = selectedApp {
            VStack(spacing: 14) {
                // Top App Hero Card
                heroAppCard(app: selectedApp, preview: preview)

                // Itemized Residuals Bento List
                itemizedResidualsCard(preview: preview)

                // Bottom Action Bar
                bottomActionBar(preview: preview)
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.cyan.opacity(0.4))
                Text("Chọn một ứng dụng từ danh sách")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Kiểm tra và bóc tách các tệp cấu hình, bộ nhớ đệm và tệp thừa liên quan")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .specularBorder(cornerRadius: 18)
        }
    }

    // MARK: - Hero App Card

    private func heroAppCard(app: InstalledApp, preview: AppUninstallPreview) -> some View {
        HStack(spacing: 16) {
            Image(systemName: app.iconName)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .specularBorder(cornerRadius: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(app.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                if !app.bundleId.isEmpty {
                    Text(app.bundleId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(preview.selectedSizeText)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.cyan)
                Text("Dung lượng giải phóng")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .specularBorder(cornerRadius: 16)
    }

    // MARK: - Itemized Residuals Bento List

    private func itemizedResidualsCard(preview: AppUninstallPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tệp liên quan & File thừa (Residuals)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("\(preview.selectedItemCount) / \(preview.residuals.count) mục đã chọn")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                // Quick Selection Buttons
                HStack(spacing: 8) {
                    Button("Chọn tất cả") {
                        selectAllResiduals(true)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cyan)
                    .buttonStyle(.plain)

                    Text("•")
                        .foregroundStyle(.white.opacity(0.2))

                    Button("Bỏ chọn") {
                        selectAllResiduals(false)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .buttonStyle(.plain)
                }
            }

            // Scrollable List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(preview.residuals.enumerated()), id: \.element.id) { index, residual in
                        HStack(spacing: 12) {
                            // Checkbox
                            Button {
                                toggleResidual(at: index)
                            } label: {
                                Image(systemName: residual.isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(residual.isSelected ? Color(red: 0.2, green: 0.85, blue: 0.55) : Color.white.opacity(0.25))
                            }
                            .buttonStyle(.plain)

                            // Kind Icon
                            Image(systemName: residual.kind.iconName)
                                .font(.system(size: 13))
                                .foregroundStyle(residual.isSelected ? Color.cyan : Color.white.opacity(0.4))
                                .frame(width: 24, height: 24)

                            // Title & Path
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(residual.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text("•")
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text(residual.kind.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.cyan.opacity(0.12))
                                        .foregroundStyle(Color.cyan.opacity(0.9))
                                        .clipShape(Capsule())
                                }

                                Text(residual.path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Size
                            Text(residual.sizeText)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(residual.isSelected ? .white.opacity(0.9) : .white.opacity(0.4))
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .specularBorder(cornerRadius: 16)
    }

    // MARK: - Bottom Action Bar

    private func bottomActionBar(preview: AppUninstallPreview) -> some View {
        HStack {
            Label("Tệp sẽ được chuyển an toàn vào Trash", systemImage: "trash")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Menu {
                Button {
                    showTrashConfirm = true
                } label: {
                    Label("Gỡ bỏ vào Thùng Rác (Khuyên dùng)", systemImage: "trash")
                }

                Button(role: .destructive) {
                    showPermanentConfirm = true
                } label: {
                    Label("Xóa vĩnh viễn (Bỏ qua Thùng Rác)", systemImage: "trash.slash")
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                    Text("Gỡ bỏ vào Thùng Rác (\(preview.selectedSizeText))")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.25, blue: 0.35), Color(red: 0.8, green: 0.15, blue: 0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .specularBorder(cornerRadius: 12)
            } primaryAction: {
                showTrashConfirm = true
            }
            .menuStyle(.borderlessButton)
            .disabled(preview.selectedItemCount == 0 || isUninstalling)
            .opacity((preview.selectedItemCount == 0 || isUninstalling) ? 0.5 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions & State Helpers

    private var selectedApp: InstalledApp? {
        apps.first { $0.id == selectedAppId }
    }

    private var filteredApps: [InstalledApp] {
        if searchFilter.trimmingCharacters(in: .whitespaces).isEmpty {
            return apps
        }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchFilter) ||
            $0.uninstallName.localizedCaseInsensitiveContains(searchFilter)
        }
    }

    private func selectApp(_ app: InstalledApp) {
        selectedAppId = app.id
        Task {
            await inspectApp(app)
        }
    }

    private func toggleResidual(at index: Int) {
        guard var currentPreview = preview, index < currentPreview.residuals.count else { return }
        currentPreview.residuals[index].isSelected.toggle()
        self.preview = currentPreview
    }

    private func selectAllResiduals(_ isSelected: Bool) {
        guard var currentPreview = preview else { return }
        for i in 0..<currentPreview.residuals.count {
            currentPreview.residuals[i].isSelected = isSelected
        }
        self.preview = currentPreview
    }

    private func loadInstalledApps() async {
        isLoadingApps = true
        errorMessage = nil
        do {
            let loaded = try await engine.listInstalledApps()
            self.apps = loaded
            self.isLoadingApps = false

            // Auto-select first app if none selected
            if selectedAppId == nil, let first = loaded.first {
                selectedAppId = first.id
                await inspectApp(first)
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoadingApps = false
        }
    }

    private func inspectApp(_ app: InstalledApp) async {
        isInspectingApp = true
        errorMessage = nil
        do {
            let result = try await engine.inspectApp(app: app)
            self.preview = result
            self.isInspectingApp = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isInspectingApp = false
        }
    }

    private func executeUninstall(app: InstalledApp, permanent: Bool) async {
        isUninstalling = true
        errorMessage = nil
        do {
            let result = try await engine.performUninstall(app: app, permanent: permanent)
            self.lastResult = result
            self.isUninstalling = false

            let destText = permanent ? "vĩnh viễn" : "vào Thùng Rác"
            self.toastMessage = "Đã gỡ bỏ \(result.appName) (\(result.reclaimedFormatted)) \(destText) thành công."

            withAnimation {
                self.showSuccessToast = true
            }

            // Deselect the uninstalled app and reload
            self.selectedAppId = nil
            self.preview = nil
            await loadInstalledApps()

            Task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                withAnimation {
                    self.showSuccessToast = false
                }
            }
        } catch {
            self.isUninstalling = false
            self.errorMessage = "Không thể gỡ bỏ \(app.name): \(error.localizedDescription)"
        }
    }
}
