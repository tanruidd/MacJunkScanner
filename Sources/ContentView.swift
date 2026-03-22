import SwiftUI

private enum Palette {
    static let panelBackground = Color(red: 0.93, green: 0.95, blue: 0.98)
    static let sidebarTop = Color(red: 0.88, green: 0.92, blue: 0.97)
    static let sidebarBottom = Color(red: 0.84, green: 0.89, blue: 0.95)
    static let detailTop = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let detailBottom = Color(red: 0.90, green: 0.94, blue: 0.98)
    static let titleColor = Color(red: 0.12, green: 0.16, blue: 0.24)
    static let bodyColor = Color(red: 0.21, green: 0.27, blue: 0.37)
    static let secondaryColor = Color(red: 0.38, green: 0.45, blue: 0.56)
    static let borderColor = Color(red: 0.80, green: 0.86, blue: 0.93)
    static let softWhite = Color.white.opacity(0.88)
}

struct ContentView: View {
    @ObservedObject var viewModel: JunkScannerViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 250, ideal: 280)
        } detail: {
            detail
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("确认清理", isPresented: $viewModel.showingCleanupConfirmation) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) {
                viewModel.performCleanup()
            }
        } message: {
            let previewLines = viewModel.cleanupPreviewLines()
            let preview = previewLines.joined(separator: "\n\n")
            let extraCount = max(viewModel.cleanupCandidateCount() - previewLines.count, 0)
            let suffix = extraCount > 0 ? "\n\n... 以及另外 \(extraCount) 个项目。" : ""
            Text("本次将移动到废纸篓：\(viewModel.selectedCleanupSizeText())\n\n" + preview + suffix)
        }
        .alert("彻底清空废纸篓", isPresented: $viewModel.showingTrashClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("彻底清除", role: .destructive) {
                viewModel.performPermanentTrashClear()
            }
        } message: {
            Text("这个操作会直接删除废纸篓中的内容，不会再移动到废纸篓，也不容易恢复。确认继续吗？")
        }
        .sheet(isPresented: $viewModel.showingPermissionGuide) {
            PermissionGuideSheet(
                categories: viewModel.permissionRestrictedCategories(),
                openSettings: viewModel.openFullDiskAccessSettings,
                close: viewModel.dismissPermissionGuide
            )
        }
        .task {
            if viewModel.report == nil {
                viewModel.scan()
            }
        }
    }

    private var sidebar: some View {
        List(selection: Binding(
            get: { viewModel.selectedCategoryID },
            set: { newValue in
                if let newValue {
                    viewModel.selectCategory(newValue)
                }
            }
        )) {
            controlsSection

            if let report = viewModel.report {
                let restricted = report.restrictedCategories
                if !restricted.isEmpty {
                    sidebarGroup(title: ScanSection.restricted.title, categories: restricted)
                }

                sidebarGroup(title: ScanSection.regular.title, categories: report.regularCategories)

                if report.includesRemnants {
                    sidebarGroup(title: ScanSection.remnants.title, categories: report.remnantCategories)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    Palette.sidebarTop,
                    Palette.sidebarBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func sidebarGroup(title: String, categories: [CategoryResult]) -> some View {
        if !categories.isEmpty {
            Section(title) {
                ForEach(categories) { category in
                    SidebarCategoryRow(
                        category: category,
                        isSelected: viewModel.selectedCategoryID == category.id
                    )
                    .tag(category.id)
                    .onTapGesture {
                        viewModel.selectCategory(category.id)
                    }
                }
            }
        }
    }

    private var controlsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Mac 垃圾扫描")
                        .font(.title2.bold())
                        .foregroundStyle(Palette.titleColor)
                    Text("更像一个原生清理工具的布局，左侧导航，右侧详情。")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryColor)
                    Text("清理前请先勾选想处理的项目。")
                        .font(.caption)
                        .foregroundStyle(Palette.bodyColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("应用关键字")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryColor)
                    TextField("例如 JetBrains、Xcode、Slack", text: $viewModel.options.appFilter)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("白名单")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryColor)
                    TextField("用逗号分隔关键字或绝对路径", text: $viewModel.options.whitelistText)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("显示数量")
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryColor)
                        Stepper(value: $viewModel.options.topItemCount, in: 1...20) {
                            Text("\(viewModel.options.topItemCount)")
                                .frame(width: 36, alignment: .leading)
                                .foregroundStyle(Palette.bodyColor)
                        }
                    }
                    Spacer()
                    Button(action: viewModel.scan) {
                        if viewModel.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("开始扫描", systemImage: "sparkle.magnifyingglass")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.12, green: 0.45, blue: 0.92))
                    .disabled(viewModel.isScanning)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("显示不存在的目录", isOn: $viewModel.options.includeMissing)
                        .toggleStyle(.checkbox)
                    Toggle("扫描已卸载应用残留", isOn: $viewModel.options.scanUninstalledRemnants)
                        .toggleStyle(.checkbox)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var detail: some View {
        Group {
            if let report = viewModel.report, let category = viewModel.selectedCategory() {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        detailHeader(report: report)
                        DetailCategoryCard(category: category, viewModel: viewModel, revealAction: viewModel.reveal(_:))
                    }
                    .padding(24)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Palette.detailTop,
                            Palette.detailBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else if viewModel.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("扫描中...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 34))
                        .foregroundStyle(Palette.secondaryColor)
                    Text("左侧选择一个分类")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.titleColor)
                    Text("先开始扫描，然后在左侧查看分类，在右侧查看详细条目。")
                        .foregroundStyle(Palette.secondaryColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func detailHeader(report: ScanReport) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("扫描概览")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.titleColor)
                    Text(viewModel.statusMessage)
                        .foregroundStyle(Palette.secondaryColor)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button("全选当前分类", action: viewModel.selectAllInSelectedCategory)
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isScanning)
                    Button("只全选低风险项", action: viewModel.selectLowRiskInSelectedCategory)
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isScanning)
                    Button("清空当前分类", action: viewModel.clearSelectionInSelectedCategory)
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isScanning || viewModel.selectedCountInSelectedCategory() == 0)
                    if viewModel.canPermanentlyClearSelectedTrash() {
                        Button("彻底清空废纸篓", role: .destructive, action: viewModel.requestPermanentTrashClear)
                            .buttonStyle(.bordered)
                    }
                    if !viewModel.canPermanentlyClearSelectedTrash() {
                        Button("移到废纸篓", role: .destructive, action: viewModel.requestCleanup)
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.83, green: 0.29, blue: 0.23))
                            .disabled(viewModel.isScanning || viewModel.cleanupCandidateCount() == 0)
                    }
                }
            }

            HStack(spacing: 16) {
                SummaryCard(title: "候选空间", value: report.totalSizeBytes.formattedByteCount, accent: Color(red: 0.18, green: 0.52, blue: 0.94))
                SummaryCard(title: "文件数", value: "\(report.totalFiles)", accent: Color(red: 0.09, green: 0.67, blue: 0.59))
                SummaryCard(title: "已选中待清理", value: viewModel.selectedCleanupSizeText(), accent: Color(red: 0.75, green: 0.34, blue: 0.28))
                SummaryCard(title: "高风险保护", value: "\(viewModel.highRiskItemCount()) 项", accent: Color(red: 0.86, green: 0.47, blue: 0.17))
                SummaryCard(title: "已选中项目", value: "\(viewModel.cleanupCandidateCount()) 项", accent: Color(red: 0.42, green: 0.38, blue: 0.91))
            }

            if viewModel.highRiskItemCount() > 0 {
                WarningBanner(
                    text: "现在所有项目都需要逐项勾选后才会进入废纸篓，高风险项目只是额外提醒你更谨慎。"
                )
            }

            if viewModel.hasPermissionWarnings() {
                PermissionBanner(
                    text: "部分目录因为 macOS 权限限制无法扫描，例如废纸篓、部分系统缓存和容器目录。给应用开启“完全磁盘访问”后再重新扫描，会更完整。",
                    action: viewModel.openFullDiskAccessSettings
                )
            }

            if let errorMessage = viewModel.errorMessage {
                WarningBanner(text: errorMessage, tint: Color(red: 0.72, green: 0.18, blue: 0.15))
            }
        }
    }
}

