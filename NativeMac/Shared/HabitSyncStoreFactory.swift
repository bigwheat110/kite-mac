import Foundation

enum HabitSyncStoreMode {
    case local
    case cloudKit

    static let cloudKitLaunchArgument = "--kite-sync-cloudkit"
    #if DEBUG
    static let debugPreferenceKey = "KiteDebugSyncStoreMode"
    #endif

    static let current: HabitSyncStoreMode = fromLaunchArguments()

    private static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> HabitSyncStoreMode {
        if arguments.contains(cloudKitLaunchArgument) {
            return .cloudKit
        }
        #if DEBUG
        if let preferred = debugPreference {
            return preferred
        }
        #endif
        return .local
    }

    #if DEBUG
    static var debugPreference: HabitSyncStoreMode? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: debugPreferenceKey) else {
                return nil
            }
            return HabitSyncStoreMode(rawValue: rawValue)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: debugPreferenceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: debugPreferenceKey)
            }
        }
    }
    #endif

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
