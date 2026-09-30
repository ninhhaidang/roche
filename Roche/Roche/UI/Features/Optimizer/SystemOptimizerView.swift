import SwiftUI

public struct SystemOptimizerView: View {
    private let engine: any OptimizeEngineProtocol

    @State private var diagnosis: SystemDiagnosis
    @State private var isDryRun: Bool = true
    @State private var isOptimizing: Bool = false
    @State private var errorMessage: String? = nil

    public init(
        engine: (any OptimizeEngineProtocol)? = nil,
        initialDiagnosis: SystemDiagnosis? = nil
    ) {
        let resolvedEngine = engine ?? RealOptimizeEngine()
        self.engine = resolvedEngine
        _diagnosis = State(initialValue: initialDiagnosis ?? MockOptimizeEngine.mockDiagnosis())
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tối ưu hóa Hệ thống")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Chẩn đoán nút thắt hiệu năng và bảo trì 20 thành phần hệ thống")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()

                    // Quick Refresh Button
                    Button {
                        Task { await refreshDiagnosis() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(isOptimizing ? 360 : 0))
                                .animation(isOptimizing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isOptimizing)
                            Text("Chẩn đoán lại")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        .specularBorder(cornerRadius: 20, opacity: 0.15)
                    }
                    .buttonStyle(.plain)
                    .disabled(isOptimizing)
                }
                .padding(.horizontal, 4)

                // Hero Bottleneck Diagnosis Bento Card with Dry Run Switch
                heroDiagnosisCard

                // Error Banner (if any)
                if let errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35))
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.25), lineWidth: 1))
                }

                // 2x2 Bento Thematic Categories Grid
                bento2x2Grid
            }
            .padding(20)
        }
        .background(Color.black.opacity(0.95).ignoresSafeArea())
        .task {
            await refreshDiagnosis()
        }
    }

    // MARK: - Hero Bottleneck Card with Dry Run Switch

    private var heroDiagnosisCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                // Bottleneck Status Orb
                ZStack {
                    Circle()
                        .fill(diagnosis.severity.color.opacity(0.15))
                        .frame(width: 58, height: 58)
                    Image(systemName: diagnosis.severity.iconName)
                        .font(.system(size: 26))
                        .foregroundStyle(diagnosis.severity.color)
                        .shadow(color: diagnosis.severity.color.opacity(0.5), radius: 8)
                }

                // Bottleneck Details
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Chẩn đoán Nghẽn Hiệu năng:")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Text(diagnosis.component)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(diagnosis.severity.color.opacity(0.2))
                            .foregroundStyle(diagnosis.severity.color)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(diagnosis.severity.color.opacity(0.4), lineWidth: 1))

                        if let cpu = diagnosis.cpuUsagePercent {
                            Text(String(format: "~%.1f%% CPU", cpu))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(diagnosis.severity.color.opacity(0.9))
                        }
                    }

                    Text(diagnosis.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow.opacity(0.8))
                        Text("Khuyến nghị: \(diagnosis.recommendation)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                // Dry Run Switch & Action Button Controls
                VStack(alignment: .trailing, spacing: 10) {
                    // Dry-Run Toggle Switch
                    HStack(spacing: 8) {
                        Toggle(isOn: $isDryRun) {
                            Text("Dry Run (Xem trước)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isDryRun ? Color.cyan : .white.opacity(0.7))
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .specularBorder(cornerRadius: 18, opacity: 0.2)

                    // Execute Button
                    Button {
                        Task { await executeOptimization() }
                    } label: {
                        HStack(spacing: 8) {
                            if isOptimizing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text(isDryRun ? "Mô phỏng Tối ưu" : "Bắt đầu Tối ưu")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isOptimizing ? .white.opacity(0.7) : .black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(isOptimizing ? Color.white.opacity(0.2) : Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.cyan.opacity(isOptimizing ? 0.0 : 0.4), radius: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isOptimizing)
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .specularBorder(cornerRadius: 18)
    }

    // MARK: - 2x2 Bento Thematic Categories Grid

    private var bento2x2Grid: some View {
        let categories: [OptimizeTaskCategory] = [
            .systemAndSearch,
            .cacheAndFinder,
            .networkAndData,
            .configAndSecurity
        ]

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(categories) { category in
                let catTasks = diagnosis.tasks.filter { $0.category == category }
                categoryCard(category: category, tasks: catTasks)
            }
        }
    }

    private func categoryCard(category: OptimizeTaskCategory, tasks: [OptimizeTask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack(spacing: 10) {
                Image(systemName: category.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(category.themeColor)

                Text(category.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(tasks.count) tác vụ")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .foregroundStyle(.white.opacity(0.6))
                    .clipShape(Capsule())
            }

            Divider().background(Color.white.opacity(0.08))

            // Task Rows with Dynamic Glow Badges
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .specularBorder(cornerRadius: 16)
    }

    private func taskRow(_ task: OptimizeTask) -> some View {
        HStack(spacing: 10) {
            Image(systemName: task.outcome.iconName)
                .font(.system(size: 13))
                .foregroundStyle(task.outcome.badgeColor)

            Text(task.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            // Dynamic Glow Badge
            Text(task.outcome.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(task.outcome.badgeColor.opacity(0.15))
                .foregroundStyle(task.outcome.badgeColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(task.outcome.badgeColor.opacity(0.35), lineWidth: 0.8)
                )
                .shadow(color: task.outcome.badgeColor.opacity(0.35), radius: 4)
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func refreshDiagnosis() async {
        do {
            let fresh = try await engine.diagnosePerformance()
            await MainActor.run {
                self.diagnosis = fresh
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Không thể chẩn đoán: \(error.localizedDescription)"
            }
        }
    }

    private func executeOptimization() async {
        await MainActor.run {
            self.isOptimizing = true
            self.errorMessage = nil
        }
        defer {
            Task { @MainActor in
                self.isOptimizing = false
            }
        }

        do {
            let updatedTasks = try await engine.runOptimization(dryRun: isDryRun)
            await MainActor.run {
                self.diagnosis = SystemDiagnosis(
                    id: self.diagnosis.id,
                    component: self.diagnosis.component,
                    description: self.diagnosis.description,
                    recommendation: self.diagnosis.recommendation,
                    severity: self.diagnosis.severity,
                    cpuUsagePercent: self.diagnosis.cpuUsagePercent,
                    hasBottleneck: self.diagnosis.hasBottleneck,
                    tasks: updatedTasks,
                    rawOutput: self.diagnosis.rawOutput
                )
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Tối ưu hóa thất bại: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - UI Color & Styling Extensions

public extension OptimizeTaskOutcome {
    var badgeColor: Color {
        switch self {
        case .pending:
            return .white.opacity(0.4)
        case .running:
            return .cyan
        case .applied:
            return Color(red: 0.2, green: 0.85, blue: 0.55)
        case .unchanged:
            return Color(red: 0.4, green: 0.65, blue: 0.95)
        case .attention:
            return Color(red: 0.95, green: 0.75, blue: 0.2)
        case .skipped:
            return .white.opacity(0.35)
        }
    }
}

public extension DiagnosisSeverity {
    var color: Color {
        switch self {
        case .nominal:
            return Color(red: 0.2, green: 0.85, blue: 0.55)
        case .moderate:
            return Color(red: 0.95, green: 0.75, blue: 0.2)
        case .severe:
            return Color(red: 0.95, green: 0.25, blue: 0.35)
        }
    }

    var iconName: String {
        switch self {
        case .nominal:
            return "checkmark.circle.fill"
        case .moderate:
            return "exclamationmark.triangle.fill"
        case .severe:
            return "exclamationmark.octagon.fill"
        }
    }
}

public extension OptimizeTaskCategory {
    var themeColor: Color {
        switch self {
        case .systemAndSearch:
            return .cyan
        case .cacheAndFinder:
            return .orange
        case .networkAndData:
            return Color(red: 0.2, green: 0.85, blue: 0.55)
        case .configAndSecurity:
            return Color(red: 0.75, green: 0.55, blue: 0.95)
        }
    }
}