private struct SidebarCategoryRow: View {
    let category: CategoryResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: iconName)
                        .foregroundStyle(accentColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Color.white : Palette.titleColor)
                Text(category.totalSizeBytes.formattedByteCount)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : Palette.secondaryColor)
            }

            Spacer()

            if category.childItems.isEmpty == false {
                Text("\(category.childItems.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.75)), in: Capsule())
                    .foregroundStyle(isSelected ? Color.white : Palette.bodyColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? accentColor : Color.clear)
        )
    }

    private var iconName: String {
        switch category.section {
        case .restricted:
            return "lock.trianglebadge.exclamationmark"
        case .regular:
            return "internaldrive"
        case .remnants:
            return "app.badge.checkmark"
        }
    }

    private var accentColor: Color {
        if category.requiresPermission {
            return Color(red: 0.78, green: 0.49, blue: 0.14)
        }
        switch category.riskLevel {
        case .low:
            return Color(red: 0.14, green: 0.49, blue: 0.93)
        case .medium:
            return Color(red: 0.85, green: 0.53, blue: 0.12)
        case .high:
            return Color(red: 0.80, green: 0.25, blue: 0.19)
        }
    }
}

private struct DetailCategoryCard: View {
    let category: CategoryResult
    @ObservedObject var viewModel: JunkScannerViewModel
    let revealAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(category.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.titleColor)
                        if category.requiresPermission {
                            StatusBadge(title: "需要授权", tint: .orange)
                        }
                        RiskBadge(level: category.riskLevel)
                    }
                    Text(category.description)
                        .foregroundStyle(Palette.secondaryColor)
                    Text(category.rootPath)
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryColor)
                        .textSelection(.enabled)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(category.totalSizeBytes.formattedByteCount)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.titleColor)
                    Text("\(category.fileCount) 个文件")
                        .foregroundStyle(Palette.secondaryColor)
                }
            }

            if category.childItems.isEmpty {
                Text("没有匹配到一级目录项目。")
                    .foregroundStyle(Palette.secondaryColor)
                    .padding(.vertical, 18)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(category.childItems) { item in
                        DetailItemCard(item: item, viewModel: viewModel, revealAction: revealAction)
                    }
                }
            }

            if !category.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("警告")
                        .font(.headline)
                        .foregroundStyle(Palette.titleColor)
                    if category.warnings.contains(where: { warning in
                        let lowered = warning.lowercased()
                        return lowered.contains("permission") || lowered.contains("operation not permitted")
                    }) {
                        Text("这个分类当前存在权限限制。常见情况是没有为应用开启“完全磁盘访问”。")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.70, green: 0.35, blue: 0.10))
                    }
                    ForEach(category.warnings, id: \.self) { warning in
                        Text("• \(warning)")
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryColor)
                            .textSelection(.enabled)
                    }
                }
                .padding(16)
                .background(Palette.panelBackground, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    Palette.softWhite,
                    Palette.panelBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Palette.borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

private struct DetailItemCard: View {
    let item: ChildItem
    @ObservedObject var viewModel: JunkScannerViewModel
    let revealAction: (String) -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(iconTint.opacity(0.14))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "shippingbox")
                        .foregroundStyle(iconTint)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.appName)
                        .font(.headline)
                        .foregroundStyle(Palette.titleColor)
                    if item.isWhitelisted {
                        StatusBadge(title: "已保护", tint: .green)
                    } else if !item.deletionAllowed {
                        StatusBadge(title: "高风险保护", tint: .red)
                    } else {
                        StatusBadge(title: "可选择", tint: .orange)
                    }
                    RiskBadge(level: item.riskLevel)
                    ScoreBadge(score: item.matchScore)
                }
                if let bundleIdentifier = item.bundleIdentifier {
                    Text("Bundle ID：\(bundleIdentifier)")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryColor)
                        .textSelection(.enabled)
                }
                Text("来源：\(item.sourceCategoryName)")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryColor)
                Text("删除原因：\(item.matchReason)")
                    .font(.caption)
                    .foregroundStyle(Palette.bodyColor)
                Text("命中规则：\(item.matchedRules.joined(separator: " · "))")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryColor)
                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryColor)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 5) {
                Text(item.sizeBytes.formattedByteCount)
                    .font(.headline)
                    .foregroundStyle(Palette.titleColor)
                Text("\(item.itemCount) 个文件")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryColor)
                Button("在 Finder 中显示") {
                    revealAction(item.path)
                }
                .buttonStyle(.borderless)
            }

            if !item.isWhitelisted && item.deletionAllowed {
                Toggle(
                    item.riskLevel == .high ? "允许清理" : "加入清理",
                    isOn: Binding(
                        get: { viewModel.isItemSelected(item.id) },
                        set: { viewModel.setItemSelected(item.id, selected: $0) }
                    )
                )
                .toggleStyle(.checkbox)
                .frame(width: 92, alignment: .trailing)
            }
        }
        .padding(16)
        .background(Palette.softWhite, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Palette.borderColor, lineWidth: 1)
        )
    }

    private var iconTint: Color {
        if item.isWhitelisted {
            return .green
        }
        return item.deletionAllowed ? Color(red: 0.14, green: 0.49, blue: 0.93) : .red
    }
}

