import SwiftUI

struct KiteIOSSyncSettingsView: View {
    @ObservedObject var viewModel: KiteIOSViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("当前模式", value: viewModel.syncModeTitle)
                    #if DEBUG
                    LabeledContent("下次启动", value: viewModel.nextLaunchSyncModeText)
                    #endif
                    LabeledContent("iCloud 账号", value: viewModel.iCloudAccountStatusText)
                    LabeledContent("同步事件", value: viewModel.cloudKitEventText)
                    LabeledContent("最近刷新", value: viewModel.lastRefreshText)
                }

                Section {
                    Text(viewModel.syncModeDetail)
                        .foregroundStyle(.secondary)

                    LabeledContent("Bundle ID", value: viewModel.bundleIdentifierText)
                    LabeledContent("Container", value: viewModel.cloudKitContainerIdentifierText)

                    Text("Store: \(viewModel.syncStorePath)")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if viewModel.syncMode == .local {
                        Text("CloudKit 试运行需使用启动参数 \(viewModel.cloudKitLaunchArgumentText)。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        viewModel.reload()
                    } label: {
                        Label("刷新数据", systemImage: "arrow.clockwise")
                    }

                    Button {
                        viewModel.refreshICloudAccountStatus()
                    } label: {
                        Label("检查 iCloud", systemImage: "icloud")
                    }

                    Button {
                        viewModel.insertSyncMarker()
                    } label: {
                        Label("写入同步标记", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                #if DEBUG
                Section {
                    Button {
                        viewModel.setNextLaunchSyncMode(.local)
                    } label: {
                        Label("下次启动用本地 Core Data", systemImage: "internaldrive")
                    }

                    Button {
                        viewModel.setNextLaunchSyncMode(.cloudKit)
                    } label: {
                        Label("下次启动用 iCloud / CloudKit", systemImage: "icloud")
                    }
                } footer: {
                    Text("仅 Debug 试运行使用，重启 App 后生效。")
                }
                #endif
            }
            .navigationTitle("同步")
            .onAppear {
                viewModel.refreshICloudAccountStatus()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    KiteIOSSyncSettingsView(viewModel: KiteIOSViewModel())
}
