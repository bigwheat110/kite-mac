import Foundation

enum KiteIOSCoreDataStoreFactory {
    static let mode = HabitSyncStoreMode.current
    static let directoryName = "KiteIOS-CoreData"
    static let storeFileName = "kite-ios-core-data.sqlite"

    static func makeStore() -> HabitCoreDataStore {
        HabitSyncStoreFactory.makeStore(
            directoryName: directoryName,
            fileName: storeFileName,
            mode: mode
        )
    }

    static func storeURL() -> URL {
        HabitSyncStoreFactory.storeURL(
            directoryName: directoryName,
            fileName: storeFileName,
            mode: mode
        )
    }
}
