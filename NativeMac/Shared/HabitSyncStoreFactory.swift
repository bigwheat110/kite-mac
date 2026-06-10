import Foundation

enum HabitSyncStoreMode {
    case local
    case cloudKit

    static let cloudKitLaunchArgument = "--kite-sync-cloudkit"
    static let preferenceKey = "KiteSyncStoreMode"
    static let legacyDebugPreferenceKey = "KiteDebugSyncStoreMode"

    static let current: HabitSyncStoreMode = fromLaunchArguments()

    private static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> HabitSyncStoreMode {
        if arguments.contains(cloudKitLaunchArgument) {
            return .cloudKit
        }
        if let preferred = preference {
            return preferred
        }
        return .local
    }

    static var preference: HabitSyncStoreMode? {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: preferenceKey) {
                return HabitSyncStoreMode(rawValue: rawValue)
            }
            if let legacyRawValue = UserDefaults.standard.string(forKey: legacyDebugPreferenceKey),
               let legacyValue = HabitSyncStoreMode(rawValue: legacyRawValue) {
                UserDefaults.standard.set(legacyValue.rawValue, forKey: preferenceKey)
                UserDefaults.standard.removeObject(forKey: legacyDebugPreferenceKey)
                return legacyValue
            }
            return nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: preferenceKey)
            }
            UserDefaults.standard.removeObject(forKey: legacyDebugPreferenceKey)
        }
    }

    static var preferredOrCurrent: HabitSyncStoreMode {
        preference ?? current
    }

    var title: String {
        switch self {
        case .local:
            return "本地 Core Data"
        case .cloudKit:
            return "iCloud / CloudKit"
        }
    }

    var detail: String {
        switch self {
        case .local:
            return "当前只保存在本机，尚未和其他设备同步。"
        case .cloudKit:
            return "本地立即生效，iCloud 会在后台自动同步，不是实时协同。"
        }
    }

    var coreDataBackend: HabitCoreDataBackend {
        switch self {
        case .local:
            return .local
        case .cloudKit:
            return .cloudKit
        }
    }
}

enum HabitMacSyncStoreConfig {
    static let useSyncStoreLaunchArgument = "--kite-use-sync-store"
    static let importReleaseStateLaunchArgument = "--kite-import-release-state"
    static let directoryName = "KiteNative-SyncCoreData"
    static let storeFileName = "kite-sync-core-data.sqlite"

    static var usesSyncStore: Bool {
        ProcessInfo.processInfo.arguments.contains(useSyncStoreLaunchArgument)
            || HabitSyncStoreMode.current == .cloudKit
    }

    static var shouldImportReleaseState: Bool {
        ProcessInfo.processInfo.arguments.contains(importReleaseStateLaunchArgument)
    }

    static func makeStore(mode: HabitSyncStoreMode = HabitSyncStoreMode.current) -> HabitCoreDataStore {
        HabitSyncStoreFactory.makeStore(
            directoryName: directoryName,
            fileName: storeFileName,
            mode: mode
        )
    }

    static func storeURL(mode: HabitSyncStoreMode = HabitSyncStoreMode.current) -> URL {
        HabitSyncStoreFactory.storeURL(
            directoryName: directoryName,
            fileName: storeFileName,
            mode: mode
        )
    }
}

extension HabitSyncStoreMode: RawRepresentable {
    init?(rawValue: String) {
        switch rawValue {
        case "local":
            self = .local
        case "cloudKit":
            self = .cloudKit
        default:
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .local:
            return "local"
        case .cloudKit:
            return "cloudKit"
        }
    }
}

enum HabitSyncStoreFactory {
    static func makeStore(
        directoryName: String,
        fileName: String,
        mode: HabitSyncStoreMode = .local
    ) -> HabitCoreDataStore {
        HabitCoreDataStore(
            storeURL: storeURL(directoryName: directoryName, fileName: fileName, mode: mode),
            backend: mode.coreDataBackend
        )
    }

    static func storeURL(directoryName: String, fileName: String) -> URL {
        let directory = applicationSupportURL()
            .appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    static func storeURL(
        directoryName: String,
        fileName: String,
        mode: HabitSyncStoreMode
    ) -> URL {
        switch mode {
        case .local:
            return storeURL(directoryName: directoryName, fileName: fileName)
        case .cloudKit:
            return storeURL(directoryName: "\(directoryName)-CloudKit", fileName: fileName)
        }
    }

    private static func applicationSupportURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }
}
