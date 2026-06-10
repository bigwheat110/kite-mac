import CoreData
import Foundation

struct HabitCoreDataImportSummary: Equatable {
    let habitCount: Int
    let entryCount: Int
    let dailyOverrideCount: Int
    let hiddenHabitCount: Int
}

struct HabitCoreDataDaySummary: Equatable {
    let dateKey: String
    let totalHabitCount: Int
    let visibleHabitCount: Int
    let doneCount: Int
    let overrideCount: Int
    let hiddenCount: Int
    let visibleTitles: [String]
    let snapshot: HabitDaySnapshot
}

enum HabitCoreDataBackend {
    case local
    case cloudKit

    var cacheKey: String {
        switch self {
        case .local:
            return "local"
        case .cloudKit:
            return "cloudKit"
        }
    }
}

private struct HabitDeletedMarker {
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date
}

private final class HabitCoreDataContainerCache {
    static let shared = HabitCoreDataContainerCache()

    private var containers: [String: NSPersistentContainer] = [:]
    private let lock = NSLock()

    func container(
        storeURL: URL,
        backend: HabitCoreDataBackend,
        make: () throws -> NSPersistentContainer
    ) throws -> NSPersistentContainer {
        let key = "\(backend.cacheKey)|\(storeURL.standardizedFileURL.path)"
        lock.lock()
        defer { lock.unlock() }

        if let container = containers[key] {
            return container
        }

        let container = try make()
        containers[key] = container
        return container
    }

    func remove(storeURL: URL, backend: HabitCoreDataBackend) {
        let key = "\(backend.cacheKey)|\(storeURL.standardizedFileURL.path)"
        lock.lock()
        containers[key] = nil
        lock.unlock()
    }
}

struct HabitCoreDataStore: HabitSyncStore {
    let storeURL: URL
    var backend: HabitCoreDataBackend = .local

    func addHabit(
        title: String,
        startDate: Date,
        todayOnly: Bool,
        id: UUID = UUID()
    ) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        let dateKey = HabitDate.key(for: startDate)
        let container = try makeContainer()
        let context = container.viewContext

        let existing = try fetchObjects(entityName: HabitCoreDataEntity.habit, id: id, in: context)
        if let entity = latestObject(from: existing) {
            deleteObjects(except: entity, from: existing, in: context)
            if context.hasChanges {
                try context.save()
            }
            return
        }

