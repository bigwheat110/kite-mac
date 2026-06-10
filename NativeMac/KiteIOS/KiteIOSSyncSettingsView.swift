import SwiftUI

struct KiteIOSSyncSettingsView: View {
    @ObservedObject var viewModel: KiteIOSViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("当前模式", value: viewModel.syncModeTitle)
                    LabeledContent("下次启动", value: viewModel.nextLaunchSyncModeText)
                    LabeledContent("iCloud 账号", value: viewModel.iCloudAccountStatusText)
                    LabeledContent("同步事件", value: viewModel.cloudKitEventText)
                    LabeledContent("最近刷新", value: viewModel.lastRefreshText)
                    LabeledContent("最近标记", value: viewModel.lastSyncMarkerText)
                }

                Section {
                    Text(viewModel.syncModeDetail)
                        .foregroundStyle(.secondary)

                    if let message = viewModel.syncSettingsMessage {
                        Label(message, systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.needsRestartForPreferredSyncMode {
                        Label(viewModel.restartNoticeText, systemImage: "arrow.clockwise.circle")
                            .foregroundStyle(.orange)
                    } else {
                        Label(viewModel.restartNoticeText, systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Bundle ID", value: viewModel.bundleIdentifierText)
                    LabeledContent("Container", value: viewModel.cloudKitContainerIdentifierText)

                    Text("Store: \(viewModel.syncStorePath)")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if viewModel.syncMode == .local {
                        Text("可点下方“下次启动用 iCloud / CloudKit”后重启，也可用启动参数 \(viewModel.cloudKitLaunchArgumentText)。")
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
                    .disabled(viewModel.canWriteSyncMarker == false)
                }

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
                    Text(viewModel.restartNoticeText)
                }
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
