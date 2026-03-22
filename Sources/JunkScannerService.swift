import Foundation

struct JunkScannerService {
    static let regularCategories: [ScanCategory] = [
        .init(id: "user-caches", name: "用户缓存", description: "位于 ~/Library/Caches 的应用缓存", path: "~/Library/Caches", section: .regular, riskLevel: .low),
        .init(id: "user-logs", name: "用户日志", description: "诊断日志和应用日志", path: "~/Library/Logs", section: .regular, riskLevel: .low),
        .init(id: "trash", name: "废纸篓", description: "当前位于 macOS 废纸篓中的文件", path: "~/.Trash", section: .regular, riskLevel: .medium),
        .init(id: "xcode-derived-data", name: "Xcode DerivedData", description: "Xcode 生成的构建中间产物", path: "~/Library/Developer/Xcode/DerivedData", section: .regular, riskLevel: .low),
        .init(id: "xcode-archives", name: "Xcode Archives", description: "Xcode 保留的归档构建产物", path: "~/Library/Developer/Xcode/Archives", section: .regular, riskLevel: .high),
        .init(id: "ios-simulators", name: "iOS 模拟器", description: "模拟器设备数据和应用容器", path: "~/Library/Developer/CoreSimulator/Devices", section: .regular, riskLevel: .high),
        .init(id: "mail-downloads", name: "邮件下载", description: "Apple Mail 附件产生的临时文件", path: "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads", section: .regular, riskLevel: .low),
        .init(id: "ios-backups", name: "iPhone 备份", description: "Finder 或 iTunes 设备备份", path: "~/Library/Application Support/MobileSync/Backup", section: .regular, riskLevel: .high)
    ]

    static let remnantCategories: [ScanCategory] = [
        .init(id: "remnant-app-support", name: "Application Support 残留", description: "位于 ~/Library/Application Support 的疑似卸载应用残留", path: "~/Library/Application Support", section: .remnants, riskLevel: .medium),
        .init(id: "remnant-preferences", name: "Preferences 残留", description: "位于 ~/Library/Preferences 的疑似卸载应用残留", path: "~/Library/Preferences", section: .remnants, riskLevel: .low),
        .init(id: "remnant-containers", name: "Containers 残留", description: "位于 ~/Library/Containers 的疑似卸载应用残留", path: "~/Library/Containers", section: .remnants, riskLevel: .medium),
        .init(id: "remnant-saved-state", name: "Saved State 残留", description: "位于 ~/Library/Saved Application State 的疑似卸载应用残留", path: "~/Library/Saved Application State", section: .remnants, riskLevel: .low)
    ]

    private let fileManager = FileManager.default
    func scan(options: ScanOptions) -> ScanReport {
        let installedApps = collectInstalledApps()
        var categories: [CategoryResult] = []

        categories += Self.regularCategories.compactMap { category in
            let result = scan(category: category, options: options)
            return shouldInclude(result: result, options: options) ? result : nil
        }

        if options.scanUninstalledRemnants {
            categories += Self.remnantCategories.compactMap { category in
                let result = scanRemnants(category: category, options: options, installedApps: installedApps)
                return shouldInclude(result: result, options: options) ? result : nil
            }
        }

        categories.sort {
            if $0.requiresPermission != $1.requiresPermission { return !$0.requiresPermission }
            if $0.section != $1.section { return $0.section == .regular }
            if $0.totalSizeBytes != $1.totalSizeBytes { return $0.totalSizeBytes > $1.totalSizeBytes }
            return $0.name < $1.name
        }

        return ScanReport(
            scannedAt: Date(),
            totalSizeBytes: categories.reduce(0) { $0 + $1.totalSizeBytes },
            totalFiles: categories.reduce(0) { $0 + $1.fileCount },
            categories: categories,
            appFilter: options.normalizedAppFilter,
            whitelist: options.whitelistPatterns,
            includesRemnants: options.scanUninstalledRemnants
        )
    }

