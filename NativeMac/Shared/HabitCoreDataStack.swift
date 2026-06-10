import CoreData
import Foundation

enum HabitCoreDataEntity {
    static let habit = "HabitEntity"
    static let entry = "HabitEntryEntity"
    static let dailyOverride = "DailyOverrideEntity"
    static let hiddenHabit = "HiddenHabitEntity"

    static let all = [habit, entry, dailyOverride, hiddenHabit]
}

enum HabitCoreDataStack {
    static let modelName = "KiteHabitModel"
    static let cloudKitContainerIdentifier = "iCloud.cn.kitlib.kite"

    static func makeLocalContainer(storeURL: URL) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(
            name: modelName,
            managedObjectModel: makeModel()
        )
        let description = makeStoreDescription(storeURL: storeURL)
        container.persistentStoreDescriptions = [description]
        try load(container)
        configureContext(container.viewContext)
        return container
    }

    static func makeCloudKitContainer(storeURL: URL) throws -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(
            name: modelName,
            managedObjectModel: makeModel()
        )
        let description = makeStoreDescription(storeURL: storeURL)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: cloudKitContainerIdentifier
        )
        container.persistentStoreDescriptions = [description]
        try load(container)
        configureContext(container.viewContext)
        return container
    }

    private static func makeStoreDescription(storeURL: URL) -> NSPersistentStoreDescription {
        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        return description
    }

    private static func load(_ container: NSPersistentContainer) throws {
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError {
            throw loadError
        }
    }

    private static func configureContext(_ context: NSManagedObjectContext) {
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
    }

    static func makeModel() -> NSManagedObjectModel {
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
            name: HabitCoreDataEntity.habit,
            properties: [
                attribute("id", .UUIDAttributeType, optional: false, defaultValue: UUID()),
                attribute("title", .stringAttributeType, optional: false, defaultValue: ""),
                attribute("baseTitle", .stringAttributeType, optional: false, defaultValue: ""),
                attribute("orderIndex", .integer64AttributeType, defaultValue: 0),
                attribute("createdAt", .dateAttributeType, optional: false, defaultValue: Date(timeIntervalSince1970: 0)),
                attribute("updatedAt", .dateAttributeType, optional: false, defaultValue: Date(timeIntervalSince1970: 0)),
                attribute("deletedAt", .dateAttributeType),
                attribute("startDateKey", .stringAttributeType),
                attribute("endDateKey", .stringAttributeType),
                attribute("repeatKind", .stringAttributeType, optional: false, defaultValue: HabitRepeatKind.daily.rawValue),
                attribute("repeatWeekdays", .stringAttributeType, optional: false, defaultValue: ""),
                attribute("titleHistoryJSON", .stringAttributeType, optional: false, defaultValue: "{}")
            ]
        )
    }

    private static func makeHabitEntryEntity() -> NSEntityDescription {
        makeEntity(
            name: HabitCoreDataEntity.entry,
            properties: datedHabitProperties() + [
                attribute("isDone", .booleanAttributeType, optional: false, defaultValue: false)
            ]
        )
    }

    private static func makeDailyOverrideEntity() -> NSEntityDescription {
        makeEntity(
            name: HabitCoreDataEntity.dailyOverride,
            properties: datedHabitProperties() + [
                attribute("title", .stringAttributeType, optional: false, defaultValue: "")
            ]
        )
    }

    private static func makeHiddenHabitEntity() -> NSEntityDescription {
        makeEntity(
            name: HabitCoreDataEntity.hiddenHabit,
            properties: datedHabitProperties()
        )
    }

    private static func datedHabitProperties() -> [NSAttributeDescription] {
        [
            attribute("id", .UUIDAttributeType, optional: false, defaultValue: UUID()),
            attribute("habitID", .UUIDAttributeType, optional: false, defaultValue: UUID()),
            attribute("dateKey", .stringAttributeType, optional: false, defaultValue: ""),
            attribute("createdAt", .dateAttributeType, optional: false, defaultValue: Date(timeIntervalSince1970: 0)),
            attribute("updatedAt", .dateAttributeType, optional: false, defaultValue: Date(timeIntervalSince1970: 0)),
            attribute("deletedAt", .dateAttributeType)
        ]
    }

    private static func makeEntity(
        name: String,
        properties: [NSPropertyDescription]
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = properties
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = true,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
