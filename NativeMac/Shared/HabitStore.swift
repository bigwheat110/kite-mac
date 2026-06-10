import Foundation

final class HabitStore {
    static let shared = HabitStore()

    static let fileName = "app-state.json"
    static let uiTestFileName = "app-state-uitest.json"
    #if DEBUG
    static let appDirectoryName = "KiteNative-Debug"
    #else
    static let appDirectoryName = "KiteNative"
    #endif
    static let uiTestDirectoryName = "KiteNativeUITests"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> AppState {
        if Self.shouldResetUITestState {
            save(.default)
            return .default
        }
        guard let url = storageURL(),
              let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(AppState.self, from: data)
        else {
            return .default
        }
        return state
    }

    func save(_ state: AppState) {
        guard let url = storageURL() else { return }
        do {
            let data = try encoder.encode(state)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save app state: \(error)")
        }
    }

    private func storageURL() -> URL? {
        let isUITest = Self.usesUITestState
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first

        return appSupport?
            .appendingPathComponent(
                isUITest ? Self.uiTestDirectoryName : Self.appDirectoryName,
                isDirectory: true
            )
            .appendingPathComponent(isUITest ? Self.uiTestFileName : Self.fileName)
    }

    private static var shouldResetUITestState: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-reset-state")
    }

    private static var usesUITestState: Bool {
        shouldResetUITestState || ProcessInfo.processInfo.arguments.contains("--uitest-use-state")
    }
}

struct CoreDataImportSummary: Equatable {
    let sourceURL: URL
    let storeURL: URL
    let habitCount: Int
    let entryCount: Int
    let dailyOverrideCount: Int
    let hiddenHabitCount: Int
}

struct CoreDataSyncMarkerResult: Equatable {
    let dateKey: String
    let title: String
    let visibleHabitCount: Int
    let storeURL: URL
}

enum HabitMacSyncStoreBootstrap {
    static func importReleaseState() throws -> CoreDataImportSummary {
        try HabitCoreDataImporter.importState(
            from: appStateURL(directoryName: "KiteNative"),
            into: HabitMacSyncStoreConfig.makeStore(),
            storeURL: HabitMacSyncStoreConfig.storeURL(),
            mergeExisting: true
        )
    }

    private static func appStateURL(directoryName: String) -> URL {
        applicationSupportURL()
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(HabitStore.fileName)
    }
}

enum HabitMacSyncStoreDiagnostics {
    static func insertSyncMarker(on date: Date = .now) throws -> CoreDataSyncMarkerResult {
        try HabitCoreDataSyncMarkerWriter.insertSyncMarker(
            titlePrefix: "Mac主同步标记",
            on: date,
            into: HabitMacSyncStoreConfig.makeStore(),
            storeURL: HabitMacSyncStoreConfig.storeURL()
        )
    }
}

private enum HabitCoreDataSyncMarkerWriter {
    static func insertSyncMarker(
        titlePrefix: String,
        on date: Date,
        into store: HabitCoreDataStore,
        storeURL: URL
    ) throws -> CoreDataSyncMarkerResult {
        let dateKey = HabitDate.key(for: date)
        let timeText = syncMarkerTimeFormatter.string(from: .now)
        let title = "\(titlePrefix)-\(dateKey)-\(timeText)"

        try store.addHabit(title: title, startDate: date, todayOnly: false)
        let summary = try store.daySummary(for: date)

        return CoreDataSyncMarkerResult(
            dateKey: dateKey,
            title: title,
            visibleHabitCount: summary.visibleHabitCount,
            storeURL: storeURL
        )
    }

    private static let syncMarkerTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HHmmss"
        return formatter
    }()
}

private enum HabitCoreDataImporter {
    enum ImportError: Error {
        case missingSource(URL)
    }

    static func importState(
        from sourceURL: URL,
        into store: HabitCoreDataStore,
        storeURL: URL,
        mergeExisting: Bool = false
    ) throws -> CoreDataImportSummary {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ImportError.missingSource(sourceURL)
        }

        let data = try Data(contentsOf: sourceURL)
        let state = try JSONDecoder().decode(AppState.self, from: data)
        let summary = mergeExisting
            ? try store.mergeImport(state)
            : try store.replaceAll(with: state)

        return CoreDataImportSummary(
            sourceURL: sourceURL,
            storeURL: storeURL,
            habitCount: summary.habitCount,
            entryCount: summary.entryCount,
            dailyOverrideCount: summary.dailyOverrideCount,
            hiddenHabitCount: summary.hiddenHabitCount
        )
    }
}

#if DEBUG
struct CoreDataExperimentSummary: Equatable {
    let sourceURL: URL
    let storeURL: URL
    let habitCount: Int
    let entryCount: Int
    let dailyOverrideCount: Int
    let hiddenHabitCount: Int
}

struct CoreDataExperimentDayPreview: Equatable {
    let dateKey: String
    let totalHabitCount: Int
    let visibleHabitCount: Int
    let doneCount: Int
    let overrideCount: Int
    let hiddenCount: Int
    let visibleTitles: [String]
    let snapshot: HabitDaySnapshot
}

struct CoreDataExperimentWriteExerciseResult: Equatable {
    let dateKey: String
    let insertedTitle: String
    let renamedTodayTitle: String
    let renamedTemplateTitle: String
    let totalHabitCount: Int
    let visibleHabitCount: Int
    let doneCount: Int
    let hiddenCount: Int
    let visibleTitles: [String]
}