private struct ScoreBadge: View {
    let score: Int

    var body: some View {
        Text("匹配度 \(score)")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(red: 0.29, green: 0.35, blue: 0.47).opacity(0.12), in: Capsule())
            .foregroundStyle(Color(red: 0.29, green: 0.35, blue: 0.47))
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.secondaryColor)
            Text(value)
                .font(.headline)
                .foregroundStyle(Palette.titleColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(accent.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct WarningBanner: View {
    let text: String
    var tint: Color = Color(red: 0.88, green: 0.54, blue: 0.10)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield")
                .foregroundStyle(tint)
            Text(text)
                .font(.callout)
                .foregroundStyle(Palette.titleColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct PermissionBanner: View {
    let text: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .foregroundStyle(Color(red: 0.13, green: 0.45, blue: 0.89))
            Text(text)
                .font(.callout)
                .foregroundStyle(Palette.titleColor)
            Spacer()
            Button("打开完全磁盘访问") {
                action()
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.82, green: 0.90, blue: 0.98).opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(red: 0.68, green: 0.80, blue: 0.94), lineWidth: 1)
        )
    }
}

private struct PermissionGuideSheet: View {
    let categories: [CategoryResult]
    let openSettings: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("需要额外授权")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.titleColor)

            Text("macOS 会限制应用访问废纸篓、部分缓存、容器和系统目录。要获得更完整的扫描结果，请为本应用开启“完全磁盘访问”。")
                .foregroundStyle(Palette.bodyColor)

            VStack(alignment: .leading, spacing: 10) {
                Text("当前受限的分类")
                    .font(.headline)
                    .foregroundStyle(Palette.titleColor)
                ForEach(categories) { category in
                    Text("• \(category.name)")
                        .foregroundStyle(Palette.secondaryColor)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("操作步骤")
                    .font(.headline)
                    .foregroundStyle(Palette.titleColor)
                Text("1. 点击下方按钮打开“完全磁盘访问”")
                    .foregroundStyle(Palette.secondaryColor)
                Text("2. 把 Mac 垃圾扫描 加入允许列表")
                    .foregroundStyle(Palette.secondaryColor)
                Text("3. 回到应用后重新点击“开始扫描”")
                    .foregroundStyle(Palette.secondaryColor)
            }

            HStack {
                Button("稍后再说") {
                    close()
                }
                Spacer()
                Button("打开完全磁盘访问") {
                    openSettings()
                    close()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 380)
        .background(
            LinearGradient(
                colors: [Palette.softWhite, Palette.panelBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct StatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct RiskBadge: View {
    let level: RiskLevel

    var body: some View {
        Text(level.title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.14), in: Capsule())
            .foregroundStyle(backgroundColor)
    }

    private var backgroundColor: Color {
        switch level {
        case .low:
            return Color(red: 0.14, green: 0.49, blue: 0.93)
        case .medium:
            return Color(red: 0.85, green: 0.53, blue: 0.12)
        case .high:
            return Color(red: 0.80, green: 0.25, blue: 0.19)
        }
    }
}
