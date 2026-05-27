import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HabitViewModel

    var body: some View {
        Form {
            Section("主题") {
                Picker("界面主题", selection: Binding(
                    get: { store.theme },
                    set: { store.setTheme($0) }
                )) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("说明") {
                Text("这个版本会把待办数据保存在本地。")
                Text("如果启用 Widget，请保证 App Group 与主应用保持一致。")
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
