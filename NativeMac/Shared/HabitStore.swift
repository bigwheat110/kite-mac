import CoreData
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
}

enum CoreDataExperimentError: Error {
    case missingSource(URL)
    case modelLoadFailed
    case storeLoadFailed(Error)
    case saveFailed(Error)
}

enum HabitCoreDataExperiment {
    static let storeFileName = "kite-core-data-experiment.sqlite"

    static func importDebugState() throws -> CoreDataExperimentSummary {
        try importState(from: appStateURL(directoryName: HabitStore.appDirectoryName))
    }

    static func importReleaseStateReadOnly() throws -> CoreDataExperimentSummary {
        try importState(from: appStateURL(directoryName: "KiteNative"))
    }

    static func importState(from sourceURL: URL) throws -> CoreDataExperimentSummary {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CoreDataExperimentError.missingSource(sourceURL)
        }

        let data = try Data(contentsOf: sourceURL)
        let state = try JSONDecoder().decode(AppState.self, from: data)
        let container = try makeContainer()
        let context = container.viewContext

        try resetExperimentData(in: context)
        let summary = importState(state, sourceURL: sourceURL, storeURL: storeURL(), into: context)

        do {
            try context.save()
        } catch {
            throw CoreDataExperimentError.saveFailed(error)
        }

