import AppKit
import Foundation

@MainActor
final class JunkScannerViewModel: ObservableObject {
    private let hasSeenPermissionGuideKey = "hasSeenPermissionGuide"
    @Published var options = ScanOptions()
    @Published var report: ScanReport?
    @Published var selectedCategoryID: String?
    @Published var selectedItemIDs: Set<String> = []
    @Published var isScanning = false
    @Published var statusMessage = "点击“开始扫描”以检查可清理项目。"
    @Published var errorMessage: String?
    @Published var showingCleanupConfirmation = false
    @Published var showingTrashClearConfirmation = false
    @Published var showingPermissionGuide = false
    @Published var deletedPaths: [String] = []

    private let service = JunkScannerService()

    func scan() {
        isScanning = true
        statusMessage = options.scanUninstalledRemnants
            ? "正在扫描常见垃圾目录，并识别疑似卸载残留..."
            : "正在扫描常见的 macOS 垃圾目录..."
        errorMessage = nil

        let options = self.options
        Task(priority: .userInitiated) {
            let report = await Task.detached(priority: .userInitiated) {
                JunkScannerService().scan(options: options)
            }.value

            self.report = report
            self.syncSelectedItems(with: report)
            self.syncSelection(with: report)
            self.showingPermissionGuide = !self.hasSeenPermissionGuide() && self.hasPermissionWarnings(in: report)
            self.isScanning = false
            self.statusMessage = self.statusText(for: report)
        }
    }

    func requestCleanup() {
        guard let report else {
            errorMessage = "请先执行一次扫描，再进行清理。"
            return
        }

        let candidates = service.cleanupTargets(in: report, selectedItemIDs: selectedItemIDs)
        guard !candidates.isEmpty else {
            errorMessage = CleanupError.nothingToDelete.localizedDescription
            return
        }

        showingCleanupConfirmation = true
    }

    func performCleanup() {
        guard let report else {
            return
        }

        do {
            deletedPaths = try service.cleanup(report: report, selectedItemIDs: selectedItemIDs)
            showingCleanupConfirmation = false
            statusMessage = "已将 \(deletedPaths.count) 个项目移到废纸篓，正在重新扫描..."
            scan()
        } catch {
            showingCleanupConfirmation = false
            errorMessage = error.localizedDescription
        }
    }

    func requestPermanentTrashClear() {
        guard let category = selectedCategory(), category.id == "trash" else {
            return
        }
        showingTrashClearConfirmation = true
    }

    func performPermanentTrashClear() {
        do {
            let removedCount = try service.permanentlyClearTrash()
            showingTrashClearConfirmation = false
            statusMessage = "已彻底清空废纸篓中的 \(removedCount) 个项目，正在重新扫描..."
            scan()
        } catch {
            showingTrashClearConfirmation = false
            errorMessage = error.localizedDescription
        }
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func cleanupPreviewLines(limit: Int = 12) -> [String] {
        guard let report else { return [] }
        return service.cleanupTargets(in: report, selectedItemIDs: selectedItemIDs)
            .prefix(limit)
            .map { "• \($0.appName)\n  \($0.path)" }
    }

    func cleanupCandidateCount() -> Int {
        guard let report else { return 0 }
        return service.cleanupTargets(in: report, selectedItemIDs: selectedItemIDs).count
    }

    func highRiskItemCount() -> Int {
        guard let report else { return 0 }
        return report.categories
            .flatMap(\.childItems)
            .filter { !$0.isWhitelisted && !$0.deletionAllowed }
            .count
    }

    func hasPermissionWarnings() -> Bool {
        guard let report else { return false }
        return hasPermissionWarnings(in: report)
    }

    func dismissPermissionGuide() {
        UserDefaults.standard.set(true, forKey: hasSeenPermissionGuideKey)
        showingPermissionGuide = false
    }

    func permissionRestrictedCategories() -> [CategoryResult] {
        guard let report else { return [] }
        return report.restrictedCategories
    }

    func selectedCategory() -> CategoryResult? {
        guard let report else { return nil }
        if let selectedCategoryID,
           let category = report.categories.first(where: { $0.id == selectedCategoryID }) {
            return category
        }
        return report.categories.first
    }

    func selectCategory(_ categoryID: String) {
        selectedCategoryID = categoryID
    }

    func isItemSelected(_ itemID: String) -> Bool {
        selectedItemIDs.contains(itemID)
    }

    func setItemSelected(_ itemID: String, selected: Bool) {
        if selected {
            selectedItemIDs.insert(itemID)
        } else {
            selectedItemIDs.remove(itemID)
        }
    }

    func selectedCleanupSizeText() -> String {
        guard let report else { return "0 KB" }
        let total = service.cleanupTargets(in: report, selectedItemIDs: selectedItemIDs)
            .reduce(UInt64(0)) { $0 + $1.sizeBytes }
        return total.formattedByteCount
    }

    func selectAllInSelectedCategory() {
        guard let category = selectedCategory() else { return }
        for item in category.childItems where !item.isWhitelisted && item.deletionAllowed {
            selectedItemIDs.insert(item.id)
        }
    }

    func selectLowRiskInSelectedCategory() {
        guard let category = selectedCategory() else { return }
        for item in category.childItems where !item.isWhitelisted && item.deletionAllowed && item.riskLevel == .low {
            selectedItemIDs.insert(item.id)
        }
    }

    func clearSelectionInSelectedCategory() {
        guard let category = selectedCategory() else { return }
        for item in category.childItems {
            selectedItemIDs.remove(item.id)
        }
    }

    func selectedCountInSelectedCategory() -> Int {
        guard let category = selectedCategory() else { return 0 }
        return category.childItems.filter { selectedItemIDs.contains($0.id) }.count
    }

    func canPermanentlyClearSelectedTrash() -> Bool {
        guard let category = selectedCategory() else { return false }
        return category.id == "trash" && !category.requiresPermission
    }

    private func statusText(for report: ScanReport) -> String {
        let remnantCount = report.remnantCategories.reduce(0) { $0 + $1.childItems.count }
        let restrictedCount = report.restrictedCategories.count
        if report.includesRemnants {
            return "常规分类 \(report.regularCategories.count) 个，疑似残留 \(remnantCount) 项，需要授权 \(restrictedCount) 个"
        }
        return "共 \(report.categories.count) 个分类，\(report.totalFiles) 个文件，需要授权 \(restrictedCount) 个"
    }

    private func syncSelection(with report: ScanReport) {
        if let selectedCategoryID,
           report.categories.contains(where: { $0.id == selectedCategoryID }) {
            return
        }
        selectedCategoryID = report.restrictedCategories.isEmpty
            ? report.categories.first?.id
            : report.restrictedCategories.first?.id ?? report.categories.first?.id
    }

    private func syncSelectedItems(with report: ScanReport) {
        let validIDs = Set(
            report.categories
                .flatMap(\.childItems)
                .filter { !$0.isWhitelisted && $0.deletionAllowed }
                .map(\.id)
        )
        selectedItemIDs = selectedItemIDs.intersection(validIDs)
    }

    private func hasPermissionWarnings(in report: ScanReport) -> Bool {
        report.categories.contains(where: \.requiresPermission)
    }

    private func hasSeenPermissionGuide() -> Bool {
        UserDefaults.standard.bool(forKey: hasSeenPermissionGuideKey)
    }
}