    func cleanup(report: ScanReport, selectedItemIDs: Set<String>) throws -> [String] {
        let targets = cleanupTargets(in: report, selectedItemIDs: selectedItemIDs)
        guard !targets.isEmpty else { throw CleanupError.nothingToDelete }

        var trashed: [String] = []
        for item in targets {
            var resultURL: NSURL?
            try fileManager.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: &resultURL)
            trashed.append(item.path)
        }
        return trashed
    }

    func permanentlyClearTrash() throws -> Int {
        let trashPath = NSString(string: "~/.Trash").expandingTildeInPath
        let trashURL = URL(fileURLWithPath: trashPath, isDirectory: true)
        let contents = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)

        var removedCount = 0
        for url in contents {
            try fileManager.removeItem(at: url)
            removedCount += 1
        }
        return removedCount
    }

    func cleanupTargets(in report: ScanReport, selectedItemIDs: Set<String>) -> [ChildItem] {
        report.categories
            .flatMap(\.childItems)
            .filter { item in
                guard !item.isWhitelisted, item.deletionAllowed else { return false }
                return selectedItemIDs.contains(item.id)
            }
    }

    private func shouldInclude(result: CategoryResult, options: ScanOptions) -> Bool {
        if options.includeMissing { return true }
        guard result.exists else { return false }
        if options.normalizedAppFilter != nil {
            return !result.childItems.isEmpty || result.totalSizeBytes > 0
        }
        return result.exists
    }

    private func scan(category: ScanCategory, options: ScanOptions) -> CategoryResult {
        let rootPath = NSString(string: category.path).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: rootPath, isDirectory: &isDirectory)

        guard exists, isDirectory.boolValue else {
            return CategoryResult(id: category.id, name: category.name, description: category.description, rootPath: rootPath, exists: false, fileCount: 0, totalSizeBytes: 0, childItems: [], warnings: ["Path does not exist or is not a directory."], section: category.section, riskLevel: category.riskLevel, requiresPermission: false)
        }

        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey]

        var totalSize: UInt64 = 0
        var fileCount = 0
        var warnings: [String] = []
        var topLevelSizes: [String: UInt64] = [:]
        var topLevelCounts: [String: Int] = [:]

        guard let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: Array(resourceKeys), options: [], errorHandler: { url, error in
            warnings.append("Cannot access \(url.path): \(error.localizedDescription)")
            return true
        }) else {
            return CategoryResult(id: category.id, name: category.name, description: category.description, rootPath: rootPath, exists: true, fileCount: 0, totalSizeBytes: 0, childItems: [], warnings: ["Failed to enumerate directory contents."], section: category.section, riskLevel: category.riskLevel, requiresPermission: true)
        }

        for case let url as URL in enumerator {
            do {
                let values = try url.resourceValues(forKeys: resourceKeys)
                if values.isSymbolicLink == true {
                    if values.isDirectory == true { enumerator.skipDescendants() }
                    continue
                }
                guard values.isRegularFile == true else { continue }

                let relative = url.path.replacingOccurrences(of: rootPath + "/", with: "")
                guard let topLevel = relative.split(separator: "/", maxSplits: 1).first.map(String.init) else { continue }
                let derivedAppName = displayName(forTopLevelName: topLevel)

                if let filter = options.normalizedAppFilter, !matchesFilter(filter, childName: topLevel, appName: derivedAppName) {
                    continue
                }

                let size = byteSize(from: values)
                totalSize += size
                fileCount += 1
                topLevelSizes[topLevel, default: 0] += size
                topLevelCounts[topLevel, default: 0] += 1
            } catch {
                warnings.append("Cannot inspect \(url.path): \(error.localizedDescription)")
            }
        }

        let childItems = topLevelSizes.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }
        .prefix(options.topItemCount)
        .map { name, size in
            let itemPath = rootURL.appendingPathComponent(name).path
            let appName = displayName(forTopLevelName: name)
            return ChildItem(
                id: itemPath,
                appName: appName,
                bundleIdentifier: normalizedBundleIdentifier(from: name),
                path: itemPath,
                sizeBytes: size,
                itemCount: topLevelCounts[name, default: 0],
                isWhitelisted: isWhitelisted(itemPath: itemPath, patterns: options.whitelistPatterns),
                riskLevel: category.riskLevel,
                deletionAllowed: category.riskLevel.deletionAllowedByDefault,
                sourceCategoryName: category.name,
                matchScore: 100,
                matchReason: regularMatchReason(for: category),
                matchedRules: regularMatchRules(for: category)
            )
        }

        let uniqueWarnings = uniqueOrdered(warnings)
        return CategoryResult(id: category.id, name: category.name, description: category.description, rootPath: rootPath, exists: true, fileCount: fileCount, totalSizeBytes: totalSize, childItems: childItems, warnings: uniqueWarnings, section: category.section, riskLevel: category.riskLevel, requiresPermission: containsPermissionWarning(uniqueWarnings))
    }

    private func scanRemnants(category: ScanCategory, options: ScanOptions, installedApps: InstalledApps) -> CategoryResult {
        let rootPath = NSString(string: category.path).expandingTildeInPath
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: rootPath, isDirectory: &isDirectory)

        guard exists, isDirectory.boolValue else {
            return CategoryResult(id: category.id, name: category.name, description: category.description, rootPath: rootPath, exists: false, fileCount: 0, totalSizeBytes: 0, childItems: [], warnings: ["Path does not exist or is not a directory."], section: category.section, riskLevel: category.riskLevel, requiresPermission: false)
        }

        var fileCount = 0
        var totalSize: UInt64 = 0
        var warnings: [String] = []
        var candidateItems: [ChildItem] = []

        do {
            let contents = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            for itemURL in contents {
                let itemName = itemURL.lastPathComponent
                let appName = displayName(forTopLevelName: itemName)
                if let filter = options.normalizedAppFilter, !matchesFilter(filter, childName: itemName, appName: appName) {
                    continue
                }

                guard let match = evaluateRemnantMatch(itemName: itemName, appName: appName, installedApps: installedApps) else {
                    continue
                }

                do {
                    let summary = try summarizeTopLevelItem(itemURL)
                    fileCount += summary.fileCount
                    totalSize += summary.sizeBytes
                    candidateItems.append(
                        ChildItem(
                            id: itemURL.path,
                            appName: appName,
                            bundleIdentifier: match.bundleIdentifier,
                            path: itemURL.path,
                            sizeBytes: summary.sizeBytes,
                            itemCount: summary.fileCount,
                            isWhitelisted: isWhitelisted(itemPath: itemURL.path, patterns: options.whitelistPatterns),
                            riskLevel: category.riskLevel,
                            deletionAllowed: category.riskLevel.deletionAllowedByDefault,
                            sourceCategoryName: category.name,
                            matchScore: match.score,
                            matchReason: match.reason,
                            matchedRules: match.rules
                        )
                    )
                } catch {
                    warnings.append("Cannot inspect \(itemURL.path): \(error.localizedDescription)")
                }
            }
        } catch {
            warnings.append("Cannot access \(rootPath): \(error.localizedDescription)")
        }

        candidateItems.sort {
            if $0.matchScore == $1.matchScore {
                if $0.sizeBytes == $1.sizeBytes { return $0.appName < $1.appName }
                return $0.sizeBytes > $1.sizeBytes
            }
            return $0.matchScore > $1.matchScore
        }

        let uniqueWarnings = uniqueOrdered(warnings)
        return CategoryResult(id: category.id, name: category.name, description: category.description, rootPath: rootPath, exists: true, fileCount: fileCount, totalSizeBytes: totalSize, childItems: Array(candidateItems.prefix(options.topItemCount)), warnings: uniqueWarnings, section: category.section, riskLevel: category.riskLevel, requiresPermission: containsPermissionWarning(uniqueWarnings))
    }

    private func summarizeTopLevelItem(_ itemURL: URL) throws -> (sizeBytes: UInt64, fileCount: Int) {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        let values = try itemURL.resourceValues(forKeys: resourceKeys)
        if values.isRegularFile == true {
            return (byteSize(from: values), 1)
        }

        guard let enumerator = fileManager.enumerator(at: itemURL, includingPropertiesForKeys: Array(resourceKeys), options: [], errorHandler: { _, _ in true }) else {
            return (0, 0)
        }

        var totalSize: UInt64 = 0
        var fileCount = 0
        for case let url as URL in enumerator {
            let itemValues = try? url.resourceValues(forKeys: resourceKeys)
            if itemValues?.isSymbolicLink == true {
                if itemValues?.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            if itemValues?.isRegularFile == true {
                totalSize += byteSize(from: itemValues ?? URLResourceValues())
                fileCount += 1
            }
        }
        return (totalSize, fileCount)
    }

    private func collectInstalledApps() -> InstalledApps {
        let searchRoots = ["/Applications", NSString(string: "~/Applications").expandingTildeInPath]
        var bundleIdentifiers = Set<String>()
        var appNames = Set<String>()

        for root in searchRoots {
            guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                appNames.insert(normalizeForMatching(url.deletingPathExtension().lastPathComponent))
                if let bundle = Bundle(url: url), let bundleIdentifier = bundle.bundleIdentifier?.lowercased() {
                    bundleIdentifiers.insert(bundleIdentifier)
                }
                enumerator.skipDescendants()
            }
        }

        return InstalledApps(bundleIdentifiers: bundleIdentifiers, appNames: appNames)
    }

    private func evaluateRemnantMatch(itemName: String, appName: String, installedApps: InstalledApps) -> RemnantMatch? {
        let normalizedName = normalizeForMatching(itemName)
        let normalizedAppName = normalizeForMatching(appName)
        let bundleID = normalizedBundleIdentifier(from: itemName)

        if normalizedName.hasPrefix("com.apple") || normalizedName.hasPrefix("group.com.apple") { return nil }
        if let bundleID, installedApps.bundleIdentifiers.contains(bundleID) { return nil }
        if installedApps.appNames.contains(normalizedAppName) || installedApps.appNames.contains(normalizedName) { return nil }

        var score = 0
        var rules: [String] = []

        if let bundleID {
            score += 55
            rules.append("目录名包含 Bundle Identifier 形态")
            if !installedApps.bundleIdentifiers.contains(bundleID) {
                score += 20
                rules.append("系统中找不到对应 Bundle Identifier 的已安装应用")
            }
        }

        if normalizedAppName.count >= 3 {
            score += 20
            rules.append("可解析出稳定应用名")
        }

        if itemName.contains(".plist") || itemName.contains(".savedState") {
            score += 10
            rules.append("命中偏好设置或保存状态残留")
        }

        if itemName.hasPrefix("com.") || itemName.hasPrefix("group.") {
            score += 10
            rules.append("命中反向域名命名规则")
        }

        guard score >= 50 else { return nil }

        let reason: String
        if let bundleID {
            reason = "发现 `\(bundleID)` 对应的配置/容器数据，但系统中没有匹配的已安装应用。"
        } else {
            reason = "目录名与应用命名规则高度匹配，但系统中没有找到对应已安装应用。"
        }

        return RemnantMatch(score: min(score, 100), reason: reason, rules: uniqueOrdered(rules), bundleIdentifier: bundleID)
    }

    private func matchesFilter(_ filter: String, childName: String, appName: String) -> Bool {
        childName.lowercased().contains(filter) || appName.lowercased().contains(filter)
    }

    private func displayName(forTopLevelName name: String) -> String {
        var value = name
        if value.hasSuffix(".plist") { value = String(value.dropLast(6)) }
        if value.hasSuffix(".savedState") { value = String(value.dropLast(11)) }
        if value.hasPrefix("group.") { value = String(value.dropFirst(6)) }

        let components = value.split(separator: ".").map(String.init)
        if components.count >= 3 {
            value = components.suffix(from: 2).joined(separator: " ")
        } else if components.count == 2 {
            value = components[1]
        }

        return value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                let lowered = word.lowercased()
                return lowered.prefix(1).uppercased() + lowered.dropFirst()
            }
            .joined(separator: " ")
    }

    private func normalizedBundleIdentifier(from name: String) -> String? {
        let cleaned = name
            .replacingOccurrences(of: ".plist", with: "")
            .replacingOccurrences(of: ".savedState", with: "")
            .lowercased()
        return cleaned.contains(".") ? cleaned : nil
    }

    private func normalizeForMatching(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: ".plist", with: "")
            .replacingOccurrences(of: ".savedstate", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func regularMatchReason(for category: ScanCategory) -> String {
        switch category.id {
        case "user-caches":
            return "命中应用缓存目录，通常可在应用下次启动时自动重建。"
        case "user-logs":
            return "命中日志目录，主要是调试日志和运行日志。"
        case "trash":
            return "命中废纸篓目录，文件已经处于待删除状态。"
        case "xcode-derived-data":
            return "命中 Xcode 构建缓存目录，可通过重新编译重新生成。"
        case "xcode-archives":
            return "命中 Xcode 归档目录，删除后会丢失历史归档产物。"
        case "ios-simulators":
            return "命中模拟器数据目录，删除会影响模拟器中的应用和数据。"
        case "mail-downloads":
            return "命中邮件附件临时下载目录。"
        case "ios-backups":
            return "命中本地设备备份目录，删除后无法再用于恢复设备。"
        default:
            return "命中预设垃圾目录规则。"
        }
    }

    private func regularMatchRules(for category: ScanCategory) -> [String] {
        ["命中预设目录：\(category.path)", "分类风险：\(category.riskLevel.title)"]
    }

    private func byteSize(from values: URLResourceValues) -> UInt64 {
        if let allocated = values.totalFileAllocatedSize { return UInt64(max(allocated, 0)) }
        if let allocated = values.fileAllocatedSize { return UInt64(max(allocated, 0)) }
        if let size = values.fileSize { return UInt64(max(size, 0)) }
        return 0
    }

    private func uniqueOrdered(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func containsPermissionWarning(_ warnings: [String]) -> Bool {
        warnings.contains { warning in
            let lowered = warning.lowercased()
            return lowered.contains("permission") || lowered.contains("operation not permitted")
        }
    }

    private func isWhitelisted(itemPath: String, patterns: [String]) -> Bool {
        guard !patterns.isEmpty else { return false }
        let path = itemPath.lowercased()
        let name = URL(fileURLWithPath: itemPath).lastPathComponent.lowercased()

        for pattern in patterns {
            let expanded = NSString(string: pattern).expandingTildeInPath
            let lowered = expanded.lowercased()
            if expanded.hasPrefix("/") {
                if path.hasPrefix(lowered) { return true }
            } else if name.contains(lowered) || path.contains(lowered) {
                return true
            }
        }
        return false
    }
}

private struct InstalledApps {
    let bundleIdentifiers: Set<String>
    let appNames: Set<String>
}

private struct RemnantMatch {
    let score: Int
    let reason: String
    let rules: [String]
    let bundleIdentifier: String?
}