        return summary
    }

    static func clearExperimentStore() throws {
        let url = storeURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    static func previewDay(_ date: Date = .now) throws -> CoreDataExperimentDayPreview {
        let dateKey = HabitDate.key(for: date)
        let container = try makeContainer()
        let context = container.viewContext
        let habits = try fetchObjects(entityName: "HabitEntity", in: context)
        let entries = try fetchObjects(entityName: "HabitEntryEntity", dateKey: dateKey, in: context)
        let overrides = try fetchObjects(entityName: "DailyOverrideEntity", dateKey: dateKey, in: context)
        let hidden = try fetchObjects(entityName: "HiddenHabitEntity", dateKey: dateKey, in: context)

        let hiddenIDs = Set(hidden.compactMap { $0.value(forKey: "habitID") as? UUID })
        let doneIDs = Set(entries.compactMap { object -> UUID? in
            guard object.value(forKey: "isDone") as? Bool == true else { return nil }
            return object.value(forKey: "habitID") as? UUID
        })
        let titleByHabitID = Dictionary(
            uniqueKeysWithValues: overrides.compactMap { object -> (UUID, String)? in
                guard let habitID = object.value(forKey: "habitID") as? UUID,
                      let title = object.value(forKey: "title") as? String
                else {
                    return nil
                }
                return (habitID, title)
            }
        )

        let visibleTitles = habits
            .compactMap { object -> (Date, String)? in
                guard let habitID = object.value(forKey: "id") as? UUID,
                      hiddenIDs.contains(habitID) == false,
                      habitApplies(object, on: dateKey)
                else {
                    return nil
                }
                let createdAt = object.value(forKey: "createdAt") as? Date ?? .distantPast
                let title = titleByHabitID[habitID]
                    ?? object.value(forKey: "title") as? String
                    ?? object.value(forKey: "baseTitle") as? String
                    ?? "未命名"
                return (createdAt, title)
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)

        return CoreDataExperimentDayPreview(
            dateKey: dateKey,
            totalHabitCount: habits.count,
            visibleHabitCount: visibleTitles.count,
            doneCount: doneIDs.subtracting(hiddenIDs).count,
            overrideCount: overrides.count,
            hiddenCount: hidden.count,
            visibleTitles: visibleTitles
        )
    }

    private static func importState(
        _ state: AppState,
        sourceURL: URL,
        storeURL: URL,
        into context: NSManagedObjectContext
    ) -> CoreDataExperimentSummary {
        var entryCount = 0
        var dailyOverrideCount = 0
        var hiddenHabitCount = 0

        for habit in state.habits {
            let entity = NSEntityDescription.insertNewObject(forEntityName: "HabitEntity", into: context)
            entity.setValue(habit.id, forKey: "id")
            entity.setValue(habit.title, forKey: "title")
            entity.setValue(habit.baseTitle, forKey: "baseTitle")
            entity.setValue(habit.createdAt, forKey: "createdAt")
            entity.setValue(habit.createdAt, forKey: "updatedAt")
            entity.setValue(habit.startDateKey, forKey: "startDateKey")
            entity.setValue(habit.endDateKey, forKey: "endDateKey")
            entity.setValue(habit.repeatRule.kind.rawValue, forKey: "repeatKind")
            entity.setValue(habit.repeatRule.weekdays.map(String.init).joined(separator: ","), forKey: "repeatWeekdays")
            entity.setValue(encodeJSONString(habit.titleHistory), forKey: "titleHistoryJSON")
        }

        for (dateKey, entries) in state.entries {
            for (habitID, isDone) in entries {
                let entity = NSEntityDescription.insertNewObject(forEntityName: "HabitEntryEntity", into: context)
                entity.setValue(UUID(), forKey: "id")
                entity.setValue(habitID, forKey: "habitID")
                entity.setValue(dateKey, forKey: "dateKey")
                entity.setValue(isDone, forKey: "isDone")
                entity.setValue(Date(), forKey: "createdAt")
                entity.setValue(Date(), forKey: "updatedAt")
                entryCount += 1
            }
        }

        for (dateKey, overrides) in state.dailyOverrides {
            for (habitID, title) in overrides {
                let entity = NSEntityDescription.insertNewObject(forEntityName: "DailyOverrideEntity", into: context)
                entity.setValue(UUID(), forKey: "id")
                entity.setValue(habitID, forKey: "habitID")
                entity.setValue(dateKey, forKey: "dateKey")
                entity.setValue(title, forKey: "title")
                entity.setValue(Date(), forKey: "createdAt")
                entity.setValue(Date(), forKey: "updatedAt")
                dailyOverrideCount += 1
            }
        }

        for (dateKey, hiddenIDs) in state.hiddenHabits {
            for habitID in hiddenIDs {
                let entity = NSEntityDescription.insertNewObject(forEntityName: "HiddenHabitEntity", into: context)
                entity.setValue(UUID(), forKey: "id")
                entity.setValue(habitID, forKey: "habitID")
                entity.setValue(dateKey, forKey: "dateKey")
                entity.setValue(Date(), forKey: "createdAt")
                entity.setValue(Date(), forKey: "updatedAt")
                hiddenHabitCount += 1
            }
        }

        return CoreDataExperimentSummary(
            sourceURL: sourceURL,
            storeURL: storeURL,
            habitCount: state.habits.count,
            entryCount: entryCount,
            dailyOverrideCount: dailyOverrideCount,
            hiddenHabitCount: hiddenHabitCount
        )
    }

    private static func makeContainer() throws -> NSPersistentContainer {
        let model = makeModel()
        let container = NSPersistentContainer(name: "KiteCoreDataExperiment", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL())
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError {
            throw CoreDataExperimentError.storeLoadFailed(loadError)
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    private static func resetExperimentData(in context: NSManagedObjectContext) throws {
        for entityName in ["HabitEntity", "HabitEntryEntity", "DailyOverrideEntity", "HiddenHabitEntity"] {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
    }

    private static func fetchObjects(
        entityName: String,
        dateKey: String? = nil,
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        if let dateKey {
            request.predicate = NSPredicate(format: "dateKey == %@", dateKey)
        }
        return try context.fetch(request)
    }

    private static func habitApplies(_ object: NSManagedObject, on dateKey: String) -> Bool {
        if let startDateKey = object.value(forKey: "startDateKey") as? String,
           startDateKey > dateKey {
            return false
        }
        if let endDateKey = object.value(forKey: "endDateKey") as? String,
           endDateKey < dateKey {
            return false
        }

        let repeatKind = object.value(forKey: "repeatKind") as? String ?? HabitRepeatKind.daily.rawValue
        guard repeatKind != HabitRepeatKind.daily.rawValue else { return true }

        let weekday = HabitDate.calendar.component(.weekday, from: HabitDate.date(from: dateKey))
        switch HabitRepeatKind(rawValue: repeatKind) {
        case .weekdays:
            return (2...6).contains(weekday)
        case .weekends:
            return weekday == 1 || weekday == 7
        case .custom:
            let weekdays = (object.value(forKey: "repeatWeekdays") as? String ?? "")
                .split(separator: ",")
                .compactMap { Int($0) }
            return weekdays.contains(weekday)
        case .daily, .none:
            return true
        }
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            makeHabitEntity(),
            makeHabitEntryEntity(),
            makeDailyOverrideEntity(),
            makeHiddenHabitEntity()
        ]
        return model
    }

    private static func makeHabitEntity() -> NSEntityDescription {
        makeEntity(
            name: "HabitEntity",
            properties: [
                attribute("id", .UUIDAttributeType, optional: false),
                attribute("title", .stringAttributeType, optional: false),
                attribute("baseTitle", .stringAttributeType, optional: false),
                attribute("createdAt", .dateAttributeType, optional: false),
                attribute("updatedAt", .dateAttributeType, optional: false),
                attribute("deletedAt", .dateAttributeType),
                attribute("startDateKey", .stringAttributeType),
                attribute("endDateKey", .stringAttributeType),
                attribute("repeatKind", .stringAttributeType, optional: false),
                attribute("repeatWeekdays", .stringAttributeType, optional: false),
                attribute("titleHistoryJSON", .stringAttributeType, optional: false)
            ]
        )
    }

    private static func makeHabitEntryEntity() -> NSEntityDescription {
        makeEntity(
            name: "HabitEntryEntity",
            properties: datedHabitProperties() + [
                attribute("isDone", .booleanAttributeType, optional: false)
            ]
        )
    }

    private static func makeDailyOverrideEntity() -> NSEntityDescription {
        makeEntity(
            name: "DailyOverrideEntity",
            properties: datedHabitProperties() + [
                attribute("title", .stringAttributeType, optional: false)
            ]
        )
    }

    private static func makeHiddenHabitEntity() -> NSEntityDescription {
        makeEntity(name: "HiddenHabitEntity", properties: datedHabitProperties())
    }

    private static func datedHabitProperties() -> [NSAttributeDescription] {
        [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("habitID", .UUIDAttributeType, optional: false),
            attribute("dateKey", .stringAttributeType, optional: false),
            attribute("createdAt", .dateAttributeType, optional: false),
            attribute("updatedAt", .dateAttributeType, optional: false),
            attribute("deletedAt", .dateAttributeType)
        ]
    }

    private static func makeEntity(name: String, properties: [NSPropertyDescription]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = properties
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = true
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }

    private static func encodeJSONString<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return text
    }

    private static func appStateURL(directoryName: String) -> URL {
        applicationSupportURL()
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(HabitStore.fileName)
    }

    private static func storeURL() -> URL {
        let directory = applicationSupportURL()
            .appendingPathComponent("KiteNative-CoreDataExperiment", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(storeFileName)
    }

    private static func applicationSupportURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }
}
#endif
