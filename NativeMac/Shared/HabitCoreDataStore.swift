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
        let maxOrder = try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context)
            .compactMap { $0.value(forKey: "orderIndex") as? Int }
            .max() ?? -1

        let entity = NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.habit, into: context)
        entity.setValue(id, forKey: "id")
        entity.setValue(trimmed, forKey: "title")
        entity.setValue(trimmed, forKey: "baseTitle")
        entity.setValue(maxOrder + 1, forKey: "orderIndex")
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

        let entity = matches.first
            ?? NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.entry, into: context)
        if matches.isEmpty {
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
        let current = try fetchObjects(
            entityName: HabitCoreDataEntity.entry,
            dateKey: dateKey,
            habitID: habitID,
            in: context
        )
        .first?
        .value(forKey: "isDone") as? Bool ?? false

        try setDone(!current, habitID: habitID, on: date)
    }

    func updateRepeatRule(habitID: UUID, rule: HabitRepeatRule) throws {
        let container = try makeContainer()
        let context = container.viewContext
        guard let habit = try fetchHabit(id: habitID, in: context) else { return }

        habit.setValue(rule.kind.rawValue, forKey: "repeatKind")
        habit.setValue(rule.weekdays.map(String.init).joined(separator: ","), forKey: "repeatWeekdays")
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
            habit.setValue(orderIndex, forKey: "orderIndex")
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

        let entity = matches.first
            ?? NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.dailyOverride, into: context)
        if matches.isEmpty {
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
        guard existing.isEmpty else { return }

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
            context.delete(habit)
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

        try reset(in: context)
        let summary = importState(state, into: context)
        try context.save()

        return summary
    }

    func clearStoreFile() throws {
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
        let habits = try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context)
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
        let habits = try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context)
        let entries = try fetchObjects(entityName: HabitCoreDataEntity.entry, dateKey: dateKey, in: context)
        let overrides = try fetchObjects(entityName: HabitCoreDataEntity.dailyOverride, dateKey: dateKey, in: context)
        let hidden = try fetchObjects(entityName: HabitCoreDataEntity.hiddenHabit, dateKey: dateKey, in: context)

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

        let items = habits
            .compactMap { object -> (Int, HabitDaySnapshotItem)? in
                guard let habitID = object.value(forKey: "id") as? UUID,
                      hiddenIDs.contains(habitID) == false,
                      habitApplies(object, on: dateKey)
                else {
                    return nil
                }
                let orderIndex = object.value(forKey: "orderIndex") as? Int ?? Int.max
                let title = titleByHabitID[habitID] ?? resolvedTitle(for: object, on: dateKey)
                return (
                    orderIndex,
                    HabitDaySnapshotItem(
                        id: habitID,
                        title: title,
                        isDone: doneIDs.contains(habitID),
                        repeatRule: repeatRule(from: object)
                    )
                )
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)

        return HabitDaySnapshot(dateKey: dateKey, habits: items)
    }

    func loadAppState() throws -> AppState {
        let container = try makeContainer()
        let context = container.viewContext
        let habitObjects = try fetchObjects(entityName: HabitCoreDataEntity.habit, in: context)
        let entryObjects = try fetchObjects(entityName: HabitCoreDataEntity.entry, in: context)
        let overrideObjects = try fetchObjects(entityName: HabitCoreDataEntity.dailyOverride, in: context)
        let hiddenObjects = try fetchObjects(entityName: HabitCoreDataEntity.hiddenHabit, in: context)

        let habits = habitObjects
            .compactMap { habit(from: $0) }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { $0.habit }

        var entries: [String: [UUID: Bool]] = [:]
        for object in entryObjects {
            guard let dateKey = object.value(forKey: "dateKey") as? String,
                  let habitID = object.value(forKey: "habitID") as? UUID
            else {
                continue
            }
            entries[dateKey, default: [:]][habitID] = object.value(forKey: "isDone") as? Bool ?? false
        }

        var dailyOverrides: [String: [UUID: String]] = [:]
        for object in overrideObjects {
            guard let dateKey = object.value(forKey: "dateKey") as? String,
                  let habitID = object.value(forKey: "habitID") as? UUID,
                  let title = object.value(forKey: "title") as? String
            else {
                continue
            }
            dailyOverrides[dateKey, default: [:]][habitID] = title
        }

        var hiddenHabits: [String: [UUID]] = [:]
        for object in hiddenObjects {
            guard let dateKey = object.value(forKey: "dateKey") as? String,
                  let habitID = object.value(forKey: "habitID") as? UUID
            else {
                continue
            }
            hiddenHabits[dateKey, default: []].append(habitID)
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
        switch backend {
        case .local:
            return try HabitCoreDataStack.makeLocalContainer(storeURL: storeURL)
        case .cloudKit:
            return try HabitCoreDataStack.makeCloudKitContainer(storeURL: storeURL)
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
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
    }

    private func importState(
        _ state: AppState,
        into context: NSManagedObjectContext
    ) -> HabitCoreDataImportSummary {
        var entryCount = 0
        var dailyOverrideCount = 0
        var hiddenHabitCount = 0

        for (index, habit) in state.habits.enumerated() {
            let entity = NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.habit, into: context)
            entity.setValue(habit.id, forKey: "id")
            entity.setValue(habit.title, forKey: "title")
            entity.setValue(habit.baseTitle, forKey: "baseTitle")
            entity.setValue(index, forKey: "orderIndex")
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
                let entity = NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.entry, into: context)
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
                let entity = NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.dailyOverride, into: context)
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
                let entity = NSEntityDescription.insertNewObject(forEntityName: HabitCoreDataEntity.hiddenHabit, into: context)
                entity.setValue(UUID(), forKey: "id")
                entity.setValue(habitID, forKey: "habitID")
                entity.setValue(dateKey, forKey: "dateKey")
                entity.setValue(Date(), forKey: "createdAt")
                entity.setValue(Date(), forKey: "updatedAt")
                hiddenHabitCount += 1
            }
        }

        return HabitCoreDataImportSummary(
            habitCount: state.habits.count,
            entryCount: entryCount,
            dailyOverrideCount: dailyOverrideCount,
            hiddenHabitCount: hiddenHabitCount
        )
    }

    private func fetchObjects(
        entityName: String,
        dateKey: String? = nil,
        habitID: UUID? = nil,
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        var predicates: [NSPredicate] = []
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
        let request = NSFetchRequest<NSManagedObject>(entityName: HabitCoreDataEntity.habit)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
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
        return HabitRepeatRule(kind: repeatKind, weekdays: repeatWeekdays)
    }

    private func habit(from object: NSManagedObject) -> (habit: HabitItem, orderIndex: Int)? {
        guard let id = object.value(forKey: "id") as? UUID else { return nil }
        let title = object.value(forKey: "title") as? String ?? "未命名"
        let baseTitle = object.value(forKey: "baseTitle") as? String ?? title
        let createdAt = object.value(forKey: "createdAt") as? Date ?? .now
        let startDateKey = object.value(forKey: "startDateKey") as? String
        let endDateKey = object.value(forKey: "endDateKey") as? String
        let orderIndex = object.value(forKey: "orderIndex") as? Int ?? Int.max

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
}
