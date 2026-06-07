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
