import SwiftUI

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

                settingsRow(title: "数据存储", subtitle: "待办和提醒只保存在这台 Mac") {
                    Label("本地", systemImage: "lock.fill")
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

#if DEBUG
struct CoreDataExperimentPanelView: View {
    @EnvironmentObject private var store: HabitViewModel
    var embeddedInSettings = false
    @State private var message = "尚未运行"
    private var palette: ThemePalette { .palette(for: store.theme) }

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
                        Text("只写入独立实验库，不替换当前 JSON 数据源")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Core Data 实验")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("只写入独立实验库，不替换当前 JSON 数据源")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }
            }

            HStack(spacing: 8) {
                experimentButton("导入 Debug", prominent: true) {
                    run { try HabitCoreDataExperiment.importDebugState() }
                }

                experimentButton("只读正式数据", prominent: true) {
                    run { try HabitCoreDataExperiment.importReleaseStateReadOnly() }
                }

                experimentButton("清理实验库", prominent: false) {
                    clearStore()
                }
            }

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

    private func clearStore() {
        do {
            try HabitCoreDataExperiment.clearExperimentStore()
            message = "实验库已清理"
        } catch {
            message = "清理失败: \(error)"
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
