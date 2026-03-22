import Foundation

enum ScanSection: String, Hashable {
    case regular
    case remnants
    case restricted

    var title: String {
        switch self {
        case .regular:
            return "常规垃圾文件"
        case .remnants:
            return "疑似卸载残留文件"
        case .restricted:
            return "需要授权的分类"
        }
    }

    var description: String {
        switch self {
        case .regular:
            return "系统缓存、日志、废纸篓及开发工具临时产物。"
        case .remnants:
            return "根据应用名或 Bundle Identifier 推断，系统中已找不到对应 .app 的残留数据。"
        case .restricted:
            return "这些分类因为 macOS 权限限制暂时无法完整扫描。"
        }
    }
}

enum RiskLevel: String, Hashable, Comparable {
    case low
    case medium
    case high

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.sortRank < rhs.sortRank
    }

    var sortRank: Int {
        switch self {
        case .low:
            return 0
        case .medium:
            return 1
        case .high:
            return 2
        }
    }

    var title: String {
        switch self {
        case .low:
            return "低风险"
        case .medium:
            return "中风险"
        case .high:
            return "高风险"
        }
    }

    var deletionAllowedByDefault: Bool {
        self != .high
    }
}

struct ScanCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let path: String
    let section: ScanSection
    let riskLevel: RiskLevel
}

struct ChildItem: Identifiable, Hashable {
    let id: String
    let appName: String
    let bundleIdentifier: String?
    let path: String
    let sizeBytes: UInt64
    let itemCount: Int
    let isWhitelisted: Bool
    let riskLevel: RiskLevel
    let deletionAllowed: Bool
    let sourceCategoryName: String
    let matchScore: Int
    let matchReason: String
    let matchedRules: [String]
}

struct CategoryResult: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let rootPath: String
    let exists: Bool
    let fileCount: Int
    let totalSizeBytes: UInt64
    let childItems: [ChildItem]
    let warnings: [String]
    let section: ScanSection
    let riskLevel: RiskLevel
    let requiresPermission: Bool
}

struct ScanReport: Hashable {
    let scannedAt: Date
    let totalSizeBytes: UInt64
    let totalFiles: Int
    let categories: [CategoryResult]
    let appFilter: String?
    let whitelist: [String]
    let includesRemnants: Bool

    var regularCategories: [CategoryResult] {
        categories.filter { $0.section == .regular && !$0.requiresPermission }
    }

    var remnantCategories: [CategoryResult] {
        categories.filter { $0.section == .remnants && !$0.requiresPermission }
    }

    var restrictedCategories: [CategoryResult] {
        categories.filter { $0.requiresPermission }
    }
}

struct ScanOptions: Hashable {
    var appFilter: String = ""
    var whitelistText: String = ""
    var topItemCount: Int = 5
    var includeMissing: Bool = false
    var scanUninstalledRemnants: Bool = false

    var normalizedAppFilter: String? {
        let trimmed = appFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    var whitelistPatterns: [String] {
        whitelistText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum CleanupError: LocalizedError {
    case nothingToDelete

    var errorDescription: String? {
        switch self {
        case .nothingToDelete:
            return "应用白名单、风险保护和勾选条件后，没有可删除的项目。"
        }
    }
}

extension UInt64 {
    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}

extension Date {
    var appTimestamp: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