struct CoreDataExperimentSyncMarkerResult: Equatable {
    let result: CoreDataSyncMarkerResult

    var dateKey: String { result.dateKey }
    var title: String { result.title }
    var visibleHabitCount: Int { result.visibleHabitCount }
    var storeURL: URL { result.storeURL }
}

enum CoreDataExperimentError: Error {
    case missingSource(URL)
    case modelLoadFailed
    case storeLoadFailed(Error)
    case saveFailed(Error)
}

enum HabitCoreDataExperiment {
    static let storeFileName = "kite-core-data-experiment.sqlite"
    static let directoryName = "KiteNative-CoreDataExperiment"
    static var storeMode: HabitSyncStoreMode {
        HabitSyncStoreMode.current
    }

    static func importDebugState() throws -> CoreDataExperimentSummary {
        try importState(from: appStateURL(directoryName: HabitStore.appDirectoryName))
    }

    static func importReleaseStateIntoExperimentStore() throws -> CoreDataExperimentSummary {
        try importState(from: appStateURL(directoryName: "KiteNative"))
    }

    static func importState(from sourceURL: URL) throws -> CoreDataExperimentSummary {
        do {
            let summary = try HabitCoreDataImporter.importState(
                from: sourceURL,
                into: experimentStore(),
                storeURL: storeURL()
            )
            return CoreDataExperimentSummary(
                sourceURL: summary.sourceURL,
                storeURL: summary.storeURL,
                habitCount: summary.habitCount,
                entryCount: summary.entryCount,
                dailyOverrideCount: summary.dailyOverrideCount,
                hiddenHabitCount: summary.hiddenHabitCount
            )
        } catch {
            throw CoreDataExperimentError.saveFailed(error)
        }
    }

    static func clearExperimentStore() throws {
        try experimentStore().clearStoreFile()
    }

    static func previewDay(_ date: Date = .now) throws -> CoreDataExperimentDayPreview {
        let summary = try experimentStore().daySummary(for: date)

        return CoreDataExperimentDayPreview(
            dateKey: summary.dateKey,
            totalHabitCount: summary.totalHabitCount,
            visibleHabitCount: summary.visibleHabitCount,
            doneCount: summary.doneCount,
            overrideCount: summary.overrideCount,
            hiddenCount: summary.hiddenCount,
            visibleTitles: summary.visibleTitles,
            snapshot: summary.snapshot
        )
    }

    static func daySnapshot(for date: Date) throws -> HabitDaySnapshot {
        try experimentStore().daySnapshot(for: date)
    }

    static func runWriteExercise(on date: Date = .now) throws -> CoreDataExperimentWriteExerciseResult {
        let dateKey = HabitDate.key(for: date)
        let insertedTitle = "CoreData写入演练-\(dateKey)"
        let renamedTodayTitle = "\(insertedTitle)-今日改名"
        let renamedTemplateTitle = "\(insertedTitle)-模板改名"
        let store = experimentStore()
        let insertedID = UUID()

        try store.addHabit(title: insertedTitle, startDate: date, todayOnly: false, id: insertedID)
        try store.setDone(true, habitID: insertedID, on: date)
        try store.renameHabitForDay(habitID: insertedID, title: renamedTodayTitle, on: date)
        try store.renameHabitFromDate(habitID: insertedID, title: renamedTemplateTitle, from: date)
        try store.hideHabitForDay(habitID: insertedID, on: date)
        let hiddenSummary = try store.daySummary(for: date)

        try store.endHabitFromDate(habitID: insertedID, from: date)

        return CoreDataExperimentWriteExerciseResult(
            dateKey: dateKey,
            insertedTitle: insertedTitle,
            renamedTodayTitle: renamedTodayTitle,
            renamedTemplateTitle: renamedTemplateTitle,
            totalHabitCount: hiddenSummary.totalHabitCount,
            visibleHabitCount: hiddenSummary.visibleHabitCount,
            doneCount: hiddenSummary.doneCount,
            hiddenCount: hiddenSummary.hiddenCount,
            visibleTitles: hiddenSummary.visibleTitles
        )
    }

    static func insertSyncMarker(on date: Date = .now) throws -> CoreDataExperimentSyncMarkerResult {
        CoreDataExperimentSyncMarkerResult(
            result: try HabitCoreDataSyncMarkerWriter.insertSyncMarker(
                titlePrefix: "Mac实验同步标记",
                on: date,
                into: experimentStore(),
                storeURL: storeURL()
            )
        )
    }

    private static func appStateURL(directoryName: String) -> URL {
        applicationSupportURL()
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(HabitStore.fileName)
    }

    static func storeURL() -> URL {
        HabitSyncStoreFactory.storeURL(directoryName: directoryName, fileName: storeFileName, mode: storeMode)
    }

    private static func experimentStore() -> HabitCoreDataStore {
        HabitSyncStoreFactory.makeStore(directoryName: directoryName, fileName: storeFileName, mode: storeMode)
    }
}

struct HabitCoreDataExperimentStore: HabitSyncStore {
    func daySnapshot(for date: Date) throws -> HabitDaySnapshot {
        try HabitSyncStoreFactory.makeStore(
            directoryName: HabitCoreDataExperiment.directoryName,
            fileName: HabitCoreDataExperiment.storeFileName,
            mode: HabitCoreDataExperiment.storeMode
        )
        .daySnapshot(for: date)
    }
}
#endif