        let maxOrder = try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context)
            .compactMap { orderIndex(from: $0) }
            .max() ?? -1

        let entity = NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.habit, into: context)
        entity.setValue(id, forKey: "id")
        entity.setValue(trimmed, forKey: "title")
        entity.setValue(trimmed, forKey: "baseTitle")
        entity.setValue(Int64(maxOrder + 1), forKey: "orderIndex")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")
        entity.setValue(dateKey, forKey: "startDateKey")
        entity.setValue(todayOnly ? dateKey : nil, forKey: "endDateKey")
        entity.setValue(HabitRepeatKind.daily.rawValue, forKey: "repeatKind")
        entity.setValue("", forKey: "repeatWeekdays")
        entity.setValue("{}", forKey: "titleHistoryJSON")

        try context.save()
    }

    func setDone(_ isDone: Bool, habitID: UUID, on date: Date) throws {
        let dateKey = HabitDate.key(for: date)
        let container = try makeContainer()
        let context = container.viewContext
        let matches = try fetchObjects(
            entityName: HabitCoreDataEntity.entry,
            dateKey: dateKey,
            habitID: habitID,
            in: context
        )

        let entity = latestObject(from: matches)
            ?? NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.entry, into: context)
        deleteObjects(except: entity, from: matches, in: context)
        if entity.isInserted {
            entity.setValue(UUID(), forKey: "id")
            entity.setValue(habitID, forKey: "habitID")
            entity.setValue(dateKey, forKey: "dateKey")
            entity.setValue(Date(), forKey: "createdAt")
        }
        entity.setValue(isDone, forKey: "isDone")
        entity.setValue(Date(), forKey: "updatedAt")

        try context.save()
    }

    func toggleDone(habitID: UUID, on date: Date) throws {
        let dateKey = HabitDate.key(for: date)
        let container = try makeContainer()
        let context = container.viewContext
        let current = latestEntryDoneByHabitID(from: try fetchObjects(
            entityName: HabitCoreDataEntity.entry,
            dateKey: dateKey,
            habitID: habitID,
            in: context
        ))[habitID] ?? false

        try setDone(!current, habitID: habitID, on: date)
    }

    func updateRepeatRule(habitID: UUID, rule: HabitRepeatRule) throws {
        let container = try makeContainer()
        let context = container.viewContext
        guard let habit = try fetchHabit(id: habitID, in: context) else { return }
        let normalized = rule.normalized()

        habit.setValue(normalized.kind.rawValue, forKey: "repeatKind")
        habit.setValue(normalized.weekdays.map(String.init).joined(separator: ","), forKey: "repeatWeekdays")
        habit.setValue(Date(), forKey: "updatedAt")

        try context.save()
    }

    func reorderHabits(orderedIDs: [UUID]) throws {
        let container = try makeContainer()
        let context = container.viewContext
        let orderByID = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($1, $0) })

        for habit in try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context) {
            guard let habitID = habit.value(forKey: "id") as? UUID,
                  let orderIndex = orderByID[habitID]
            else {
                continue
            }
            habit.setValue(Int64(orderIndex), forKey: "orderIndex")
            habit.setValue(Date(), forKey: "updatedAt")
        }

        try context.save()
    }

    func renameHabitForDay(habitID: UUID, title: String, on date: Date) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        let dateKey = HabitDate.key(for: date)
        let container = try makeContainer()
        let context = container.viewContext
        let matches = try fetchObjects(
            entityName: HabitCoreDataEntity.dailyOverride,
            dateKey: dateKey,
            habitID: habitID,
            in: context
        )

        let entity = latestObject(from: matches)
            ?? NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.dailyOverride, into: context)
        deleteObjects(except: entity, from: matches, in: context)
        if entity.isInserted {
            entity.setValue(UUID(), forKey: "id")
            entity.setValue(habitID, forKey: "habitID")
            entity.setValue(dateKey, forKey: "dateKey")
            entity.setValue(Date(), forKey: "createdAt")
        }
        entity.setValue(trimmed, forKey: "title")
        entity.setValue(Date(), forKey: "updatedAt")

        try context.save()
    }

    func renameHabitFromDate(habitID: UUID, title: String, from date: Date) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        let dateKey = HabitDate.key(for: date)
        let container = try makeContainer()
        let context = container.viewContext
        guard let habit = try fetchHabit(id: habitID, in: context) else { return }
        let oldTitle = resolvedTitle(for: habit, on: dateKey)
        let history = titleHistory(from: habit)
        var updatedHistory = history
        updatedHistory[dateKey] = trimmed

        habit.setValue(trimmed, forKey: "title")
        if (habit.value(forKey: "baseTitle") as? String ?? "").isEmpty {
            habit.setValue(oldTitle, forKey: "baseTitle")
        }
        habit.setValue(encodeJSONString(updatedHistory), forKey: "titleHistoryJSON")
        habit.setValue(Date(), forKey: "updatedAt")

        for object in try fetchObjects(
            entityName: HabitCoreDataEntity.dailyOverride,
            dateKey: dateKey,
            habitID: habitID,
            in: context
        ) {
            context.delete(object)
        }

        try context.save()
    }

    func hideHabitForDay(habitID: UUID, on date: Date) throws {
        let dateKey = HabitDate.key(for: date)
        let container = try makeContainer()
        let context = container.viewContext
        let existing = try fetchObjects(
            entityName: HabitCoreDataEntity.hiddenHabit,
            dateKey: dateKey,
            habitID: habitID,
            in: context
        )
        if let entity = latestObject(from: existing) {
            deleteObjects(except: entity, from: existing, in: context)
            if context.hasChanges {
                try context.save()
            }
            return
        }

        let entity = NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.hiddenHabit, into: context)
        entity.setValue(UUID(), forKey: "id")
        entity.setValue(habitID, forKey: "habitID")
        entity.setValue(dateKey, forKey: "dateKey")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")

        try context.save()
    }

    func endHabitFromDate(habitID: UUID, from date: Date) throws {
        let container = try makeContainer()
        let context = container.viewContext
        guard let habit = try fetchHabit(id: habitID, in: context) else { return }

        let previousDay = HabitDate.calendar.date(
            byAdding: .day,
            value: -1,
            to: HabitDate.startOfDay(date)
        ) ?? date
        let dateKey = HabitDate.key(for: date)

        habit.setValue(HabitDate.key(for: previousDay), forKey: "endDateKey")
        habit.setValue(Date(), forKey: "updatedAt")
        for object in try fetchObjects(
            entityName: HabitCoreDataEntity.hiddenHabit,
            dateKey: dateKey,
            habitID: habitID,
            in: context
        ) {
            context.delete(object)
        }

        try context.save()
    }

    func deleteHabit(habitID: UUID) throws {
        let container = try makeContainer()
        let context = container.viewContext
        if let habit = try fetchHabit(id: habitID, in: context) {
            habit.setValue(Date(), forKey: "deletedAt")
            habit.setValue(Date(), forKey: "updatedAt")
        }
        for entityName in [
            HabitCoreDataEntity.entry,
            HabitCoreDataEntity.dailyOverride,
            HabitCoreDataEntity.hiddenHabit
        ] {
            for object in try fetchObjects(entityName: entityName, habitID: habitID, in: context) {
                context.delete(object)
            }
        }

        try context.save()
    }

    func replaceAll(with state: AppState) throws -> HabitCoreDataImportSummary {
        let container = try makeContainer()
        let context = container.viewContext

        let deletedHabitMarkers = try fetchDeletedHabitMarkers(in: context)
        try reset(in: context)
        let summary = try importState(state, into: context, skippingHabitIDs: Set(deletedHabitMarkers.keys))
        try importDeletedHabitMarkers(deletedHabitMarkers, into: context)
        try context.save()

        return summary
    }

    func mergeImport(_ state: AppState) throws -> HabitCoreDataImportSummary {
        let container = try makeContainer()
        let context = container.viewContext
        let deletedHabitMarkers = try fetchDeletedHabitMarkers(in: context)
        let summary = try importState(
            state,
            into: context,
            skippingHabitIDs: Set(deletedHabitMarkers.keys),
            mergeExisting: true
        )
        try importDeletedHabitMarkers(deletedHabitMarkers, into: context)
        try context.save()

        return summary
    }

    func clearStoreFile() throws {
        if FileManager.default.fileExists(atPath: storeURL.path) {
            let container = try makeContainer()
            try container.persistentStoreCoordinator.destroyPersistentStore(
                at: storeURL,
                ofType: NSSQLiteStoreType
            )
        }
        HabitCoreDataContainerCache.shared.remove(storeURL: storeURL, backend: backend)

        for url in storeFileURLs() {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try FileManager.default.removeItem(at: url)
        }
    }

    func daySummary(for date: Date = .now) throws -> HabitCoreDataDaySummary {
        let snapshot = try daySnapshot(for: date)
        let dateKey = HabitDate.key(for: date)
        let container = try makeContainer()
        let context = container.viewContext
        let habits = latestHabitObjectsByID(from: try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context))
        let overrides = try fetchObjects(entityName: HabitCoreDataEntity.dailyOverride, dateKey: dateKey, in: context)
        let hidden = try fetchObjects(entityName: HabitCoreDataEntity.hiddenHabit, dateKey: dateKey, in: context)

        return HabitCoreDataDaySummary(
            dateKey: dateKey,
            totalHabitCount: habits.count,
            visibleHabitCount: snapshot.totalCount,
            doneCount: snapshot.doneCount,
            overrideCount: overrides.count,
            hiddenCount: hidden.count,
            visibleTitles: snapshot.habits.map(\.title),
            snapshot: snapshot
        )
    }

    func daySnapshot(for date: Date) throws -> HabitDaySnapshot {
        let dateKey = HabitDate.key(for: date)
        let container = try makeContainer()
        let context = container.viewContext
        let habits = latestHabitObjectsByID(from: try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context))
        let entries = try fetchObjects(entityName: HabitCoreDataEntity.entry, dateKey: dateKey, in: context)
        let overrides = try fetchObjects(entityName: HabitCoreDataEntity.dailyOverride, dateKey: dateKey, in: context)
        let hidden = try fetchObjects(entityName: HabitCoreDataEntity.hiddenHabit, dateKey: dateKey, in: context)

        let hiddenIDs = Set(hidden.compactMap { $0.value(forKey: "habitID") as? UUID })
        let doneByHabitID = latestEntryDoneByHabitID(from: entries)
        let titleByHabitID = latestDailyOverrideTitles(from: overrides)

        let items = habits
            .compactMap { object -> (Int, Date, String, HabitDaySnapshotItem)? in
                guard let habitID = object.value(forKey: "id") as? UUID,
                      object.value(forKey: "deletedAt") as? Date == nil,
                      hiddenIDs.contains(habitID) == false,
                      habitApplies(object, on: dateKey)
                else {
                    return nil
                }
                let orderIndex = orderIndex(from: object) ?? Int.max
                let createdAt = object.value(forKey: "createdAt") as? Date ?? .now
                let title = titleByHabitID[habitID] ?? resolvedTitle(for: object, on: dateKey)
                return (
                    orderIndex,
                    createdAt,
                    habitID.uuidString,
                    HabitDaySnapshotItem(
                        id: habitID,
                        title: title,
                        isDone: doneByHabitID[habitID] ?? false,
                        repeatRule: repeatRule(from: object)
                    )
                )
            }
            .sorted { isOrderedBefore(lhs: ($0.0, $0.1, $0.2), rhs: ($1.0, $1.1, $1.2)) }
            .map(\.3)

        return HabitDaySnapshot(dateKey: dateKey, habits: items)
    }

    func loadAppState() throws -> AppState {
        let container = try makeContainer()
        let context = container.viewContext
        let habitObjects = latestHabitObjectsByID(from: try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context))
        let entryObjects = try fetchObjects(entityName: HabitCoreDataEntity.entry, in: context)
        let overrideObjects = try fetchObjects(entityName: HabitCoreDataEntity.dailyOverride, in: context)
        let hiddenObjects = try fetchObjects(entityName: HabitCoreDataEntity.hiddenHabit, in: context)

        let habits = habitObjects
            .compactMap { habit(from: $0) }
            .sorted {
                isOrderedBefore(
                    lhs: ($0.orderIndex, $0.habit.createdAt, $0.habit.id.uuidString),
                    rhs: ($1.orderIndex, $1.habit.createdAt, $1.habit.id.uuidString)
                )
            }
            .map { $0.habit }

        var latestEntries: [String: [UUID: (isDone: Bool, updatedAt: Date)]] = [:]
        for object in entryObjects {
            guard let dateKey = object.value(forKey: "dateKey") as? String,
                  let habitID = object.value(forKey: "habitID") as? UUID
            else {
                continue
            }
            let isDone = object.value(forKey: "isDone") as? Bool ?? false
            let updatedAt = object.value(forKey: "updatedAt") as? Date ?? .distantPast
            if let existing = latestEntries[dateKey]?[habitID], existing.updatedAt > updatedAt {
                continue
            }
            latestEntries[dateKey, default: [:]][habitID] = (isDone, updatedAt)
        }
        let entries = latestEntries.mapValues { values in
            values.mapValues(\.isDone)
        }

        var latestDailyOverrides: [String: [UUID: (title: String, updatedAt: Date)]] = [:]
        for object in overrideObjects {
            guard let dateKey = object.value(forKey: "dateKey") as? String,
                  let habitID = object.value(forKey: "habitID") as? UUID,
                  let title = object.value(forKey: "title") as? String
            else {
                continue
            }
            let updatedAt = object.value(forKey: "updatedAt") as? Date ?? .distantPast
            if let existing = latestDailyOverrides[dateKey]?[habitID], existing.updatedAt > updatedAt {
                continue
            }
            latestDailyOverrides[dateKey, default: [:]][habitID] = (title, updatedAt)
        }
        let dailyOverrides = latestDailyOverrides.mapValues { values in
            values.mapValues(\.title)
        }

        var hiddenHabitIDs: [String: Set<UUID>] = [:]
        for object in hiddenObjects {
            guard let dateKey = object.value(forKey: "dateKey") as? String,
                  let habitID = object.value(forKey: "habitID") as? UUID
            else {
                continue
            }
            hiddenHabitIDs[dateKey, default: []].insert(habitID)
        }
        let hiddenHabits = hiddenHabitIDs.mapValues { ids in
            ids.sorted { $0.uuidString < $1.uuidString }
        }

        return AppState(
            habits: habits,
            entries: entries,
            dailyOverrides: dailyOverrides,
            hiddenHabits: hiddenHabits,
            reminders: [],
            uiPreferences: .default,
            focusSession: .default
        )
    }

    private func makeContainer() throws -> NSPersistentContainer {
        try HabitCoreDataContainerCache.shared.container(storeURL: storeURL, backend: backend) {
            switch backend {
            case .local:
                return try HabitCoreDataStack.makeLocalContainer(storeURL: storeURL)
            case .cloudKit:
                return try HabitCoreDataStack.makeCloudKitContainer(storeURL: storeURL)
            }
        }
    }

    private func storeFileURLs() -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: "\(storeURL.path)-wal"),
            URL(fileURLWithPath: "\(storeURL.path)-shm")
        ]
    }

    private func reset(in context: NSManagedObjectContext) throws {
        for entityName in HabitCoreDataEntity.all {
            for object in try fetchObjects(entityName: entityName, in: context) {
                context.delete(object)
            }
        }
    }

    private func importState(
        _ state: AppState,
        into context: NSManagedObjectContext,
        skippingHabitIDs skippedHabitIDs: Set<UUID> = [],
        mergeExisting: Bool = false
    ) throws -> HabitCoreDataImportSummary {
        var entryCount = 0
        var dailyOverrideCount = 0
        var hiddenHabitCount = 0

        var importedHabitIDs = Set<UUID>()
        var nextOrderIndex = 0
        for habit in state.habits where skippedHabitIDs.contains(habit.id) == false {
            guard importedHabitIDs.contains(habit.id) == false else { continue }
            importedHabitIDs.insert(habit.id)
            let entity = try importedObject(
                entityName: HabitCoreDataEntity.habit,
                id: habit.id,
                mergeExisting: mergeExisting,
                in: context
            )
            applyHabit(habit, orderIndex: nextOrderIndex, to: entity)
            nextOrderIndex += 1
        }

        for (dateKey, entries) in state.entries {
            for (habitID, isDone) in entries {
                guard importedHabitIDs.contains(habitID) else { continue }
                let entity = try importedObject(
                    entityName: HabitCoreDataEntity.entry,
                    dateKey: dateKey,
                    habitID: habitID,
                    mergeExisting: mergeExisting,
                    in: context
                )
                if entity.isInserted {
                    entity.setValue(UUID(), forKey: "id")
                }
                entity.setValue(habitID, forKey: "habitID")
                entity.setValue(dateKey, forKey: "dateKey")
                entity.setValue(isDone, forKey: "isDone")
                if entity.isInserted {
                    entity.setValue(Date(), forKey: "createdAt")
                }
                entity.setValue(Date(), forKey: "updatedAt")
                entryCount += 1
            }
        }

        for (dateKey, overrides) in state.dailyOverrides {
            for (habitID, title) in overrides {
                guard importedHabitIDs.contains(habitID) else { continue }
                let entity = try importedObject(
                    entityName: HabitCoreDataEntity.dailyOverride,
                    dateKey: dateKey,
                    habitID: habitID,
                    mergeExisting: mergeExisting,
                    in: context
                )
                if entity.isInserted {
                    entity.setValue(UUID(), forKey: "id")
                }
                entity.setValue(habitID, forKey: "habitID")
                entity.setValue(dateKey, forKey: "dateKey")
                entity.setValue(title, forKey: "title")
                if entity.isInserted {
                    entity.setValue(Date(), forKey: "createdAt")
                }
                entity.setValue(Date(), forKey: "updatedAt")
                dailyOverrideCount += 1
            }
        }

        for (dateKey, hiddenIDs) in state.hiddenHabits {
            for habitID in hiddenIDs {
                guard importedHabitIDs.contains(habitID) else { continue }
                let entity = try importedObject(
                    entityName: HabitCoreDataEntity.hiddenHabit,
                    dateKey: dateKey,
                    habitID: habitID,
                    mergeExisting: mergeExisting,
                    in: context
                )
                if entity.isInserted {
                    entity.setValue(UUID(), forKey: "id")
                }
                entity.setValue(habitID, forKey: "habitID")
                entity.setValue(dateKey, forKey: "dateKey")
                if entity.isInserted {
                    entity.setValue(Date(), forKey: "createdAt")
                }
                entity.setValue(Date(), forKey: "updatedAt")
                hiddenHabitCount += 1
            }
        }

        return HabitCoreDataImportSummary(
            habitCount: importedHabitIDs.count,
            entryCount: entryCount,
            dailyOverrideCount: dailyOverrideCount,
            hiddenHabitCount: hiddenHabitCount
        )
    }

    private func importedObject(
        entityName: String,
        id: UUID,
        mergeExisting: Bool,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        guard mergeExisting else {
            return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        }
        let matches = try fetchObjects(entityName: entityName, id: id, in: context)
        let entity = latestObject(from: matches)
            ?? NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        deleteObjects(except: entity, from: matches, in: context)
        return entity
    }

    private func importedObject(
        entityName: String,
        dateKey: String,
        habitID: UUID,
        mergeExisting: Bool,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        guard mergeExisting else {
            return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        }
        let matches = try fetchObjects(
            entityName: entityName,
            dateKey: dateKey,
            habitID: habitID,
            in: context
        )
        let entity = latestObject(from: matches)
            ?? NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        deleteObjects(except: entity, from: matches, in: context)
        return entity
    }

    private func applyHabit(_ habit: HabitItem, orderIndex: Int, to entity: NSManagedObject) {
        entity.setValue(habit.id, forKey: "id")
        entity.setValue(habit.title, forKey: "title")
        entity.setValue(habit.baseTitle, forKey: "baseTitle")
        entity.setValue(Int64(orderIndex), forKey: "orderIndex")
        entity.setValue(habit.createdAt, forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")
        entity.setValue(nil, forKey: "deletedAt")
        entity.setValue(habit.startDateKey, forKey: "startDateKey")
        entity.setValue(habit.endDateKey, forKey: "endDateKey")
        let repeatRule = habit.repeatRule.normalized()
        entity.setValue(repeatRule.kind.rawValue, forKey: "repeatKind")
        entity.setValue(repeatRule.weekdays.map(String.init).joined(separator: ","), forKey: "repeatWeekdays")
        entity.setValue(encodeJSONString(habit.titleHistory), forKey: "titleHistoryJSON")
    }

    private func fetchDeletedHabitMarkers(in context: NSManagedObjectContext) throws -> [UUID: HabitDeletedMarker] {
        let habitObjects = try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context)
        var markers: [UUID: HabitDeletedMarker] = [:]
        for object in habitObjects {
            guard let id = object.value(forKey: "id") as? UUID,
                  let deletedAt = object.value(forKey: "deletedAt") as? Date
            else {
                continue
            }
            let marker = HabitDeletedMarker(
                createdAt: object.value(forKey: "createdAt") as? Date ?? deletedAt,
                updatedAt: object.value(forKey: "updatedAt") as? Date ?? deletedAt,
                deletedAt: deletedAt
            )
            if let existing = markers[id], existing.deletedAt > marker.deletedAt {
                continue
            }
            markers[id] = marker
        }
        return markers
    }

    private func importDeletedHabitMarkers(_ markers: [UUID: HabitDeletedMarker], into context: NSManagedObjectContext) throws {
        for (habitID, marker) in markers {
            let matches = try fetchObjects(entityName: HabitCoreDataEntity.habit, id: habitID, in: context)
            let entity = latestObject(from: matches)
                ?? NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.habit, into: context)
            deleteObjects(except: entity, from: matches, in: context)
            entity.setValue(habitID, forKey: "id")
            entity.setValue("", forKey: "title")
            entity.setValue("", forKey: "baseTitle")
            entity.setValue(Int64.max, forKey: "orderIndex")
            entity.setValue(marker.createdAt, forKey: "createdAt")
            entity.setValue(marker.updatedAt, forKey: "updatedAt")
            entity.setValue(marker.deletedAt, forKey: "deletedAt")
            entity.setValue(HabitRepeatKind.daily.rawValue, forKey: "repeatKind")
            entity.setValue("", forKey: "repeatWeekdays")
            entity.setValue("{}", forKey: "titleHistoryJSON")
        }
    }

    private func fetchObjects(
        entityName: String,
        id: UUID? = nil,
        dateKey: String? = nil,
        habitID: UUID? = nil,
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        var predicates: [NSPredicate] = []
        if let id {
            predicates.append(NSPredicate(format: "id == %@", id as CVarArg))
        }
        if let dateKey {
            predicates.append(NSPredicate(format: "dateKey == %@", dateKey))
        }
        if let habitID {
            predicates.append(NSPredicate(format: "habitID == %@", habitID as CVarArg))
        }
        if predicates.isEmpty == false {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        return try context.fetch(request)
    }

    private func fetchHabit(id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let matches = try fetchObjects(entityName: HabitCoreDataEntity.habit, id: id, in: context)
        guard let entity = latestObject(from: matches) else { return nil }
        deleteObjects(except: entity, from: matches, in: context)
        return entity
    }

    private func resolvedTitle(for habit: NSManagedObject, on dateKey: String) -> String {
        let selected = HabitDate.date(from: dateKey)
        let effective = titleHistory(from: habit)
            .sorted { $0.key < $1.key }
            .last(where: { HabitDate.date(from: $0.key) <= selected })

        return effective?.value
            ?? habit.value(forKey: "baseTitle") as? String
            ?? habit.value(forKey: "title") as? String
            ?? "未命名"
    }

    private func titleHistory(from habit: NSManagedObject) -> [String: String] {
        guard let text = habit.value(forKey: "titleHistoryJSON") as? String,
              let data = text.data(using: .utf8),
              let history = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return history
    }

    private func habitApplies(_ object: NSManagedObject, on dateKey: String) -> Bool {
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

    private func repeatRule(from object: NSManagedObject) -> HabitRepeatRule {
        let repeatKindText = object.value(forKey: "repeatKind") as? String ?? HabitRepeatKind.daily.rawValue
        let repeatKind = HabitRepeatKind(rawValue: repeatKindText) ?? .daily
        let repeatWeekdays = (object.value(forKey: "repeatWeekdays") as? String ?? "")
            .split(separator: ",")
            .compactMap { Int($0) }
        return HabitRepeatRule(kind: repeatKind, weekdays: repeatWeekdays).normalized()
    }

    private func habit(from object: NSManagedObject) -> (habit: HabitItem, orderIndex: Int)? {
        guard let id = object.value(forKey: "id") as? UUID else { return nil }
        if object.value(forKey: "deletedAt") as? Date != nil {
            return nil
        }
        let title = object.value(forKey: "title") as? String ?? "未命名"
        let baseTitle = object.value(forKey: "baseTitle") as? String ?? title
        let createdAt = object.value(forKey: "createdAt") as? Date ?? .now
        let startDateKey = object.value(forKey: "startDateKey") as? String
        let endDateKey = object.value(forKey: "endDateKey") as? String
        let orderIndex = orderIndex(from: object) ?? Int.max

        return (
            HabitItem(
                id: id,
                title: title,
                createdAt: createdAt,
                startDateKey: startDateKey,
                endDateKey: endDateKey,
                repeatRule: repeatRule(from: object),
                baseTitle: baseTitle,
                titleHistory: titleHistory(from: object)
            ),
            orderIndex
        )
    }

    private func encodeJSONString<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return text
    }

    private func orderIndex(from object: NSManagedObject) -> Int? {
        let value = object.value(forKey: "orderIndex")
        if let int = value as? Int {
            return int
        }
        if let int64 = value as? Int64 {
            return Int(int64)
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func latestDailyOverrideTitles(from objects: [NSManagedObject]) -> [UUID: String] {
        var titles: [UUID: (title: String, updatedAt: Date)] = [:]
        for object in objects {
            guard let habitID = object.value(forKey: "habitID") as? UUID,
                  let title = object.value(forKey: "title") as? String
            else {
                continue
            }
            let updatedAt = object.value(forKey: "updatedAt") as? Date ?? .distantPast
            if let existing = titles[habitID], existing.updatedAt > updatedAt {
                continue
            }
            titles[habitID] = (title, updatedAt)
        }
        return titles.mapValues(\.title)
    }

    private func latestEntryDoneByHabitID(from objects: [NSManagedObject]) -> [UUID: Bool] {
        var entries: [UUID: (isDone: Bool, updatedAt: Date)] = [:]
        for object in objects {
            guard let habitID = object.value(forKey: "habitID") as? UUID else {
                continue
            }
            let isDone = object.value(forKey: "isDone") as? Bool ?? false
            let updatedAt = object.value(forKey: "updatedAt") as? Date ?? .distantPast
            if let existing = entries[habitID], existing.updatedAt > updatedAt {
                continue
            }
            entries[habitID] = (isDone, updatedAt)
        }
        return entries.mapValues(\.isDone)
    }

    private func latestObject(from objects: [NSManagedObject]) -> NSManagedObject? {
        objects.max {
            let lhsDeletedAt = $0.value(forKey: "deletedAt") as? Date
            let rhsDeletedAt = $1.value(forKey: "deletedAt") as? Date
            switch (lhsDeletedAt, rhsDeletedAt) {
            case let (lhs?, rhs?) where lhs != rhs:
                return lhs < rhs
            case (_?, nil):
                return false
            case (nil, _?):
                return true
            default:
                break
            }
            let lhsUpdatedAt = $0.value(forKey: "updatedAt") as? Date ?? .distantPast
            let rhsUpdatedAt = $1.value(forKey: "updatedAt") as? Date ?? .distantPast
            if lhsUpdatedAt != rhsUpdatedAt {
                return lhsUpdatedAt < rhsUpdatedAt
            }
            let lhsCreatedAt = $0.value(forKey: "createdAt") as? Date ?? .distantPast
            let rhsCreatedAt = $1.value(forKey: "createdAt") as? Date ?? .distantPast
            return lhsCreatedAt < rhsCreatedAt
        }
    }

    private func latestHabitObjectsByID(from objects: [NSManagedObject]) -> [NSManagedObject] {
        var habits: [UUID: NSManagedObject] = [:]
        for object in objects {
            guard let id = object.value(forKey: "id") as? UUID else {
                continue
            }
            guard let existing = habits[id] else {
                habits[id] = object
                continue
            }
            habits[id] = latestObject(from: [existing, object])
        }
        return Array(habits.values)
    }

    private func deleteObjects(
        except preservedObject: NSManagedObject,
        from objects: [NSManagedObject],
        in context: NSManagedObjectContext
    ) {
        for object in objects where object.objectID != preservedObject.objectID {
            context.delete(object)
        }
    }

    private func isOrderedBefore(
        lhs: (orderIndex: Int, createdAt: Date, id: String),
        rhs: (orderIndex: Int, createdAt: Date, id: String)
    ) -> Bool {
        if lhs.orderIndex != rhs.orderIndex {
            return lhs.orderIndex < rhs.orderIndex
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id < rhs.id
    }
}
