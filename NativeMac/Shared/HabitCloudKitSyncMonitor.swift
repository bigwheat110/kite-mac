import CoreData
import Foundation

struct HabitCloudKitSyncEventSummary: Equatable {
    let text: String
    let shouldReloadLocalData: Bool
}

final class HabitCloudKitSyncMonitor {
    private var observer: NSObjectProtocol?
    private let onChange: (HabitCloudKitSyncEventSummary) -> Void

    init(onChange: @escaping (HabitCloudKitSyncEventSummary) -> Void) {
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else {
                return
            }
            self?.onChange(Self.describe(event))
        }
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private static func describe(_ event: NSPersistentCloudKitContainer.Event) -> HabitCloudKitSyncEventSummary {
        let kind: String
        switch event.type {
        case .setup:
            kind = "准备"
        case .import:
            kind = "导入"
        case .export:
            kind = "导出"
        @unknown default:
            kind = "未知"
        }

        if let error = event.error {
            return HabitCloudKitSyncEventSummary(
                text: "\(kind)失败：\(error.localizedDescription)",
                shouldReloadLocalData: false
            )
        }

        if event.endDate == nil {
            return HabitCloudKitSyncEventSummary(
                text: "\(kind)中...",
                shouldReloadLocalData: false
            )
        }

        return HabitCloudKitSyncEventSummary(
            text: "\(kind)完成",
            shouldReloadLocalData: event.type == .import
        )
    }
}
