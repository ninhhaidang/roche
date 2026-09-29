import Foundation

public nonisolated enum MoleError: LocalizedError, Sendable, Equatable {
    case executableNotFound
    case processExecutionFailed(exitCode: Int32, stderr: String)
    case decodingFailed(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Không tìm thấy Mole CLI hoặc status-go trên hệ thống."
        case .processExecutionFailed(let code, let stderr):
            return "Thực thi Mole thất bại (mã \(code)): \(stderr)"
        case .decodingFailed(let reason):
            return "Lỗi phân tích dữ liệu JSON từ Mole: \(reason)"
        case .timeout:
            return "Quá thời gian chờ phản hồi từ Mole CLI."
        }
    }
}
