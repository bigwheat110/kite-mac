import SwiftUI
import CloudKit

struct SettingsView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 42, height: 42)
                    .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Kite 设置")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("调整窗口外观和本地数据体验")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }
            }

            VStack(spacing: 0) {
                settingsRow(title: "界面主题", subtitle: "跟随当前窗口即时切换明暗外观") {
                    Picker("", selection: Binding(
                        get: { store.theme },
                        set: { store.setTheme($0) }
                    )) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 184)
                }

                Divider()
                    .overlay(palette.divider)
                    .padding(.leading, 16)

                settingsRow(title: "数据存储", subtitle: HabitSyncStoreMode.current == .cloudKit ? "习惯数据通过 iCloud 私有库同步" : "当前仍使用这台 Mac 的本地数据") {
                    Label(HabitSyncStoreMode.current == .cloudKit ? "iCloud" : "本地", systemImage: HabitSyncStoreMode.current == .cloudKit ? "icloud.fill" : "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(palette.successSoft, in: Capsule())
                }

                Divider()
                    .overlay(palette.divider)
                    .padding(.leading, 16)

                settingsRow(title: "Widget", subtitle: "启用桌面组件时需保持 App Group 一致") {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(palette.panelStrong, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Divider()
                    .overlay(palette.divider)
                    .padding(.leading, 16)

                MacSyncSettingsPanelView()
                    .environmentObject(store)

                #if DEBUG
                Divider()
                    .overlay(palette.divider)
                    .padding(.leading, 16)

                CoreDataExperimentPanelView(embeddedInSettings: true)
                    .environmentObject(store)
                #endif
            }
            .background(palette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.divider, lineWidth: 0.8)
            }
        }
        .padding(22)
        .frame(width: 460)
        .background(
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func settingsRow<Accessory: View>(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            accessory()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct MacSyncSettingsPanelView: View {
    @EnvironmentObject private var store: HabitViewModel
    @State private var message = "尚未运行"
    @State private var iCloudAccountStatus = "尚未检查"
    @State private var nextLaunchSyncMode = HabitSyncStoreMode.preferredOrCurrent
    @StateObject private var cloudKitSyncStatus = CloudKitSyncStatusModel()
    private var palette: ThemePalette { .palette(for: store.theme) }
    private var syncMode: HabitSyncStoreMode { HabitSyncStoreMode.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("同步")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("Mac 与 iPhone 使用同一个 iCloud 私有库同步习惯数据")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: syncMode == .cloudKit ? "icloud" : "internaldrive")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Text("当前模式：\(syncMode.title)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                }

                Text("下次启动：\(nextLaunchSyncMode.title)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)

                Text(syncMode == nextLaunchSyncMode
                    ? "当前启动已使用所选模式。"
                    : "重启后切换到\(nextLaunchSyncMode.title)。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(syncMode == nextLaunchSyncMode ? palette.textSecondary : .orange)

                Text("主同步库: \(HabitMacSyncStoreConfig.storeURL().path)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Text("Bundle ID: \(Bundle.main.bundleIdentifier ?? "未知")")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .textSelection(.enabled)

                Text("Container: \(HabitCoreDataStack.cloudKitContainerIdentifier)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .textSelection(.enabled)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.panelStrong.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 8) {
                syncButton("检查 iCloud", prominent: false) {
                    checkICloudAccountStatus()
                }

                syncButton("下次本地", prominent: false) {
                    setNextLaunchSyncMode(.local)
                }

                syncButton("下次 iCloud", prominent: true) {
                    setNextLaunchSyncMode(.cloudKit)
                }
            }

            HStack(spacing: 8) {
                syncButton("导入主同步库", prominent: true) {
                    importReleaseStateIntoMainSyncStore()
                }

                syncButton("主同步标记", prominent: false) {
                    insertMainSyncMarker()
                }
            }

            Text("iCloud 账号：\(iCloudAccountStatus)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textSecondary)

            Text("同步事件：\(cloudKitSyncStatus.eventText)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textSecondary)

            Text(message)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .textSelection(.enabled)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .onAppear {
            cloudKitSyncStatus.configure(for: syncMode) {
                store.reloadSyncStoreIfNeeded()
            }
        }
    }

    private func importReleaseStateIntoMainSyncStore() {
        guard syncMode == .cloudKit else {
            message = "请先设置下次 iCloud 并重启，再导入主同步库"
            return
        }

        do {
            let summary = try HabitMacSyncStoreBootstrap.importReleaseState()
            store.reloadSyncStoreIfNeeded()
            message = """
            主同步库已导入正式数据
            habits: \(summary.habitCount), entries: \(summary.entryCount)
            store: \(summary.storeURL.path)
            """
        } catch {
            message = "主同步库导入失败: \(error)"
        }
    }

    private func insertMainSyncMarker() {
        guard syncMode == .cloudKit else {
            message = "请先设置下次 iCloud 并重启，再写入主同步标记"
            return
        }

        do {
            let result = try HabitMacSyncStoreDiagnostics.insertSyncMarker(on: store.selectedDate)
            store.reloadSyncStoreIfNeeded()
            message = """
            主同步标记已写入
            title: \(result.title)
            visible: \(result.visibleHabitCount)
            """
        } catch {
            message = "主同步标记写入失败: \(error)"
        }
    }

    private func checkICloudAccountStatus() {
        iCloudAccountStatus = "检查中..."
        let container = CKContainer(identifier: HabitCoreDataStack.cloudKitContainerIdentifier)
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error {
                    iCloudAccountStatus = "检查失败：\(error.localizedDescription)"
                } else {
                    iCloudAccountStatus = describeICloudAccountStatus(status)
                }
            }
        }
    }

    private func setNextLaunchSyncMode(_ mode: HabitSyncStoreMode) {
        HabitSyncStoreMode.preference = mode
        nextLaunchSyncMode = mode
        message = "下次启动将使用：\(mode.title)"
    }

    private func describeICloudAccountStatus(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "可用"
        case .noAccount:
            return "未登录 iCloud"
        case .restricted:
            return "受限制"
        case .couldNotDetermine:
            return "无法确定"
        case .temporarilyUnavailable:
            return "暂时不可用"
        @unknown default:
            return "未知状态"
        }
    }

    private func syncButton(
        _ title: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(prominent ? Color.white : palette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    prominent ? palette.accentSoft : palette.panelStrong,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(prominent ? palette.accent.opacity(0.22) : palette.divider, lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
    }
}

private final class CloudKitSyncStatusModel: ObservableObject {
    @Published var eventText = "仅 CloudKit 模式监听"
    private var monitor: HabitCloudKitSyncMonitor?
    private var onReloadLocalData: (() -> Void)?

    func configure(for mode: HabitSyncStoreMode, onReloadLocalData: @escaping () -> Void) {
        self.onReloadLocalData = onReloadLocalData
        guard mode == .cloudKit else {
            monitor?.stop()
            monitor = nil
            eventText = "仅 CloudKit 模式监听"
            return
        }

        guard monitor == nil else { return }
        eventText = "尚未收到同步事件"
        let monitor = HabitCloudKitSyncMonitor { [weak self] summary in
            Task { @MainActor in
                self?.eventText = summary.text
                if summary.shouldReloadLocalData {
                    self?.onReloadLocalData?()
                }
            }
        }
        monitor.start()
        self.monitor = monitor
    }
}

#if DEBUG
struct CoreDataExperimentPanelView: View {
    @EnvironmentObject private var store: HabitViewModel
    var embeddedInSettings = false
    @State private var message = "尚未运行"
    @State private var iCloudAccountStatus = "尚未检查"
    @State private var nextLaunchSyncMode = HabitSyncStoreMode.preferredOrCurrent
    @StateObject private var cloudKitSyncStatus = CloudKitSyncStatusModel()
    private var palette: ThemePalette { .palette(for: store.theme) }
    private var syncMode: HabitSyncStoreMode { HabitCoreDataExperiment.storeMode }

    var body: some View {
        VStack(alignment: .leading, spacing: embeddedInSettings ? 12 : 16) {
            if !embeddedInSettings {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.icloud")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 40, height: 40)
                        .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Core Data 实验")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                        Text("调试实验库与主同步库分开，默认仍使用 JSON")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Core Data 实验")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("调试实验库与主同步库分开，默认仍使用 JSON")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: syncMode == .cloudKit ? "icloud" : "internaldrive")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Text("当前模式：\(syncMode.title)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                }

                Text(syncMode.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textSecondary)

                Text("实验库: \(HabitCoreDataExperiment.storeURL().path)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Text("主同步库: \(HabitMacSyncStoreConfig.storeURL().path)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Text(syncMode == .local
                    ? "Mac 主 UI 使用同步库需启动参数 \(HabitMacSyncStoreConfig.useSyncStoreLaunchArgument)。"
                    : "Mac 主 UI 在 CloudKit 模式下会自动使用主同步库。"
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.textSecondary)

                Text("启动时播种正式数据可加 \(HabitMacSyncStoreConfig.importReleaseStateLaunchArgument)。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.textSecondary)

                Text("下次启动：\(nextLaunchSyncMode.title)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)

                Text("Bundle ID: \(Bundle.main.bundleIdentifier ?? "未知")")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .textSelection(.enabled)

                Text("Container: \(HabitCoreDataStack.cloudKitContainerIdentifier)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .textSelection(.enabled)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.panelStrong.opacity(embeddedInSettings ? 0.55 : 1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 8) {
                experimentButton("导入 Debug", prominent: true) {
                    run { try HabitCoreDataExperiment.importDebugState() }
                }

                experimentButton("导入实验库", prominent: true) {
                    run { try HabitCoreDataExperiment.importReleaseStateIntoExperimentStore() }
                }

                experimentButton("导入主同步库", prominent: true) {
                    importReleaseStateIntoMainSyncStore()
                }

                experimentButton("预览今天", prominent: true) {
                    previewToday()
                }
            }

            HStack(spacing: 8) {
                experimentButton("对比今天", prominent: true) {
                    compareToday()
                }

                experimentButton("写入演练", prominent: true) {
                    runWriteExercise()
                }

                experimentButton("实验标记", prominent: true) {
                    insertSyncMarker()
                }

                experimentButton("主同步标记", prominent: true) {
                    insertMainSyncMarker()
                }
            }

            HStack(spacing: 8) {
                experimentButton("清理实验库", prominent: false) {
                    clearStore()
                }

                Text(syncMode.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)

                experimentButton(store.usesCoreDataTrial ? "关闭试运行" : "开启试运行", prominent: !store.usesCoreDataTrial) {
                    toggleCoreDataTrial()
                }

                experimentButton("检查 iCloud", prominent: false) {
                    checkICloudAccountStatus()
                }
            }

            HStack(spacing: 8) {
                experimentButton("下次本地", prominent: false) {
                    setNextLaunchSyncMode(.local)
                }

                experimentButton("下次 iCloud", prominent: false) {
                    setNextLaunchSyncMode(.cloudKit)
                }
            }

            Text("iCloud 账号：\(iCloudAccountStatus)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textSecondary)

            Text("同步事件：\(cloudKitSyncStatus.eventText)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textSecondary)

            Text(message)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .textSelection(.enabled)
                .lineLimit(embeddedInSettings ? 6 : 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(embeddedInSettings ? 0 : 12)
                .background {
                    if !embeddedInSettings {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(palette.panelStrong)
                    }
                }
        }
        .padding(embeddedInSettings ? EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16) : EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
        .frame(width: embeddedInSettings ? nil : 460)
        .background {
            if !embeddedInSettings {
                LinearGradient(
                    colors: [palette.backgroundTop, palette.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .onAppear {
            cloudKitSyncStatus.configure(for: syncMode) {
                store.reloadSyncStoreIfNeeded()
                store.reloadCoreDataTrialIfNeeded()
            }
        }
        .onChange(of: syncMode) { _, newMode in
            cloudKitSyncStatus.configure(for: newMode) {
                store.reloadSyncStoreIfNeeded()
                store.reloadCoreDataTrialIfNeeded()
            }
        }
    }

    private func run(_ action: () throws -> CoreDataExperimentSummary) {
        do {
            let summary = try action()
            message = """
            habits: \(summary.habitCount), entries: \(summary.entryCount)
            overrides: \(summary.dailyOverrideCount), hidden: \(summary.hiddenHabitCount)
            source: \(summary.sourceURL.path)
            store: \(summary.storeURL.path)
            """
        } catch {
            message = "失败: \(error)"
        }
    }

    private func importReleaseStateIntoMainSyncStore() {
        do {
            let summary = try HabitMacSyncStoreBootstrap.importReleaseState()
            message = """
            主同步库已导入正式数据
            habits: \(summary.habitCount), entries: \(summary.entryCount)
            overrides: \(summary.dailyOverrideCount), hidden: \(summary.hiddenHabitCount)
            source: \(summary.sourceURL.path)
            store: \(summary.storeURL.path)
            """
        } catch {
            message = "主同步库导入失败: \(error)"
        }
    }

    private func clearStore() {
        do {
            try HabitCoreDataExperiment.clearExperimentStore()
            message = "实验库已清理"
        } catch {
            message = "清理失败: \(error)"
        }
    }

    private func toggleCoreDataTrial() {
        let enabled = !store.usesCoreDataTrial
        store.setCoreDataTrialEnabled(enabled)
        message = enabled
            ? "试运行已开启：Mac UI 将读写独立 Core Data 实验库"
            : "试运行已关闭：Mac UI 已回到 JSON 数据源"
    }

    private func previewToday() {
        do {
            let syncStore = HabitCoreDataExperimentStore()
            let snapshot = try syncStore.daySnapshot(for: store.selectedDate)
            let preview = try HabitCoreDataExperiment.previewDay(store.selectedDate)
            let titles = snapshot.habits.map(\.title).prefix(8).joined(separator: " / ")
            let suffix = snapshot.habits.count > 8 ? " ..." : ""
            message = """
            date: \(snapshot.dateKey)
            total: \(preview.totalHabitCount), visible: \(snapshot.totalCount), done: \(snapshot.doneCount)
            overrides: \(preview.overrideCount), hidden: \(preview.hiddenCount)
            titles: \(titles)\(suffix)
            """
        } catch {
            message = "预览失败: \(error)"
        }
    }

    private func compareToday() {
        do {
            let comparison = try HabitSnapshotComparator.compare(
                json: HabitJSONSnapshotStore(state: store.state),
                other: HabitCoreDataExperimentStore(),
                on: store.selectedDate
            )
            if comparison.matches {
                message = """
                date: \(comparison.dateKey)
                JSON 与 Core Data 匹配
                visible: \(comparison.json.totalCount), done: \(comparison.json.doneCount)
                """
            } else {
                let details = comparison.differences.prefix(5).joined(separator: "\n")
                let suffix = comparison.differences.count > 5 ? "\n..." : ""
                message = """
                date: \(comparison.dateKey)
                JSON/Core Data 不一致
                JSON: \(comparison.json.totalCount) visible, \(comparison.json.doneCount) done
                Core Data: \(comparison.other.totalCount) visible, \(comparison.other.doneCount) done
                \(details)\(suffix)
                """
            }
        } catch {
            message = "对比失败: \(error)"
        }
    }

    private func runWriteExercise() {
        do {
            let result = try HabitCoreDataExperiment.runWriteExercise(on: store.selectedDate)
            let titles = result.visibleTitles.prefix(8).joined(separator: " / ")
            let suffix = result.visibleTitles.count > 8 ? " ..." : ""
            message = """
            date: \(result.dateKey)
            写入演练完成
            inserted: \(result.insertedTitle)
            todayName: \(result.renamedTodayTitle)
            templateName: \(result.renamedTemplateTitle)
            total: \(result.totalHabitCount), visible: \(result.visibleHabitCount), done: \(result.doneCount), hidden: \(result.hiddenCount)
            titles: \(titles)\(suffix)
            """
        } catch {
            message = "写入演练失败: \(error)"
        }
    }

    private func insertSyncMarker() {
        do {
            let result = try HabitCoreDataExperiment.insertSyncMarker(on: store.selectedDate)
            store.reloadCoreDataTrialIfNeeded()
            message = """
            date: \(result.dateKey)
            同步标记已写入
            title: \(result.title)
            visible: \(result.visibleHabitCount)
            store: \(result.storeURL.path)
            """
        } catch {
            message = "同步标记写入失败: \(error)"
        }
    }

    private func insertMainSyncMarker() {
        do {
            let result = try HabitMacSyncStoreDiagnostics.insertSyncMarker(on: store.selectedDate)
            store.reloadSyncStoreIfNeeded()
            message = """
            date: \(result.dateKey)
            主同步标记已写入
            title: \(result.title)
            visible: \(result.visibleHabitCount)
            store: \(result.storeURL.path)
            """
        } catch {
            message = "主同步标记写入失败: \(error)"
        }
    }

    private func checkICloudAccountStatus() {
        iCloudAccountStatus = "检查中..."
        let container = CKContainer(identifier: HabitCoreDataStack.cloudKitContainerIdentifier)
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error {
                    iCloudAccountStatus = "检查失败：\(error.localizedDescription)"
                } else {
                    iCloudAccountStatus = describeICloudAccountStatus(status)
                }
            }
        }
    }

    private func setNextLaunchSyncMode(_ mode: HabitSyncStoreMode) {
        HabitSyncStoreMode.preference = mode
        nextLaunchSyncMode = mode
        message = "下次启动将使用：\(mode.title)"
    }

    private func describeICloudAccountStatus(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "可用"
        case .noAccount:
            return "未登录 iCloud"
        case .restricted:
            return "受限制"
        case .couldNotDetermine:
            return "无法确定"
        case .temporarilyUnavailable:
            return "暂时不可用"
        @unknown default:
            return "未知状态"
        }
    }

    private func experimentButton(
        _ title: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(prominent ? Color.white : palette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    prominent ? palette.accentSoft : palette.panelStrong,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(prominent ? palette.accent.opacity(0.22) : palette.divider, lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
    }
}
#endif
